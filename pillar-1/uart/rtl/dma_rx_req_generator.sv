module dma_rx_req_generator (
    input logic clk,
    input logic rst_n,
    input logic rx_fifo_empty,
    input logic dma_enabled,
    output logic dma_rx_req
);

assign dma_rx_req = !rx_fifo_empty && dma_enabled;

endmodule
