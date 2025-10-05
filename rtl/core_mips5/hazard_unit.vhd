library ieee;
use ieee.std_logic_1164.all;
use work.pkg_types.all;

entity hazard_unit is
  port(
    -- ID stage source regs
    ifid_instr : in  std_logic_vector(31 downto 0);

    -- ID/EX info (the instruction currently in EX)
    idex_rt    : in  std_logic_vector(4 downto 0);
    idex_mem_cmd : in mem_cmd_t;

    -- outputs
    stall_if   : out std_logic;
    stall_id   : out std_logic;
    flush_ex   : out std_logic  -- insert bubble in EX
  );
end entity;

architecture rtl of hazard_unit is
  signal id_rs, id_rt : std_logic_vector(4 downto 0);
  signal load_use     : std_logic;
begin
  id_rs <= ifid_instr(25 downto 21);
  id_rt <= ifid_instr(20 downto 16);

  -- load-use when EX is a LOAD writing to rt and ID needs that reg
  load_use <= '1' when (idex_mem_cmd = MEM_LOAD) and
                      ( (idex_rt = id_rs) or (idex_rt = id_rt) ) and (idex_rt /= "00000")
              else '0';

  stall_if <= load_use;
  stall_id <= load_use;
  flush_ex <= load_use; -- turn the EX stage into bubble for one cycle
end architecture;
