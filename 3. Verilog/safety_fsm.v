
module safety_fsm (
    input  wire        clk,
    input  wire        rst_n,


    input  wire [1:0]  zone,
    input  wire        zone_valid,


    input  wire        estop_trip,
    input  wire        wdt_trip,


    input  wire        reset_btn,
    input  wire        estop_clear,


    output reg         relay_en,
    output reg  [1:0]  fan_level,
    output reg         stopped
);


    localparam SAFE    = 2'd0;
    localparam CAUTION = 2'd1;
    localparam WARNING = 2'd2;
    localparam DANGER  = 2'd3;


    localparam LV_STOP = 2'd0;
    localparam LV_50   = 2'd1;
    localparam LV_80   = 2'd2;
    localparam LV_100  = 2'd3;


    localparam S_RUNNING = 1'b0;
    localparam S_STOPPED = 1'b1;
    reg state;


    reg reset_btn_d;
    wire reset_edge = reset_btn & ~reset_btn_d;



    wire stop_condition = estop_trip
                        | wdt_trip
                        | (zone_valid & (zone == DANGER))
                        | ~zone_valid;

    always @(posedge clk) begin
        if (!rst_n) begin

            state      <= S_STOPPED;
            relay_en   <= 1'b0;
            fan_level  <= LV_STOP;
            stopped    <= 1'b1;
            reset_btn_d<= 1'b0;
        end else begin
            reset_btn_d <= reset_btn;

            case (state)

            S_RUNNING: begin
                if (stop_condition) begin

                    state     <= S_STOPPED;
                    relay_en  <= 1'b0;
                    fan_level <= LV_STOP;
                    stopped   <= 1'b1;
                end else begin

                    relay_en <= 1'b1;
                    stopped  <= 1'b0;
                    case (zone)
                        SAFE:    fan_level <= LV_100;
                        CAUTION: fan_level <= LV_80;
                        WARNING: fan_level <= LV_50;
                        default: fan_level <= LV_STOP;
                    endcase
                end
            end

            S_STOPPED: begin

                relay_en  <= 1'b0;
                fan_level <= LV_STOP;
                stopped   <= 1'b1;


                if (reset_edge && estop_clear && !stop_condition) begin
                    state    <= S_RUNNING;
                    relay_en <= 1'b1;
                    stopped  <= 1'b0;
                    fan_level<= LV_100;
                end

            end

            default: begin
                state     <= S_STOPPED;
                relay_en  <= 1'b0;
                fan_level <= LV_STOP;
                stopped   <= 1'b1;
            end
            endcase
        end
    end

endmodule
