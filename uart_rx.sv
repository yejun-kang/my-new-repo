`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 9600
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       rx_in,
    output logic [7:0] rx_data,
    output logic       rx_data_valid
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // 10,417 cycles
    localparam HALF_BIT_CLK = CLKS_PER_BIT / 2;     // 5,208 cycles

    typedef enum logic [2:0] {
        ST_IDLE  = 3'b000,
        ST_START = 3'b001,
        ST_DATA  = 3'b010,
        ST_STOP  = 3'b011
    } state_t;

    state_t state;

    // 2-stage synchronizer to prevent metastability
    logic rx_sync1, rx_sync2;
    always_ff @(posedge clk) begin
        if (rst) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_in;
            rx_sync2 <= rx_sync1;
        end
    end

    logic [13:0] clk_count;
    logic [2:0]  bit_index;
    logic [7:0]  rx_byte;

    always_ff @(posedge clk) begin
        if (rst) begin
            state         <= ST_IDLE;
            clk_count     <= '0;
            bit_index     <= '0;
            rx_byte       <= '0;
            rx_data       <= '0;
            rx_data_valid <= 1'b0;
        end else begin
            // rx_data_valid is a single-cycle pulse
            rx_data_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    clk_count <= '0;
                    bit_index <= '0;

                    // Start bit detection: falling edge on synchronized RX line
                    if (rx_sync2 == 1'b0) begin
                        state <= ST_START;
                    end
                end

                ST_START: begin
                    // Wait for the MIDDLE of the start bit
                    if (clk_count < HALF_BIT_CLK - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        // Verify rx_sync2 is still LOW at mid-bit point (filters false start spikes)
                        if (rx_sync2 == 1'b0) begin
                            state <= ST_DATA;
                        end else begin
                            state <= ST_IDLE; // False start glitch detected
                        end
                    end
                end

                ST_DATA: begin
                    // Sample every full bit period (10,417 cycles) from the center
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        rx_byte[bit_index] <= rx_sync2; // Sample bit in center

                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= '0;
                            state     <= ST_STOP;
                        end
                    end
                end

                ST_STOP: begin
                    // Wait one full bit period to align to the middle of the Stop Bit
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count     <= '0;
                        rx_data       <= rx_byte; // Transfer assembled byte to output
                        rx_data_valid <= 1'b1;   // Pulse valid signal for 1 cycle
                        state         <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
