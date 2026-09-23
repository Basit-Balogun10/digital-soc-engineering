module dma_tx_req_generator (
    input logic clk,
    input logic rst_n,
    input logic tx_fifo_full,
    input logic dma_enabled,
    output logic dma_tx_req
);

assign dma_tx_req = !tx_fifo_full && dma_enabled;

endmodule
