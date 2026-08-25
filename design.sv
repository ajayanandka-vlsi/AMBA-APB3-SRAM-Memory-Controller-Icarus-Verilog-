// Code your design here
module apb_sram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input PCLK,
    input PRESETn,
    input PSEL,
    input PENABLE,
    input PWRITE,
    input [ADDR_WIDTH-1:0] PADDR,
    input [DATA_WIDTH-1:0] PWDATA,
    output reg [DATA_WIDTH-1:0] PRDATA,
    output reg PREADY,
    output reg PSLVERR
);

localparam IDLE   = 2'b00;
localparam SETUP  = 2'b01;
localparam ACCESS = 2'b10;

reg [1:0] state, next_state;
reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) state <= IDLE;
    else          state <= next_state;
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (PSEL && !PENABLE) next_state = SETUP;
        end
        SETUP: begin
            if (PSEL && PENABLE) next_state = ACCESS;
            else next_state = IDLE;
        end
        ACCESS: begin
            if (PREADY) begin
                if (PSEL && !PENABLE) next_state = SETUP;
                else next_state = IDLE;
            end
        end
        default: next_state = IDLE;
    endcase
end

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        PREADY <= 1'b0;
        PSLVERR <= 1'b0;
        PRDATA <= {DATA_WIDTH{1'b0}};
    end else begin
        if (state == SETUP) begin
            PREADY <= 1'b1;
            PSLVERR <= 1'b0;
        end else if (state == ACCESS && PREADY) begin
            PREADY <= 1'b0;
            if (PWRITE) begin
                mem[PADDR] <= PWDATA;
            end else begin
                PRDATA <= mem[PADDR];
            end
        end else begin
            PREADY <= 1'b0;
        end
    end
end

endmodule