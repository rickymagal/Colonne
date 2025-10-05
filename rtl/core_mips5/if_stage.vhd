library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_types.all;

entity if_stage is
  port(
    clk       : in  std_logic;
    rst       : in  std_logic;

    -- control/hazard
    stall_if  : in  std_logic;
    flush_if  : in  std_logic;

    -- next PC control
    next_pc   : in  u32;       -- used when pc_sel='1'
    pc_sel    : in  std_logic; -- 1=use next_pc, else pc+4

    -- IMEM
    imem_rdata : in  u32;
    imem_addr  : out u32;

    -- IF/ID outputs
    if_pc      : out u32;
    if_instr   : out u32;
    if_valid   : out std_logic
  );
end entity;

architecture rtl of if_stage is
  signal pc_r   : u32 := (others => '0');
  signal instrr : u32 := (others => '0');
  signal validr : std_logic := '0';
  signal pc_inc : u32;
begin
  pc_inc <= std_logic_vector(unsigned(pc_r) + 4);

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pc_r   <= (others => '0');
        instrr <= (others => '0');
        validr <= '0';
      else
        if flush_if = '1' then
          -- Insert bubble; leave PC unless a redirect is requested
          validr <= '0';
          if pc_sel = '1' then
            pc_r <= next_pc;
          end if;
        elsif stall_if = '1' then
          -- Hold everything
          null;
        else
          -- Normal advance or redirect
          if pc_sel = '1' then
            pc_r <= next_pc;
          else
            pc_r <= pc_inc;
          end if;
          instrr <= imem_rdata;
          validr <= '1';
        end if;
      end if;
    end if;
  end process;

  -- IMEM address and IF outputs
  imem_addr <= pc_r;
  if_pc     <= pc_r;
  if_instr  <= instrr;
  if_valid  <= validr;
end architecture;
