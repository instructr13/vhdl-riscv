library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
use work.util.all;
use work.eei.all;
use work.io_ty.all;
use work.membus_ty.all;
use work.initial_mem.all;

-- メモリ

entity memory is
  generic (
    MEM_INIT_FILE    : string;
    MEM_USE_CONSTANT : boolean
  );
  port (
    clk      : in    std_logic;
    rst      : in    std_logic;
    mem_cmd  : in    t_cpu_to_mem;
    addr     : in    unsigned(MEM_ADDR_WIDTH - 1 downto 0);     -- アクセス先アドレス
    wdata    : in    unsigned(MEM_DATA_WIDTH - 1 downto 0);     -- 書き込みデータ
    wmask    : in    unsigned(MEM_DATA_WIDTH / 8 - 1 downto 0); -- 書き込みマスク
    mem_resp : out   t_mem_to_cpu;
    rdata    : out   unsigned(MEM_DATA_WIDTH - 1 downto 0)      -- 読み出しデータ
  );
end entity memory;

architecture rtl of memory is

  subtype t_mask is unsigned(MEM_DATA_WIDTH / 8 - 1 downto 0);

  type t_state is (READY, WRITE_VALID);

  signal s_state : t_state;

  signal s_addr_saved  : unsigned(MEM_ADDR_WIDTH - 1 downto 0);
  signal s_wdata_saved : t_data;
  signal s_wmask_saved : t_mask;
  signal s_rdata_saved : t_data;

  signal mem : t_mem := load_mem_from_hex(MEM_INIT_FILE, MEM_USE_CONSTANT);

begin

  comb : process (s_state) is
  begin

    if (s_state = READY) then
      mem_resp.ready <= '1';
    else
      mem_resp.ready <= '0';
    end if;

  end process comb;

  ff : process (clk, rst) is

    variable expanded_wmask : unsigned(MEM_DATA_WIDTH - 1 downto 0);

  begin

    if (rst = '1') then
      s_state <= READY;

      mem_resp.rvalid <= '0';
      rdata           <= (others => '0');

      s_addr_saved  <= (others => '0');
      s_wdata_saved <= (others => '0');
      s_wmask_saved <= (others => '0');
      s_rdata_saved <= (others => '0');
    elsif (rising_edge(clk)) then
      if (s_state = WRITE_VALID) then
        expanded_wmask := wmask_expand(s_wmask_saved, MEM_DATA_WIDTH);

        mem(to_integer(s_addr_saved(MEM_ADDR_WIDTH - 1 downto 0))) <= (s_wdata_saved and expanded_wmask) or (s_rdata_saved and (not expanded_wmask));
      end if;

      case s_state is

        when READY =>

          mem_resp.rvalid <= mem_cmd.valid and (not mem_cmd.wen);
          rdata           <= mem(to_integer(addr(MEM_ADDR_WIDTH - 1 downto 0)));
          s_addr_saved    <= addr(MEM_ADDR_WIDTH - 1 downto 0);
          s_wdata_saved   <= wdata;
          s_wmask_saved   <= wmask;
          s_rdata_saved   <= mem(to_integer(addr(MEM_ADDR_WIDTH - 1 downto 0)));

          -- 書きアクセス (wen='1')
          if (mem_cmd.valid = '1' and mem_cmd.wen = '1') then
            s_state <= WRITE_VALID;
          end if;

        when WRITE_VALID =>

          s_state         <= READY;
          mem_resp.rvalid <= '1';

      end case;

    end if;

  end process ff;

end architecture rtl;
