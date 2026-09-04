`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 9600
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx_out,
    output logic       tx_busy
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // 10,417 for 100MHz / 9600 baud

    typedef enum logic [2:0] {
        ST_IDLE  = 3'b000,
        ST_START = 3'b001,
        ST_DATA  = 3'b010,
        ST_STOP  = 3'b011
    } state_t;

    state_t state;

    logic [13:0] clk_count;
    logic [2:0]  bit_index;
    logic [7:0]  tx_data_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            state       <= ST_IDLE;
            tx_out      <= 1'b1; // IDLE line state is HIGH
            tx_busy     <= 1'b0;
            clk_count   <= '0;
            bit_index   <= '0;
            tx_data_reg <= '0;
        end else begin
            case (state)
                ST_IDLE: begin
                    tx_out    <= 1'b1;
                    clk_count <= '0;
                    bit_index <= '0;

                    if (tx_start) begin
                        tx_busy     <= 1'b1;
                        tx_data_reg <= tx_data; // Latch input byte
                        state       <= ST_START;
                    end else begin
                        tx_busy     <= 1'b0;
                    end
                end

                ST_START: begin
                    tx_out <= 1'b0; // Start bit is LOW

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        state     <= ST_DATA;
                    end
                end

                ST_DATA: begin
                    tx_out <= tx_data_reg[bit_index]; // Shift out LSB first

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= '0;
                            state     <= ST_STOP;
                        end
                    end
                end

                ST_STOP: begin
                    tx_out <= 1'b1; // Stop bit is HIGH

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        tx_busy   <= 1'b0;
                        state     <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
