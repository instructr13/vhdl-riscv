library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
use work.eei.all;

-- 汎用メモリバスパッケージ
package membus_ty is

  type t_cpu_to_mem is record
    valid : std_logic; -- メモリアクセス要求
    wen   : std_logic; -- 書き込みかどうか
  end record t_cpu_to_mem;

  type t_mem_to_cpu is record
    ready  : std_logic; -- 要求受容
    rvalid : std_logic; -- 完了 (読み出しデータ有効)
  end record t_mem_to_cpu;

  function wmask_expand (
    wmask: unsigned;
    len: natural
  ) return unsigned;

end package membus_ty;

package body membus_ty is

  function wmask_expand (
    wmask: unsigned;
    len: natural
  ) return unsigned is

    variable ret : unsigned(len - 1 downto 0);

  begin

    for i in 0 to len - 1 loop

      ret(i) := wmask(i / 8);

    end loop;

    return ret;

  end function wmask_expand;

end package body membus_ty;

