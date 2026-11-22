`timescale 1ns/1ps
module tb_apb_sram;
parameter ADDR_WIDTH = 8;
parameter DATA_WIDTH = 32;

reg                   PCLK;
reg                   PRESETn;
reg                   PSEL;
reg                   PENABLE;
reg                   PWRITE;
reg  [ADDR_WIDTH-1:0] PADDR;
reg  [DATA_WIDTH-1:0] PWDATA;
wire [DATA_WIDTH-1:0] PRDATA,  PRDATA_s;
wire                  PREADY,  PREADY_s;
wire                  PSLVERR, PSLVERR_s;
reg                   use_small;

apb_sram #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut (
    .PCLK(PCLK), .PRESETn(PRESETn), .PSEL(PSEL & ~use_small),
    .PENABLE(PENABLE), .PWRITE(PWRITE), .PADDR(PADDR),
    .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR)
);
apb_sram #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .MEM_DEPTH(200)) dut_small (
    .PCLK(PCLK), .PRESETn(PRESETn), .PSEL(PSEL & use_small),
    .PENABLE(PENABLE), .PWRITE(PWRITE), .PADDR(PADDR),
    .PWDATA(PWDATA), .PRDATA(PRDATA_s), .PREADY(PREADY_s), .PSLVERR(PSLVERR_s)
);

wire                  bus_ready  = use_small ? PREADY_s  : PREADY;
wire [DATA_WIDTH-1:0] bus_rdata  = use_small ? PRDATA_s  : PRDATA;
wire                  bus_slverr = use_small ? PSLVERR_s : PSLVERR;

initial begin
    PCLK = 0;
    forever #5 PCLK = ~PCLK;
end

integer errors;
integer i, n;
integer seed;
reg [DATA_WIDTH-1:0] model [0:(1<<ADDR_WIDTH)-1];
reg [DATA_WIDTH-1:0] rd_val;
reg                  rd_err;
reg [ADDR_WIDTH-1:0] a;
reg [DATA_WIDTH-1:0] d;

task apb_xfer;
    input                  wr;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    begin
        PSEL    <= 1'b1;
        PWRITE  <= wr;
        PADDR   <= addr;
        PWDATA  <= data;
        PENABLE <= 1'b0;
        @(posedge PCLK);
        PENABLE <= 1'b1;
        @(posedge PCLK);
        while (!bus_ready) @(posedge PCLK);
        rd_val = bus_rdata;
        rd_err = bus_slverr;
        PSEL    <= 1'b0;
        PENABLE <= 1'b0;
    end
endtask

task apb_write;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    begin
        apb_xfer(1'b1, addr, data);
        if (rd_err !== 1'b0) begin
            errors = errors + 1;
            $display("ERROR @%0t write %h: unexpected PSLVERR", $time, addr);
        end
        model[addr] = data;
    end
endtask

task apb_read_check;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] expected;
    begin
        apb_xfer(1'b0, addr, {DATA_WIDTH{1'b0}});
        if (rd_val !== expected || rd_err !== 1'b0) begin
            errors = errors + 1;
            $display("ERROR @%0t read %h: got %h (PSLVERR=%b), expected %h", $time, addr, rd_val, rd_err, expected);
        end
    end
endtask

initial begin
    #1_000_000;
    $display("STATUS: SIMULATION FAIL (timeout)");
    $finish;
end

initial begin
    $dumpfile("apb_sram.vcd");
    $dumpvars(0, tb_apb_sram);
    errors = 0; seed = 7; use_small = 0;
    PRESETn = 0; PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = 0; PWDATA = 0;
    repeat (2) @(posedge PCLK);
    PRESETn <= 1'b1;
    @(posedge PCLK);

    apb_write(8'hA1, 32'h11223344);
    apb_write(8'hA2, 32'h55667788);
    @(posedge PCLK);
    apb_read_check(8'hA1, 32'h11223344);
    apb_read_check(8'hA2, 32'h55667788);

    for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1)
        apb_write(i, {i[7:0], ~i[7:0], i[7:0] ^ 8'h5A, 8'hC3});
    for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1)
        apb_read_check(i, model[i]);

    for (n = 0; n < 500; n = n + 1) begin
        a = $random(seed);
        d = $random(seed);
        if ($random(seed) % 2) apb_write(a, d);
        else                   apb_read_check(a, model[a]);
        if ($random(seed) % 4 == 0) @(posedge PCLK);
    end

    use_small = 1;
    @(posedge PCLK);
    apb_xfer(1'b1, 8'd10, 32'hCAFE_0010);
    if (rd_err !== 1'b0) begin errors = errors + 1; $display("ERROR: PSLVERR on a valid write"); end
    apb_xfer(1'b1, 8'd250, 32'hBAD0_0250);
    if (rd_err !== 1'b1) begin errors = errors + 1; $display("ERROR: no PSLVERR on write to 250"); end
    apb_xfer(1'b0, 8'd250, 32'd0);
    if (rd_err !== 1'b1 || rd_val !== 32'd0) begin errors = errors + 1; $display("ERROR: bad PSLVERR read of 250"); end
    apb_xfer(1'b0, 8'd10, 32'd0);
    if (rd_err !== 1'b0 || rd_val !== 32'hCAFE_0010) begin errors = errors + 1; $display("ERROR: read-back of 10 failed (%h)", rd_val); end
    use_small = 0;

    repeat (3) @(posedge PCLK);
    if (errors == 0)
        $display("\n===================================\nSTATUS: SIMULATION PASS\n===================================\n");
    else
        $display("\n===================================\nSTATUS: SIMULATION FAIL (%0d ERRORS)\n===================================\n", errors);
    $finish;
end
endmodule
