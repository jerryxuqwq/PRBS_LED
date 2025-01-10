`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:18:30 10/25/2024 
// Design Name: 
// Module Name:    strobe_converter 
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
module strobe_converter(
	 input wire clk,
	 input wire in,
	 output wire out
    );
	reg delay;
	always@(posedge clk)
	begin
		delay <= in;
	end
	assign out= in & ~delay;
	 
endmodule
