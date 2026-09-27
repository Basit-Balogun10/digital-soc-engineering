interface mmio_if;
  logic [4:0] address; // only the 5 bottom bits is needed to route actions across the ctrl r/w, status (r), tx_data (w) and rx_data (r).
  logic write_en;
  logic read_en;
  logic [31:0] wdata;
  logic [31:0] ctrl1_reg;
  logic [31:0] ctrl2_reg;
  logic [31:0] rdata;

  modport mmio(input address, write_en, read_en, wdata, output ctrl1_reg, ctrl2_reg, rdata);
  modport uart_top(output address, write_en, read_en, wdata, input ctrl1_reg, ctrl2_reg, rdata);
endinterface
