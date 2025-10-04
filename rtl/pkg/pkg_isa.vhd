library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_isa is
  -- opcodes (subset)
  constant OPC_RTYPE : std_logic_vector(5 downto 0) := "000000";
  constant OPC_ADDI  : std_logic_vector(5 downto 0) := "001000";
  constant OPC_ANDI  : std_logic_vector(5 downto 0) := "001100";
  constant OPC_ORI   : std_logic_vector(5 downto 0) := "001101";
  constant OPC_XORI  : std_logic_vector(5 downto 0) := "001110";
  constant OPC_LUI   : std_logic_vector(5 downto 0) := "001111";
  constant OPC_LW    : std_logic_vector(5 downto 0) := "100011";
  constant OPC_SW    : std_logic_vector(5 downto 0) := "101011";

  -- funct
  constant FUNCT_ADD : std_logic_vector(5 downto 0) := "100000";
  constant FUNCT_SUB : std_logic_vector(5 downto 0) := "100010";
  constant FUNCT_AND : std_logic_vector(5 downto 0) := "100100";
  constant FUNCT_OR  : std_logic_vector(5 downto 0) := "100101";
  constant FUNCT_XOR : std_logic_vector(5 downto 0) := "100110";
  constant FUNCT_SLT : std_logic_vector(5 downto 0) := "101010";
  constant FUNCT_SLL : std_logic_vector(5 downto 0) := "000000";
  constant FUNCT_SRL : std_logic_vector(5 downto 0) := "000010";
  constant FUNCT_SRA : std_logic_vector(5 downto 0) := "000011";
end package;
