library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_types.all;

entity core_single_top is
  port(
    clk     : in  std_logic;
    rst     : in  std_logic;
    dbg_r6  : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of core_single_top is
  component mem_dual
    generic(G_DEPTH_WORDS : integer := 1024);
    port(
      a_addr  : in  std_logic_vector(31 downto 0);
      a_rdata : out std_logic_vector(31 downto 0);
      clk     : in  std_logic;
      b_we    : in  std_logic;
      b_addr  : in  std_logic_vector(31 downto 0);
      b_wdata : in  std_logic_vector(31 downto 0);
      b_rdata : out std_logic_vector(31 downto 0)
    );
  end component;

  component regfile
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
  end component;

  component alu
    port(
      a, b : in  std_logic_vector(31 downto 0);
      op   : in  alu_op_t;
      y    : out std_logic_vector(31 downto 0)
    );
  end component;

  component control_simple
    port(
      instr      : in  std_logic_vector(31 downto 0);
      alu_op     : out alu_op_t;
      reg_dst    : out std_logic;
      reg_we     : out std_logic;
      alu_src    : out std_logic;
      mem_cmd    : out mem_cmd_t;
      mem_to_reg : out std_logic
    );
  end component;

  -- === VHDL-93 HEX HELPERS ===
  function nybble_to_char(n : std_logic_vector(3 downto 0)) return character is
    variable u : unsigned(3 downto 0);
  begin
    u := unsigned(n);
    if u < 10 then
      return character'val(character'pos('0') + to_integer(u));
    else
      return character'val(character'pos('A') + to_integer(u) - 10);
    end if;
  end function;

  function slv32_to_hex(s : std_logic_vector(31 downto 0)) return string is
    variable res : string(1 to 8);
    variable nib : std_logic_vector(3 downto 0);
  begin
    for i in 0 to 7 loop
      nib := s(31 - i*4 downto 28 - i*4);
      res(i+1) := nybble_to_char(nib);
    end loop;
    return res;
  end function;

  -- PC and instruction
  signal pc          : std_logic_vector(31 downto 0) := (others => '0');
  signal instr       : std_logic_vector(31 downto 0);
  signal mem_i_rdata : std_logic_vector(31 downto 0);

  -- Decode fields
  signal rs, rt, rd : std_logic_vector(4 downto 0);
  signal imm16      : std_logic_vector(15 downto 0);
  signal imm_sext   : std_logic_vector(31 downto 0);

  -- Control
  signal alu_op     : alu_op_t;
  signal reg_dst    : std_logic;
  signal reg_we     : std_logic;
  signal alu_src    : std_logic;
  signal mem_cmd    : mem_cmd_t;
  signal mem_to_reg : std_logic;

  -- Register file
  signal reg_waddr  : std_logic_vector(4 downto 0);
  signal reg_wdata  : std_logic_vector(31 downto 0);
  signal rs_data, rt_data : std_logic_vector(31 downto 0);

  -- ALU
  signal alu_b   : std_logic_vector(31 downto 0);
  signal alu_y   : std_logic_vector(31 downto 0);

  -- Data memory
  signal mem_d_rdata : std_logic_vector(31 downto 0);
  signal mem_we      : std_logic;
  signal mem_addr    : std_logic_vector(31 downto 0);
  signal mem_wdata   : std_logic_vector(31 downto 0);

  -- Debug
  signal r6_value : std_logic_vector(31 downto 0) := (others=>'0');

  -- Small inline ROM for first 9 words
  type rom_t is array (0 to 8) of std_logic_vector(31 downto 0);
  constant ROM : rom_t := (
    0 => x"20010001", -- addi $1,$0,1
    1 => x"20020002", -- addi $2,$0,2
    2 => x"20030003", -- addi $3,$0,3
    3 => x"00222020", -- add  $4,$1,$2
    4 => x"00832020", -- add  $4,$4,$3
    5 => x"20050004", -- addi $5,$0,4
    6 => x"00852020", -- add  $4,$4,$5   => $4 = 10
    7 => x"AC040100", -- sw   $4,0x0100($0)
    8 => x"8C060100"  -- lw   $6,0x0100($0)
  );

  function pc_to_index(p: std_logic_vector(31 downto 0)) return integer is
  begin
    if p(31 downto 9) /= (p(31 downto 9)'range => '0') then
      return -1;
    end if;
    return to_integer(unsigned(p(8 downto 2)));
  end function;

  signal instr_from_rom : std_logic_vector(31 downto 0);
  signal instr_sel_rom  : std_logic := '0';

begin
  -- PC
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pc <= (others => '0');
      else
        pc <= std_logic_vector(unsigned(pc) + 4);
      end if;
    end if;
  end process;

  -- Unified memory
  u_mem: mem_dual
    generic map(G_DEPTH_WORDS => 1024)
    port map(
      a_addr  => pc,
      a_rdata => mem_i_rdata,
      clk     => clk,
      b_we    => mem_we,
      b_addr  => mem_addr,
      b_wdata => mem_wdata,
      b_rdata => mem_d_rdata
    );

  -- ROM fetch
  process(pc)
    variable idx : integer;
  begin
    idx := pc_to_index(pc);
    if idx >= 0 and idx <= 8 then
      instr_from_rom <= ROM(idx);
      instr_sel_rom  <= '1';
    else
      instr_from_rom <= (others => '0');
      instr_sel_rom  <= '0';
    end if;
  end process;

  -- Single instruction driver
  instr <= instr_from_rom when instr_sel_rom = '1' else mem_i_rdata;

  -- DEBUG: IFETCH
  process(clk)
    variable shown : integer := 0;
  begin
    if rising_edge(clk) then
      if rst = '0' and shown < 20 then
        report "IFETCH pc=0x" & slv32_to_hex(pc) &
               " instr=0x" & slv32_to_hex(instr) severity note;
        shown := shown + 1;
      end if;
    end if;
  end process;

  -- Decode
  rs    <= instr(25 downto 21);
  rt    <= instr(20 downto 16);
  rd    <= instr(15 downto 11);
  imm16 <= instr(15 downto 0);
  imm_sext <= (31 downto 16 => imm16(15)) & imm16;

  -- Control
  u_ctl: control_simple
    port map(
      instr      => instr,
      alu_op     => alu_op,
      reg_dst    => reg_dst,
      reg_we     => reg_we,
      alu_src    => alu_src,
      mem_cmd    => mem_cmd,
      mem_to_reg => mem_to_reg
    );

  -- Regfile
  u_rf: regfile
    port map(
      clk    => clk,
      we     => reg_we,
      waddr  => reg_waddr,
      wdata  => reg_wdata,
      raddr1 => rs,
      raddr2 => rt,
      rdata1 => rs_data,
      rdata2 => rt_data
    );

  -- ALU
  alu_b <= imm_sext when alu_src = '1' else rt_data;
  u_alu: alu port map(a => rs_data, b => alu_b, op => alu_op, y => alu_y);

  -- Data memory
  mem_addr  <= alu_y;
  mem_wdata <= rt_data;
  mem_we    <= '1' when mem_cmd = MEM_STORE else '0';

  -- DEBUG: STORE
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' and mem_we = '1' then
        report "STORE  addr=0x" & slv32_to_hex(mem_addr) &
               " data=0x" & slv32_to_hex(mem_wdata) severity note;
      end if;
    end if;
  end process;

  -- Writeback
  reg_waddr <= rd when reg_dst = '1' else rt;
  reg_wdata <= mem_d_rdata when mem_to_reg = '1' else alu_y;

  -- DEBUG: WB
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' and reg_we = '1' then
        report "WB     r" & integer'image(to_integer(unsigned(reg_waddr))) &
               " = 0x" & slv32_to_hex(reg_wdata) severity note;
      end if;
    end if;
  end process;

  -- Capture last write to $6
  process(clk)
  begin
    if rising_edge(clk) then
      if reg_we = '1' and reg_waddr = "00110" then
        r6_value <= reg_wdata;
      end if;
    end if;
  end process;

  dbg_r6 <= r6_value;

end architecture;
