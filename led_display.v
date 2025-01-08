`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    00:52:25 01/07/2025 
// Design Name: 
// Module Name:    led_display 
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
module led_display(
    input clk,
	input reset,
	input blinker,
    input PRBS_error,
    output reg led
    );
	reg error1, error2;
	
	always@(posedge clk or posedge reset) begin
		if (reset) begin
			led <= 1'b0;
			error1 <= 1'b0;
			error2 <= 1'b0;
			end
		else begin
			if (PRBS_error == 1'b1)
				if (error1 == 1'b0) begin //first error
					error2 <= 1'b0;
					error1 <= 1'b1;
					end
				else if (error1 == 1'b1) begin
					error1 <= 1'b1;
					error2 <= 1'b1;
					end
				else begin
					error1 <= 1'b0;
					error2 <= 1'b0;
			end
			
			if(error1 == 1'b1 && error2 == 1'b0)
				led <= 1'b1;
			else
				led <= 1'b0;
				
			if(error1 == 1'b1 && error2 == 1'b1)
				led <= blinker;
			else
				led <= 1'b0;
		end
		


	end


endmodule
