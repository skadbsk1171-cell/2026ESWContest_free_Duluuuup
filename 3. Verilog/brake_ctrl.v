

`timescale 1ns / 1ps

module brake_ctrl #(
    parameter integer CLK_HZ       = 100000000,
    parameter integer DEF_PULSE_MS = 800,
    parameter integer DEF_COOL_MS  = 5000,
    parameter integer MAX_PULSE_MS = 1500
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        trigger,


    input  wire [15:0] cfg_pulse_ms,
    input  wire [15:0] cfg_cool_ms,

    output reg         brake_en,
    output reg         brake_fault
);

    localparam integer MS_DIV = CLK_HZ / 1000;

    reg [31:0] div_cnt;
    wire       ms_tick = (div_cnt == MS_DIV - 1);

    localparam [1:0] S_IDLE  = 2'd0,
                     S_PULSE = 2'd1,
                     S_COOL  = 2'd2;

    reg [1:0]  state;
    reg [15:0] ms_cnt;
    reg        trig_d;

    wire trig_rise = trigger & ~trig_d;


    wire [15:0] eff_pulse =
        ((cfg_pulse_ms == 16'd0) || (cfg_pulse_ms >= MAX_PULSE_MS[15:0]))
        ? DEF_PULSE_MS[15:0] : cfg_pulse_ms;

    wire [15:0] eff_cool =
        (cfg_cool_ms == 16'd0) ? DEF_COOL_MS[15:0] : cfg_cool_ms;


    always @(posedge clk) begin
        if (!rst_n) begin
            div_cnt     <= 32'd0;
            state       <= S_IDLE;
            ms_cnt      <= 16'd0;
            brake_en    <= 1'b0;
            brake_fault <= 1'b0;

            trig_d      <= 1'b1;
        end else begin
            if (ms_tick) div_cnt <= 32'd0;
            else         div_cnt <= div_cnt + 32'd1;

            trig_d <= trigger;

            case (state)

            S_IDLE: begin
                brake_en <= 1'b0;
                ms_cnt   <= 16'd0;
                if (trig_rise) begin
                    brake_en <= 1'b1;
                    state    <= S_PULSE;
                end
            end


            S_PULSE: begin
                if (ms_tick) begin
                    ms_cnt <= ms_cnt + 16'd1;


                    if (ms_cnt + 16'd1 >= MAX_PULSE_MS[15:0]) begin
                        brake_en    <= 1'b0;
                        brake_fault <= 1'b1;
                        ms_cnt      <= 16'd0;
                        state       <= S_COOL;
                    end
                    else if (ms_cnt + 16'd1 >= eff_pulse) begin
                        brake_en <= 1'b0;
                        ms_cnt   <= 16'd0;
                        state    <= S_COOL;
                    end
                end
            end


            S_COOL: begin
                brake_en <= 1'b0;
                if (ms_tick) begin
                    ms_cnt <= ms_cnt + 16'd1;
                    if (ms_cnt + 16'd1 >= eff_cool) begin
                        ms_cnt <= 16'd0;
                        state  <= S_IDLE;
                    end
                end
            end


            default: begin
                brake_en <= 1'b0;
                state    <= S_IDLE;
            end
            endcase
        end
    end

endmodule
