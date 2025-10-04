library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_types.all;
use work.pkg_isa.all;

entity control_simple is
  port(
    instr      : in  std_logic_vector(31 downto 0);
    alu_op     : out alu_op_t;
    reg_dst    : out std_logic;  -- 1=rd, 0=rt
    reg_we     : out std_logic;
    alu_src    : out std_logic;  -- 1=imm, 0=reg
    mem_cmd    : out mem_cmd_t;  -- NONE/LOAD/STORE
    mem_to_reg : out std_logic   -- 1=from MEM, 0=ALU
  );
end entity;

architecture rtl of control_simple is
  signal op : std_logic_vector(5 downto 0);
  signal fn : std_logic_vector(5 downto 0);
begin
  op <= instr(31 downto 26);
  fn <= instr(5 downto 0);

  process(op, fn)
  begin
    alu_op     <= ALU_ADD;
    reg_dst    <= '0';
    reg_we     <= '0';
    alu_src    <= '0';
    mem_cmd    <= MEM_NONE;
    mem_to_reg <= '0';

    if op = OPC_RTYPE then
      reg_dst <= '1';
      reg_we  <= '1';
      case fn is
        when FUNCT_ADD => alu_op <= ALU_ADD;
        when FUNCT_SUB => alu_op <= ALU_SUB;
        when FUNCT_AND => alu_op <= ALU_AND;
        when FUNCT_OR  => alu_op <= ALU_OR;
        when FUNCT_XOR => alu_op <= ALU_XOR;
        when others    => reg_we <= '0';
      end case;

    elsif op = OPC_ADDI then
      reg_we  <= '1';
      alu_src <= '1';
      alu_op  <= ALU_ADD;

    elsif op = OPC_LW then
      reg_we     <= '1';
      alu_src    <= '1';
      mem_cmd    <= MEM_LOAD;
      mem_to_reg <= '1';
      alu_op     <= ALU_ADD; -- base + offset

    elsif op = OPC_SW then
      reg_we  <= '0';
      alu_src <= '1';
      mem_cmd <= MEM_STORE;
      alu_op  <= ALU_ADD; -- base + offset

    else
      -- Unsupported in Week 1 → NOP
      null;
    end if;
  end process;
end architecture;
