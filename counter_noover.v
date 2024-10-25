`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:00:19 10/20/2024 
// Design Name: 
// Module Name:    counter_noover 
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

module counter_noover (
    input clk,            // Clock signal
	 input enable,         // Enable signal
    input rst,          // Active-high Reset signal
    output reg [1:0] out    // 2-bit output counter
);

    // Always block triggered on clock edge or reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out <= 2'b00;  
        end
        else if (enable) begin
            if (out == 2'b11)
                out <= 2'b11 ;
				else
					out <= out + 2'b01;  // Increment the counter when enabled, but limit to 2'b11
        end
    end

endmodule