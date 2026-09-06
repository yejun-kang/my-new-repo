`timescale 1ns / 1ps

module spi_master #(
    parameter int CLK_FREQ  = 100_000_000,
    parameter int SPI_SCLK  = 10_000_000
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        start,
    input  logic [1:0]  mode,
    input  logic [15:0] byte_count,
    output logic        busy,
    output logic        done,

    input  logic [7:0]  tx_data,
    output logic        tx_ready,
    output logic [7:0]  rx_data,
    output logic        rx_valid,

    output logic        sclk,
    output logic        cs_n,
    output logic        mosi,
    input  logic        miso
);

    logic cpol, cpha;
    assign cpol = mode[1];
    assign cpha = mode[0];

    typedef enum logic [2:0] {
        IDLE      = 3'b000,
        SETUP_CS  = 3'b001,
        TRANSFER  = 3'b010,
        NEXT_BYTE = 3'b011,
        HOLD_CS   = 3'b100,
        DONE_ST   = 3'b101
    } state_t;

    state_t state, next_state;

    localint CLK_DIV = CLK_FREQ / (2 * SPI_SCLK);
    localint DIV_WIDTH = $clog2(CLK_DIV);

    logic [DIV_WIDTH-1:0] clk_cnt;
    logic                 sclk_tick;
    logic                 sclk_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt   <= '0;
            sclk_tick <= 1'b0;
        end else if (state == TRANSFER) begin
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt   <= '0;
                sclk_tick <= 1'b1;
            end else begin
                clk_cnt   <= clk_cnt + 1'b1;
                sclk_tick <= 1'b0;
            end
        end else begin
            clk_cnt   <= '0;
            sclk_tick <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_reg <= 1'b0;
        end else begin
            if (state == IDLE || state == SETUP_CS || state == HOLD_CS || state == DONE_ST) begin
                sclk_reg <= cpol;
            end else if (state == TRANSFER && sclk_tick) begin
                sclk_reg <= ~sclk_reg;
            end
        end
    end

    assign sclk = sclk_reg;

    logic sample_edge, drive_edge;
    assign sample_edge = sclk_tick && ((cpha == 1'b0) ? (sclk_reg == cpol) : (sclk_reg != cpol));
    assign drive_edge  = sclk_tick && ((cpha == 1'b0) ? (sclk_reg != cpol) : (sclk_reg == cpol));

    logic [2:0]  bit_cnt;
    logic [15:0] bytes_rem;
    logic [7:0]  tx_shift;
    logic [7:0]  rx_shift;
    logic        cs_n_reg;
    logic        mosi_reg;

    assign cs_n = cs_n_reg;
    assign mosi = mosi_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && (byte_count > 0))
                    next_state = SETUP_CS;
            end

            SETUP_CS: begin
                if (sclk_tick)
                    next_state = TRANSFER;
            end

            TRANSFER: begin
                if (sclk_tick && (bit_cnt == 3'd7) && sample_edge) begin
                    if (bytes_rem == 16'd1)
                        next_state = HOLD_CS;
                    else
                        next_state = NEXT_BYTE;
                end
            end

            NEXT_BYTE: begin
                next_state = TRANSFER;
            end

            HOLD_CS: begin
                if (sclk_tick)
                    next_state = DONE_ST;
            end

            DONE_ST: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cs_n_reg  <= 1'b1;
            mosi_reg  <= 1'b0;
            busy      <= 1'b0;
            done      <= 1'b0;
            tx_ready  <= 1'b0;
            rx_valid  <= 1'b0;
            rx_data   <= 8'h00;
            bit_cnt   <= 3'd0;
            bytes_rem <= 16'd0;
            tx_shift  <= 8'h00;
            rx_shift  <= 8'h00;
        end else begin
            done     <= 1'b0;
            rx_valid <= 1'b0;
            tx_ready <= 1'b0;

            case (state)
                IDLE: begin
                    cs_n_reg  <= 1'b1;
                    busy      <= 1'b0;
                    mosi_reg  <= 1'b0;
                    if (start && (byte_count > 0)) begin
                        busy      <= 1'b1;
                        bytes_rem <= byte_count;
                        tx_shift  <= tx_data;
                        bit_cnt   <= 3'd7;
                        tx_ready  <= 1'b1;
                    end
                end

                SETUP_CS: begin
                    cs_n_reg <= 1'b0;
                    if (cpha == 1'b0) begin
                        mosi_reg <= tx_shift[7];
                    end
                end

                TRANSFER: begin
                    if (drive_edge) begin
                        if (cpha == 1'b1) begin
                            mosi_reg <= tx_shift[bit_cnt];
                        end else begin
                            if (bit_cnt != 3'd7) begin
                                mosi_reg <= tx_shift[bit_cnt];
                            end
                        end
                    end

                    if (sample_edge) begin
                        rx_shift[bit_cnt] <= miso;
                        if (bit_cnt == 3'd0) begin
                            bit_cnt  <= 3'd7;
                            rx_data  <= {rx_shift[7:1], miso};
                            rx_valid <= 1'b1;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end
                end

                NEXT_BYTE: begin
                    bytes_rem <= bytes_rem - 1'b1;
                    tx_shift  <= tx_data;
                    tx_ready  <= 1'b1;
                    if (cpha == 1'b0) begin
                        mosi_reg <= tx_data[7];
                    end
                end

                HOLD_CS: begin
                    mosi_reg <= 1'b0;
                end

                DONE_ST: begin
                    cs_n_reg <= 1'b1;
                    busy     <= 1'b0;
                    done     <= 1'b1;
                end
            endcase
        end
    end

endmodule
