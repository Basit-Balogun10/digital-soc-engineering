
interface fifo_ctrl_if;
  logic push;
  logic [7:0] push_data;
  logic pop;
  logic [7:0] pop_data;

  modport fifo(input push, pop, push_data, output pop_data);
  modport mmio(output push, pop, push_data, input pop_data);
endinterface  //fifo_ctrl_if
