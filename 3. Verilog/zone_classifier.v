

module zone_classifier #(
    parameter DANGER_MM  = 350, // 35cm
    parameter WARNING_MM = 500, // 50cm
    parameter CAUTION_MM = 800, // 80cm
    parameter DW         = 12 
)(
    input  wire [DW-1:0] dist,
    input  wire          valid_in,
    output reg  [1:0]    zone,
    output wire          zone_valid_out
);
    localparam SAFE    = 2'd0;
    // localparam CAUTION = 2'd1;
    localparam WARNING = 2'd2;
    localparam DANGER  = 2'd3;

    wire valid = valid_in & (dist != 0);
    assign zone_valid_out = valid;

    always @(*) begin // 조합논리, 클럭에 무관
        if (!valid)                 zone = SAFE;
        else if (dist <= DANGER_MM)  zone = DANGER; // 150mm
        else if (dist <= WARNING_MM) zone = WARNING; // 500mm
        // else if (dist <= CAUTION_MM) zone = CAUTION; 
        else                         zone = SAFE;   // 800mm
    end
endmodule
