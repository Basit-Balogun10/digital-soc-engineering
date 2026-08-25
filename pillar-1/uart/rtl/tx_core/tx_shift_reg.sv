module tx_shift_reg
  import uart_pkg::DATA_BITS;
(
    input logic clk,
    input logic rst_n,
    input logic shift_enable,
    input logic load_enable,
    input logic [DATA_BITS - 1:0] tx_fifo_pop_data,
    output logic tx_fifo_pop,
    output logic tx_data_bit
);
  logic [DATA_BITS - 1:0] shift_reg;
  assign tx_data_bit = shift_reg[0];
  assign tx_fifo_pop = load_enable;

  always_ff @(posedge clk) begin : drive_shift_reg
    if (!rst_n) begin
      shift_reg <= '0;
    end else if (load_enable) begin
      shift_reg <= tx_fifo_pop_data;
    end else if (shift_enable) begin
      shift_reg <= shift_reg >> 1;
    end
  end
endmodule
