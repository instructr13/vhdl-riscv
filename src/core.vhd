library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_textio.all;
use std.textio.all;
use work.eei.all;
use work.corectrl.all;
use work.membus_ty.all;
use work.io_ty.all;

entity core is
  port (
    clk : in    std_logic;
    rst : in    std_logic;

    i_mem_cmd   : out   t_cpu_to_mem;
    i_mem_addr  : out   t_addr;
    i_mem_wdata : out   unsigned(ILEN - 1 downto 0);
    i_mem_wmask : out   unsigned(ILEN / 8 - 1 downto 0);
    i_mem_resp  : in    t_mem_to_cpu;
    i_mem_rdata : in    unsigned(ILEN - 1 downto 0);

    d_mem_cmd   : out   t_cpu_to_mem;
    d_mem_addr  : out   t_addr;
    d_mem_wdata : out   unsigned(MEM_DATA_WIDTH - 1 downto 0);
    d_mem_wmask : out   unsigned(MEM_DATA_WIDTH / 8 - 1 downto 0);
    d_mem_resp  : in    t_mem_to_cpu;
    d_mem_rdata : in    unsigned(MEM_DATA_WIDTH - 1 downto 0);

    io_cmd  : out   t_cpu_to_io;
    io_resp : in    t_io_to_cpu
  );
end entity core;

architecture rtl of core is

  signal dbg_clock_count : unsigned(63 downto 0);

  type t_if_fifo is record
    addr : t_addr;
    bits : t_inst;
  end record t_if_fifo;

  constant IF_FIFO_LEN : natural := XLEN + ILEN;

  constant IF_FIFO_ZERO : t_if_fifo :=
  (
    addr => (others => '0'),
    bits => (others => '0')
  );

  subtype t_if_fifo_vector is std_logic_vector(IF_FIFO_LEN - 1 downto 0);

  function if_fifo_to_vector (
    r: t_if_fifo
  ) return std_logic_vector is

    variable ret : std_logic_vector(IF_FIFO_LEN - 1 downto 0);

  begin

    ret := std_logic_vector(r.addr) & r.bits;

    return ret;

  end function if_fifo_to_vector;

  function if_fifo_from_vector (
    v: std_logic_vector
  ) return t_if_fifo is

    variable ret : t_if_fifo;

    constant ADDR_LEN : natural := XLEN;
    constant INST_LEN : natural := ILEN;

    constant ADDR_LOW : natural := INST_LEN;

  begin

    ret.addr := unsigned(v(ADDR_LOW + ADDR_LEN - 1 downto ADDR_LOW));
    ret.bits := v(ADDR_LOW - 1 downto 0);

    return ret;

  end function if_fifo_from_vector;

  -- 命令フェッチ プログラムカウンタ
  signal if_pc : t_addr;
  -- フェッチ中かどうか
  signal if_is_requested : std_logic;
  -- 要求したアドレス
  signal if_pc_requested : t_addr;

  -- FIFO 制御用レジスタ
  signal if_fifo_wready       : std_logic;
  signal if_fifo_wready_two   : std_logic;
  signal if_fifo_wvalid       : std_logic;
  signal if_fifo_wdata        : t_if_fifo;
  signal if_fifo_wdata_vector : t_if_fifo_vector;
  signal if_fifo_rready       : std_logic;
  signal if_fifo_rvalid       : std_logic;
  signal if_fifo_rdata        : t_if_fifo;
  signal if_fifo_rdata_vector : t_if_fifo_vector;

  -- 命令フェッチ
  alias inst_pc   : t_addr is if_fifo_rdata.addr;
  alias inst_bits : t_inst is if_fifo_rdata.bits;

  -- 命令デコーダー
  signal inst_ctrl : t_inst_ctrl;
  signal inst_imm  : t_uintx;

  -- レジスタ

  type t_regfile is array(0 to 31) of t_uintx;

  signal regfile : t_regfile;

  alias rs1_addr : std_logic_vector(4 downto 0) is inst_bits(19 downto 15);
  alias rs2_addr : std_logic_vector(4 downto 0) is inst_bits(24 downto 20);

  signal rs1_data : t_uintx;
  signal rs2_data : t_uintx;

  function to_reg_data (
    addr: std_logic_vector;
    r: t_regfile
  ) return unsigned is

    variable ret : t_uintx;

  begin

    if (addr = (addr'range => '0')) then
      ret := (others => '0');
    else
      ret := r(to_integer(unsigned(addr)));
    end if;

    return ret;

  end function to_reg_data;

  -- ALU
  signal op1        : t_uintx;
  signal op2        : t_uintx;
  signal alu_result : t_uintx;

  -- レジスタへのライトバック
  signal rd_addr : std_logic_vector(4 downto 0);
  signal wb_data : t_uintx;

  -- メモリ読み書き
  signal inst_valid : std_logic;

  -- 命令が現在のクロックで供給されたかどうか
  signal inst_is_new : std_logic;

  signal memu_rdata : t_uintx;
  signal memu_stall : std_logic;

  -- ジャンプ
  signal control_hazard         : std_logic;
  signal control_hazard_pc_next : t_addr;

  -- 条件付きジャンプ
  signal brunit_take : std_logic;

  function inst_is_br (
    ctrl: in t_inst_ctrl
  ) return std_logic is
  begin

    if (ctrl.itype = B) then
      return '1';
    else
      return '0';
    end if;

  end function inst_is_br;

  -- CSR
  signal csru_rs1         : t_uintx;
  signal csru_rdata       : t_uintx;
  signal csru_raise_trap  : std_logic;
  signal csru_trap_vector : t_addr;

begin

  if_fifo_wdata_vector <= if_fifo_to_vector(if_fifo_wdata);
  if_fifo_rdata        <= if_fifo_from_vector(if_fifo_rdata_vector);

  reg_read : process (rs1_addr, rs2_addr, regfile) is
  begin

    rs1_data <= to_reg_data(rs1_addr, regfile);
    rs2_data <= to_reg_data(rs2_addr, regfile);

  end process reg_read;

  rd_addr <= inst_bits(11 downto 7);

  inst_valid <= if_fifo_rvalid;

  control_hazard_assign : process (inst_valid, inst_ctrl, inst_pc, inst_imm, alu_result, csru_raise_trap, csru_trap_vector, brunit_take) is
  begin

    if (inst_valid = '1' and (csru_raise_trap = '1' or inst_ctrl.is_jump = '1' or (inst_is_br(inst_ctrl) = '1' and brunit_take = '1'))) then
      control_hazard <= '1';
    else
      control_hazard <= '0';
    end if;

    if (csru_raise_trap = '1') then
      control_hazard_pc_next <= csru_trap_vector;
    elsif (inst_is_br(inst_ctrl) = '1') then
      control_hazard_pc_next <= inst_pc + inst_imm;
    else
      control_hazard_pc_next <= alu_result and (not to_unsigned(1, alu_result'length));
    end if;

  end process control_hazard_assign;

  csr_assign : process (inst_ctrl, rs1_addr, rs1_data) is
  begin

    if (inst_ctrl.funct3(2) = '1' and inst_ctrl.funct3(1 downto 0) /= (1 downto 0 => '0')) then
      csru_rs1 <= (XLEN - rs1_addr'length - 1 downto 0 => '0') & unsigned(rs1_addr);
    else
      csru_rs1 <= rs1_data;
    end if;

  end process csr_assign;

  u_memu : entity work.memunit(rtl)
    port map (
      clk       => clk,
      rst       => rst,
      valid     => inst_valid,
      is_new    => inst_is_new,
      ctrl      => inst_ctrl,
      addr      => alu_result,
      rs2       => rs2_data,
      rdata     => memu_rdata,
      stall     => memu_stall,
      mem_cmd   => d_mem_cmd,
      mem_addr  => d_mem_addr,
      mem_wdata => d_mem_wdata,
      mem_wmask => d_mem_wmask,
      mem_resp  => d_mem_resp,
      mem_rdata => d_mem_rdata
    );

  u_if_fifo : entity work.fifo(rtl)
    generic map (
      DATA_LEN => IF_FIFO_LEN,
      WIDTH    => 3
    )
    port map (
      clk        => clk,
      rst        => rst,
      flush      => control_hazard,
      wready     => if_fifo_wready,
      wready_two => if_fifo_wready_two,
      wvalid     => if_fifo_wvalid,
      wdata      => if_fifo_wdata_vector,
      rready     => if_fifo_rready,
      rvalid     => if_fifo_rvalid,
      rdata      => if_fifo_rdata_vector
    );

  u_decoder : entity work.inst_decoder(rtl)
    port map (
      bits => inst_bits,
      ctrl => inst_ctrl,
      imm  => inst_imm
    );

  u_alu : entity work.alu(rtl)
    port map (
      ctrl   => inst_ctrl,
      op1    => op1,
      op2    => op2,
      result => alu_result
    );

  u_bru : entity work.brunit(rtl)
    port map (
      funct3 => inst_ctrl.funct3,
      op1    => op1,
      op2    => op2,
      take   => brunit_take
    );

  u_csru : entity work.csrunit(rtl)
    port map (
      clk         => clk,
      rst         => rst,
      valid       => inst_valid,
      pc          => inst_pc,
      ctrl        => inst_ctrl,
      rd_addr     => rd_addr,
      csr_addr    => unsigned(inst_bits(31 downto 20)),
      rs1         => csru_rs1,
      rdata       => csru_rdata,
      raise_trap  => csru_raise_trap,
      trap_vector => csru_trap_vector,
      io_resp     => io_resp,
      io_cmd      => io_cmd
    );

  comb_fetch : process (if_fifo_wready_two, if_pc, memu_stall) is
  begin

    -- FIFO に2個以上空きがあれば、命令をフェッチする
    i_mem_cmd.valid <= if_fifo_wready_two;
    i_mem_addr      <= if_pc;
    i_mem_cmd.wen   <= '0';
    i_mem_wdata     <= (others => 'U');

    -- memunit が処理中でないときは FIFO から命令を取り出してよい
    if_fifo_rready <= not memu_stall;

  end process comb_fetch;

  comb_ops : process (inst_ctrl, inst_pc, inst_imm, rs1_data, rs2_data) is
  begin

    case inst_ctrl.itype is

      when R | B =>

        op1 <= rs1_data;
        op2 <= rs2_data;

      when I | S =>

        op1 <= rs1_data;
        op2 <= inst_imm;

      when U | J =>

        op1 <= inst_pc;
        op2 <= inst_imm;

      when others =>

        op1 <= (others => 'U');
        op2 <= (others => 'U');

    end case;

  end process comb_ops;

  comb_wb : process (inst_ctrl, inst_pc, inst_imm, alu_result, memu_rdata, csru_rdata) is
  begin

    if (inst_ctrl.is_lui = '1') then
      wb_data <= inst_imm;
    elsif (inst_ctrl.is_jump = '1') then
      wb_data <= inst_pc + 4;
    elsif (inst_ctrl.is_load = '1') then
      wb_data <= memu_rdata;
    elsif (inst_ctrl.is_csr = '1') then
      wb_data <= csru_rdata;
    else
      wb_data <= alu_result;
    end if;

  end process comb_wb;

  ff : process (clk, rst) is

    variable if_pc_next : t_addr;

  begin

    if (rst = '1') then
      if_pc           <= (others => '0');
      if_is_requested <= '0';
      if_pc_requested <= (others => '0');

      if_fifo_wvalid <= '0';
      if_fifo_wdata  <= IF_FIFO_ZERO;

      inst_is_new <= '0';

      regfile <= (others => (others => '0'));
    elsif (rising_edge(clk)) then
      if_pc_next := if_pc + 4;

      if (control_hazard = '1') then
        if_pc           <= control_hazard_pc_next;
        if_is_requested <= '0';
        if_fifo_wvalid  <= '0';
      else
        if (if_is_requested = '1') then
          if (i_mem_resp.rvalid = '1') then
            if_is_requested <= i_mem_resp.ready;

            if (i_mem_resp.ready = '1') then
              if_pc           <= if_pc_next;
              if_pc_requested <= if_pc;
            end if;
          end if;
        else
          if (i_mem_resp.ready = '1') then
            if_is_requested <= '1';
            if_pc           <= if_pc_next;
            if_pc_requested <= if_pc;
          end if;
        end if;

        if (if_is_requested = '1' and i_mem_resp.rvalid = '1') then
          if_fifo_wvalid     <= '1';
          if_fifo_wdata.addr <= if_pc_requested;
          if_fifo_wdata.bits <= std_logic_vector(i_mem_rdata);
        elsif (if_fifo_wvalid = '1' and if_fifo_wready = '1') then
          if_fifo_wvalid <= '0';
        end if;
      end if;

      if (inst_valid = '1' and if_fifo_rready = '1' and inst_ctrl.rwb_en = '1') then
        regfile(to_integer(unsigned(rd_addr))) <= wb_data;
      end if;

      if (if_fifo_rvalid = '1') then
        inst_is_new <= if_fifo_rready;
      else
        inst_is_new <= '1';
      end if;
    end if;

  end process ff;

  -- DEBUG

  dbg : process (clk, rst) is

    variable l : line;

  begin

    if (rst = '1') then
      dbg_clock_count <= (0 => '1', others => '0');
    elsif (rising_edge(clk)) then
      dbg_clock_count <= dbg_clock_count + 1;

      writeline(output, l);

      write(l, string'("# "));
      write(l, integer'image(to_integer(unsigned(dbg_clock_count))));
      writeline(output, l);

      write(l, string'("  "));
      hwrite(l, std_logic_vector(inst_pc));
      write(l, string'(" : "));
      hwrite(l, std_logic_vector(if_fifo_rdata.bits));
      writeline(output, l);

      write(l, string'("  itype : "));
      write(l, INST_TYPE(inst_ctrl.itype));
      writeline(output, l);

      write(l, string'("  imm   : "));
      hwrite(l, std_logic_vector(inst_imm));
      writeline(output, l);

      write(l, string'("     pc : "));
      hwrite(l, std_logic_vector(if_pc));
      writeline(output, l);

      write(l, string'(" is req : "));
      write(l, if_is_requested);
      writeline(output, l);

      write(l, string'(" pc req : "));
      hwrite(l, std_logic_vector(if_pc_requested));
      writeline(output, l);

      write(l, string'("  op1     : "));
      hwrite(l, std_logic_vector(op1));
      writeline(output, l);

      write(l, string'("  op2     : "));
      hwrite(l, std_logic_vector(op2));
      writeline(output, l);

      write(l, string'("  alu     : "));
      hwrite(l, std_logic_vector(alu_result));
      writeline(output, l);

      if (inst_is_br(inst_ctrl) = '1') then
        write(l, string'("  br take : "));
        write(l, brunit_take);
        writeline(output, l);
      end if;

      write(l, string'("  mem stall : "));
      write(l, memu_stall);
      writeline(output, l);

      write(l, string'("  mem rdata : "));
      hwrite(l, std_logic_vector(memu_rdata));
      writeline(output, l);

      if (inst_ctrl.is_csr = '1') then
        write(l, string'("  csr rdata : "));
        hwrite(l, std_logic_vector(csru_rdata));
        writeline(output, l);

        write(l, string'("  csr trap  : "));
        write(l, csru_raise_trap);
        writeline(output, l);

        write(l, string'("  csr vec   : "));
        hwrite(l, std_logic_vector(csru_trap_vector));
        writeline(output, l);
      end if;

      if (if_fifo_rready = '1' and inst_ctrl.rwb_en = '1') then
        write(l, string'("  reg["));
        write(l, integer'image(to_integer(unsigned(rd_addr))));
        write(l, string'("] <= "));
        hwrite(l, std_logic_vector(wb_data));
        writeline(output, l);
      end if;
    end if;

  end process dbg;

end architecture rtl;
