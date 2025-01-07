`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:19:36 10/25/2024 
// Design Name: 
// Module Name:    strobe_converter_tb 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module strobe_converter_tb(
    );
	 reg clk;
	 reg in;
	 wire out;
strobe_converter dut(clk,in,out);
initial begin
	clk<=0;
	in<=0;
		forever begin
	#5 clk <=~clk;
end

end
initial begin 
	#10 in<=1;
	#20 in<=0;
end



endmodule
