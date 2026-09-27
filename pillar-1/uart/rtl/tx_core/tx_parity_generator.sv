module tx_parity_generator
  import uart_pkg::DATA_BITS;
  import uart_pkg::parity_e, uart_pkg::NONE, uart_pkg::EVEN, uart_pkg::ODD;
(
    input logic [DATA_BITS - 1:0] tx_fifo_pop_data,
    input parity_e parity_mode,
    output logic parity_bit
);

  assign parity_bit = parity_mode == EVEN ? ^tx_fifo_pop_data : parity_mode == ODD ? ~^tx_fifo_pop_data : 'x;

endmodule
