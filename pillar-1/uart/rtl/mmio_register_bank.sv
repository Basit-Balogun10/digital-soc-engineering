/*
    (0x4000_4000) -> Base address
    (0x00) CTRL (R/W) -> [31:16]BAUD_DIV [4]SEND_BREAK [3:2]STOP_BITS [1:0]PARITY_MODE
    (0x04) STATUS (R) -> [10]RX_FIFO_EMPTY [9]RX_FIFO_FULL [8]TX_FIFO_EMPTY [7]TX_FIFO_FULL [6]BREAK_DETECTED [5]NOISE_ERR [4]OVERRUN [3]PARITY_ERR [2]FRAMING_ERR [1]RX_VALID [0]TX_BUSY
    (0x08) TX_DATA (W) -> [8:0]DATA
    (0x0C) RX_DATA (R) -> [8:0]DATA
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
  assign is_tx_data_write = transaction_bus.write_en && transaction_bus.address[3:0] == 4'h08;

  always_ff @(posedge clk) begin : ctrl_write
    if (transaction_bus.write_en && transaction_bus.address[3:0] == 4'h00) begin
      transaction_bus.ctrl_reg[31:16] <= transaction_bus.wdata[31:16];
      if (allow_send_break_override && transaction_bus.ctrl_reg[4] != transaction_bus.wdata[4]) begin
        transaction_bus.ctrl_reg[4] <= transaction_bus.wdata[4];
      end
      transaction_bus.ctrl_reg[3:2] <= transaction_bus.wdata[3:2];
      transaction_bus.ctrl_reg[1:0] <= transaction_bus.wdata[1:0];
    end

    transaction_bus.ctrl_reg[15:5] <= '0;  // Reserved bits
  end

  // TX_DATA WRITE
  assign fifo_ctrl.push = is_tx_data_write ? '1 : '0;
  assign fifo_ctrl.push_data = is_tx_data_write ? transaction_bus.wdata[7:0] : 'x;

  // STATUS, RX_DATA AND CTRL READ
  assign transaction_bus.rdata = (transaction_bus.read_en && transaction_bus.address[3:0] == 4'h04) ?
      // upper bits are reserved
      {
        {21{1'b0}},
        status_flags
      }
      : (transaction_bus.read_en && transaction_bus.address[3:0] == 4'h0C) ?
          32'(fifo_ctrl.pop_data) : (transaction_bus.read_en && transaction_bus.address[3:0] == 4'h00) ? transaction_bus.ctrl_reg : 'x;

  always_comb begin : rx_data_read
    if (transaction_bus.read_en && transaction_bus.address[3:0] == 4'h0C) begin
      fifo_ctrl.pop  = '1;
      clear_rx_valid = '1;
    end else begin
      fifo_ctrl.pop = '0;
    end
  end

  assign tx_data_pulse = !fifo_empty && !status_flags[0];
endmodule
