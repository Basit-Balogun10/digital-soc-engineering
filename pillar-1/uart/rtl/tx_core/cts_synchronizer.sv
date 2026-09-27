module cts_synchronizer (
    input logic clk,
    input logic rst_n,
    input logic cts,
    output logic cts_sync
);
  logic cts_raw;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      cts_raw  <= '0;
      cts_sync <= '0;
    end else begin
      cts_raw  <= cts;
      cts_sync <= cts_raw;
    end
  end
endmodule
