GHDL ?= ghdl
LIB   = work

VHDL_SOURCES = \
  ../../rtl/pkg/pkg_types.vhd \
  ../../rtl/pkg/pkg_isa.vhd \
  ../../rtl/mem/mem_dual.vhd \
  ../../rtl/core_single/regfile.vhd \
  ../../rtl/core_mips5/if_stage.vhd \
  ../../rtl/core_mips5/id_stage.vhd \
  ../../rtl/core_mips5/ex_stage.vhd \
  ../../rtl/core_mips5/mem_stage.vhd \
  ../../rtl/core_mips5/wb_stage.vhd \
  ../../rtl/core_mips5/forward_unit.vhd \
  ../../rtl/core_mips5/hazard_unit.vhd \
  ../../rtl/core_mips5/control_decode.vhd \
  ../../rtl/core_mips5/core_mips5_top.vhd \
  tb_core_mips5.vhd

all:
	$(GHDL) -i --work=$(LIB) $(VHDL_SOURCES)
	$(GHDL) -m --work=$(LIB) tb_core_mips5

run:
	./tb_core_mips5 --stop-time=1us --vcd=waves.vcd

clean:
	rm -f *.cf *.o tb_core_mips5 waves.vcd
