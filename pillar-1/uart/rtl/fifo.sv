module fifo #(
    parameter int unsigned FIFO_DEPTH = 16
) (
    input logic clk,
    input logic rst_n,
    input logic push,
    input logic [7:0] push_data,
    input logic pop,
    output logic [7:0] pop_data,
    output logic full,
    output logic empty,
    output logic [7:0] fifo_reg[FIFO_DEPTH]
);
  // extra-bit wide to track full vs empty when both pointers are equal (but addressing only uses lower N-1 bits, not including the extra MSB)
  logic [$clog2(FIFO_DEPTH):0] write_ptr;
  logic [$clog2(FIFO_DEPTH):0] read_ptr;
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
      // shouldn't we be emptying the fifo_reg here too?
    end else begin
      // Compare bottom (N-1) bits without the LSB (extra bit to used to mark full vs empty)
      if (push && !is_full) begin
        fifo_reg[write_ptr[$clog2(FIFO_DEPTH)-1:0]] <= push_data;
        write_ptr <= write_ptr + 1;  // wraps implicitly
      end
    end
  end

  always_ff @(posedge clk) begin : fifo_read_ptr
    if (!rst_n) begin
      read_ptr <= '0;
    end else begin
      if (pop && write_ptr != read_ptr) begin
        read_ptr <= read_ptr + 1;  // wraps implicitly
      end
    end
  end

  always_comb begin : fifo_pop_data
    if (write_ptr == read_ptr) begin
      pop_data = '0;
    end else begin
      pop_data = fifo_reg[read_ptr[$clog2(FIFO_DEPTH)-1:0]];
    end
  end
endmodule
