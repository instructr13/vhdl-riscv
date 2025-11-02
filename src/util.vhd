library ieee;
  use ieee.std_logic_1164.all;

package util is

  -- 累乗用の補助関数

  function pow2 (
    n : natural
  ) return natural;

  function clog2 (
    n: positive
  ) return natural;

end package util;

package body util is

  function pow2 (
    n : natural
  ) return natural is
  begin

    return 2 ** n;

  end function pow2;

  function clog2 (
    n: positive
  ) return natural is

    variable ret : natural;
    variable v   : natural;

  begin

    ret := 0;
    v   := n - 1;

    while (v > 0) loop

      v   := v / 2;
      ret := ret + 1;

    end loop;

    return ret;

  end function clog2;

end package body util;

