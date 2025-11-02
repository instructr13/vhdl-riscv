library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
use work.eei.all;
use work.membus_ty.all;
use work.io_ty.all;
use work.util.all;

entity top is
  generic (
    RST_INVERT       : boolean := false;
    MEM_INIT_FILE    : string  := "mem_init.hex";
    MEM_USE_CONSTANT : boolean := false;
    TEST_MODE        : boolean := false
  );
  port (
    clk : in    std_logic;
    rst : in    std_logic;

    switches : in    t_switches;
    leds     : out   t_leds_raw
  );
end entity top;

architecture rtl of top is

  signal rst_actual     : std_logic;

  signal s_membus_cmd   : t_cpu_to_mem;
  signal s_membus_resp  : t_mem_to_cpu;
  signal s_membus_addr  : unsigned(MEM_ADDR_WIDTH - 1 downto 0);
  signal s_membus_rdata : unsigned(MEM_DATA_WIDTH - 1 downto 0);
  signal s_membus_wdata : unsigned(MEM_DATA_WIDTH - 1 downto 0);
  signal s_membus_wmask : unsigned(MEM_DATA_WIDTH / 8 - 1 downto 0);

  signal s_io_cmd  : t_cpu_to_io;
  signal s_io_resp : t_io_to_cpu;

  function addr_to_memaddr (
    addr : in t_addr
  )
  return unsigned is

    constant OFFSET_BITS : natural := clog2(MEM_DATA_WIDTH / 8);

    variable ret : unsigned(MEM_ADDR_WIDTH - 1 downto 0);

  begin

    ret := addr(OFFSET_BITS + MEM_ADDR_WIDTH - 1 downto OFFSET_BITS);

    return ret;

  end function addr_to_memaddr;

  signal s_i_membus_cmd   : t_cpu_to_mem;
  signal s_i_membus_resp  : t_mem_to_cpu;
  signal s_i_membus_addr  : t_addr;
  signal s_i_membus_rdata : unsigned(ILEN - 1 downto 0);
  signal s_i_membus_wdata : unsigned(ILEN - 1 downto 0);
  signal s_i_membus_wmask : unsigned(ILEN / 8 - 1 downto 0);

  signal s_d_membus_cmd   : t_cpu_to_mem;
  signal s_d_membus_resp  : t_mem_to_cpu;
  signal s_d_membus_addr  : t_addr;
  signal s_d_membus_rdata : unsigned(MEM_DATA_WIDTH - 1 downto 0);
  signal s_d_membus_wdata : unsigned(MEM_DATA_WIDTH - 1 downto 0);
  signal s_d_membus_wmask : unsigned(MEM_DATA_WIDTH / 8 - 1 downto 0);

  signal s_memarb_last_i    : std_logic;
  signal s_memarb_last_iaddr : t_addr;

begin

  rst_inv_true : if RST_INVERT generate
    rst_actual <= not rst;
  end generate rst_inv_true;

  rst_inv_false : if not RST_INVERT generate
    rst_actual <= rst;
  end generate rst_inv_false;

  u_memory : entity work.memory(rtl)
    generic map (
      MEM_INIT_FILE    => MEM_INIT_FILE,
      MEM_USE_CONSTANT => MEM_USE_CONSTANT
    )
    port map (
      clk      => clk,
      rst      => rst_actual,
      mem_cmd  => s_membus_cmd,
      addr     => s_membus_addr,
      wdata    => s_membus_wdata,
      wmask    => s_membus_wmask,
      mem_resp => s_membus_resp,
      rdata    => s_membus_rdata
    );

  u_io : entity work.io(rtl)
    port map (
      switches => switches,
      leds     => leds,
      io_cmd   => s_io_cmd,
      io_resp  => s_io_resp
    );

  u_core : entity work.core(rtl)
    port map (
      clk => clk,
      rst => rst_actual,

      i_mem_cmd   => s_i_membus_cmd,
      i_mem_addr  => s_i_membus_addr,
      i_mem_wdata => s_i_membus_wdata,
      i_mem_wmask => s_i_membus_wmask,
      i_mem_resp  => s_i_membus_resp,
      i_mem_rdata => s_i_membus_rdata,

      d_mem_cmd   => s_d_membus_cmd,
      d_mem_addr  => s_d_membus_addr,
      d_mem_wdata => s_d_membus_wdata,
      d_mem_wmask => s_d_membus_wmask,
      d_mem_resp  => s_d_membus_resp,
      d_mem_rdata => s_d_membus_rdata,

      io_resp => s_io_resp,
      io_cmd  => s_io_cmd
    );

  ff : process (clk, rst_actual) is
  begin

    if (rst_actual = '1') then
      s_memarb_last_i     <= '0';
      s_memarb_last_iaddr <= (others => '0');
    elsif (rising_edge(clk)) then
      if (s_membus_resp.ready = '1' and s_membus_cmd.valid = '1') then
        s_memarb_last_i <= not s_d_membus_cmd.valid;
        if (s_d_membus_cmd.valid = '0') then
          s_memarb_last_iaddr <= s_i_membus_addr;
        end if;
      end if;
    end if;

  end process ff;

  comb : process (
                  s_membus_resp,
                  s_membus_rdata,
                  s_i_membus_cmd,
                  s_i_membus_addr,
                  s_d_membus_cmd,
                  s_d_membus_addr,
                  s_d_membus_wdata,
                  s_d_membus_wmask,
                  s_memarb_last_i,
                  s_memarb_last_iaddr
                 ) is
  begin

    s_i_membus_resp.ready  <= s_membus_resp.ready and (not s_d_membus_cmd.valid);
    s_i_membus_resp.rvalid <= s_membus_resp.rvalid and s_memarb_last_i;

    if (s_memarb_last_iaddr(2) = '0') then
      s_i_membus_rdata <= s_membus_rdata(31 downto 0);
    else
      s_i_membus_rdata <= s_membus_rdata(63 downto 32);
    end if;

    s_d_membus_resp.ready  <= s_membus_resp.ready and s_d_membus_cmd.valid;
    s_d_membus_resp.rvalid <= s_membus_resp.rvalid and (not s_memarb_last_i);
    s_d_membus_rdata       <= s_membus_rdata;

    s_membus_cmd.valid <= s_i_membus_cmd.valid or s_d_membus_cmd.valid;

    if (s_d_membus_cmd.valid = '1') then
      s_membus_addr    <= addr_to_memaddr(s_d_membus_addr);
      s_membus_cmd.wen <= s_d_membus_cmd.wen;
      s_membus_wdata   <= s_d_membus_wdata;
      s_membus_wmask   <= s_d_membus_wmask;
    else
      s_membus_addr    <= addr_to_memaddr(s_i_membus_addr);
      s_membus_cmd.wen <= '0'; -- 命令フェッチは常に読み込み
      s_membus_wdata   <= (others => 'U');
      s_membus_wmask   <= (others => 'U');
    end if;

  end process comb;

  -- Test monitor (enabled only in TEST_MODE)

  gen_test : if TEST_MODE generate
  begin

    mon : process (clk) is
    begin

      if (rising_edge(clk)) then
        if (s_d_membus_cmd.valid = '1' and s_d_membus_resp.ready = '1' and s_d_membus_cmd.wen = '1') then
          if (s_d_membus_addr = x"00001000" and s_d_membus_wdata(0) = '1') then
            if (s_d_membus_wdata(7 downto 0) = "00000001") then
              assert (false)
                report "PASS"
                severity failure;
            else
              assert (false)
                report "FAIL"
                severity failure;
            end if;
          end if;
        end if;
      end if;

    end process mon;

  end generate gen_test;

end architecture rtl;
