module tx_parity_generator
  import uart_pkg::DATA_BITS;
  import uart_pkg::PARITY_MODE, uart_pkg::NONE, uart_pkg::EVEN, uart_pkg::ODD;
(
    input logic clk,
    input logic rst_n,
    input logic load_enable,
    input logic [DATA_BITS - 1:0] tx_fifo_pop_data,
    output logic parity_bit
);
  logic [DATA_BITS - 1:0] data_bits;

  always_ff @(posedge clk) begin : latch_data_bits
    if (!rst_n) begin
      data_bits <= '0;
    end else begin
      if (load_enable) begin
        data_bits <= tx_fifo_pop_data;
      end
    end
  end

  assign parity_bit = PARITY_MODE == EVEN ? ^tx_fifo_pop_data : PARITY_MODE == ODD ? ~^tx_fifo_pop_data : 'x;

endmodule
