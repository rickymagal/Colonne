library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_types.all;  -- u32, mem_cmd_t

-- Estágio MEM: interface com RAM de dados.
entity mem_stage is
  port (
    clk        : in  std_logic;   -- presente para compatibilidade (não usado)
    mem_cmd    : in  mem_cmd_t;   -- MEM_NONE / MEM_LOAD / MEM_STORE

    addr       : in  u32;         -- endereço vindo da EX (exmem_alu_y)
    wdata      : in  u32;         -- dado para STORE (rt)

    dmem_rdata : in  u32;         -- dado lido da RAM
    dmem_addr  : out u32;
    dmem_wdata : out u32;
    dmem_we    : out std_logic;

    mem_out    : out u32          -- para WB (LOAD) ou zero caso contrário
  );
end entity mem_stage;

architecture rtl of mem_stage is
begin
  -- Conexões diretas
  dmem_addr  <= addr;
  dmem_wdata <= wdata;

  -- Escrita só em STORE
  dmem_we <= '1' when mem_cmd = MEM_STORE else '0';

  -- Saída ao próximo estágio
  mem_out <= dmem_rdata when mem_cmd = MEM_LOAD else (others => '0');
end architecture rtl;
