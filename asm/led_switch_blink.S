.section .text.start
.global _start

_start:
  # CSR addresses
  #   LED CSR:    0x800 (write-only)
  #   SWITCH CSR: 0x801 (read-only, bit0 = switch 0)

  # Setup initial color = RED on LED0 (bit1)
  li   s0, 2            # s0 = RED mask (LED0 red = bit1)
  li   s1, 1            # s1 = GREEN mask   (LED0 green = bit0)
  mv   s2, s0           # s2 = current color mask
  li   s3, 0            # s3 = toggle state (0=off, 1=on)

loop:
  beqz s3, led_off
  csrw 0x800, s2        # turn LED ON with current color
  j    delay

led_off:
  li   t0, 0
  csrw 0x800, t0        # turn LED OFF

delay:
  li   t1, 0x400000
1:
  addi t1, t1, -1
  bnez t1, 1b

  csrr t2, 0x801        # t2 = switches
  andi t3, t2, 1        # check bit0
  beqz t3, 2f
  mv   s2, s1           # switch to RED
2:
  xori s3, s3, 1        # toggle on/off
  j    loop
