
module watchdog #(
    parameter TIMEOUT = 100000000,
    parameter CW      = 32
)(
    input  wire clk,
    input  wire rst_n,
    input  wire kick,
    output reg  wdt_trip
);
    reg        kick_d;
    wire       kicked = (kick != kick_d);

    reg [CW-1:0] counter;

    always @(posedge clk) begin
        if (!rst_n) begin
            counter  <= {CW{1'b0}};
            kick_d   <= 1'b0;
            wdt_trip <= 1'b0;
        end else begin
            kick_d <= kick;

            if (kicked) begin

                counter  <= {CW{1'b0}};
                wdt_trip <= 1'b0;
            end else if (counter >= TIMEOUT-1) begin

                counter  <= counter;
                wdt_trip <= 1'b1;
            end else begin
                counter  <= counter + 1'b1;
            end
        end
    end
endmodule
