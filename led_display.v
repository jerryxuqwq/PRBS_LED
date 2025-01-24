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
    output reg led,
	 output wire [0:1]out1,
	 output wire [0:1]out0
    );
	reg rst0,rst1,error1,error2;
	
	counter_noover error_count0(
    .clk(clk),            // Clock signal
	 .enable(PRBS_error),         // Enable signal
    .rst(rst0),          // Active-high Reset signal
    .out(out0)    // 2-bit output counter
	 );
	 	counter_noover error_count1(
    .clk(clk),            // Clock signal
	 .enable(PRBS_error),         // Enable signal
    .rst(rst1),          // Active-high Reset signal
    .out(out1)    // 2-bit output counter
	 );
	always@(posedge clk or posedge reset) begin
		if (reset) begin
			rst0<= 1'b1;
			rst1<= 1'b1;
			led <= 1'b0;
			error1 <= 1'b0;
			error2 <= 1'b0;
			end
		else begin
			
			if (out0 == 2'b11 && out1 < 2'b11) begin
				error1 <= 1'b1;
				error2 <= 1'b0;
				rst1<= 1'b0;
				led <= 1'b1;
			end
			
			else if(out0 == 2'b11 && out1 == 2'b11) begin
				led <= blinker;
				rst0<= 1'b0;
				rst1<= 1'b0;
			end
			
			else begin
				rst0<= 1'b0;
				rst1<= 1'b1;
				led <= 1'b0;
			end
		
		end
		
	end


endmodule
