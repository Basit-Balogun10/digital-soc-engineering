module baud_generator (
    input logic clk,
    input logic rst_n,
    input logic [15:0] baud_div,
    output logic tick
);

  logic [15:0] count;

  always_ff @(posedge clk, negedge rst_n) begin : baud_count
    if (!rst_n) begin
      count <= '0;
    end else begin
      // Counts to D-1 before resetting
      if (count < (baud_div - 1)) begin
        count <= count + 1;
      end else if (count == (baud_div - 1)) begin
        count <= '0;
      end
    end
  end

  // Pulse when counts reaches D-1
  assign tick = count == (baud_div - 1) ? '1 : '0;

endmodule
