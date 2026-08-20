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
    output logic [7:0] tx_fifo_reg  [FIFO_DEPTH],
    output logic [7:0] rx_fifo_reg  [FIFO_DEPTH]
);
  logic [$clog2(FIFO_DEPTH):0] write_ptr;
  logic [$clog2(FIFO_DEPTH):0] read_ptr;

  always_ff @(posedge clk) begin : tx_fifo_push
    if (!rst_n) begin
      write_ptr <= '0;
    end else begin
      if (push) begin
        // TODO: revisit full/empty logic
        if (write_ptr == 0) begin
          tx_full <= '1;
        end else begin
          tx_fifo_reg[write_ptr] <= push_data;
          // TODO: modulo/wrap logic here
          write_ptr <= write_ptr - 1;
        end
      end
    end
  end

  always_ff @(posedge clk) begin : tx_fifo_pop
    if (!rst_n) begin
      read_ptr <= FIFO_DEPTH;
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
