# Digital SoC Engineering

SoC engineering IP cores, built live on stream - RTL, testbenches, design specs.

Working through the whole digital design stack, pillar by pillar. For each pillar, breaking it down into its actual components first instead of treating the whole thing as one big black box - build the components, wire it up, then verify it (self-checking testbenches, assertions, coverage, working up to UVM and cocotb), then firmware where it applies.

## The pillars

1. **Low-speed control** - UART, SPI, I2C, I3C
2. **High-speed SerDes** - 8b/10b encoding, 10G Ethernet MAC/PCS, PCIe endpoint, USB3 PIPE
3. **On-chip bus fabrics** - AXI4-Lite slave, AXI4 multi-master interconnect, APB/AHB bridges, TileLink
4. **Streaming dataflow** - AXI4-Stream skid buffer, scatter-gather DMA
5. **Memory and caching** - async CDC FIFO, SRAM/SDRAM controller, DDR4 PHY, L1/L2 cache (MESI)
6. **Hardware compute** - AES-128, SHA-256, pipelined FIR filter, systolic NPU engine
7. **Display and media** - VGA pattern/text engine, HDMI 2.0 framebuffer, MIPI CSI-2 camera ISP
8. **System control** - timers, PWM core, NVIC/PLIC interrupt controller, clock gating units
9. **Processors and debug** - RV32I pipelined CPU core, JTAG TAP controller, hardware breakpoints

For each core, it's not really one hardware branch, it's two: an ASIC path (synthesis, place and route, all the way to a real GDSII) and an FPGA path (down to an actual bitstream) - plus firmware, wherever a core actually needs something driving it from software.

## Right now

**UART.** Register bank, baud generator, shift registers, FSMs, synchronizers, FIFOs, all wired together. First one on the list.

## Elsewhere

- Full story + roadmap: [basitbalogun.dev](https://basitbalogun.dev)
- Live builds: [Twitch](https://www.twitch.tv/basitbalogun10) · [YouTube](https://www.youtube.com/@basitbalogun10)
- Write-ups once something's finished: [basitbalogun.dev/blog](https://basitbalogun.dev/blog/)
