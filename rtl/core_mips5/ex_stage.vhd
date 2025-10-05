-- File: rtl/core_mips5/ex_stage.vhd
-- EX stage: forwarding muxes + ALU + passagem de RT pós-forwarding (para stores).
-- Compatível com o componente instanciado em core_mips5_top.vhd:
--   portas: clk, rst, id_rs_val, id_rt_val, imm_sext, exmem_val, memwb_val,
--           alu_src, alu_op, fwd_a_sel, fwd_b_sel, alu_y, store_d
--
-- Convenção de forwarding:
--   fwd_*_sel = "10" -> usar EX/MEM (exmem_val)
--   fwd_*_sel = "01" -> usar MEM/WB  (memwb_val)
--   fwd_*_sel = "00" -> usar valor do ID/EX (id_*_val)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pkg_types.all;  -- alu_op_t, etc. (u32 = std_logic_vector(31 downto 0))

entity ex_stage is
  port (
    clk        : in  std_logic;  -- não usado (combinacional)
    rst        : in  std_logic;  -- não usado (combinacional)

    -- Dados de entrada (ID/EX) e caminhos de forwarding
    id_rs_val  : in  std_logic_vector(31 downto 0);
    id_rt_val  : in  std_logic_vector(31 downto 0);
    imm_sext   : in  std_logic_vector(31 downto 0);
    exmem_val  : in  std_logic_vector(31 downto 0);
    memwb_val  : in  std_logic_vector(31 downto 0);

    -- Controle
    alu_src    : in  std_logic;                    -- 1: usa imm_sext em B
    alu_op     : in  alu_op_t;
    fwd_a_sel  : in  std_logic_vector(1 downto 0);
    fwd_b_sel  : in  std_logic_vector(1 downto 0);

    -- Saídas
    alu_y      : out std_logic_vector(31 downto 0);
    store_d    : out std_logic_vector(31 downto 0) -- RT pós-forwarding (para sw)
  );
end entity;

architecture rtl of ex_stage is
  signal a_fwd : std_logic_vector(31 downto 0);
  signal b_fwd : std_logic_vector(31 downto 0);  -- RT após forwarding
  signal b_alu : std_logic_vector(31 downto 0);  -- operando B efetivo para ALU
  signal r     : std_logic_vector(31 downto 0);
begin
  -- ========= Forwarding MUX A (RS) =========
  -- prioridade: EX/MEM ("10") > MEM/WB ("01") > ID/EX ("00"/outros)
  process(id_rs_val, exmem_val, memwb_val, fwd_a_sel)
  begin
    case fwd_a_sel is
      when "10" => a_fwd <= exmem_val;
      when "01" => a_fwd <= memwb_val;
      when others => a_fwd <= id_rs_val;
    end case;
  end process;

  -- ========= Forwarding MUX B (RT) =========
  process(id_rt_val, exmem_val, memwb_val, fwd_b_sel)
  begin
    case fwd_b_sel is
      when "10" => b_fwd <= exmem_val;
      when "01" => b_fwd <= memwb_val;
      when others => b_fwd <= id_rt_val;
    end case;
  end process;

  -- Valor de RT pós-forwarding vai para stores
  store_d <= b_fwd;

  -- ========= Seleção do operando B da ALU (RT/imm) =========
  b_alu <= imm_sext when (alU_src = '1') else b_fwd;

  -- ========= ALU (VHDL-93) =========
  process(a_fwd, b_alu, alu_op)
    variable a_s : signed(31 downto 0);
    variable b_s : signed(31 downto 0);
    variable a_u : unsigned(31 downto 0);
    variable b_u : unsigned(31 downto 0);
    variable tmp : unsigned(31 downto 0);
    variable res : std_logic_vector(31 downto 0);
  begin
    a_s := signed(a_fwd);  b_s := signed(b_alu);
    a_u := unsigned(a_fwd); b_u := unsigned(b_alu);
    res := (others => '0');

    case alu_op is
      when ALU_ADD =>
        tmp := a_u + b_u;
        res := std_logic_vector(tmp);

      when ALU_SUB =>
        tmp := a_u - b_u;
        res := std_logic_vector(tmp);

      when ALU_AND =>
        res := a_fwd and b_alu;

      when ALU_OR  =>
        res := a_fwd or b_alu;

      when ALU_XOR =>
        res := a_fwd xor b_alu;

      when ALU_SLT =>
        if a_s < b_s then
          res := (others => '0'); res(0) := '1';
        else
          res := (others => '0');
        end if;

      when ALU_SLTU =>
        if a_u < b_u then
          res := (others => '0'); res(0) := '1';
        else
          res := (others => '0');
        end if;

      when ALU_SLL =>
        res := std_logic_vector(shift_left (unsigned(a_fwd), to_integer(unsigned(b_alu(4 downto 0)))));

      when ALU_SRL =>
        res := std_logic_vector(shift_right(unsigned(a_fwd), to_integer(unsigned(b_alu(4 downto 0)))));

      when ALU_SRA =>
        res := std_logic_vector(shift_right(signed(a_fwd),   to_integer(unsigned(b_alu(4 downto 0)))));

      when others =>  -- ALU_PASS
        res := b_alu;
    end case;

    r <= res;
  end process;

  alu_y <= r;
end architecture;
