library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_types.all;  -- u32, mem_cmd_t, alu_op_t

-- Decodificador de controle: R-type, ADDI, LW, SW, BEQ
entity control_decode is
  port (
    instr      : in  u32;          -- instrução de 32 bits

    reg_dst    : out std_logic;    -- 1: destino = rd (R-type), 0: destino = rt (I-type)
    alu_src    : out std_logic;    -- 1: segundo operando vem do imediato
    mem_to_reg : out std_logic;    -- 1: writeback vem da memória (LW)
    reg_we     : out std_logic;    -- habilita escrita no banco de registradores

    mem_cmd    : out mem_cmd_t;    -- MEM_NONE / MEM_LOAD / MEM_STORE
    alu_op     : out alu_op_t      -- ALU_ADD / ALU_SUB / ...
  );
end entity control_decode;

architecture rtl of control_decode is
begin
  process(instr)
    variable op_i    : integer range 0 to 63;
    variable funct_i : integer range 0 to 63;
  begin
    -- defaults (NOP seguro)
    reg_dst    <= '0';
    alu_src    <= '0';
    mem_to_reg <= '0';
    reg_we     <= '0';
    mem_cmd    <= MEM_NONE;
    alu_op     <= ALU_PASS;

    -- extrai campos como INTEIRO para case estático
    op_i    := to_integer(unsigned(instr(31 downto 26)));
    funct_i := to_integer(unsigned(instr(5  downto  0)));

    case op_i is
      -- R-type (opcode 0x00)
      when 16#00# =>
        reg_dst    <= '1';
        alu_src    <= '0';
        mem_to_reg <= '0';
        reg_we     <= '1';
        mem_cmd    <= MEM_NONE;

        case funct_i is
          when 16#20# => alu_op <= ALU_ADD; -- ADD
          when 16#22# => alu_op <= ALU_SUB; -- SUB
          when 16#24# => alu_op <= ALU_AND; -- AND
          when 16#25# => alu_op <= ALU_OR;  -- OR
          when 16#26# => alu_op <= ALU_XOR; -- XOR
          when 16#2A# => alu_op <= ALU_SLT; -- SLT
          when 16#00# => alu_op <= ALU_SLL; -- SLL
          when 16#02# => alu_op <= ALU_SRL; -- SRL
          when 16#03# => alu_op <= ALU_SRA; -- SRA
          when others => alu_op <= ALU_PASS;
        end case;

      -- ADDI (0x08)
      when 16#08# =>
        reg_dst    <= '0';
        alu_src    <= '1';
        mem_to_reg <= '0';
        reg_we     <= '1';
        mem_cmd    <= MEM_NONE;
        alu_op     <= ALU_ADD;

      -- LW (0x23)
      when 16#23# =>
        reg_dst    <= '0';
        alu_src    <= '1';
        mem_to_reg <= '1';
        reg_we     <= '1';
        mem_cmd    <= MEM_LOAD;
        alu_op     <= ALU_ADD;     -- base + imediato

      -- SW (0x2B)
      when 16#2B# =>
        reg_dst    <= '0';
        alu_src    <= '1';
        mem_to_reg <= '0';
        reg_we     <= '0';
        mem_cmd    <= MEM_STORE;
        alu_op     <= ALU_ADD;     -- base + imediato

      -- BEQ (0x04) – comparação via SUB; controle de branch fora daqui
      when 16#04# =>
        reg_dst    <= '0';
        alu_src    <= '0';
        mem_to_reg <= '0';
        reg_we     <= '0';
        mem_cmd    <= MEM_NONE;
        alu_op     <= ALU_SUB;

      -- default: NOP
      when others =>
        reg_dst    <= '0';
        alu_src    <= '0';
        mem_to_reg <= '0';
        reg_we     <= '0';
        mem_cmd    <= MEM_NONE;
        alu_op     <= ALU_PASS;
    end case;
  end process;
end architecture rtl;
