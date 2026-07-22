`timescale 1ns/1ps

module FIFO #(
    parameter DEPTH = 8,
    parameter DWIDTH = 16
) (
    input logic  clk, reset, wrEn, rdEn,
    input logic [DWIDTH-1:0] dataIn,
    output logic [DWIDTH-1:0] dataOut,
    output logic empty, full
);

logic [DWIDTH-1:0] mem[DEPTH];

logic [$clog2(DEPTH)-1:0] wptr, rptr;
logic [$clog2(DEPTH):0] count;

always_ff @( posedge clk ) begin : WriteMod
    if (reset) begin
        wptr <= 0;
    end else begin
        if (wrEn & !full) begin
            mem[wptr] <= dataIn;
            wptr <= wptr + 1;
        end
    end
end

always_ff @( posedge clk ) begin : ReadMod
    if (reset) begin
        rptr <= 0;
    end else begin
        if (rdEn & !empty) begin
            dataOut <= mem[rptr];
            rptr <= rptr + 1;
        end
    end
end

always_ff @( posedge clk ) begin : CountMod
    if (reset) begin
        count <= 0;
    end else begin
        case ({wrEn & !full, rdEn & !empty})
            2'b10: count <= count + 1;
            2'b01: count <=count - 1; 
            default: count <= count;
        endcase
    end
end
    
always_comb begin : FlagComb
    full = (count==DEPTH);
    empty = (count == 0);
end

endmodule