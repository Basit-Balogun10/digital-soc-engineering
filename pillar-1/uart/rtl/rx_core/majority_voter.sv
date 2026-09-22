module majority_voter
  import uart_pkg::OVERSAMPLE_N;
(
    input logic clk,
    input logic rst_n,
    input logic rx_sync,
    input logic [OVERSAMPLE_N - 1:0] oversample_count,
    output logic voted_rx,
    output logic noise_err,
    output logic oversampling_done
);
  logic sample_a, sample_b, sample_c;
  localparam int unsigned CenterSamplingPoint = OVERSAMPLE_N / 2;
  localparam int unsigned LeftSamplingPoint   = CenterSamplingPoint - 1;
  localparam int unsigned RightSamplingPoint  = CenterSamplingPoint + 1;

  assign oversampling_done = 32'(oversample_count) > RightSamplingPoint;
  assign voted_rx = oversampling_done ? (sample_a & sample_b) | (sample_b & sample_c) | (sample_a & sample_c) : 'x;
  assign noise_err = oversampling_done ? (sample_a != sample_b) || (sample_b != sample_c) || (sample_a != sample_c) : 'x;

  always_ff @(posedge clk) begin : sampling_left_right_center
    if (!rst_n) begin
      sample_a <= '0;
      sample_b <= '0;
      sample_c <= '0;
    end else if (32'(oversample_count) == LeftSamplingPoint) begin
      sample_a <= rx_sync;
    end else if (32'(oversample_count) == CenterSamplingPoint) begin
      sample_b <= rx_sync;
    end else if (32'(oversample_count) == RightSamplingPoint) begin
      sample_c <= rx_sync;
    end
  end
endmodule
