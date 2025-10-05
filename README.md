# MIPS-Lab VHDL

A didactic collection of VHDL projects:

- **MIPS-like 5-stage core** (visualizable, with tracing, forwarding, and hazards).
- **Microcoded** MIPS-like variant (control via microcode ROM).
- **Minimal FPU** (IEEE-754 single precision).
- **SIMD Coprocessor** (8/16-bit).
- **Tiny-GPU** (scalar ALU + simple scheduler).
- **Caches** (I/D) and cache controller.
- **SoC** with MMIO (UART, Timer, GPIO).

---

## Project status

- ✅ **Week 1 (single-cycle datapath)** — PASS  
  Regfile, ALU, PC, unified memory (I+D), arithmetic ops + `LW/SW`, testbench with a small sum program.

- ✅ **Week 2 (5-stage pipeline: IF/ID/EX/MEM/WB)** — PASS  
  Full pipeline with **forwarding** (EX/MEM, MEM/WB), **load-use hazard** stall/flush, **WB→ID bypass** (write-first emulation), inline ROM program, and **VHDL-93 tracing** (`report`-based per stage). Compatible with GHDL VHDL-93 (no `--std=08` required).

- ⏳ **Next** — branch predictor, caches, FPU, SIMD, Tiny-GPU, microcoded core.

---

## Prerequisites

- **GHDL** (recent build)
- **GTKWave** (optional, for `VCD` viewing)
- `make`, `gcc`

**Ubuntu/Debian**
```bash
sudo apt-get update
sudo apt-get install -y ghdl gtkwave make gcc
