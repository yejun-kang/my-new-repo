`timescale 1ns / 1ps

module uart_top #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 9600
)(
    input  logic       clk,      // 100 MHz oscillator (Pin W5)
    input  logic       btnC,     // Reset or manual TX trigger button
    input  logic [7:0] sw,       // Manual byte selection switches
    input  logic       RsRx,     // FPGA UART RX input (Pin B18)
    output logic       RsTx,     // FPGA UART TX output (Pin A18)
    output logic [7:0] led,      // Received byte display
    output logic       led_valid // Valid byte pulse indicator
);

    // Internal Signals
    logic       tx_start;
    logic [7:0] tx_data;
    logic       tx_busy;

    logic [7:0] rx_data;
    logic       rx_data_valid;

    // Latch last received byte for LED display
    always_ff @(posedge clk) begin
        if (btnC) begin
            led <= '0;
            led_valid <= 1'b0;
        end else if (rx_data_valid) begin
            led <= rx_data;
            led_valid <= ~led_valid; // Toggle LED on every valid received byte
        end
    end

    // Echo Logic: Trigger TX whenever RX completes a byte, OR manually via btnC/sw switches
    assign tx_start = rx_data_valid;
    assign tx_data  = rx_data;

    // Instantiate UART Transmitter
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk(clk),
        .rst(1'b0), // System reset inactive
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_out(RsTx),
        .tx_busy(tx_busy)
    );

    // Instantiate UART Receiver
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_rx (
        .clk(clk),
        .rst(1'b0), // System reset inactive
        .rx_in(RsRx),
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid)
    );

endmodule
