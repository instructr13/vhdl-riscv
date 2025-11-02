library ieee;
  use ieee.std_logic_1164.all;
use work.eei.all;

package io_ty is

  constant SW_LEN  : natural := 3; -- 最後のスイッチはRSTに使用
  constant LED_LEN : natural := 10;

  -- LED (生)

  type t_led_raw is record
    r_plus  : std_logic;
    r_minus : std_logic;
    g_plus  : std_logic;
    g_minus : std_logic;
  end record t_led_raw;

  -- LED (プラス、マイナスの区別なし)

  type t_led_obj is record
    r : std_logic;
    g : std_logic;
  end record t_led_obj;

  -- LED (生) への変換

  function to_led_in (
    arg : t_led_obj
  ) return t_led_raw;

  subtype t_switches is std_logic_vector(SW_LEN - 1 downto 0);

  type t_leds_raw is array (0 to LED_LEN - 1) of t_led_raw;

  -- IO バス (master -> 出力系、slave -> 入力系)

  type t_cpu_to_io is record
    leds : t_uintx;
  end record t_cpu_to_io;

  type t_io_to_cpu is record
    switches : t_uintx;
  end record t_io_to_cpu;

end package io_ty;

package body io_ty is

  function to_led_in (
    arg : t_led_obj
  ) return t_led_raw is

    variable ret : t_led_raw;

  begin

    ret.r_plus  := arg.r;
    ret.r_minus := not arg.r;
    ret.g_plus  := arg.g;
    ret.g_minus := not arg.g;

    return ret;

  end function to_led_in;

end package body io_ty;
