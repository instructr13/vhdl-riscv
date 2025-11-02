library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package eei is

  -- 整数レジスタ長
  constant XLEN : natural := 64;
  -- 最大命令長
  constant ILEN : natural := 32;

  -- 読み書きデータ幅
  constant MEM_DATA_WIDTH : natural := 64;

  -- アドレス幅 (4096 words = 32KB)
  constant MEM_ADDR_WIDTH : natural := 12;

  subtype t_uintx is unsigned(XLEN - 1 downto 0);

  subtype t_uint32 is unsigned(31 downto 0);

  subtype t_uint64 is unsigned(63 downto 0);

  subtype t_sintx is signed(XLEN - 1 downto 0);

  subtype t_sint32 is signed(31 downto 0);

  subtype t_sint64 is signed(63 downto 0);

  -- 命令ビット列

  subtype t_inst is std_logic_vector(ILEN - 1 downto 0);

  -- メモリアドレス列

  subtype t_addr is unsigned(XLEN - 1 downto 0);

  -- Opcode
  constant OP_LUI       : std_logic_vector(6 downto 0) := "0110111";
  constant OP_AUIPC     : std_logic_vector(6 downto 0) := "0010111";
  constant OP_OP        : std_logic_vector(6 downto 0) := "0110011";
  constant OP_OP_32     : std_logic_vector(6 downto 0) := "0111011";
  constant OP_OP_IMM    : std_logic_vector(6 downto 0) := "0010011";
  constant OP_OP_IMM_32 : std_logic_vector(6 downto 0) := "0011011";
  constant OP_JAL       : std_logic_vector(6 downto 0) := "1101111";
  constant OP_JALR      : std_logic_vector(6 downto 0) := "1100111";
  constant OP_BRANCH    : std_logic_vector(6 downto 0) := "1100011";
  constant OP_LOAD      : std_logic_vector(6 downto 0) := "0000011";
  constant OP_STORE     : std_logic_vector(6 downto 0) := "0100011";
  constant OP_SYSTEM    : std_logic_vector(6 downto 0) := "1110011";

end package eei;
