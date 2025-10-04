library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity regfile is
  port(
    clk    : in  std_logic;
    we     : in  std_logic;
    waddr  : in  std_logic_vector(4 downto 0);
    wdata  : in  std_logic_vector(31 downto 0);
    raddr1 : in  std_logic_vector(4 downto 0);
    raddr2 : in  std_logic_vector(4 downto 0);
    rdata1 : out std_logic_vector(31 downto 0);
    rdata2 : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of regfile is
  type reg_array is array (31 downto 0) of std_logic_vector(31 downto 0);
  signal regs : reg_array := (others => (others => '0'));
begin
  rdata1 <= (others=>'0') when raddr1 = "00000" else regs(to_integer(unsigned(raddr1)));
  rdata2 <= (others=>'0') when raddr2 = "00000" else regs(to_integer(unsigned(raddr2)));

  process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' and waddr /= "00000" then
        regs(to_integer(unsigned(waddr))) <= wdata;
      end if;
    end if;
  end process;
end architecture;
