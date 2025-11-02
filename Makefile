OUT_DIR=out

GHDL=ghdl
GHDL_FLAGS=--std=93 -fsynopsys -fexplicit -C --workdir=$(OUT_DIR)
TOP=tb_top

SRCS= \
			src/util.vhd \
			src/fifo.vhd \
			src/eei.vhd \
			src/corectrl.vhd \
			src/inst_decoder.vhd \
			src/alu.vhd \
			src/brunit.vhd \
			src/io_ty.vhd \
			src/csrunit.vhd \
			src/membus_ty.vhd \
			src/memunit.vhd \
			src/initial_mem.vhd \
			src/memory.vhd \
			src/io.vhd \
			src/core.vhd \
			src/top.vhd \
			bench/tb_top.vhd

.PHONY: all analyze elab run clean format

all: run

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

analyze: $(OUT_DIR) $(SRCS)
	$(GHDL) -a $(GHDL_FLAGS) $(SRCS)

elab: analyze
	$(GHDL) -e $(GHDL_FLAGS) -o $(OUT_DIR)/$(TOP) $(TOP)

run: elab
	$(OUT_DIR)/$(TOP) --backtrace-severity=warning --stop-time=100us --max-stack-alloc=256 --wave=$(OUT_DIR)/wave.ghw

clean:
	rm -rf $(OUT_DIR)

format:
	uvx vsg -c vsg_config.yaml --fix src/*.vhd

# test runner
TEST_PREFIXES ?= rv32ui-p- rv64ui-p-
TEST_STOP_TIME ?= 100us

.PHONY: test

test: $(OUT_DIR) elab
	OUT_DIR=$(OUT_DIR) GHDL=$(GHDL) GHDL_FLAGS='$(GHDL_FLAGS)' TOP=$(TOP) TEST_PREFIXES='$(TEST_PREFIXES)' TEST_STOP_TIME='$(TEST_STOP_TIME)' \
		python3 test/test.py

# RISC-V asm -> hex

RISCV_PREFIX ?= riscv64-unknown-elf-
RISCV_CC ?= $(RISCV_PREFIX)gcc
RISCV_OBJCOPY ?= $(RISCV_PREFIX)objcopy
RISCV_CFLAGS ?= -march=rv32i_zicsr -mabi=ilp32 -nostdlib -ffreestanding -static -Wl,-Tasm/linker.ld,-e,0 -Wl,--build-id=none

OUT_ASM_DIR := $(OUT_DIR)/asm

ASM_SRCS := $(wildcard asm/*.S) $(wildcard asm/*.s)
ASM_NAMES := $(basename $(notdir $(ASM_SRCS)))
ASM_HEX := $(addprefix $(OUT_ASM_DIR)/,$(addsuffix .hex,$(ASM_NAMES)))

ifeq ($(FILE),)
ASM_TARGETS := $(ASM_HEX)
else
ASM_SRC := $(if $(filter asm/%,$(FILE)),$(FILE),asm/$(FILE))
ASM_NAME := $(basename $(notdir $(ASM_SRC)))
ASM_TARGETS := $(OUT_ASM_DIR)/$(ASM_NAME).hex
endif

.PHONY: asm
asm: $(OUT_ASM_DIR) $(ASM_TARGETS)
	@true

$(OUT_ASM_DIR):
	mkdir -p $(OUT_ASM_DIR)

# Build rules
$(OUT_ASM_DIR)/%.elf: asm/%.S asm/linker.ld | $(OUT_ASM_DIR)
	$(RISCV_CC) $(RISCV_CFLAGS) -o $@ $<

$(OUT_ASM_DIR)/%.elf: asm/%.s asm/linker.ld | $(OUT_ASM_DIR)
	$(RISCV_CC) $(RISCV_CFLAGS) -o $@ $<

$(OUT_ASM_DIR)/%.bin: $(OUT_ASM_DIR)/%.elf | $(OUT_ASM_DIR)
	$(RISCV_OBJCOPY) -O binary $< $@

$(OUT_ASM_DIR)/%.hex: $(OUT_ASM_DIR)/%.bin | $(OUT_ASM_DIR)
	python3 test/bin2hex.py 8 $< > $@

