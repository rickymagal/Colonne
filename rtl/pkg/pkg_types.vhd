library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_types is
  subtype u1  is std_logic;
  subtype u5  is std_logic_vector(4 downto 0);
  subtype u6  is std_logic_vector(5 downto 0);
  subtype u32 is std_logic_vector(31 downto 0);

  type alu_op_t is (
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR,
    ALU_SLT, ALU_SLTU, ALU_SLL, ALU_SRL, ALU_SRA,
    ALU_PASS
  );

  type mem_cmd_t is (MEM_NONE, MEM_LOAD, MEM_STORE);
end package;
