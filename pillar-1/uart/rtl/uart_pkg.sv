package uart_pkg;
  typedef struct packed {
    logic autobaud_err;
    logic rts_err;
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

  typedef enum logic [1:0] {
    NONE,
    EVEN,
    ODD
  } parity_e;

  typedef enum logic {
    ONE_STOP_BIT  = 0,
    TWO_STOP_BITS = 1
  } stop_bits_e;

  parameter int unsigned BAUD_DIV_WIDTH = 16;
  parameter int unsigned DATA_BITS = 8;
  parameter int unsigned FIFO_DEPTH = 16;
  parameter int unsigned OVERSAMPLE_N = 16;

  parameter int unsigned RTS_FULL_THRESHOLD = 14;
  parameter int unsigned TX_WATERMARK = 14;
  parameter int unsigned RX_WATERMARK = 2;
endpackage
