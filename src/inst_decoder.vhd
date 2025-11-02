library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
use work.eei.all;
use work.corectrl.all;

entity inst_decoder is
  port (
    bits : in    t_inst;
    ctrl : out   t_inst_ctrl;
    imm  : out   t_uintx
  );
end entity inst_decoder;

architecture rtl of inst_decoder is

  constant T : std_logic := '1';
  constant F : std_logic := '0';

begin

  comb : process (bits) is

    -- 即値の生成
    variable imm_i_g : std_logic_vector(11 downto 0);
    variable imm_s_g : std_logic_vector(11 downto 0);
    variable imm_b_g : std_logic_vector(11 downto 0);
    variable imm_u_g : std_logic_vector(19 downto 0);
    variable imm_j_g : std_logic_vector(19 downto 0);

    variable imm_i : std_logic_vector(XLEN - 1 downto 0);
    variable imm_s : std_logic_vector(XLEN - 1 downto 0);
    variable imm_b : std_logic_vector(XLEN - 1 downto 0);
    variable imm_u : std_logic_vector(XLEN - 1 downto 0);
    variable imm_j : std_logic_vector(XLEN - 1 downto 0);

    variable op : std_logic_vector(6 downto 0);
    variable f7 : std_logic_vector(6 downto 0);
    variable f3 : std_logic_vector(2 downto 0);

  begin

    imm_i_g := bits(31 downto 20);
    imm_s_g := bits(31 downto 25) & bits(11 downto 7);
    imm_b_g := bits(31) & bits(7) & bits(30 downto 25) & bits(11 downto 8);
    imm_u_g := bits(31 downto 12);
    imm_j_g := bits(31) & bits(19 downto 12) & bits(20) & bits(30 downto 21);

    imm_i := (XLEN - imm_i_g'length - 1 downto 0 => bits(31)) & imm_i_g;
    imm_s := (XLEN - imm_s_g'length - 1 downto 0 => bits(31)) & imm_s_g;
    imm_b := (XLEN - imm_b_g'length - 1 - 1 downto 0 => bits(31)) & imm_b_g & "0";
    imm_u := (XLEN - imm_u_g'length - 12 - 1 downto 0 => bits(31)) & imm_u_g & (11 downto 0 => '0');
    imm_j := (XLEN - imm_j_g'length - 1 - 1 downto 0 => bits(31)) & imm_j_g & "0";

    op := bits(6 downto 0);
    f7 := bits(31 downto 25);
    f3 := bits(14 downto 12);

    case op is

      when OP_LUI =>

        imm  <= unsigned(imm_u);
        ctrl <=
        (
          itype    => U,
          rwb_en   => T,
          is_lui   => T,
          is_aluop => F,
          is_op32  => F,
          is_jump  => F,
          is_load  => F,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

      when OP_AUIPC =>

        imm  <= unsigned(imm_u);
        ctrl <=
        (
          itype    => U,
          rwb_en   => T,
          is_lui   => F,
          is_aluop => F,
          is_op32  => F,
          is_jump  => F,
          is_load  => F,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

      when OP_JAL =>

        imm  <= unsigned(imm_j);
        ctrl <=
        (
          itype    => J,
          rwb_en   => T,
          is_lui   => F,
          is_aluop => F,
          is_op32  => F,
          is_jump  => T,
          is_load  => F,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

      when OP_JALR =>

        imm  <= unsigned(imm_i);
        ctrl <=
        (
          itype    => I,
          rwb_en   => T,
          is_lui   => F,
          is_aluop => F,
          is_op32  => F,
          is_jump  => T,
          is_load  => F,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

      when OP_LOAD =>

        imm  <= unsigned(imm_i);
        ctrl <=
        (
          itype    => I,
          rwb_en   => T,
          is_lui   => F,
          is_aluop => F,
          is_op32  => F,
          is_jump  => F,
          is_load  => T,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

      when OP_OP =>

        imm  <= (others => 'U');
        ctrl <=
        (
          itype    => R,
          rwb_en   => T,
          is_lui   => F,
          is_aluop => T,
          is_op32  => F,
          is_jump  => F,
          is_load  => F,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

      when OP_OP_32 =>

        imm  <= (others => 'U');
        ctrl <=
        (
          itype    => R,
          rwb_en   => T,
          is_lui   => F,
          is_aluop => T,
          is_op32  => T,
          is_jump  => F,
          is_load  => F,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

      when OP_OP_IMM =>

        imm  <= unsigned(imm_i);
        ctrl <=
        (
          itype    => I,
          rwb_en   => T,
          is_lui   => F,
          is_aluop => T,
          is_op32  => F,
          is_jump  => F,
          is_load  => F,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

      when OP_OP_IMM_32 =>

        imm  <= unsigned(imm_i);
        ctrl <=
        (
          itype    => I,
          rwb_en   => T,
          is_lui   => F,
          is_aluop => T,
          is_op32  => T,
          is_jump  => F,
          is_load  => F,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

      when OP_BRANCH =>

        imm  <= unsigned(imm_b);
        ctrl <=
        (
          itype    => B,
          rwb_en   => F,
          is_lui   => F,
          is_aluop => F,
          is_op32  => F,
          is_jump  => F,
          is_load  => F,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

      when OP_STORE =>

        imm  <= unsigned(imm_s);
        ctrl <=
        (
          itype    => S,
          rwb_en   => F,
          is_lui   => F,
          is_aluop => F,
          is_op32  => F,
          is_jump  => F,
          is_load  => F,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

      when OP_SYSTEM =>

        imm  <= unsigned(imm_i);
        ctrl <=
        (
          itype    => I,
          rwb_en   => T,
          is_lui   => F,
          is_aluop => F,
          is_op32  => F,
          is_jump  => F,
          is_load  => F,
          is_csr   => T,
          funct3   => f3,
          funct7   => f7
        );

      when others =>

        imm  <= (others => 'U');
        ctrl <=
        (
          itype    => X,
          rwb_en   => F,
          is_lui   => F,
          is_aluop => F,
          is_op32  => F,
          is_jump  => F,
          is_load  => F,
          is_csr   => F,
          funct3   => f3,
          funct7   => f7
        );

    end case;

  end process comb;

end architecture rtl;
