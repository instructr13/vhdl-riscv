library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_textio.all;
use std.textio.all;
use work.eei.all;
use work.util.all;
use work.membus_ty.all;

package initial_mem is

  subtype t_data is unsigned(MEM_DATA_WIDTH - 1 downto 0);

  type t_mem is array (0 to pow2(MEM_ADDR_WIDTH) - 1) of t_data;

  impure function load_mem_from_hex (
    filename        : string;
    use_initial_mem : boolean
  ) return t_mem;

  constant MEM_INIT : t_mem :=
  (
    others => (others => '0') -- 0x0
  );

end package initial_mem;

package body initial_mem is

  -- HEX ファイルからメモリを読み取る

  impure function load_mem_from_hex (
    filename        : string;
    use_initial_mem : boolean
  ) return t_mem is

    file     hex_file  : text;
    variable file_line : line;
    variable mem_data  : t_mem   := (others => (others => '0'));
    variable hex_value : std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);
    variable addr      : natural := 0;
    variable good      : boolean;

  begin

    if (not use_initial_mem) then
      file_open(hex_file, filename, read_mode);

      while not endfile(hex_file) loop

        readline(hex_file, file_line);

        if (file_line'length > 0) then
          hread(file_line, hex_value, good);

          if (good) then
            mem_data(addr) := unsigned(hex_value);
            addr           := addr + 1;
          end if;
        end if;

        exit when addr >= pow2(MEM_ADDR_WIDTH);

      end loop;

      file_close(hex_file);
    else
      mem_data := MEM_INIT;
    end if;

    return mem_data;

  end function load_mem_from_hex;

end package body initial_mem;

