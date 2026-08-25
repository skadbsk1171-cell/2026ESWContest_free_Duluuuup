
module estop_sync #(
    parameter ACTIVE_LEVEL_NORMAL = 1,
    parameter STAGES              = 3
)(
    input  wire clk,
    input  wire rst_n,
    input  wire estop_raw,
    output wire estop_trip,
    output wire estop_clear
);

    reg [STAGES-1:0] sync;
    always @(posedge clk) begin
        if (!rst_n)
            sync <= { STAGES {1'b0} };
        else
            sync <= { sync[STAGES-2:0], estop_raw };
    end

    wire synced = sync[STAGES-1];


    wire is_normal = (synced == ACTIVE_LEVEL_NORMAL[0]);
    assign estop_trip  = ~is_normal;
    assign estop_clear =  is_normal;
endmodule
