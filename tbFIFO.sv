`timescale 1ns/1ps

module tbFIFO ();

    localparam DEPTH = 8;
    localparam  DWIDTH = 16;
    localparam CLKPERIOD = 10;

    logic clk, reset, wrEn, rdEn;
    logic [DWIDTH-1:0] dataIn;
    logic [DWIDTH-1:0] dataOut;
    logic empty, full;

    logic [DWIDTH-1:0] refModel[$];

    FIFO #(
        .DEPTH (DEPTH),
        .DWIDTH (DWIDTH)
    ) dut (
        .clk (clk),
        .reset (reset),
        .wrEn (wrEn),
        .rdEn (rdEn),
        .dataIn (dataIn),
        .dataOut (dataOut),
        .empty (empty),
        .full (full)
    );

    initial begin
       clk = 0;
        forever #(CLKPERIOD/2) clk = ~clk;
    end

    initial begin
        reset = 0;
        wrEn = 0;
        rdEn = 0;
        #50 reset = 1;
    #100 reset = 0;
    end

    task automatic doWrite(input logic [DWIDTH-1:0] value);
        dataIn = value;
        wrEn = 1;
        @(posedge clk );
        #1
        if (!full) refModel.push_back(value);
        wrEn = 0;
    endtask

    task automatic doRead();
        logic [DWIDTH-1:0] expected;
        rdEn = 1;
        @(posedge clk);
        #1
        if (!empty) begin
            expected = refModel.pop_front();
            if (dataOut !== expected)
                $display("ERROR: esperaba %0h, DUT dio %0h", expected, dataOut);
        end
        rdEn = 0;
    endtask

    initial begin
        @(negedge reset);
        @(posedge clk);

        for (int i = 0; i < DEPTH; i++) begin
            doWrite(i);
        end
        #1
        if (!full) $display("ERROR: se esperaba full despues de llenar el FIFO");

        for (int i = 0; i < DEPTH; i++) begin
            doRead();
        end
        #1
        if (!empty) $display("ERROR: se esperaba empty despues de vaciar el FIFO");

        $display("Test terminado");
        $finish;
    end

endmodule