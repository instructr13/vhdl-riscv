library ieee;
  use ieee.std_logic_1164.all;
use work.io_ty.all;

entity tb_top is
  generic (
    MEM_INIT_FILE : string  := "mem_init.hex";
    TEST_MODE     : boolean := false
  );
end entity tb_top;

architecture sim of tb_top is

  signal clk      : std_logic  := '0';
  signal rst      : std_logic  := '1';
  signal switches : t_switches := (others => '0');
  signal leds     : t_leds_raw := (others => (others => '0'));

  constant CLK_PERIOD : time := 10 ns;  -- 100 MHz相当

begin

  uut : entity work.top(rtl)
    generic map (
      MEM_INIT_FILE => MEM_INIT_FILE,
      TEST_MODE     => TEST_MODE
    )
    port map (
      clk      => clk,
      rst      => rst,
      switches => switches,
      leds     => leds
    );

  -- クロック生成プロセス
  clk_proc : process is
  begin

    while true loop

      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;

    end loop;

  end process clk_proc;

  -- リセット解除
  stim_proc : process is
  begin

    wait for 50 ns;
    rst <= '0';
    wait;

  end process stim_proc;

end architecture sim;

