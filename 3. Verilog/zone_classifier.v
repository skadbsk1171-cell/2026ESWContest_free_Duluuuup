4개 존에 대해 이 모듈을 64개 병렬 인스턴스화한다.
















module zone_classifier #(
    parameter DANGER_MM  = 350,
    parameter WARNING_MM = 500,
    parameter CAUTION_MM = 800,
    parameter DW         = 12
)(
    input  wire [DW-1:0] dist,
    input  wire          valid_in,
    output reg  [1:0]    zone,
    output wire          zone_valid_out
);
    localparam SAFE    = 2'd0;
    localparam CAUTION = 2'd1;
    localparam WARNING = 2'd2;
    localparam DANGER  = 2'd3;

    wire valid = valid_in & (dist != 0);
    assign zone_valid_out = valid;

    always @(*) begin
        if (!valid)                 zone = SAFE;
        else if (dist <= DANGER_MM)  zone = DANGER;
        else if (dist <= WARNING_MM) zone = WARNING;
        else if (dist <= CAUTION_MM) zone = CAUTION;
        else                         zone = SAFE;
    end
endmodule
