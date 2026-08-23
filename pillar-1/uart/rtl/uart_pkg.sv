package uart_pkg;
  typedef struct packed {
    logic rx_fifo_empty;
    logic rx_fifo_full;
    logic tx_fifo_empty;
    logic tx_fifo_full;
    logic break_detected;
    logic noise_err;
    logic overrun;
    logic parity_err;
    logic framing_err;
    logic rx_valid;
    logic tx_busy;
  } mmio_status_flags_t;
endpackage
