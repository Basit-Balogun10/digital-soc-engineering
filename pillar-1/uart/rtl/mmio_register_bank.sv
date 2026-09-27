/*
    (0x4000_4000) -> Base address
    (0x00) CTRL1 (R/W) -> [31:16]BAUD_DIV [10:7]RTS_FULL_THRESHOLD [6]AUTOBAUD_MODE [5]DMA_ENABLED [4]SEND_BREAK [3:2]STOP_BITS [1:0]PARITY_MODE
    (0x04) CTRL2 (R/W) -> RX_WATERMARK [7:4] TX_WATERMARK [3:0]
    (0x08) STATUS (R) -> [12]AUTOBAUD_ERR [11]RTS_ERR [10]RX_FIFO_EMPTY [9]RX_FIFO_FULL [8]TX_FIFO_EMPTY [7]TX_FIFO_FULL [6]BREAK_DETECTED [5]NOISE_ERR [4]OVERRUN [3]PARITY_ERR [2]FRAMING_ERR [1]RX_VALID [0]TX_BUSY
    (0x0C) TX_DATA (W) -> [8:0]DATA
    (0x10) RX_DATA (R) -> [8:0]DATA
 */

module mmio_register_bank
  import uart_pkg::mmio_status_flags_t;
(
    input logic clk,
    input logic fifo_empty,
    input logic allow_send_break_override,
    input mmio_status_flags_t status_flags,
    output logic tx_data_pulse,
    output logic clear_rx_valid,
    mmio_if.mmio transaction_bus,
    fifo_ctrl_if.mmio fifo_ctrl
);
  logic is_tx_data_write;
  assign is_tx_data_write = transaction_bus.write_en && transaction_bus.address[4:0] == 5'h0C;

  always_ff @(posedge clk) begin : ctrl1_write
    if (transaction_bus.write_en && transaction_bus.address[4:0] == 5'h00) begin
      transaction_bus.ctrl1_reg[31:16] <= transaction_bus.wdata[31:16];
      transaction_bus.ctrl1_reg[10:7] <= transaction_bus.wdata[10:7];
      transaction_bus.ctrl1_reg[6] <= transaction_bus.wdata[6];
      transaction_bus.ctrl1_reg[5] <= transaction_bus.wdata[5];

      if (allow_send_break_override && transaction_bus.ctrl1_reg[4] != transaction_bus.wdata[4]) begin
        transaction_bus.ctrl1_reg[4] <= transaction_bus.wdata[4];
      end

      transaction_bus.ctrl1_reg[3:2] <= transaction_bus.wdata[3:2];
      transaction_bus.ctrl1_reg[1:0] <= transaction_bus.wdata[1:0];
    end

    transaction_bus.ctrl1_reg[15:11] <= '0;  // Reserved bits
  end

  always_ff @(posedge clk) begin : ctrl2_write
    if (transaction_bus.write_en && transaction_bus.address[4:0] == 5'h04) begin
      transaction_bus.ctrl2_reg[3:0] <= transaction_bus.wdata[3:0];
      transaction_bus.ctrl2_reg[7:4] <= transaction_bus.wdata[7:4];
    end

    transaction_bus.ctrl2_reg[31:8] <= '0;  // Reserved bits
  end

  // TX_DATA WRITE
  assign fifo_ctrl.push = is_tx_data_write ? '1 : '0;
  assign fifo_ctrl.push_data = is_tx_data_write ? transaction_bus.wdata[7:0] : 'x;

  // STATUS, RX_DATA AND CTRL1 READ
  assign transaction_bus.rdata = (transaction_bus.read_en && transaction_bus.address[4:0] == 5'h08) ?
      // upper bits are reserved
      {
        {19{1'b0}},
        status_flags
      }
      : (transaction_bus.read_en && transaction_bus.address[4:0] == 5'h10) ?
          32'(fifo_ctrl.pop_data) : (transaction_bus.read_en && transaction_bus.address[4:0] == 5'h00) ? transaction_bus.ctrl1_reg : (transaction_bus.read_en && transaction_bus.address[4:0] == 5'h04) ? transaction_bus.ctrl2_reg : 'x;

  always_comb begin : rx_data_read
    if (transaction_bus.read_en && transaction_bus.address[4:0] == 5'h10) begin
      fifo_ctrl.pop  = '1;
      clear_rx_valid = '1;
    end else begin
      fifo_ctrl.pop  = '0;
      clear_rx_valid = '0;
    end
  end

  assign tx_data_pulse = !fifo_empty && !status_flags[0];
endmodule
