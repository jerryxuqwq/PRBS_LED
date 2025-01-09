`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    23:48:14 01/08/2025 
// Design Name: 
// Module Name:    debouncer 
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
module debouncer #(

	parameter	DIV_CNT	= 18

) (
	input	clk,
	input	btn,

	output	out
);
	
	wire	trig;
	reg	[DIV_CNT:0] clk_div;
	reg	hold;


	initial hold = 1'b0;
	initial clk_div = 0;


	assign	out	= hold;
	assign	trig	= clk_div[DIV_CNT];

	
	always @ (posedge clk) begin
		if (btn) begin
			hold <= 1'b1;
		end else if (trig) begin
			hold <= 1'b0;
			clk_div <= 0;
		end else if (hold) begin
			clk_div <= clk_div + 1'b1;
		end
	end


endmodule
