module tx_fsm
  import tx_pkg::*;
  import uart_pkg::DATA_BITS, uart_pkg::STOP_BITS, uart_pkg::OVERSAMPLE_N;
  import uart_pkg::PARITY_MODE, uart_pkg::NONE;
  import uart_pkg::ONE_STOP_BIT, uart_pkg::TWO_STOP_BITS;
(
    input  logic clk,
    input  logic rst_n,
    input  logic tick,
    input  logic tx_start_pulse,
    input  logic tx_data_bit,
    input  logic parity_bit,
    output logic tx,
    output logic tx_busy,
    output logic tx_shift_enable,
    output logic tx_load_enable
);
  tx_state_e state, next_state;
  logic bit_period_complete;
  logic [$clog2(OVERSAMPLE_N):0] ticks;
  logic [$clog2(DATA_BITS) - 1:0] data_bit_periods;
  logic [1:0] stop_bit_periods;

  assign tx_busy = state != TX_IDLE;
  assign bit_period_complete = 32'(ticks) == OVERSAMPLE_N ? '1 : '0;

  // sync or async reset? Sync? Same reasoning?
  always_ff @(posedge clk) begin : data_bit_periods_counter
    // Do we hold off counting until state is TX_DATA? Since that's what needs it? So we are only counting "bit periods since state became TX_DATA"
    // If not, should we restart counting from zero when state switches to TX_DATA to be sure our bit_periods counter is starting from 0? Or is that guaranteed considering we only go from TX_START to TX_DATA when a bit period is complete (wait, bit periods complete/"16 ticks just happened" doesn't mean the bit_periods counter just reached max/wraps over to 0 at that same instant though...)
    // I'm leaned towards holding off though (and calling it data_bit_periods instead of bit_periods?)
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

  // sync or async reset? Sync I guess, same vein/reasoning as resets in fifo.sv?
  always_ff @(posedge clk) begin : ticks_counter
    if (!rst_n) begin
      ticks <= '0;
    end else begin
      if (32'(ticks) == OVERSAMPLE_N - 1) begin
        // wraps, can't rely on bit-width based wrapping since its width is dynamic (and dependent on the OVERSAMPLE_N parameter)
        ticks <= '0;
      end else if (tick) begin
        ticks <= ticks + 1;
      end
    end
  end

  // sync or async reset?
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
          next_state = PARITY_MODE == NONE ? TX_STOP : TX_PARITY;
      end
      TX_PARITY: if (bit_period_complete) next_state = TX_STOP;
      TX_STOP: begin
        if ((STOP_BITS == ONE_STOP_BIT && stop_bit_periods == ONE_STOP_BIT + 1) ||
          (STOP_BITS == TWO_STOP_BITS && stop_bit_periods == TWO_STOP_BITS + 1))
          next_state = TX_IDLE;
      end

      default: next_state = state;
    endcase
  end

  always_comb begin : state_output
    tx = '1;
    tx_shift_enable = '0;
    tx_load_enable = '0;

    case (state)
      TX_IDLE:   tx = '1;
      TX_START: begin
        tx = '0;
        tx_load_enable = '1;
      end
      TX_DATA: begin
        tx = tx_data_bit;
        tx_shift_enable = bit_period_complete ? '1 : '0;
      end
      TX_PARITY: tx = parity_bit;
      TX_STOP:   tx = '1;

      default: begin
        tx = '1;
        tx_shift_enable = '0;
        tx_load_enable = '0;
      end
    endcase
  end

  // assign tx = state == TX_DATA ? tx_data_bit : '0;

endmodule
