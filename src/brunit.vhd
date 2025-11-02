library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
use work.eei.all;
use work.corectrl.all;

entity brunit is
  port (
    funct3 : in    std_logic_vector(2 downto 0);
    op1    : in    t_uintx;
    op2    : in    t_uintx;
    take   : out   std_logic
  );
end entity brunit;

architecture rtl of brunit is

  signal beq  : std_logic;
  signal blt  : std_logic;
  signal bltu : std_logic;

begin

  br_comp : process (op1, op2) is
  begin

    if (op1 = op2) then
      beq <= '1';
    else
      beq <= '0';
    end if;

    if (signed(op1) < signed(op2)) then
      blt <= '1';
    else
      blt <= '0';
    end if;

    if (op1 < op2) then
      bltu <= '1';
    else
      bltu <= '0';
    end if;

  end process br_comp;

  comb : process (funct3, beq, blt, bltu) is
  begin

    case funct3 is

      when "000" =>

        take <= beq;

      when "001" =>

        take <= not beq;

      when "100" =>

        take <= blt;

      when "101" =>

        take <= not blt;

      when "110" =>

        take <= bltu;

      when "111" =>

        take <= not bltu;

      when others =>

        take <= '0';

    end case;

  end process comb;

end architecture rtl;
