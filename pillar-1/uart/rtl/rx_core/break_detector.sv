module break_detector
  import uart_pkg::OVERSAMPLE_N;
  import uart_pkg::parity_e, uart_pkg::NONE;
  import uart_pkg::stop_bits_e, uart_pkg::ONE_STOP_BIT, uart_pkg::TWO_STOP_BITS;
  import tx_pkg::MAX_FRAME_WIDTH;

(
    input logic clk,
    input logic rst_n,
    input logic tick,
    input logic rx_sync,
    input parity_e parity_mode,
    input stop_bits_e stop_bits,
    output logic rx_break
);
  logic [3:0] FrameWidth = (parity_mode != NONE && stop_bits == TWO_STOP_BITS) ? 12 : (parity_mode != NONE && stop_bits == ONE_STOP_BIT) ? 11 : (parity_mode == NONE && stop_bits == TWO_STOP_BITS) ? 11 : (parity_mode == NONE && stop_bits == ONE_STOP_BIT) ? 10 : 0;

  logic [$clog2(MAX_FRAME_WIDTH) - 1:0] low_rx_sync_count;
  logic [$clog2(OVERSAMPLE_N) - 1:0] ticks;
  logic bit_period_complete;

  assign bit_period_complete = 32'(ticks) == OVERSAMPLE_N - 1 ? '1 : '0;
  assign rx_break = low_rx_sync_count == FrameWidth;

  always_ff @(posedge clk) begin : low_rx_sync_counter
    if (!rst_n) begin
      low_rx_sync_count <= '0;
    end else begin
      if (rx_sync) begin
        low_rx_sync_count <= '0;
      end else if (!rx_sync && bit_period_complete && low_rx_sync_count != FrameWidth) begin
        low_rx_sync_count <= low_rx_sync_count + 1;
      end
    end
  end

  always_ff @(posedge clk) begin : ticks_counter
    if (!rst_n) begin
      ticks <= '0;
    end else begin
      if (tick) begin
        ticks <= ticks + 1;
      end
    end
  end
endmodule
