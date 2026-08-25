
module pwm_gen #(
    parameter CLK_HZ     = 100000000,
    parameter PWM_HZ     = 25000,
    parameter CW         = 16
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  fan_level,
    output reg         pwm_out
);
    localparam [CW-1:0] PERIOD = CLK_HZ / PWM_HZ;


    reg [CW-1:0] thresh;
    always @(*) begin
        case (fan_level)
            2'd3: thresh = PERIOD;
            2'd2: thresh = (PERIOD * 80) / 100;
            2'd1: thresh = (PERIOD * 50) / 100;
            default: thresh = {CW{1'b0}};
        endcase
    end

    reg [CW-1:0] counter;
    always @(posedge clk) begin
        if (!rst_n) begin
            counter <= {CW{1'b0}};
            pwm_out <= 1'b0;
        end else begin

            if (counter >= PERIOD - 1)
                counter <= {CW{1'b0}};
            else
                counter <= counter + 1'b1;



            pwm_out <= (counter < thresh);
        end
    end
endmodule
