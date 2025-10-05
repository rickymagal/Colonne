-- File: rtl/core_mips5/forward_unit.vhd
-- Função: Resolve hazards de dados via forwarding.
-- Política correta: EX/MEM tem prioridade sobre MEM/WB.
-- fwd_*_sel codificação:
--   "00" -> usar valor original de ID/EX
--   "10" -> usar EX/MEM.alu_y
--   "01" -> usar MEM/WB.wb_data

library ieee;
use ieee.std_logic_1164.all;

entity forward_unit is
  port(
    idex_rs   : in  std_logic_vector(4 downto 0);
    idex_rt   : in  std_logic_vector(4 downto 0);
    exmem_rd  : in  std_logic_vector(4 downto 0);
    memwb_rd  : in  std_logic_vector(4 downto 0);
    exmem_we  : in  std_logic;
    memwb_we  : in  std_logic;
    fwd_a_sel : out std_logic_vector(1 downto 0);
    fwd_b_sel : out std_logic_vector(1 downto 0)
  );
end entity;

architecture rtl of forward_unit is
  function is_nonzero(reg5: std_logic_vector(4 downto 0)) return boolean is
  begin
    return reg5 /= "00000";
  end function;
begin
  -- A (RS)
  process(idex_rs, exmem_rd, memwb_rd, exmem_we, memwb_we)
  begin
    -- default: sem forwarding
    fwd_a_sel <= "00";

    -- prioridade EX/MEM
    if (exmem_we = '1') and is_nonzero(exmem_rd) and (exmem_rd = idex_rs) then
      fwd_a_sel <= "10";
    -- senão, MEM/WB
    elsif (memwb_we = '1') and is_nonzero(memwb_rd) and (memwb_rd = idex_rs) then
      fwd_a_sel <= "01";
    end if;
  end process;

  -- B (RT)
  process(idex_rt, exmem_rd, memwb_rd, exmem_we, memwb_we)
  begin
    -- default: sem forwarding
    fwd_b_sel <= "00";

    -- prioridade EX/MEM
    if (exmem_we = '1') and is_nonzero(exmem_rd) and (exmem_rd = idex_rt) then
      fwd_b_sel <= "10";
    -- senão, MEM/WB
    elsif (memwb_we = '1') and is_nonzero(memwb_rd) and (memwb_rd = idex_rt) then
      fwd_b_sel <= "01";
    end if;
  end process;
end architecture;
