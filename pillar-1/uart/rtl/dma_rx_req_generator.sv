module dma_rx_req_generator
  import uart_pkg::FIFO_DEPTH;

(
    input [$clog2(FIFO_DEPTH):0] rx_fifo_occupancy,
    // TODO: watermark value below can only be 0-15, uart_top should offset by +1 to allow full flexibility (to imply 1-16 fifo depth levels)
    input logic [3:0] rx_fifo_watermark,
    input logic dma_enabled,
    output logic dma_rx_req
);

  assign dma_rx_req = (int'(rx_fifo_occupancy) > int'(rx_fifo_watermark)) && dma_enabled;

endmodule
