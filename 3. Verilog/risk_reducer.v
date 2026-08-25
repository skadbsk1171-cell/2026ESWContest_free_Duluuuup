

module risk_reducer #(
    parameter N          = 64,
    parameter DW         = 12,
    parameter DANGER_MM  = 350,
    parameter WARNING_MM = 500,
    parameter CAUTION_MM = 800
)(
    input  wire [N*DW-1:0] dist_flat,
    input  wire [N-1:0]    valid_flat,
    output reg  [1:0]      worst_zone,
    output reg             out_valid
);


    wire [1:0] zone_arr  [0:N-1];
    wire       zvalid_arr[0:N-1];

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : GEN_ZC
            zone_classifier #(
                .DANGER_MM(DANGER_MM),
                .WARNING_MM(WARNING_MM),
                .CAUTION_MM(CAUTION_MM),
                .DW(DW)
            ) u_zc (
                .dist          (dist_flat[g*DW +: DW]),
                .valid_in      (valid_flat[g]),
                .zone          (zone_arr[g]),
                .zone_valid_out(zvalid_arr[g])
            );
        end
    endgenerate


    integer i;
    reg [1:0] max_zone;
    reg       any_valid;

    always @(*) begin
        max_zone  = 2'd0;
        any_valid = 1'b0;

        for (i = 0; i < N; i = i + 1) begin
            if (zvalid_arr[i])
            begin
                any_valid = 1'b1;
                if (zone_arr[i] > max_zone)
                    max_zone = zone_arr[i];
            end
        end
        worst_zone = max_zone;
        out_valid  = any_valid;
    end

endmodule
