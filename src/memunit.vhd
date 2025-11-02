library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
use work.eei.all;
use work.corectrl.all;
use work.membus_ty.all;

entity memunit is
  port (
    clk       : in    std_logic;
    rst       : in    std_logic;
    valid     : in    std_logic;
    is_new    : in    std_logic;   -- 命令が新しく供給されたかどうか
    ctrl      : in    t_inst_ctrl; -- 命令の t_inst_ctrl
    addr      : in    t_addr;      -- アクセスするアドレス
    rs2       : in    t_uintx;     -- ストア命令で書き込むデータ
    rdata     : out   t_uintx;     -- ロード命令の結果 (stall = 0 の時に有効)
    stall     : out   std_logic;   -- メモリアクセス命令が完了していないかどうか
    mem_cmd   : out   t_cpu_to_mem;
    mem_addr  : out   t_addr;
    mem_wdata : out   unsigned(MEM_DATA_WIDTH - 1 downto 0);
    mem_wmask : out   unsigned(MEM_DATA_WIDTH / 8 - 1 downto 0);
    mem_resp  : in    t_mem_to_cpu;
    mem_rdata : in    unsigned(MEM_DATA_WIDTH - 1 downto 0)
  );
end entity memunit;

architecture rtl of memunit is

  constant W : natural := XLEN;

  signal d    : unsigned(MEM_DATA_WIDTH - 1 downto 0);
  signal sext : std_logic;

  type t_state is (
    INIT,       -- 命令を受け付ける状態
    WAIT_READY, -- メモリが操作可能になるのを待つ状態
    WAIT_VALID  -- メモリ操作が終了するのを待つ状態
  );

  signal s_state : t_state;

  signal s_req_wen   : std_logic;
  signal s_req_addr  : t_addr;
  signal s_req_wdata : unsigned(MEM_DATA_WIDTH - 1 downto 0);
  signal s_req_wmask : unsigned(MEM_DATA_WIDTH / 8 - 1 downto 0);

  function inst_is_memop (
    r: t_inst_ctrl
  ) return std_logic is

    variable ret : std_logic;

  begin

    if (r.itype = S or r.is_load = '1') then
      ret := '1';
    else
      ret := '0';
    end if;

    return ret;

  end function inst_is_memop;

  function inst_is_store (
    r: t_inst_ctrl
  ) return std_logic is

    variable ret : std_logic;

  begin

    if (r.itype = S) then
      ret := '1';
    else
      ret := '0';
    end if;

    return ret;

  end function inst_is_store;

begin

  d <= mem_rdata;

  comb_sext : process (ctrl) is
  begin

    if (ctrl.funct3(2) = '0') then
      sext <= '1';
    else
      sext <= '0';
    end if;

  end process comb_sext;

  comb_access : process (s_state) is
  begin

    -- メモリアクセス
    if (s_state = WAIT_READY or s_state = WAIT_VALID) then
      -- rvalid が変わるまで valid を保持し、読み取りタイミングを保証
      mem_cmd.valid <= '1';
    else
      mem_cmd.valid <= '0';
    end if;

  end process comb_access;

  comb_load : process (ctrl, addr, d, sext) is
  begin

    -- load 結果
    case ctrl.funct3(1 downto 0) is

      when "00" =>

        case addr(2 downto 0) is

          when "000" =>

            rdata <= (W - 8 - 1 downto 0 => sext and d(7)) & d(7 downto 0);

          when "001" =>

            rdata <= (W - 8 - 1 downto 0 => sext and d(15)) & d(15 downto 8);

          when "010" =>

            rdata <= (W - 8 - 1 downto 0 => sext and d(23)) & d(23 downto 16);

          when "011" =>

            rdata <= (W - 8 - 1 downto 0 => sext and d(31)) & d(31 downto 24);

          when "100" =>

            rdata <= (W - 8 - 1 downto 0 => sext and d(39)) & d(39 downto 32);

          when "101" =>

            rdata <= (W - 8 - 1 downto 0 => sext and d(47)) & d(47 downto 40);

          when "110" =>

            rdata <= (W - 8 - 1 downto 0 => sext and d(55)) & d(55 downto 48);

          when "111" =>

            rdata <= (W - 8 - 1 downto 0 => sext and d(63)) & d(63 downto 56);

          when others =>

            rdata <= (others => 'U');

        end case;

      when "01" =>

        case addr(2 downto 0) is

          when "000" =>

            rdata <= (W - 16 - 1 downto 0 => sext and d(15)) & d(15 downto 0);

          when "010" =>

            rdata <= (W - 16 - 1 downto 0 => sext and d(31)) & d(31 downto 16);

          when "100" =>

            rdata <= (W - 16 - 1 downto 0 => sext and d(47)) & d(47 downto 32);

          when "110" =>

            rdata <= (W - 16 - 1 downto 0 => sext and d(63)) & d(63 downto 48);

          when others =>

            rdata <= (others => 'U');

        end case;

      when "10" =>

        case addr(2 downto 0) is

          when "000" =>

            rdata <= (W - 32 - 1 downto 0 => sext and d(31)) & d(31 downto 0);

          when "100" =>

            rdata <= (W - 32 - 1 downto 0 => sext and d(63)) & d(63 downto 32);

          when others =>

            rdata <= (others => 'U');

        end case;

      when "11" =>

        rdata <= d;

      when others =>

        rdata <= (others => 'U');

    end case;

  end process comb_load;

  comb_req : process (s_req_addr, s_req_wen, s_req_wdata, s_req_wmask) is
  begin

    mem_addr    <= s_req_addr;
    mem_cmd.wen <= s_req_wen;
    mem_wdata   <= s_req_wdata;
    mem_wmask   <= s_req_wmask;

  end process comb_req;

  comb_stall : process (valid, is_new, ctrl, mem_resp, s_state) is
  begin

    -- stall 判定
    if (valid = '1') then

      case s_state is

        when INIT =>

          if (is_new = '1' and inst_is_memop(ctrl) = '1') then
            stall <= '1';
          else
            stall <= '0';
          end if;

        when WAIT_READY =>

          stall <= '1';

        when WAIT_VALID =>

          stall <= not mem_resp.rvalid;

        when others =>

          stall <= '0';

      end case;

    else
      stall <= '0';
    end if;

  end process comb_stall;

  ff : process (clk, rst) is
  begin

    if (rst = '1') then
      s_state     <= INIT;
      s_req_wen   <= '0';
      s_req_addr  <= (others => '0');
      s_req_wdata <= (others => '0');
      s_req_wmask <= (others => '0');
    elsif (rising_edge(clk)) then
      if (valid = '1') then

        case s_state is

          when INIT =>

            if (is_new = '1' and inst_is_memop(ctrl) = '1') then
              s_state     <= WAIT_READY;
              s_req_wen   <= inst_is_store(ctrl);
              s_req_addr  <= addr;
              s_req_wdata <= rs2 sll to_integer(addr(2 downto 0) & "000");

              case ctrl.funct3(1 downto 0) is

                when "00" =>

                  -- SB 命令ならば、アドレスの下位2ビットに応じて1バイト分のマスクを設定
                  s_req_wmask <= "00000001" sll to_integer(addr(2 downto 0));

                when "01" =>

                  -- SH 命令ならば
                  case addr(2 downto 0) is

                    when "110" =>

                      s_req_wmask <= "11000000";

                    when "100" =>

                      s_req_wmask <= "00110000";

                    when "010" =>

                      s_req_wmask <= "00001100";

                    when "000" =>

                      s_req_wmask <= "00000011";

                    when others =>

                      s_req_wmask <= (others => 'U');

                  end case;

                when "10" =>

                  -- SW 命令ならば
                  case addr(2 downto 0) is

                    when "100" =>

                      s_req_wmask <= "11110000";

                    when "000" =>

                      s_req_wmask <= "00001111";

                    when others =>

                      s_req_wmask <= (others => 'U');

                  end case;

                when "11" =>

                  -- SD 命令ならば
                  s_req_wmask <= "11111111";

                when others =>

                  s_req_wmask <= (others => 'U');

              end case;

            end if;

          when WAIT_READY =>

            if (mem_resp.ready = '1') then
              s_state <= WAIT_VALID;
            end if;

          when WAIT_VALID =>

            if (mem_resp.rvalid = '1') then
              s_state <= INIT;
            end if;

          when others =>

        -- No-op

        end case;

      end if;
    end if;

  end process ff;

end architecture rtl;
