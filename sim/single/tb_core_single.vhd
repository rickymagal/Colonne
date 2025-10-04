library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_core_single is end;
architecture tb of tb_core_single is
  component core_single_top
    port(
      clk    : in  std_logic;
      rst    : in  std_logic;
      dbg_r6 : out std_logic_vector(31 downto 0)
    );
  end component;

  signal clk, rst : std_logic := '0';
  signal dbg_r6   : std_logic_vector(31 downto 0);

begin
  -- 100 MHz nominal (10 ns period)
  clk <= not clk after 5 ns;

  DUT: core_single_top
    port map(
      clk    => clk,
      rst    => rst,
      dbg_r6 => dbg_r6
    );

  stim: process
  begin
    rst <= '1'; wait for 40 ns;
    rst <= '0';

    -- Program has 9 instructions; give enough cycles
    wait for 300 ns;

    -- Expect 10 (0x0000000A) in $6
    assert dbg_r6 = x"0000000A"
      report "FAIL: $6 is " & integer'image(to_integer(unsigned(dbg_r6))) &
             ", expected 10"
      severity failure;

    report "TB finished OK" severity note;

    -- No stop here; let --stop-time terminate the sim with exit code 0
    wait;
  end process;
end architecture;
