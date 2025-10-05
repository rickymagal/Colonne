library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wb_stage is
  port(
    mem_to_reg : in  std_logic;
    alu_y      : in  std_logic_vector(31 downto 0);
    mem_data   : in  std_logic_vector(31 downto 0);
    wb_data    : out std_logic_vector(31 downto 0)
  );
end entity wb_stage;

architecture rtl of wb_stage is
begin
  -- Se mem_to_reg = '1' (LW), escreve dado da memória;
  -- senão, escreve resultado da ALU (tipo R/ADDI/etc).
  wb_data <= mem_data when mem_to_reg = '1' else alu_y;
end architecture rtl;
