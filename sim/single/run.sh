#!/usr/bin/env bash
set -euo pipefail
make -f ghdl.mk run
echo "[OK] ran; see waves.vcd"
