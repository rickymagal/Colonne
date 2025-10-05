library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_types.all;  -- u32, etc.

entity id_stage is
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;

    -- Da IF/ID
    instr        : in  u32;

    -- Banco de registradores (interface simples)
    regfile_rd1  : in  u32;                          -- dado lido em rs
    regfile_rd2  : in  u32;                          -- dado lido em rt
    regfile_ra1  : out std_logic_vector(4 downto 0); -- endereço rs
    regfile_ra2  : out std_logic_vector(4 downto 0); -- endereço rt

    -- Para ID/EX
    rs_idx_o     : out std_logic_vector(4 downto 0);
    rt_idx_o     : out std_logic_vector(4 downto 0);
    rd_idx_o     : out std_logic_vector(4 downto 0);
    rd1_to_ex    : out u32;  -- valor de rs
    rd2_to_ex    : out u32;  -- valor de rt
    imm_sext_o   : out u32
  );
end entity;

architecture rtl of id_stage is
  signal rs_idx : std_logic_vector(4 downto 0);
  signal rt_idx : std_logic_vector(4 downto 0);
  signal rd_idx : std_logic_vector(4 downto 0);
  signal imm16  : std_logic_vector(15 downto 0);
  signal imm32  : std_logic_vector(31 downto 0);
begin
  -- Campos da instrução MIPS
  rs_idx <= instr(25 downto 21);
  rt_idx <= instr(20 downto 16);
  rd_idx <= instr(15 downto 11);
  imm16  <= instr(15 downto 0);

  -- Sinal/extend
  imm32 <= std_logic_vector(resize(signed(imm16), 32));

  -- Endereços de leitura no regfile
  regfile_ra1 <= rs_idx;  -- rs
  regfile_ra2 <= rt_idx;  -- rt  (*** CRÍTICO: era aqui que muita gente liga errado ***)

  -- Saídas para o pipeline
  rs_idx_o   <= rs_idx;
  rt_idx_o   <= rt_idx;
  rd_idx_o   <= rd_idx;
  rd1_to_ex  <= regfile_rd1;  -- valor de rs
  rd2_to_ex  <= regfile_rd2;  -- valor de rt
  imm_sext_o <= u32(imm32);
end architecture;
