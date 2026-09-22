module rx_parity_checker
  import uart_pkg::DATA_BITS;
  import uart_pkg::parity_e, uart_pkg::EVEN, uart_pkg::ODD;

(
    input logic [DATA_BITS - 1:0] data_bits,
    input logic parity_bit,
    input parity_e parity_mode,
    output logic parity_err
);
  assign parity_err = parity_mode == EVEN ? ^{data_bits, parity_bit} : parity_mode == ODD ? ~^{data_bits, parity_bit} : 'x;
endmodule
