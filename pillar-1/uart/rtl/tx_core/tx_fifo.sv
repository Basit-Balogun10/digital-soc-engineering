module tx_fifo #(
    parameter int unsigned FIFO_DEPTH = 16
) (
    input logic clk,
    input logic rst_n,
    input logic push,
    input logic [7:0] push_data,
    input logic pop,
    output logic [7:0] pop_data,
    output logic tx_full,
    output logic tx_empty,
    output logic rx_full,
    output logic rx_empty,
    output logic [7:0] tx_fifo_reg[FIFO_DEPTH],
    output logic [7:0] rx_fifo_reg[FIFO_DEPTH]
);
  // extra-bit wide to track full vs empty when both pointers are equal (but addressing only uses lower N-1 bits, not including the extra MSB)
  logic [$clog2(FIFO_DEPTH):0] write_ptr;
  logic [$clog2(FIFO_DEPTH):0] read_ptr;

  always_ff @(posedge clk) begin : tx_fifo_empty
    if (!rst_n) begin
      tx_empty <= '1;
    end else begin
      if (write_ptr == read_ptr) begin
        tx_empty <= '1;
      end else begin
        tx_empty <= '0;
      end
    end
  end

  always_ff @(posedge clk) begin : tx_fifo_push
    if (!rst_n) begin
      write_ptr <= '0;
      tx_full   <= '0;
      // shouldn't we be emptying the fifo_reg here too?
    end else begin
      if (push) begin
        // Compare bottom (N-1) bits without the LSB (extra bit to used to mark full vs empty)
        if (write_ptr[$clog2(
                FIFO_DEPTH
            )-1:0] == read_ptr[$clog2(
                FIFO_DEPTH
            )-1:0] && write_ptr[$clog2(
                FIFO_DEPTH
            )] != read_ptr[$clog2(
                FIFO_DEPTH
            )]) begin
          tx_full <= '1;
        end else begin
          tx_fifo_reg[write_ptr] <= push_data;
          write_ptr <= write_ptr + 1;  // wraps implicitly
        end
      end
    end
  end

  always_ff @(posedge clk) begin : tx_fifo_pop
    if (!rst_n) begin
      read_ptr <= '0;
      rx_empty <= '1;
      rx_full  <= '0;
      pop_data <= '0;  // should this be 'x?
    end else begin
      if (pop) begin
        // TODO: revisit full/empty logic
        if (read_ptr == 0) begin
          rx_full <= '1;
        end else begin
          pop_data <= rx_fifo_reg[read_ptr];
          // TODO: modulo/wrap logic here
          read_ptr <= read_ptr - 1;
        end
      end
    end
  end
endmodule
