module apb_sram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH  = (1 << ADDR_WIDTH)
)(
    input                       PCLK,
    input                       PRESETn,
    input                       PSEL,
    input                       PENABLE,
    input                       PWRITE,
    input      [ADDR_WIDTH-1:0] PADDR,
    input      [DATA_WIDTH-1:0] PWDATA,
    output reg [DATA_WIDTH-1:0] PRDATA,
    output reg                  PREADY,
    output reg                  PSLVERR
);

localparam IDLE   = 2'b00;
localparam SETUP  = 2'b01;
localparam ACCESS = 2'b10;

reg [1:0] state, next_state;
reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

wire addr_err = (PADDR >= MEM_DEPTH);

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) state <= IDLE;
    else          state <= next_state;
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE:    if (PSEL && !PENABLE)            next_state = SETUP;
        SETUP:   if (PSEL && PENABLE)             next_state = ACCESS;
                 else                             next_state = IDLE;
        ACCESS:  if (PREADY)                      next_state = IDLE;
        default:                                  next_state = IDLE;
    endcase
end

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        PREADY  <= 1'b0;
        PSLVERR <= 1'b0;
        PRDATA  <= {DATA_WIDTH{1'b0}};
    end else begin
        if (state == SETUP && PSEL && PENABLE) begin
            PREADY  <= 1'b1;
            PSLVERR <= addr_err;
            if (!PWRITE)
                PRDATA <= addr_err ? {DATA_WIDTH{1'b0}} : mem[PADDR];
        end else if (state == ACCESS && PREADY) begin
            PREADY  <= 1'b0;
            PSLVERR <= 1'b0;
            if (PWRITE && !addr_err)
                mem[PADDR] <= PWDATA;
        end else begin
            PREADY  <= 1'b0;
            PSLVERR <= 1'b0;
        end
    end
end

endmodule
