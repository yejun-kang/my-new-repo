`timescale 1ns / 1ps

module tb_spi_master();

    logic        clk;
    logic        rst_n;
    logic        start;
    logic [1:0]  mode;
    logic [15:0] byte_count;
    logic        busy;
    logic        done;

    logic [7:0]  tx_data;
    logic        tx_ready;
    logic [7:0]  rx_data;
    logic        rx_valid;

    logic        sclk;
    logic        cs_n;
    logic        mosi;
    logic        miso;

    assign miso = mosi;

    spi_master #(
        .CLK_FREQ(100_000_000),
        .SPI_SCLK(10_000_000)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .mode(mode),
        .byte_count(byte_count),
        .busy(busy),
        .done(done),
        .tx_data(tx_data),
        .tx_ready(tx_ready),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .miso(miso)
    );

    always #5 clk = ~clk;

    byte test_bytes[5] = '{8'hA5, 8'h5A, 8'hDE, 8'hAD, 8'hEF};
    byte rx_buffer[5];
    int  rx_idx;
    int  error_count = 0;

    always_ff @(posedge clk) begin
        if (rx_valid) begin
            rx_buffer[rx_idx] <= rx_data;
            rx_idx <= rx_idx + 1;
        end
    end

    initial begin
        clk   = 0;
        rst_n = 0;
        start = 0;
        mode  = 2'b00;
        byte_count = 16'd5;
        tx_data    = 8'h00;
        rx_idx     = 0;

        #50;
        rst_n = 1;
        #50;

        $display("=================================================");
        $display("   STARTING SPI MASTER MULTI-MODE LOOPBACK TEST  ");
        $display("=================================================");

        for (int m = 0; m < 4; m++) begin
            mode   = m[1:0];
            rx_idx = 0;

            $display("\n---> Testing SPI Mode %0d (CPOL=%0d, CPHA=%0d)", m, mode[1], mode[0]);

            @(posedge clk);
            tx_data    = test_bytes[0];
            byte_count = 16'd5;
            start      = 1'b1;
            @(posedge clk);
            start      = 1'b0;

            for (int b = 1; b < 5; b++) begin
                wait(tx_ready);
                @(posedge clk);
                tx_data = test_bytes[b];
            end

            wait(done);
            #(100);

            for (int i = 0; i < 5; i++) begin
                if (rx_buffer[i] !== test_bytes[i]) begin
                    $display("[ERROR] Mode %0d Byte %0d Mismatch! Sent: 0x%0X, Recv: 0x%0X",
                             m, i, test_bytes[i], rx_buffer[i]);
                    error_count++;
                end else begin
                    $display("[PASS] Mode %0d Byte %0d Match: Sent 0x%0X == Recv 0x%0X",
                             m, i, test_bytes[i], rx_buffer[i]);
                end
            end
        end

        $display("\n=================================================");
        if (error_count == 0) begin
            $display("   ALL SPI MODES PASSED FULL-DUPLEX LOOPBACK!");
        end else begin
            $display("   TEST FAILED WITH %0d ERROR(S)", error_count);
        end
        $display("=================================================");

        $finish;
    end

endmodule
