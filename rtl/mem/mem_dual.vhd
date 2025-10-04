library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mem_dual is
  generic(
    G_DEPTH_WORDS : integer := 1024
  );
  port(
    -- Port A: instruction (read-only)
    a_addr  : in  std_logic_vector(31 downto 0); -- byte address
    a_rdata : out std_logic_vector(31 downto 0);

    -- Port B: data (read/write)
    clk     : in  std_logic;
    b_we    : in  std_logic;
    b_addr  : in  std_logic_vector(31 downto 0); -- byte address
    b_wdata : in  std_logic_vector(31 downto 0);
    b_rdata : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of mem_dual is
  type mem_t is array (0 to G_DEPTH_WORDS-1) of std_logic_vector(31 downto 0);
  signal mem : mem_t := (others => (others => '0'));

  -- returns true if all bits are '0' or '1'
  function is_clean_slv(s: std_logic_vector) return boolean is
  begin
    for i in s'range loop
      if s(i) /= '0' and s(i) /= '1' then
        return false;
      end if;
    end loop;
    return true;
  end function;

  function word_index(addr: std_logic_vector(31 downto 0)) return integer is
  begin
    if not is_clean_slv(addr) then
      return -1; -- avoid to_integer on meta-values
    end if;
    return to_integer(unsigned(addr(31 downto 2))); -- word index
  end function;

begin
  -- Combinational read (Port A) — sensitive to address AND memory
  process(a_addr, mem)
    variable idx : integer;
  begin
    idx := word_index(a_addr);
    if idx >= 0 and idx < G_DEPTH_WORDS then
      a_rdata <= mem(idx);
    else
      a_rdata <= (others => '0');
    end if;
  end process;

  -- Combinational read (Port B) — sensitive to address AND memory
  process(b_addr, mem)
    variable idx : integer;
  begin
    idx := word_index(b_addr);
    if idx >= 0 and idx < G_DEPTH_WORDS then
      b_rdata <= mem(idx);
    else
      b_rdata <= (others => '0');
    end if;
  end process;

  -- Synchronous write (Port B)
  process(clk)
    variable idx : integer;
  begin
    if rising_edge(clk) then
      if b_we = '1' then
        idx := word_index(b_addr);
        if idx >= 0 and idx < G_DEPTH_WORDS then
          mem(idx) <= b_wdata;
        end if;
      end if;
    end if;
  end process;
end architecture;
