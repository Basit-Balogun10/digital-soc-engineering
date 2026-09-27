module autobaud_detector
  import uart_pkg::BAUD_DIV_WIDTH;
(
    input logic clk,
    input logic rst_n,
    input logic autobaud_en,
    input logic rx_sync,
    output logic autobaud_err,
    output logic [BAUD_DIV_WIDTH - 1:0] baud_div
);
  localparam int unsigned AutobaudCounterWidth = 16;
  logic [AutobaudCounterWidth - 1:0] clock_counter;
  logic counter_empty, counter_done, prev_rx_sync;

  /*
  baud_div = (N + half-LSB) / (pattern-data-bits * oversampling) = (N + 64) / (8 * 16)
  half-LSB is added to coerce right shift's truncation to round-to-nearest
  TODO: when uart_top receives a non-zero baud_div, should store in ctrl_reg and exit autobaud mode automatically (via the same ctrl_write txn and gated on autobaud_en).
  */
  assign baud_div = counter_done ? (clock_counter + 64) >> 7 : '0;
  assign counter_empty = clock_counter == '0;

  always_ff @(posedge clk) begin
    prev_rx_sync <= rx_sync;
  end

  // Expected pattern = 0x7F
  always_ff @(posedge clk) begin : pattern_detection
    if (!rst_n) begin
      clock_counter <= '0;
      counter_done  <= '0;
    end else begin
      if (autobaud_en) begin
        if (rx_sync) begin
          if (!counter_empty) begin
            if (clock_counter == '1) begin
              // TODO: on error, uart_top auto-exits autobaud mode without overwriting the baud div (gated on autobaud_en to avoid overwriting/clearing a previously set flag/error)
              autobaud_err <= '1;
            end else begin
              clock_counter <= clock_counter + 1;
            end
          end
        end else begin
          if (counter_empty || (!counter_empty && !prev_rx_sync)) begin
            clock_counter <= clock_counter + 1;
          end else if (prev_rx_sync && !counter_empty) counter_done <= '1;
        end
      end else begin
        clock_counter <= '0;
        counter_done  <= '0;
        autobaud_err  <= '0;
      end
    end
  end
endmodule
