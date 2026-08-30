// =====================================================================
//  risk_reducer.v  —  64존 거리맵 -> 가장 위험한 구역 1개
// =====================================================================
//
//  역할:
//    - 64개 존의 거리값을 받아 zone_classifier 64개로 병렬 분류
//    - 그 중 "가장 위험한(구역 번호가 가장 큰)" 구역을 선택
//    - 유효한 존이 하나도 없으면 out_valid=0 (안전측 -> 상위서 정지)
//
//  입력 포맷:
//    dist_flat : 64개 거리값을 하나의 벡터로 flatten (존 i = dist_flat[i*DW +: DW])
//    valid_flat: 64개 유효비트
//    (PS가 AXI로 써준 값을 top에서 이 형태로 묶어 전달)
//
//  출력:
//    worst_zone : 0..3 (가장 위험)
//    out_valid  : 1=유효한 존이 하나 이상 존재
//
//  구현:
//    - 병렬 분류 후, 유효한 존의 zone 만 대상으로 최댓값(=최고위험)을 구함.
//    - 최댓값 리덕션은 for 루프(합성 시 비교 트리로 펼쳐짐).
//    - 완전 조합 논리. 필요 시 top에서 1단 레지스터로 파이프라인 가능.
// =====================================================================

////////////////////////////////////////////////////////////////////////
///////////////////////////                 ////////////////////////////
///////////////////////////  모듈 검증 완료   ////////////////////////////
///////////////////////////                 ////////////////////////////
////////////////////////////////////////////////////////////////////////

module risk_reducer #(
    parameter N          = 64, // 8x8 array 
    parameter DW         = 12, // Data_width, 거리 데이터 1개 = 12bit(0 ~ 4095mm까지 표현 가능 ==> 4.095meter 까지 표현 가능)
    parameter DANGER_MM  = 150, // least distance 
    parameter WARNING_MM = 500,
    parameter CAUTION_MM = 800
)(
    input  wire [N*DW-1:0] dist_flat, // |Zone63|Zone62|...|Zone1|Zone0|
    input  wire [N-1:0]    valid_flat, // valid_flat[0] => Zone0가 유효한가?  ...  valid_flat[63] => Zone63가 유효한가?
    output reg  [1:0]      worst_zone,
    output reg             out_valid // 유효한 데이터가 1개라도 있었다면 1 , 64개 전부 invalid 라면 0 
);

    // ----- 각 존 분류 결과 -----
    wire [1:0] zone_arr  [0:N-1]; // zone_arr[0] => SAFE , zone_arr[20] => warning, zone_arr[23] => dangaer 처럼 픽셀별로 상태 저장 
    wire       zvalid_arr[0:N-1]; // 픽셀별로 유효한지 저장 

    genvar g; 
    generate // zone_classifier를 64개 생성
        for (g = 0; g < N; g = g + 1) begin : GEN_ZC 
            zone_classifier #( 
                .DANGER_MM(DANGER_MM),
                .WARNING_MM(WARNING_MM),
                .CAUTION_MM(CAUTION_MM),
                .DW(DW)
            ) u_zc ( // instance 이름 
                .dist          (dist_flat[g*DW +: DW]),
                .valid_in      (valid_flat[g]),
                .zone          (zone_arr[g]),
                .zone_valid_out(zvalid_arr[g])
            );
        end
    endgenerate

    // 최고위험(최댓값) 지역 판정
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



