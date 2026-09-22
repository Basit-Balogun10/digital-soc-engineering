module tx_fsm
  import uart_pkg::DATA_BITS, uart_pkg::OVERSAMPLE_N;
  import uart_pkg::parity_e, uart_pkg::NONE;
  import uart_pkg::stop_bits_e, uart_pkg::ONE_STOP_BIT, uart_pkg::TWO_STOP_BITS;
  import tx_pkg::tx_state_e, tx_pkg::TX_IDLE, tx_pkg::TX_START, tx_pkg::TX_DATA, tx_pkg::TX_PARITY, tx_pkg::TX_STOP;
(
    input  logic clk,
    input  logic rst_n,
    input  logic tick,
    input  logic tx_start_pulse,
    input  logic tx_data_bit,
    input  logic parity_bit,
    input logic tx_break,
    input parity_e parity_mode,
    input stop_bits_e stop_bits,
    output logic tx,
    output logic tx_busy,
    output logic tx_shift_enable,
    output logic tx_load_enable
);
  tx_state_e state, next_state;
  logic bit_period_complete;
  logic [$clog2(OVERSAMPLE_N) - 1:0] ticks;
  logic [$clog2(DATA_BITS) - 1:0] data_bit_periods;
  logic [1:0] stop_bit_periods;

  assign tx_busy = state != TX_IDLE;
  assign bit_period_complete = 32'(ticks) == OVERSAMPLE_N - 1 ? '1 : '0;

  always_ff @(posedge clk) begin : data_bit_periods_counter
    if (!rst_n) begin
      data_bit_periods <= '0;
    end else begin
      if (state == TX_PARITY || state == TX_STOP) begin
        data_bit_periods <= '0;
      end else if (state == TX_DATA && bit_period_complete) begin
        data_bit_periods <= data_bit_periods + 1;
      end
    end
  end

  always_ff @(posedge clk) begin : stop_bit_periods_counter
    if (!rst_n) begin
      stop_bit_periods <= '0;
    end else begin
      if (state == TX_IDLE) begin
        stop_bit_periods <= '0;
      end else if (stop_bit_periods == 2) begin
        // Stop bits can only be 1 or 2, safe to wrap here instead of increasing to 3. Kept separate from the reset case above for readability
        stop_bit_periods <= '0;
      end else if (state == TX_STOP && bit_period_complete) begin
        stop_bit_periods <= stop_bit_periods + 1;
      end
    end
  end

  always_ff @(posedge clk) begin : ticks_counter
    if (!rst_n) begin
      ticks <= '0;
    end else begin
      if (tick) begin
        ticks <= ticks + 1;
      end
    end
  end

  always_ff @(posedge clk) begin : state_register
    if (!rst_n) begin
      state <= TX_IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin : state_transition
    next_state = state;

    case (state)
      TX_IDLE:   if (tx_start_pulse) next_state = TX_START;
      TX_START:  if (bit_period_complete) next_state = TX_DATA;
      TX_DATA: begin
        if (32'(data_bit_periods) == DATA_BITS - 1)
          next_state = parity_mode == NONE ? TX_STOP : TX_PARITY;
      end
      TX_PARITY: if (bit_period_complete) next_state = TX_STOP;
      TX_STOP: begin
        if ((stop_bits == ONE_STOP_BIT && stop_bit_periods == ONE_STOP_BIT + 1) ||
          (stop_bits == TWO_STOP_BITS && stop_bit_periods == TWO_STOP_BITS + 1))
          next_state = TX_IDLE;
      end

      default: next_state = state;
    endcase
  end

  always_comb begin : state_output
    tx = !tx_break;
    tx_shift_enable = '0;
    tx_load_enable = '0;

    case (state)
      TX_IDLE:   tx = !tx_break;
      TX_START: begin
        tx = tx_break;
        tx_load_enable = '1;
      end
      TX_DATA: begin
        tx = tx_break ? '0 : tx_data_bit;
        tx_shift_enable = bit_period_complete ? '1 : '0;
      end
      TX_PARITY: tx = tx_break ? '0 : parity_bit;
      TX_STOP:   tx = !tx_break;

      default: begin
        tx = !tx_break;
        tx_shift_enable = '0;
        tx_load_enable = '0;
      end
    endcase
  end

endmodule
