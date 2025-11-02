#!/usr/bin/env python3

import os
import sys
import shlex
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEST_DIR = ROOT / "test"
OUT_DIR = Path(os.environ.get("OUT_DIR", str(ROOT / "out")))
TOP = os.environ.get("TOP", "tb_top")
TEST_PREFIXES = os.environ.get("TEST_PREFIXES", "rv32ui-p-").split()
TEST_STOP_TIME = os.environ.get("TEST_STOP_TIME", "100us")

OUT_DIR.mkdir(parents=True, exist_ok=True)

# Collect hex files
hex_files = sorted(p for p in TEST_DIR.rglob("*.hex"))
if not hex_files:
  print("No .hex files found under {}".format(TEST_DIR))
  sys.exit(1)

# Filter by prefixes
candidates = [p for p in hex_files if any(p.name.startswith(pfx) for pfx in TEST_PREFIXES)]
if not candidates:
  print("No tests matched prefixes: {}".format(" ".join(TEST_PREFIXES)))
  sys.exit(1)

# Run each test

total = 0
passed = 0
failed = 0
failed_list = []

for hex_path in candidates:
  name = hex_path.name

  log_path = OUT_DIR / f"{name}.log"
  vcd_path = OUT_DIR / f"{name}.vcd"

  print(f"==> {name}")

  exe = OUT_DIR / TOP

  if not exe.exists():
    print(f"Executable {exe} not found. Run 'make elab' first.")
    sys.exit(2)

  cmd = [
    str(exe),
    f"--backtrace-severity=warning",
    f"--stop-time={TEST_STOP_TIME}",
    "--max-stack-alloc=256",
    f"--vcd={vcd_path}",
    f"-gMEM_INIT_FILE={hex_path}",
    "-gTEST_MODE=true",
  ]

  with log_path.open("w") as lf:
    try:
      subprocess.run(cmd, cwd=str(ROOT), stdout=lf, stderr=subprocess.STDOUT, check=False)
    except FileNotFoundError:
      print("GHDL not found")
      sys.exit(127)

  total += 1
  text = log_path.read_text(errors="ignore")

  if "PASS" in text:
    print(f"PASS {name}")
    passed += 1
  else:
    print(f"FAIL {name}")
    failed += 1
    failed_list.append(name)

print(f"Total: {total}, Pass: {passed}, Fail: {failed}")

if failed_list:
  print("Failed: " + ", ".join(failed_list))

  sys.exit(1)

