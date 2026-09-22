module oversample_counter
  import uart_pkg::OVERSAMPLE_N;
(
    input logic clk,
    input logic rst_n,
    input logic tick,
    input logic rst_n_via_rx_fsm,
    output logic [$clog2(OVERSAMPLE_N) - 1:0] oversample_count
);
  always_ff @(posedge clk) begin : oversample_counting
    if (!rst_n || !rst_n_via_rx_fsm) begin
      oversample_count <= '0;
    end else begin
      if (tick) begin
        oversample_count <= oversample_count + 1;
      end
    end
  end
endmodule
