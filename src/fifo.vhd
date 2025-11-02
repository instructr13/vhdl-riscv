library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
use work.util.all;

entity fifo is
  generic (
    DATA_LEN : natural;
    WIDTH    : natural := 2
  );
  port (
    clk        : in    std_logic;
    rst        : in    std_logic;
    flush      : in    std_logic;
    wready     : out   std_logic;
    wready_two : out   std_logic;
    wvalid     : in    std_logic;
    wdata      : in    std_logic_vector(DATA_LEN - 1 downto 0);
    rready     : in    std_logic;
    rvalid     : out   std_logic;
    rdata      : out   std_logic_vector(DATA_LEN - 1 downto 0)
  );
end entity fifo;

architecture rtl of fifo is

  signal s_wready : std_logic;
  signal s_rvalid : std_logic;

begin

  wready <= s_wready;
  rvalid <= s_rvalid;

  gen_single_fifo : if WIDTH = 1 generate
  begin

    comb : process (rready, s_rvalid) is
    begin

      s_wready <= (not s_rvalid) or rready;
      wready_two <= '0';

    end process comb;

    ff : process (clk, rst) is
    begin

      if (rst = '1') then
        rdata    <= (others => '0');
        s_rvalid <= '0';
      elsif (rising_edge(clk)) then
        if (flush = '1') then
          s_rvalid <= '0';
        else
          if (s_wready = '1' and wvalid = '1') then
            rdata    <= wdata;
            s_rvalid <= '1';
          elsif (rready = '1') then
            s_rvalid <= '0';
          end if;
        end if;
      end if;

    end process ff;

  end generate gen_single_fifo;

  gen_many_fifo : if WIDTH > 1 generate

    subtype ptr is std_logic_vector(WIDTH - 1 downto 0);

    signal s_head : ptr;
    signal s_tail : ptr;

    signal s_tail_plus1 : ptr;
    signal s_tail_plus2 : ptr;

    type t_mem is array(0 to pow2(WIDTH) - 1) of std_logic_vector(DATA_LEN - 1 downto 0);

    signal mem : t_mem;
  begin
    s_tail_plus1 <= ptr(unsigned(s_tail) + 1);
    s_tail_plus2 <= ptr(unsigned(s_tail) + 2);

    comb : process (mem, s_head, s_tail, s_tail_plus1, s_tail_plus2, s_wready) is
    begin

      if (s_tail_plus1 /= s_head) then
        s_wready <= '1';
      else
        s_wready <= '0';
      end if;

      if (s_wready = '1' and s_tail_plus2 /= s_head) then
        wready_two <= '1';
      else
        wready_two <= '0';
      end if;

      if (s_head /= s_tail) then
        s_rvalid <= '1';
      else
        s_rvalid <= '0';
      end if;

      rdata <= mem(to_integer(unsigned(s_head)));

    end process comb;

    ff : process (clk, rst) is
    begin

      if (rst = '1') then
        s_head <= (others => '0');
        s_tail <= (others => '0');
      elsif (rising_edge(clk)) then
        if (flush = '1') then
          s_head <= (others => '0');
          s_tail <= (others => '0');
        else
          if (s_wready = '1' and wvalid = '1') then
            mem(to_integer(unsigned(s_tail))) <= wdata;
            s_tail                            <= ptr(unsigned(s_tail) + 1);
          end if;

          if (rready = '1' and s_rvalid = '1') then
            s_head <= ptr(unsigned(s_head) + 1);
          end if;
        end if;
      end if;

    end process ff;

  end generate gen_many_fifo;

end architecture rtl;
