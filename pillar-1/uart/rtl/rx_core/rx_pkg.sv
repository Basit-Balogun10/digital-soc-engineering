package rx_pkg;
  typedef enum logic [2:0] {
    RX_IDLE,
    RX_START_VERIFY,
    RX_DATA,
    RX_PARITY,
    RX_STOP,
    RX_ERROR
  } rx_state_e;
endpackage
