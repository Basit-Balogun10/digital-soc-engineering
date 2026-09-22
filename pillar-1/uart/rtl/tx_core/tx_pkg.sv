package tx_pkg;
  typedef enum logic [2:0] {
    TX_IDLE,
    TX_START,
    TX_DATA,
    TX_PARITY,
    TX_STOP
  } tx_state_e;

  parameter int unsigned MAX_FRAME_WIDTH = 12;
endpackage
