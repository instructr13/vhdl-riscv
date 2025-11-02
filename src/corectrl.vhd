library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package corectrl is

  -- 命令形式を表す列挙型

  type t_inst_type is (X, R, I, S, B, U, J);

  type t_inst_type_lookup is array(t_inst_type) of std_logic_vector(5 downto 0);

  constant INST_TYPE : t_inst_type_lookup :=
  (
    X => "000000",
    R => "000001",
    I => "000010",
    S => "000100",
    B => "001000",
    U => "010000",
    J => "100000"
  );

  -- 制御に使うフラグ用の構造体

  type t_inst_ctrl is record
    itype    : t_inst_type; -- 命令形式
    rwb_en   : std_logic;   -- レジスタに書き込むかどうか
    is_lui   : std_logic;   -- LUI 命令である
    is_aluop : std_logic;   -- ALU を利用する命令である
    is_op32  : std_logic;   -- OP-32 または OP-IMM-32 である
    is_jump  : std_logic;   -- ジャンプ命令である
    is_load  : std_logic;   -- ロード命令である
    is_csr   : std_logic;   -- CSR 命令である
    funct3   : std_logic_vector(2 downto 0);
    funct7   : std_logic_vector(6 downto 0);
  end record t_inst_ctrl;

  constant INST_CTRL_LEN: natural := 3 + (1 * 7) + 3 + 7;

  function inst_ctrl_to_vector(r : t_inst_ctrl) return std_logic_vector;
  function inst_ctrl_from_vector(v : std_logic_vector) return t_inst_ctrl;

end package corectrl;

package body corectrl is
  function inst_ctrl_to_vector(r : t_inst_ctrl) return std_logic_vector is
    variable ret : std_logic_vector(INST_CTRL_LEN - 1 downto 0);

    variable itype_bits : std_logic_vector(2 downto 0);
  begin
    itype_bits := std_logic_vector(to_unsigned(t_inst_type'pos(r.itype), 3));

    ret := itype_bits &
           r.rwb_en &
           r.is_lui &
           r.is_aluop &
           r.is_op32 &
           r.is_jump &
           r.is_load &
           r.is_csr &
           r.funct3 &
           r.funct7;

    return ret;
  end function inst_ctrl_to_vector;

  function inst_ctrl_from_vector(v : std_logic_vector) return t_inst_ctrl is
    variable ret : t_inst_ctrl;

    variable itype_bits : std_logic_vector(2 downto 0);
    variable pos : natural;
  begin
    pos := INST_CTRL_LEN - 1;
    
    itype_bits := v(pos downto pos - 2);
    ret.itype := t_inst_type'val(to_integer(unsigned(itype_bits)));
    pos := pos - 3;
    
    ret.rwb_en := v(pos);
    pos := pos - 1;
    
    ret.is_lui := v(pos);
    pos := pos - 1;
    
    ret.is_aluop := v(pos);
    pos := pos - 1;
    
    ret.is_op32 := v(pos);
    pos := pos - 1;
    
    ret.is_jump := v(pos);
    pos := pos - 1;
    
    ret.is_load := v(pos);
    pos := pos - 1;
    
    ret.is_csr := v(pos);
    pos := pos - 3 - 7;
    
    ret.funct3 := v(pos + 3 + 7 - 1 downto pos + 7);
    
    ret.funct7 := v(pos + 7 - 1 downto pos);

    return ret;
  end function inst_ctrl_from_vector;

end package body corectrl;
