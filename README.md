# MIPS-Lab VHDL

A collection of didactic VHDL projects:
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
- ⏳ **Next** — pipeline (IF/ID/EX/MEM/WB), forwarding/hazards, branch predictor, caches, FPU, SIMD, Tiny-GPU, microcoded core.

---

## Prerequisites

- **GHDL** (recent build)
- **GTKWave** (optional, to view `VCD` waves)
- `make`, `gcc`

**Ubuntu/Debian**
```bash
sudo apt-get update
sudo apt-get install -y ghdl gtkwave make gcc

