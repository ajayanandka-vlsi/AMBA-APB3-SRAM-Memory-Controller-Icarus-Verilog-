// Code your testbench here
// or browse Examples
`timescale 1ns/1ps
module tb_apb_sram;
parameter ADDR_WIDTH = 8;
parameter DATA_WIDTH = 32;

reg PCLK;
reg PRESETn;
reg PSEL;
reg PENABLE;
reg PWRITE;
reg [ADDR_WIDTH-1:0] PADDR;
reg [DATA_WIDTH-1:0] PWDATA;
wire [DATA_WIDTH-1:0] PRDATA;
wire PREADY;
wire PSLVERR;

apb_sram #(ADDR_WIDTH, DATA_WIDTH) dut (
    .PCLK(PCLK), .PRESETn(PRESETn), .PSEL(PSEL),
    .PENABLE(PENABLE), .PWRITE(PWRITE), .PADDR(PADDR),
    .PWDATA(PWDATA), .PRDATA(PRDATA),
    .PREADY(PREADY), .PSLVERR(PSLVERR)
);

initial begin
    PCLK = 0;
    forever #5 PCLK = ~PCLK;
end

task apb_write;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    begin
        @(posedge PCLK);
        PSEL = 1;
        PWRITE = 1;
        PADDR = addr;
        PWDATA = data;
        PENABLE = 0;
        @(posedge PCLK);
        PENABLE = 1;
        wait(PREADY);
        @(posedge PCLK);
        PSEL = 0;
        PENABLE = 0;
    end
endtask

task apb_read;
    input [ADDR_WIDTH-1:0] addr;
    begin
        @(posedge PCLK);
        PSEL = 1;
        PWRITE = 0;
        PADDR = addr;
        PENABLE = 0;
        @(posedge PCLK);
        PENABLE = 1;
        wait(PREADY);
        @(posedge PCLK);
        PSEL = 0;
        PENABLE = 0;
    end
endtask

initial begin
    $dumpfile("apb_sram.vcd");
    $dumpvars(0, tb_apb_sram);
    PRESETn = 0; PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = 0; PWDATA = 0;
    #20;
    PRESETn = 1;
    #10;
    apb_write(8'hA1, 32'h11223344);
    apb_write(8'hA2, 32'h55667788);
    #10;
    apb_read(8'hA1);
    apb_read(8'hA2);
    #30;
    $finish;
end
endmodule