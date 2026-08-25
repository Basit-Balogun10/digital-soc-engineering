interface mmio_if;
  // only the 4 bottom bits is needed to route actions across the ctrl r/w, status (r), tx_data (w) and rx_data (r).
  logic [3:0] address;
  logic write_en;
  logic read_en;
  logic [31:0] wdata;
  logic [31:0] ctrl_reg;
  logic [31:0] rdata;

  modport mmio(input address, write_en, read_en, wdata, output ctrl_reg, rdata);
  modport uart_top(output address, write_en, read_en, wdata, input ctrl_reg, rdata);
endinterface
