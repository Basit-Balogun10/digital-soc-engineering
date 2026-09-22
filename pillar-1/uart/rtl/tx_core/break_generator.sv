module break_generator
  import uart_pkg::parity_e, uart_pkg::NONE;
  import uart_pkg::stop_bits_e, uart_pkg::ONE_STOP_BIT, uart_pkg::TWO_STOP_BITS;
  import tx_pkg::MAX_FRAME_WIDTH;

(
    input logic clk,
    input logic rst_n,
    input logic send_break,
    input parity_e parity_mode,
    input stop_bits_e stop_bits,
    input logic bit_period_complete,
    output logic tx_break,
    output logic allow_send_break_override
);
  logic [3:0] FrameWidth = (parity_mode != NONE && stop_bits == TWO_STOP_BITS) ? 12 : (parity_mode != NONE && stop_bits == ONE_STOP_BIT) ? 11 : (parity_mode == NONE && stop_bits == TWO_STOP_BITS) ? 11 : (parity_mode == NONE && stop_bits == ONE_STOP_BIT) ? 10 : 0;

  logic [$clog2(MAX_FRAME_WIDTH) - 1:0] bit_period_complete_count;

  assign allow_send_break_override = bit_period_complete_count == FrameWidth;

  always_ff @(posedge clk) begin : frame_period_counter
    if (!rst_n) begin
      bit_period_complete_count <= '0;
    end else begin
      if (tx_break && !send_break) begin
        bit_period_complete_count <= '0;
      end else if (bit_period_complete && bit_period_complete_count != FrameWidth) begin
        // capped at frame width rather than counting indefinitely        
        bit_period_complete_count <= bit_period_complete_count + 1;
      end
    end
  end

  always_ff @(posedge clk) begin : drive_tx_break
    if (!rst_n) begin
      tx_break <= '0;
    end else begin
      tx_break <= send_break;
    end
  end


endmodule
