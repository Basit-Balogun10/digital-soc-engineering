/*
    (0x4000_4000) -> Base address
    (0x00) CTRL (R/W) -> [31:16]BAUD_DIV [3:2]STOP_BITS [1:0]PARITY_MODE
    (0x04) STATUS (R) -> [10]RX_FIFO_EMPTY [9]RX_FIFO_FULL [8]TX_FIFO_EMPTY [7]TX_FIFO_FULL [6]BREAK_DETECTED [5]NOISE_ERR [4]OVERRUN [3]PARITY_ERR [2]FRAMING_ERR [1]RX_VALID [0]TX_BUSY
    (0x08) TX_DATA (W) -> [8:0]DATA
    (0x0C) RX_DATA (R) -> [8:0]DATA
 */

module mmio_register_bank
  import uart_pkg::mmio_status_flags_t;
(
    input logic clk,
    // only the 4 bottom bits is needed to route actions across the ctrl r/w, status (r), tx_data (w) and rx_data (r).
    input logic [3:0] address,
    input logic write_en,
    input logic read_en,
    input logic [31:0] wdata,
    input mmio_status_flags_t status_flags,
    output logic [31:0] ctrl_reg,
    output logic [31:0] rdata,
    fifo_ctrl_if.mmio fifo_ctrl
);
  logic is_tx_data_write;
  assign is_tx_data_write = write_en && address[3:0] == 4'h08;

  always_ff @(posedge clk) begin : ctrl_write
    if (write_en && address[3:0] == 4'h00) begin
      ctrl_reg[31:16] <= wdata[31:16];
      ctrl_reg[3:2]   <= wdata[3:2];
      ctrl_reg[1:0]   <= wdata[1:0];
    end

    ctrl_reg[15:4] <= '0;  // Reserved bits
  end

  // TX_DATA WRITE
  assign fifo_ctrl.push = is_tx_data_write ? '1 : '0;
  assign fifo_ctrl.push_data = is_tx_data_write ? wdata[7:0] : 'x;

  // STATUS, RX_DATA AND CTRL READ 
  assign rdata = (read_en && address[3:0] == 4'h04) ?
      // upper bits are reserved
      {
        {21{1'b0}},
        status_flags
      }
      : (read_en && address[3:0] == 4'h0C) ?
          32'(fifo_ctrl.pop_data) : (read_en && address[3:0] == 4'h00) ? ctrl_reg : 'x;

  always_comb begin : rx_data_read
    if (read_en && address[3:0] == 4'h0C) begin
      fifo_ctrl.pop = '1;
    end else begin
      fifo_ctrl.pop = '0;
    end
  end


endmodule
