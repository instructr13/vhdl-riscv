library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
use work.eei.all;
use work.io_ty.all;

entity io is
  port (
    switches : in    t_switches;
    leds     : out   t_leds_raw;
    io_cmd   : in    t_cpu_to_io;
    io_resp  : out   t_io_to_cpu
  );
end entity io;

architecture rtl of io is

begin

  comb : process (switches) is
  begin

    io_resp.switches <= (XLEN - SW_LEN - 1 downto 0 => '0') & unsigned(switches);

  end process comb;

  -- leds を 2bit (R,G) 単位で各 LED へマッピング

  gen_leds : for i in 0 to LED_LEN - 1 generate
    constant RED_INDEX   : integer := 2 * i;       -- 赤ビット位置
    constant GREEN_INDEX : integer := 2 * i + 1;   -- 緑ビット位置

    signal led_obj_i : t_led_obj;
  begin
    led_obj_i.r <= io_cmd.leds(RED_INDEX);
    led_obj_i.g <= io_cmd.leds(GREEN_INDEX);

    leds(i) <= to_led_in(led_obj_i);
  end generate gen_leds;

end architecture rtl;
