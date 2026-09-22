module rx_synchronizer (
    input  logic clk,
    input  logic rst_n,
    input  logic rx,
    output logic rx_sync
);
  logic rx_raw;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      rx_raw  <= '0;
      rx_sync <= '0;
    end else begin
      rx_raw  <= rx;
      rx_sync <= rx_raw;
    end
  end

endmodule
