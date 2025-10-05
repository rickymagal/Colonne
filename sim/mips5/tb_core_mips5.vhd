library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_core_mips5 is end;
architecture tb of tb_core_mips5 is
  component core_mips5_top
    port(
      clk   : in  std_logic;
      rst   : in  std_logic;
      dbg_r6: out std_logic_vector(31 downto 0)
    );
  end component;

  signal clk, rst : std_logic := '0';
  signal dbg_r6   : std_logic_vector(31 downto 0);
begin
  clk <= not clk after 5 ns;

  dut: core_mips5_top
    port map(clk=>clk, rst=>rst, dbg_r6=>dbg_r6);

  process
  begin
    rst <= '1'; wait for 40 ns;
    rst <= '0';
    wait for 700 ns; -- give pipeline time
    assert dbg_r6 = x"0000000A"
      report "FAIL: $6=" & integer'image(to_integer(unsigned(dbg_r6))) & " expected 10"
      severity failure;
    report "TB finished OK (Week 2 pipeline)" severity note;
    wait;
  end process;
end architecture;
