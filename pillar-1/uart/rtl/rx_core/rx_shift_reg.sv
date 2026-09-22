module rx_shift_reg
  import uart_pkg::DATA_BITS;
(
    input logic clk,
    input logic rst_n,
    input logic shift_enable,
    input logic rx_data_active,
    input logic voted_rx,
    input logic oversampling_done,
    output logic [DATA_BITS - 1:0] data_bits
);
  // assign data_bits[0] = voted_rx;

  always_ff @(posedge clk) begin : load_data_bits
    if (!rst_n) begin
      data_bits <= '0;
    end else begin

      if (shift_enable) begin
        data_bits <= data_bits >> 1;
      end else if (rx_data_active && oversampling_done) begin
        data_bits[DATA_BITS-1] <= voted_rx;
      end
    end
  end
endmodule
