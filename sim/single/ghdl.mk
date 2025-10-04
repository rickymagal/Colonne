GHDL=ghdl
LIB=work
VHDL_SOURCES= \
  ../../rtl/pkg/pkg_types.vhd \
  ../../rtl/pkg/pkg_isa.vhd \
  ../../rtl/mem/mem_dual.vhd \
  ../../rtl/core_single/regfile.vhd \
  ../../rtl/core_single/alu.vhd \
  ../../rtl/core_single/control_simple.vhd \
  ../../rtl/core_single/core_single_top.vhd \
  tb_core_single.vhd

all:
	$(GHDL) -i --work=$(LIB) $(VHDL_SOURCES)
	$(GHDL) -m --work=$(LIB) tb_core_single

run:
	./tb_core_single --stop-time=1us --vcd=waves.vcd

clean:
	rm -f *.cf *.o tb_core_single waves.vcd
