library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pkg_types.all;

entity alu is
  port(
    a, b : in  std_logic_vector(31 downto 0);
    op   : in  alu_op_t;
    y    : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of alu is
begin
  process(a,b,op)
    variable ru : unsigned(31 downto 0);
  begin
    case op is
      when ALU_ADD  => ru := unsigned(a) + unsigned(b);
      when ALU_SUB  => ru := unsigned(a) - unsigned(b);
      when ALU_AND  => ru := unsigned(a) and unsigned(b);
      when ALU_OR   => ru := unsigned(a) or  unsigned(b);
      when ALU_XOR  => ru := unsigned(a) xor unsigned(b);
      when ALU_SLL  => ru := shift_left(unsigned(a), to_integer(unsigned(b(4 downto 0))));
      when ALU_SRL  => ru := shift_right(unsigned(a), to_integer(unsigned(b(4 downto 0))));
      when ALU_SRA  => ru := unsigned(shift_right(signed(a), to_integer(unsigned(b(4 downto 0)))));
      when ALU_SLT  => ru := (others=>'0'); if signed(a) < signed(b) then ru(0):='1'; end if;
      when ALU_SLTU => ru := (others=>'0'); if unsigned(a) < unsigned(b) then ru(0):='1'; end if;
      when others   => ru := unsigned(a); -- PASS
    end case;
    y <= std_logic_vector(ru);
  end process;
end architecture;
