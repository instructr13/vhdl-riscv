OUTPUT_ARCH(riscv)
SECTIONS
{
  . = 0x00000000;
  .text : { KEEP(*(.init)) KEEP(*(.text.start)) *(.text*) }
  .rodata : { *(.rodata*) }
  .data : { *(.data*) }
  .bss : { *(.bss*) *(COMMON) }
}
