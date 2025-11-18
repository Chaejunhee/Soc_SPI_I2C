`timescale 1ns / 1ps


module Master (
    input logic clk,
    input logic reset,
    input logic run,
    input logic stop,
    input logic clear,

    output logic sclk,
    output logic mosi,
    output logic ss
);
    logic [7:0] w_data;
    logic start, tx_ready;
    logic tick;
    logic clk_1khz;

    spi_master U_SPI_MASTER (
        .*,
        .tx_data(w_data),
        .rx_data(),
        .cpol(1'b0),
        .cpha(1'b0),
        .done(),
        .miso()
    );
    clk_divider_counter U_CLK_DIV_CNT (
        .*,
        .clk_1khz(clk_1khz),
        .rst(reset)
    );

    upcounter U_UPCOUNTER (
        .*,
        .o_data(w_data),
        .tick  (clk_1khz),
        .done  ()
    );

endmodule

module clk_divider_counter (
    input  logic clk,
    input  logic rst,
    output logic clk_1khz
);
    logic [$clog2(1_000_000)-1:0] r_count;
    logic o_clk;

    assign clk_1khz = o_clk;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            r_count <= 0;
            o_clk   <= 0;
        end else begin
            if (r_count == 1_000_000 - 1) begin
                r_count <= 0;
                o_clk   <= 1;
            end else begin
                r_count <= r_count + 1;
                o_clk   <= 0;
            end
        end
    end

endmodule

module upcounter (
    //global signals
    input  logic       clk,
    input  logic       reset,
    //external signals
    input  logic       run,
    input  logic       stop,
    input  logic       clear,
    output logic       ss,
    //internal signals
    input  logic       tick,
    output logic [7:0] o_data,
    output logic       start,
    input  logic       tx_ready,
    input  logic       done
);

    logic [15:0] counter_reg, counter_next;
    logic run_reg, stop_reg, clear_reg;
    logic run_next, stop_next, clear_next;
    logic start_next, start_reg;

    typedef enum {
        RUN,
        STOP
    } state_rsc;

    state_rsc state_rsc_reg, state_rsc_next;

    typedef enum {
        IDLE,
        UPPERBIT,
        WAIT,
        DOWNBIT
    } state_d;

    state_d state_d_reg, state_d_next;

    assign ss = (state_d_reg == IDLE || state_d_reg == WAIT) ? 1 : 0;
    assign o_data = (state_d_reg == UPPERBIT) ? counter_reg[15:8] : (state_d_reg == DOWNBIT) ? counter_reg[7:0] : 8'h00;
    assign start = start_reg;

    logic tx_start_reg1, tx_start_reg2;


    always_ff @(posedge clk, posedge reset) begin : run_stop_clear_counter_manage_ff
        if (reset) begin
            state_rsc_reg <= STOP;
            run_reg       <= 0;
            stop_reg      <= 0;
            clear_reg     <= 0;
            tx_start_reg1 <= 0;
            tx_start_reg2 <= 0;
        end else begin
            state_rsc_reg <= state_rsc_next;
            run_reg       <= run_next;
            stop_reg      <= stop_next;
            clear_reg     <= clear_next;
            tx_start_reg1 <= tx_ready;
            tx_start_reg2 <= tx_start_reg1;
        end
    end


    always_ff @(posedge clk, posedge reset) begin : data_manage_ff
        if (reset) begin
            state_d_reg <= IDLE;
            start_reg   <= 1'b0;
            counter_reg <= 0;
        end else begin
            state_d_reg <= state_d_next;
            start_reg   <= start_next;
            counter_reg <= counter_next;
        end
    end

    always_comb begin : data_manage_comb
        state_rsc_next = state_rsc_reg;
        // run_next = run_reg;
        // stop_next = stop_reg;
        // clear_next = clear_reg;
        state_d_next = state_d_reg;
        start_next = start_reg;
        counter_next = counter_reg;
        if (clear) begin
            clear_next = 1'b1;
        end
        case (state_rsc_reg)
            STOP: begin
                if (run) begin
                    run_next = 1'b1;
                end
            end
            RUN: begin
                if (stop) begin
                    stop_next = 1'b1;
                end
            end
        endcase
        case (state_d_reg)
            IDLE: begin
                if (tick) begin
                    //Idle에서만 런스탑클리어를 제어한다
                    case (state_rsc_reg)
                        STOP: begin
                            //count 유지
                            counter_next = counter_reg;
                            if (run_reg) begin
                                state_rsc_next = RUN;
                                run_next = 1'b0;
                            end
                            if (clear_reg) begin
                                counter_next = 0;
                                clear_next   = 1'b0;
                            end
                        end
                        RUN: begin
                            //count 증가
                            if (counter_reg != 16'd9999) begin
                                counter_next = counter_reg + 1'd1;
                            end else begin
                                counter_next = 0;
                            end
                            //상태 제어
                            if (stop_reg) begin
                                state_rsc_next = STOP;
                                stop_next = 1'b0;
                            end
                        end
                    endcase
                    state_d_next = UPPERBIT;
                    start_next   = 1'b1;
                end
            end
            UPPERBIT: begin
                start_next = 1'b0;
                // o_data = counter_reg[15:8];
                // if (tx_ready) begin
                if (!tx_start_reg2 & tx_start_reg1) begin
                    state_d_next = WAIT;
                    //   /  start_next   = 1'b1;
                end
            end
            WAIT: begin
                start_next   = 1'b1;
                state_d_next = DOWNBIT;
            end
            DOWNBIT: begin
                start_next = 1'b0;
                // o_data = counter_reg[7:0];
                // if (tx_ready) begin
                if (!tx_start_reg2 & tx_start_reg1) begin
                    state_d_next = IDLE;
                end
            end
        endcase
    end
endmodule
