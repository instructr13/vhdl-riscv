library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
use work.eei.all;
use work.corectrl.all;
use work.io_ty.all;

entity csrunit is
  port (
    clk         : in    std_logic;
    rst         : in    std_logic;
    valid       : in    std_logic;
    pc          : in    t_addr;
    ctrl        : in    t_inst_ctrl;
    rd_addr     : in    std_logic_vector(4 downto 0);
    csr_addr    : in    unsigned(11 downto 0);
    rs1         : in    t_uintx;
    rdata       : out   t_uintx;
    raise_trap  : out   std_logic;
    trap_vector : out   t_addr;
    io_resp     : in    t_io_to_cpu;
    io_cmd      : out   t_cpu_to_io
  );
end entity csrunit;

architecture rtl of csrunit is

  type t_csr_addr is (MTVEC, MEPC, MCAUSE, MHARTID, LED, SWITCH);

  type t_csr_addr_lookup is array(t_csr_addr) of unsigned(11 downto 0);

  constant CSR_ADDR_LOOKUP : t_csr_addr_lookup :=
  (
    MTVEC   => x"305",
    MEPC    => x"341",
    MCAUSE  => x"342",
    MHARTID => x"F14",
    LED     => x"800",
    SWITCH  => x"801"
  );

  -- wmasks
  constant MTVEC_WMASK  : t_uintx := x"FFFF_FFFF_FFFF_FFFC";
  constant MEPC_WMASK   : t_uintx := x"FFFF_FFFF_FFFF_FFFC";
  constant MCAUSE_WMASK : t_uintx := x"FFFF_FFFF_FFFF_FFFF";
  constant LED_WMASK    : t_uintx := x"FFFF_FFFF_FFFF_FFFF";
  constant SWITCH_WMASK : t_uintx := x"0000_0000_0000_0000";

  signal is_wsc : std_logic;

  -- MTVEC
  signal mtvec_data : t_uintx;

  -- MEPC / MCAUSE

  type t_csr_cause is (ENVIRONMENT_CALL_FROM_M_MODE);

  type t_csr_cause_lookup is array(t_csr_cause) of t_uintx;

  constant CSR_CAUSE_LOOKUP : t_csr_cause_lookup :=
  (
    ENVIRONMENT_CALL_FROM_M_MODE => to_unsigned(11, t_uintx'length)
  );

  signal mepc_data   : t_uintx;
  signal mcause_data : t_uintx;

  signal wmask : t_uintx;
  signal wdata : t_uintx;

  -- Exception
  signal raise_expt : std_logic;
  signal expt_cause : t_uintx;

  -- Trap
  signal trap_cause : t_uintx;

  signal s_raise_trap : std_logic;

begin

  raise_trap <= s_raise_trap;

  assign : process (valid, ctrl, csr_addr, rs1, rd_addr, mtvec_data, mepc_data) is

    variable is_ecall        : std_logic;
    variable is_mret         : std_logic;
    variable trap_expt_cause : t_uintx;
    variable raise_expt_temp : std_logic;

  begin

    -- CSRR(W|S|C)[I] 命令かどうか
    if (ctrl.is_csr = '1' and ctrl.funct3(1 downto 0) /= (1 downto 0 => '0')) then
      is_wsc <= '1';
    else
      is_wsc <= '0';
    end if;

    -- ECALL 命令かどうか
    if (
      ctrl.is_csr = '1'
      and csr_addr = (csr_addr'range => '0')
      and rs1(4 downto 0) = (4 downto 0 => '0')
      and ctrl.funct3 = (ctrl.funct3'range => '0')
      and rd_addr = (rd_addr'range => '0')
    ) then
      is_ecall := '1';
    else
      is_ecall := '0';
    end if;

    if (
      ctrl.is_csr = '1'
      and csr_addr = "001100000010"
      and rs1(4 downto 0) = (4 downto 0 => '0')
      and ctrl.funct3 = (ctrl.funct3'range => '0')
      and rd_addr = (rd_addr'range => '0')
    ) then
      is_mret := '1';
    else
      is_mret := '0';
    end if;

    trap_expt_cause := CSR_CAUSE_LOOKUP(ENVIRONMENT_CALL_FROM_M_MODE);
    raise_expt_temp := valid and is_ecall;

    raise_expt <= raise_expt_temp;
    expt_cause <= trap_expt_cause;
    trap_cause <= trap_expt_cause;

    s_raise_trap <= raise_expt_temp or (valid and is_mret);

    if (raise_expt_temp = '1') then
      trap_vector <= mtvec_data;
    else
      trap_vector <= mepc_data;
    end if;

  end process assign;

  comb : process (ctrl, csr_addr, rs1, wmask, mtvec_data, mepc_data, mcause_data, io_resp) is

    variable rdata_cond : t_uintx;
    variable wdata_cond : t_uintx;

  begin

    if (csr_addr = CSR_ADDR_LOOKUP(MTVEC)) then
      rdata_cond := mtvec_data;
      wmask      <= MTVEC_WMASK;
    elsif (csr_addr = CSR_ADDR_LOOKUP(MEPC)) then
      rdata_cond := mepc_data;
      wmask      <= MEPC_WMASK;
    elsif (csr_addr = CSR_ADDR_LOOKUP(MCAUSE)) then
      rdata_cond := mcause_data;
      wmask      <= MCAUSE_WMASK;
    elsif (csr_addr = CSR_ADDR_LOOKUP(MHARTID)) then
      rdata_cond := (others => '0');
      wmask      <= (others => '0');
    elsif (csr_addr = CSR_ADDR_LOOKUP(LED)) then
      rdata_cond := (others => '0');
      wmask      <= LED_WMASK;
    elsif (csr_addr = CSR_ADDR_LOOKUP(SWITCH)) then
      rdata_cond := io_resp.switches;
      wmask      <= SWITCH_WMASK;
    else
      rdata_cond := (others => 'U');
      wmask      <= (others => '0');
    end if;

    case ctrl.funct3(1 downto 0) is

      when "01" =>

        wdata_cond := rs1;

      when "10" =>

        wdata_cond := rdata_cond or rs1;

      when "11" =>

        wdata_cond := rdata_cond and (not rs1);

      when others =>

        wdata_cond := (others => 'U');

    end case;

    rdata <= rdata_cond;
    wdata <= (wdata_cond and wmask) or (rdata_cond and (not wmask));

  end process comb;

  ff : process (clk, rst) is
  begin

    if (rst = '1') then
      mtvec_data  <= (others => '0');
      mepc_data   <= (others => '0');
      mcause_data <= (others => '0');
      io_cmd.leds <= (others => '0');
    elsif (rising_edge(clk)) then
      if (valid = '1') then
        if (s_raise_trap = '1') then
          if (raise_expt = '1') then
            mepc_data   <= pc;
            mcause_data <= trap_cause;
          end if;
        else
          if (is_wsc = '1') then
            if (csr_addr = CSR_ADDR_LOOKUP(MTVEC)) then
              mtvec_data <= wdata;
            elsif (csr_addr = CSR_ADDR_LOOKUP(MEPC)) then
              mepc_data <= wdata;
            elsif (csr_addr = CSR_ADDR_LOOKUP(MCAUSE)) then
              mcause_data <= wdata;
            elsif (csr_addr = CSR_ADDR_LOOKUP(LED)) then
              io_cmd.leds <= wdata;
            end if;
          end if;
        end if;
      end if;
    end if;

  end process ff;

end architecture rtl;

