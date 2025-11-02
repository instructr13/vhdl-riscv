library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
use work.eei.all;
use work.corectrl.all;

entity alu is
  port (
    ctrl   : in    t_inst_ctrl;
    op1    : in    t_uintx;
    op2    : in    t_uintx;
    result : out   t_uintx
  );
end entity alu;

architecture rtl of alu is

  signal s_add : t_uintx;
  signal s_sub : t_uintx;

  signal s_sll : t_uintx;
  signal s_srl : t_uintx;
  signal s_sra : t_sintx;

  signal s_slt  : t_uintx;
  signal s_sltu : t_uintx;

  -- 演算結果を 32 or 64bit で選択

  function sel_w (
    is_op32: in std_logic;
    value32: in t_uint32;
    value64: t_uint64
  )
  return t_uint64 is

    variable ret : t_uint64;

  begin

    if (is_op32 = '1') then
      ret := (31 downto 0 => value32(t_uint32'length - 1)) & value32;
    else
      ret := value64;
    end if;

    return ret;

  end function sel_w;

  signal s_add32 : t_uint32;
  signal s_sub32 : t_uint32;

  signal s_sll32 : t_uint32;
  signal s_srl32 : t_uint32;
  signal s_sra32 : t_sint32;

begin

  s_add <= op1 + op2;
  s_sub <= op1 - op2;

  s_sll <= op1 sll to_integer(op2(5 downto 0));
  s_srl <= op1 srl to_integer(op2(5 downto 0));
  s_sra <= shift_right(signed(op1), to_integer(op2(5 downto 0)));

  s_slt(XLEN - 1 downto 1)  <= (others => '0');
  s_sltu(XLEN - 1 downto 1) <= (others => '0');

  s_add32 <= op1(31 downto 0) + op2(31 downto 0);
  s_sub32 <= op1(31 downto 0) - op2(31 downto 0);

  s_sll32 <= op1(31 downto 0) sll to_integer(op2(4 downto 0));
  s_srl32 <= op1(31 downto 0) srl to_integer(op2(4 downto 0));
  s_sra32 <= shift_right(signed(op1(31 downto 0)), to_integer(op2(4 downto 0)));

  slt_comp : process (op1, op2) is
  begin

    if (signed(op1) < signed(op2)) then
      s_slt(0) <= '1';
    else
      s_slt(0) <= '0';
    end if;

    if (op1 < op2) then
      s_sltu(0) <= '1';
    else
      s_sltu(0) <= '0';
    end if;

  end process slt_comp;

  comb : process (ctrl, op1, op2, s_add, s_sub, s_sll, s_srl, s_sra, s_slt, s_sltu) is
  begin

    if (ctrl.is_aluop = '1') then

      case ctrl.funct3 is

        when "000" =>

          if (ctrl.itype = I or ctrl.funct7 = (ctrl.funct7'range => '0')) then
            result <= sel_w(ctrl.is_op32, s_add32, s_add);
          else
            result <= sel_w(ctrl.is_op32, s_sub32, s_sub);
          end if;

        when "001" =>

          result <= sel_w(ctrl.is_op32, s_sll32, s_sll);

        when "010" =>

          result <= s_slt;

        when "011" =>

          result <= s_sltu;

        when "100" =>

          result <= op1 xor op2;

        when "101" =>

          if (ctrl.funct7(5) = '0') then
            result <= sel_w(ctrl.is_op32, s_srl32, s_srl);
          else
            result <= sel_w(ctrl.is_op32, unsigned(s_sra32), unsigned(s_sra));
          end if;

        when "110" =>

          result <= op1 or op2;

        when "111" =>

          result <= op1 and op2;

        when others =>

          result <= (others => 'U');

      end case;

    else
      result <= s_add;
    end if;

  end process comb;

end architecture rtl;
