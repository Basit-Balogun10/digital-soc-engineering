module fifo
  import uart_pkg::DATA_BITS, uart_pkg::FIFO_DEPTH;
(
    input logic clk,
    input logic rst_n,
    output logic full,
    output logic empty,
    output logic [DATA_BITS - 1:0] fifo_reg[FIFO_DEPTH],
    fifo_ctrl_if.fifo fifo_ctrl
);
  // extra-bit wide to track full vs empty when both pointers are equal (but addressing only uses lower N-1 bits, not including the extra MSB)
  logic [$clog2(FIFO_DEPTH):0] write_ptr, read_ptr;
  logic is_full;
  // lower address bits match and the top lap-tracking/extra-bit differs
  assign is_full = write_ptr[$clog2(
      FIFO_DEPTH
  )-1:0] == read_ptr[$clog2(
      FIFO_DEPTH
  )-1:0] && write_ptr[$clog2(
      FIFO_DEPTH
  )] != read_ptr[$clog2(
      FIFO_DEPTH
  )];

  always_ff @(posedge clk) begin : fifo_empty
    if (!rst_n) begin
      empty <= '1;
    end else begin
      if (write_ptr == read_ptr) begin
        empty <= '1;
      end else begin
        empty <= '0;
      end
    end
  end

  always_ff @(posedge clk) begin : fifo_full
    if (!rst_n) begin
      full <= '0;
    end else begin
      if (is_full) begin
        full <= '1;
      end else begin
        full <= '0;
      end
    end
  end

  always_ff @(posedge clk) begin : fifo_push
    if (!rst_n) begin
      write_ptr <= '0;
    end else begin
      // Compare bottom (N-1) bits without the LSB (extra bit to used to mark full vs empty)
      if (fifo_ctrl.push && !is_full) begin
        fifo_reg[write_ptr[$clog2(FIFO_DEPTH)-1:0]] <= fifo_ctrl.push_data;
        write_ptr <= write_ptr + 1;  // wraps implicitly
      end
    end
  end

  always_ff @(posedge clk) begin : fifo_read_ptr
    if (!rst_n) begin
      read_ptr <= '0;
    end else begin
      if (fifo_ctrl.pop && write_ptr != read_ptr) begin
        read_ptr <= read_ptr + 1;  // wraps implicitly
      end
    end
  end

  always_comb begin : fifo_pop_data
    if (write_ptr == read_ptr) begin
      fifo_ctrl.pop_data = '0;
    end else begin
      fifo_ctrl.pop_data = fifo_reg[read_ptr[$clog2(FIFO_DEPTH)-1:0]];
    end
  end
endmodule
