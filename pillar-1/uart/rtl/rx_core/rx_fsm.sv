module rx_fsm
  import uart_pkg::DATA_BITS, uart_pkg::OVERSAMPLE_N;
  import uart_pkg::parity_e, uart_pkg::NONE;
  import uart_pkg::stop_bits_e, uart_pkg::ONE_STOP_BIT, uart_pkg::TWO_STOP_BITS;
  import rx_pkg::rx_state_e, rx_pkg::RX_IDLE, rx_pkg::RX_START_VERIFY, rx_pkg::RX_DATA, rx_pkg::RX_PARITY, rx_pkg::RX_STOP, rx_pkg::RX_ERROR;
(
    input logic clk,
    input logic rst_n,
    input logic rx_sync,
    input logic voted_rx,
    input logic oversampling_done,
    input logic [$clog2(OVERSAMPLE_N) - 1:0] oversample_count,
    input logic [DATA_BITS - 1:0] rx_data_bits,
    input logic parity_err,
    input logic rx_break,
    input parity_e parity_mode,
    input stop_bits_e stop_bits,
    output logic oversample_counter_rst_n,
    output logic rx_data_active,
    output logic rx_shift_enable,
    output logic rx_valid,
    output logic rx_push,
    output logic [DATA_BITS - 1:0] rx_push_data,
    output logic framing_err
);
  rx_state_e state, next_state;
  logic bit_period_complete;
  logic [$clog2(DATA_BITS) - 1:0] data_bit_periods;
  logic [1:0] stop_bit_periods;

  assign bit_period_complete = 32'(oversample_count) == OVERSAMPLE_N - 1 ? '1 : '0;

  always_ff @(posedge clk) begin : data_bit_periods_counter
    if (!rst_n) begin
      data_bit_periods <= '0;
    end else begin
      if (state == RX_PARITY || state == RX_STOP) begin
        data_bit_periods <= '0;
      end else if (state == RX_DATA && bit_period_complete) begin
        data_bit_periods <= data_bit_periods + 1;
      end
    end
  end

  always_ff @(posedge clk) begin : stop_bit_periods_counter
    if (!rst_n) begin
      stop_bit_periods <= '0;
    end else begin
      if (state == RX_IDLE) begin
        stop_bit_periods <= '0;
      end else if (stop_bit_periods == 2) begin
        // Stop bits can only be 1 or 2, safe to wrap here instead of increasing to 3. Kept separate from the reset case above for readability
        stop_bit_periods <= '0;
      end else if (state == RX_STOP && bit_period_complete) begin
        stop_bit_periods <= stop_bit_periods + 1;
      end
    end
  end

  always_ff @(posedge clk) begin : state_register
    if (!rst_n) begin
      state <= RX_IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin : state_transition
    next_state = state;
    rx_valid = '0;
    rx_push = '0;
    rx_push_data = 'x;

    case (state)
      RX_IDLE:
      if (!(rx_sync || rx_break)) begin
        next_state = RX_START_VERIFY;
      end
      RX_START_VERIFY: begin
        if (oversampling_done && !voted_rx) next_state = RX_DATA;
        else if (oversampling_done && voted_rx) next_state = RX_IDLE;
      end
      RX_DATA: begin
        if (32'(data_bit_periods) == DATA_BITS - 1)
          next_state = parity_mode == NONE ? RX_STOP : RX_PARITY;
      end
      RX_PARITY:
      if (parity_err) next_state = RX_ERROR;
      else next_state = RX_STOP;
      RX_STOP: begin
        if ((stop_bits == ONE_STOP_BIT && stop_bit_periods == ONE_STOP_BIT + 1) ||          (stop_bits == TWO_STOP_BITS && stop_bit_periods == TWO_STOP_BITS + 1)) begin
          rx_valid = !framing_err;  // a pulse, not a level, correct?
          rx_push = !framing_err;
          rx_push_data = framing_err ? 'x : rx_data_bits;
          next_state = framing_err ? RX_ERROR : RX_IDLE;
        end
      end
      RX_ERROR: begin
        next_state = RX_IDLE;
      end

      default: begin
        next_state = state;
        rx_valid = '0;
        rx_push = '0;
        rx_push_data = 'x;
      end
    endcase
  end

  always_comb begin : state_output
    oversample_counter_rst_n = '1;
    rx_data_active = '0;
    rx_shift_enable = '0;
    framing_err = '0;

    case (state)
      RX_IDLE:         oversample_counter_rst_n = '0;
      RX_START_VERIFY: if (oversampling_done && !voted_rx) oversample_counter_rst_n = '0;
      RX_DATA: begin
        rx_data_active  = '1;
        rx_shift_enable = bit_period_complete ? '1 : '0;
      end
      RX_PARITY:       ;
      RX_STOP:         framing_err = oversampling_done && !voted_rx;
      RX_ERROR:        ;

      default: begin
        oversample_counter_rst_n = '1;
        rx_data_active = '0;
        rx_shift_enable = '0;
        framing_err = '0;
      end
    endcase
  end
endmodule
