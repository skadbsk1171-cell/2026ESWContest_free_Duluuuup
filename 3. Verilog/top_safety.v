
module top_safety #(
    parameter N          = 64,
    parameter DW         = 12,
    parameter DANGER_MM  = 350,
    parameter WARNING_MM = 500,
    parameter CAUTION_MM = 800,
    parameter CLK_HZ     = 100000000,
    parameter WDT_TIMEOUT= 100000000,
    parameter ESTOP_NORMAL = 1
)(
    input  wire            clk,
    input  wire            rst_n,


    input  wire [N*DW-1:0] dist_flat,
    input  wire [N-1:0]    valid_flat,


    input  wire            estop_raw,
    input  wire            ps_heartbeat,
    input  wire            reset_btn,


    output wire            relay_en,
    output wire            fan_pwm,
    output wire            stopped,
    output wire [1:0]      fan_level_o,
    output wire [1:0]      worst_zone_o,
    output wire            estop_trip_o,
    output wire            wdt_trip_o
);

    wire [1:0] worst_zone;
    wire       out_valid;
    risk_reducer #(.N(N), .DW(DW),
        .DANGER_MM(DANGER_MM), .WARNING_MM(WARNING_MM), .CAUTION_MM(CAUTION_MM)
    ) u_risk (
        .dist_flat(dist_flat), .valid_flat(valid_flat),
        .worst_zone(worst_zone), .out_valid(out_valid)
    );


    wire estop_trip, estop_clear;
    estop_sync #(.ACTIVE_LEVEL_NORMAL(ESTOP_NORMAL), .STAGES(3)) u_estop (
        .clk(clk), .rst_n(rst_n), .estop_raw(estop_raw),
        .estop_trip(estop_trip), .estop_clear(estop_clear)
    );


    wire wdt_trip;
    watchdog #(.TIMEOUT(WDT_TIMEOUT), .CW(32)) u_wdt (
        .clk(clk), .rst_n(rst_n), .kick(ps_heartbeat), .wdt_trip(wdt_trip)
    );


    wire [1:0] fan_level;
    safety_fsm u_fsm (
        .clk(clk), .rst_n(rst_n),
        .zone(worst_zone), .zone_valid(out_valid),
        .estop_trip(estop_trip), .wdt_trip(wdt_trip),
        .reset_btn(reset_btn), .estop_clear(estop_clear),
        .relay_en(relay_en), .fan_level(fan_level), .stopped(stopped)
    );


    pwm_gen #(.CLK_HZ(CLK_HZ), .PWM_HZ(25000), .CW(16)) u_pwm (
        .clk(clk), .rst_n(rst_n), .fan_level(fan_level), .pwm_out(fan_pwm)
    );


    assign fan_level_o  = fan_level;
    assign worst_zone_o = worst_zone;
    assign estop_trip_o = estop_trip;
    assign wdt_trip_o   = wdt_trip;
endmodule
