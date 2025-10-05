-- File: rtl/core_mips5/core_mips5_top.vhd
-- 5-stage MIPS (VHDL-93), com ROM inline e forwarding + hazard
-- Fix: WB->ID bypass para leituras no mesmo ciclo (write-first emulado)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_types.all;

entity core_mips5_top is
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;
    dbg_r6: out std_logic_vector(31 downto 0)
  );
end;

architecture rtl of core_mips5_top is
  -- ====== Componentes ======
  component mem_dual
    generic(G_DEPTH_WORDS: integer := 1024);
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

  component control_decode
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

  component forward_unit
    port(
      idex_rs,idex_rt,exmem_rd,memwb_rd : in std_logic_vector(4 downto 0);
      exmem_we,memwb_we                 : in std_logic;
      fwd_a_sel,fwd_b_sel               : out std_logic_vector(1 downto 0)
    );
  end component;

  component hazard_unit
    port(
      ifid_instr     : in std_logic_vector(31 downto 0);
      idex_rt        : in std_logic_vector(4 downto 0);
      idex_mem_cmd   : in mem_cmd_t;
      stall_if       : out std_logic;
      stall_id       : out std_logic;
      flush_ex       : out std_logic
    );
  end component;

  component ex_stage
    port(
      clk, rst        : in  std_logic;
      -- valores já com forwarding local (vindos do ID/EX)
      id_rs_val       : in  std_logic_vector(31 downto 0);
      id_rt_val       : in  std_logic_vector(31 downto 0);
      imm_sext        : in  std_logic_vector(31 downto 0);
      alu_src         : in  std_logic;
      alu_op          : in  alu_op_t;
      -- fontes para forwarding (EX/MEM e MEM/WB do ciclo atual)
      exmem_val       : in  std_logic_vector(31 downto 0);
      memwb_val       : in  std_logic_vector(31 downto 0);
      fwd_a_sel       : in  std_logic_vector(1 downto 0);
      fwd_b_sel       : in  std_logic_vector(1 downto 0);
      alu_y           : out std_logic_vector(31 downto 0);
      store_d         : out std_logic_vector(31 downto 0)
    );
  end component;

  component mem_stage
    port(
      clk       : in  std_logic;
      mem_cmd   : in  mem_cmd_t;
      addr      : in  std_logic_vector(31 downto 0);
      wdata     : in  std_logic_vector(31 downto 0);
      dmem_rdata: in  std_logic_vector(31 downto 0);
      dmem_addr : out std_logic_vector(31 downto 0);
      dmem_wdata: out std_logic_vector(31 downto 0);
      dmem_we   : out std_logic;
      mem_out   : out std_logic_vector(31 downto 0)
    );
  end component;

  component wb_stage
    port(
      mem_to_reg : in  std_logic;
      alu_y      : in  std_logic_vector(31 downto 0);
      mem_data   : in  std_logic_vector(31 downto 0);
      wb_data    : out std_logic_vector(31 downto 0)
    );
  end component;

  component regfile
    port(
      clk   : in  std_logic;
      we    : in  std_logic;
      waddr : in  std_logic_vector(4 downto 0);
      wdata : in  std_logic_vector(31 downto 0);
      raddr1: in  std_logic_vector(4 downto 0);
      raddr2: in  std_logic_vector(4 downto 0);
      rdata1: out std_logic_vector(31 downto 0);
      rdata2: out std_logic_vector(31 downto 0)
    );
  end component;

  -- ===== ROM do programa (9 palavras) =====
  type rom_t is array (0 to 8) of std_logic_vector(31 downto 0);
  constant ROM : rom_t := (
    0 => x"20010001", -- addi $1,$0,1
    1 => x"20020002", -- addi $2,$0,2
    2 => x"20030003", -- addi $3,$0,3
    3 => x"00222020", -- add  $4,$1,$2
    4 => x"00832020", -- add  $4,$4,$3
    5 => x"20050004", -- addi $5,$0,4
    6 => x"00852020", -- add  $4,$4,$5 (=10)
    7 => x"AC040100", -- sw   $4,0x0100($0)
    8 => x"8C060100"  -- lw   $6,0x0100($0)
  );

  -- ===== Helpers p/ logs em VHDL-93 =====
  function nyb2c(n: std_logic_vector(3 downto 0)) return character is
    variable u: unsigned(3 downto 0);
  begin
    u := unsigned(n);
    if u < 10 then
      return character'val(character'pos('0') + to_integer(u));
    else
      return character'val(character'pos('A') + to_integer(u) - 10);
    end if;
  end;

  function slv32hex(s: std_logic_vector(31 downto 0)) return string is
    variable r: string(1 to 8);
    variable nib: std_logic_vector(3 downto 0);
  begin
    for i in 0 to 7 loop
      nib := s(31-4*i downto 28-4*i);
      r(i+1) := nyb2c(nib);
    end loop;
    return r;
  end;

  -- ===== IF =====
  signal pc          : u32 := (others=>'0');
  signal imem_rdata  : u32;

  -- ===== IF/ID (REG) =====
  signal ifid_pc, ifid_instr : u32 := (others=>'0');
  signal ifid_valid          : std_logic := '0';

  -- ===== ID =====
  signal id_pc, id_instr : u32;
  signal id_valid        : std_logic;
  signal rs_addr, rt_addr: std_logic_vector(4 downto 0);
  signal rs_data, rt_data: u32;

  -- *** WB->ID bypass (valores que entram no ID/EX) ***
  signal id_rs_val, id_rt_val : u32;

  -- Controle (gerado a partir de id_instr!)
  signal c_alu_op : alu_op_t;
  signal c_reg_dst, c_reg_we, c_alu_src, c_m2r: std_logic;
  signal c_mem_cmd: mem_cmd_t;

  -- ===== ID/EX (REG) =====
  signal idex_rs_data, idex_rt_data : u32;
  signal idex_imm_sext : u32;
  signal idex_reg_dst, idex_reg_we, idex_alu_src, idex_m2r : std_logic;
  signal idex_mem_cmd : mem_cmd_t;
  signal idex_alu_op  : alu_op_t;
  signal idex_rs_addr, idex_rt_addr, idex_rd_addr : std_logic_vector(4 downto 0);

  -- ===== EX =====
  signal ex_alu_y, ex_rt_pass : u32;

  -- ===== EX/MEM (REG) =====
  signal exmem_alu_y   : u32;
  signal exmem_store_d : u32;
  signal exmem_rd      : std_logic_vector(4 downto 0);
  signal exmem_we      : std_logic;
  signal exmem_mem_cmd : mem_cmd_t;
  signal exmem_m2r     : std_logic;

  -- ===== MEM =====
  signal mem_out_data : u32;
  signal d_addr, d_wdata : u32;
  signal d_rdata : u32;
  signal d_we : std_logic;

  -- ===== MEM/WB (REG) =====
  signal memwb_alu_y  : u32;
  signal memwb_memout : u32;
  signal memwb_rd     : std_logic_vector(4 downto 0);
  signal memwb_we     : std_logic;
  signal memwb_m2r    : std_logic;

  -- Forward/Hazard
  signal fwd_a_sel, fwd_b_sel : std_logic_vector(1 downto 0);
  signal stall_if, stall_id, flush_ex : std_logic;

  -- Regfile WB
  signal rf_waddr : std_logic_vector(4 downto 0);
  signal rf_wdata : u32;
  signal rf_we    : std_logic;

  -- Debug
  signal r6_value : u32 := (others=>'0');

begin
  -- ===== PC =====
  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        pc <= (others=>'0');
      elsif stall_if='1' then
        null;
      else
        pc <= std_logic_vector(unsigned(pc) + 4);
      end if;
    end if;
  end process;

  -- ===== IMEM (ROM inline) =====
  process(pc)
    variable idx: integer;
  begin
    idx := to_integer(unsigned(pc(8 downto 2)));
    if pc(31 downto 9) = (pc(31 downto 9)'range => '0') and idx>=0 and idx<=8 then
      imem_rdata <= ROM(idx);
    else
      imem_rdata <= (others=>'0');
    end if;
  end process;

  -- ===== IF/ID REG =====
  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        ifid_pc    <= (others=>'0');
        ifid_instr <= (others=>'0');
        ifid_valid <= '0';
      elsif stall_id='1' then
        null; -- segura IF/ID
      else
        ifid_pc    <= pc;
        ifid_instr <= imem_rdata;
        ifid_valid <= '1';
      end if;
    end if;
  end process;

  -- Alias para estágio ID
  id_pc    <= ifid_pc;
  id_instr <= ifid_instr;
  id_valid <= ifid_valid;

  -- ===== Controle a partir de id_instr =====
  u_ctl: control_decode
    port map(
      instr      => id_instr,
      alu_op     => c_alu_op,
      reg_dst    => c_reg_dst,
      reg_we     => c_reg_we,
      alu_src    => c_alu_src,
      mem_cmd    => c_mem_cmd,
      mem_to_reg => c_m2r
    );

  -- ===== Regfile =====
  rs_addr <= id_instr(25 downto 21);
  rt_addr <= id_instr(20 downto 16);

  regfile_inst: regfile
    port map(
      clk    => clk,
      we     => rf_we,
      waddr  => rf_waddr,
      wdata  => rf_wdata,
      raddr1 => rs_addr,
      raddr2 => rt_addr,
      rdata1 => rs_data,
      rdata2 => rt_data
    );

  -- ===== WB->ID BYPASS (write-first emulado) =====
  -- Se o WB estiver escrevendo no mesmo registrador lido na fase ID,
  -- use o dado do WB em vez do valor lido do banco.
  id_rs_val <= rf_wdata when (rf_we='1' and rf_waddr = rs_addr and rs_addr /= "00000") else rs_data;
  id_rt_val <= rf_wdata when (rf_we='1' and rf_waddr = rt_addr and rt_addr /= "00000") else rt_data;

  -- ===== ID/EX REG =====
  process(clk)
    variable imm_sx : std_logic_vector(31 downto 0);
  begin
    if rising_edge(clk) then
      if rst='1' or flush_ex='1' then
        idex_rs_data <= (others=>'0');
        idex_rt_data <= (others=>'0');
        idex_imm_sext<= (others=>'0');
        idex_reg_dst <= '0';
        idex_reg_we  <= '0';
        idex_alu_src <= '0';
        idex_m2r     <= '0';
        idex_mem_cmd <= MEM_NONE;
        idex_alu_op  <= ALU_ADD;
        idex_rs_addr <= (others=>'0');
        idex_rt_addr <= (others=>'0');
        idex_rd_addr <= (others=>'0');
      elsif stall_id='1' then
        null;
      else
        imm_sx := (31 downto 16 => id_instr(15)) & id_instr(15 downto 0);
        idex_rs_data <= id_rs_val;  -- <<< usa bypass
        idex_rt_data <= id_rt_val;  -- <<< usa bypass
        idex_imm_sext<= imm_sx;
        idex_reg_dst <= c_reg_dst;
        idex_reg_we  <= c_reg_we;
        idex_alu_src <= c_alu_src;
        idex_m2r     <= c_m2r;
        idex_mem_cmd <= c_mem_cmd;
        idex_alu_op  <= c_alu_op;
        idex_rs_addr <= id_instr(25 downto 21);
        idex_rt_addr <= id_instr(20 downto 16);
        idex_rd_addr <= id_instr(15 downto 11);
      end if;
    end if;
  end process;

  -- ===== Hazard (load-use) =====
  hazard: entity work.hazard_unit
    port map(
      ifid_instr   => id_instr,
      idex_rt      => idex_rt_addr,
      idex_mem_cmd => idex_mem_cmd,
      stall_if     => stall_if,
      stall_id     => stall_id,
      flush_ex     => flush_ex
    );

  -- ===== Forward =====
  fwd: entity work.forward_unit
    port map(
      idex_rs   => idex_rs_addr,
      idex_rt   => idex_rt_addr,
      exmem_rd  => exmem_rd,   exmem_we => exmem_we,
      memwb_rd  => memwb_rd,   memwb_we => memwb_we,
      fwd_a_sel => fwd_a_sel,  fwd_b_sel => fwd_b_sel
    );

  -- ===== EX =====
  ex: entity work.ex_stage
    port map(
      clk        => clk,
      rst        => rst,
      id_rs_val  => idex_rs_data,
      id_rt_val  => idex_rt_data,
      imm_sext   => idex_imm_sext,
      alu_src    => idex_alu_src,
      alu_op     => idex_alu_op,
      exmem_val  => exmem_alu_y,
      memwb_val  => rf_wdata,       -- dado já selecionado de WB
      fwd_a_sel  => fwd_a_sel,
      fwd_b_sel  => fwd_b_sel,
      alu_y      => ex_alu_y,
      store_d    => ex_rt_pass
    );

  -- ===== EX/MEM REG =====
  process(clk)
    variable rd_sel : std_logic_vector(4 downto 0);
  begin
    if rising_edge(clk) then
      if rst='1' then
        exmem_alu_y   <= (others=>'0');
        exmem_store_d <= (others=>'0');
        exmem_rd      <= (others=>'0');
        exmem_we      <= '0';
        exmem_mem_cmd <= MEM_NONE;
        exmem_m2r     <= '0';
      else
        rd_sel := idex_rd_addr;
        if idex_reg_dst = '0' then
          rd_sel := idex_rt_addr;
        end if;
        exmem_alu_y   <= ex_alu_y;
        exmem_store_d <= ex_rt_pass;
        exmem_rd      <= rd_sel;
        exmem_we      <= idex_reg_we;
        exmem_mem_cmd <= idex_mem_cmd;
        exmem_m2r     <= idex_m2r;
      end if;
    end if;
  end process;

  -- ===== MEM + DMEM =====
  mem: entity work.mem_stage
    port map(
      clk        => clk,
      mem_cmd    => exmem_mem_cmd,
      addr       => exmem_alu_y,
      wdata      => exmem_store_d,
      dmem_rdata => d_rdata,
      dmem_addr  => d_addr,
      dmem_wdata => d_wdata,
      dmem_we    => d_we,
      mem_out    => mem_out_data
    );

  dmem: mem_dual
    generic map(G_DEPTH_WORDS => 1024)
    port map(
      a_addr  => (others=>'0'), a_rdata => open,
      clk     => clk,
      b_we    => d_we,
      b_addr  => d_addr,
      b_wdata => d_wdata,
      b_rdata => d_rdata
    );

  -- ===== MEM/WB REG =====
  process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        memwb_alu_y  <= (others=>'0');
        memwb_memout <= (others=>'0');
        memwb_rd     <= (others=>'0');
        memwb_we     <= '0';
        memwb_m2r    <= '0';
      else
        memwb_alu_y  <= exmem_alu_y;
        memwb_memout <= mem_out_data;
        memwb_rd     <= exmem_rd;
        memwb_we     <= exmem_we;
        memwb_m2r    <= exmem_m2r;
      end if;
    end if;
  end process;

  -- ===== WB =====
  wb: entity work.wb_stage
    port map(
      mem_to_reg => memwb_m2r,
      alu_y      => memwb_alu_y,
      mem_data   => memwb_memout,
      wb_data    => rf_wdata
    );

  rf_we    <= memwb_we;
  rf_waddr <= memwb_rd;

  -- ===== Debug: trava $6 =====
  process(clk)
  begin
    if rising_edge(clk) then
      if rf_we='1' and rf_waddr="00110" then
        r6_value <= rf_wdata;
      end if;
    end if;
  end process;

  dbg_r6 <= r6_value;

  -- ===== Logs de estágio =====
  process(clk)
    variable we_str : string(1 to 1);
  begin
    if rising_edge(clk) then
      if rst = '0' then
        -- IF
        report "IF  pc=0x" & slv32hex(pc) &
               " instr=0x" & slv32hex(imem_rdata) severity note;

        -- ID
        report "ID  instr=0x" & slv32hex(id_instr) severity note;

        -- EX
        report "EX  alu=0x" & slv32hex(ex_alu_y) severity note;

        -- MEM
        if d_we = '1' then we_str := "1"; else we_str := "0"; end if;
        report "MEM we=" & we_str & " addr=0x" & slv32hex(d_addr) severity note;

        -- WB
        report "WB  rd=" & integer'image(to_integer(unsigned(memwb_rd))) &
               " data=0x" & slv32hex(rf_wdata) severity note;
      end if;
    end if;
  end process;

end architecture;
