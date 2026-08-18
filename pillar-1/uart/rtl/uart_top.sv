module uart_top
  import uart_pkg::partity_e;
#(
    parameter int unsigned BAUD_DIV_WIDTH = 16,
    parameter int unsigned DATA_BITS = 8,
    parameter parity_e PARTIY_MODE = EVEN,
    parameter int unsigned STOP_BITS = 1,
    parameter int unsigned OVERSAMPLE_N = 16,
    parameter int unsigned FIFO_DEPTH = 8
) (
  input logic clk,
  input logic rst_n
);

endmodule
