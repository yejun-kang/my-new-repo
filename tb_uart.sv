`timescale 1ns / 1ps

module tb_uart;

    // Parameters (Overridden to run fast in simulation if desired, or kept real)
    localparam CLK_FREQ  = 100_000_000;
    localparam BAUD_RATE = 9600;
    localparam CLK_PERIOD = 10; // 100 MHz -> 10ns period

    // Testbench Signals
    logic       clk;
    logic       rst;
    logic       tx_start;
    logic [7:0] tx_data;
    logic       tx_out;
    logic       tx_busy;
    
    logic [7:0] rx_data;
    logic       rx_data_valid;

    // Test array with 10 distinct byte patterns
    byte test_bytes[10] = '{
        8'hA5, 8'h55, 8'hFF, 8'h00, 8'h12, 
        8'h34, 8'h7F, 8'h80, 8'hC3, 8'hE7
    };

    // Instantiate UART Transmitter
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_out(tx_out),
        .tx_busy(tx_busy)
    );

    // Instantiate UART Receiver (Loopback connection: tx_out -> rx_in)
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_rx (
        .clk(clk),
        .rst(rst),
        .rx_in(tx_out), // Physical loopback line
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid)
    );

    // 100 MHz Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Main Test Stimulus
    initial begin
        // Initialize Signals
        clk      = 0;
        rst      = 1;
        tx_start = 0;
        tx_data  = 8'h00;

        // Apply Reset
        #(CLK_PERIOD * 10);
        rst = 0;
        #(CLK_PERIOD * 10);

        $display("--------------------------------------------------");
        $display("Starting UART TX -> RX Loopback Verification Test");
        $display("--------------------------------------------------");

        // Loop through all 10 test bytes
        for (int i = 0; i < 10; i++) begin
            // Wait if TX is busy
            while (tx_busy) @(posedge clk);

            // Send byte
            tx_data  = test_bytes[i];
            tx_start = 1'b1;
            @(posedge clk);
            tx_start = 1'b0;

            // Wait for RX to capture and output valid pulse
            fork
                begin
                    @(posedge rx_data_valid);
                    if (rx_data === test_bytes[i]) begin
                        $display("[PASS] Sent: 0x%02X | Received: 0x%02X", test_bytes[i], rx_data);
                    end else begin
                        $display("[FAIL] Sent: 0x%02X | Received: 0x%02X", test_bytes[i], rx_data);
                    end
                end
                begin
                    // Timeout check (15ms is enough time for 1 frame at 9600 baud)
                    #15_000_000;
                    if (!rx_data_valid) begin
                        $display("[TIMEOUT] Timed out waiting for byte 0x%02X", test_bytes[i]);
                        $finish;
                    end
                end
            join_any
            disable fork; // Clear timeout thread if valid received

            // Small delay between transfers
            #(CLK_PERIOD * 100);
        end

        $display("--------------------------------------------------");
        $display("UART Loopback Verification Complete!");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
