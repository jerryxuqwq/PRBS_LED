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
	 output reg out
    );
	reg reset;
	reg in_prev;
	always@(posedge clk)
	begin
		in_prev <= in;
		if(in_prev ==0  & in ==1 ) begin//posedge
		out <=1;
		end
		else if(in_prev == 1 & in ==0 ) begin//negedge
		out <=0;
		end
		else begin
		out <=0;
		end
		
	end
	
	 


endmodule
