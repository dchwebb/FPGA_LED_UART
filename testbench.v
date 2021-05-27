`timescale 1ns / 1ns

module testbench;
	
	wire led;
	wire led_clk;
	reg reset;
	reg start;
	reg clk = 1'b0;
	
	WS2812 ws2812 (
		.i_Reset(reset),
		.i_Clock(clk),
		.i_Start(start),
		.o_Led(led),
		.o_Clock(led_clk)
	);
	
	always
		#2 clk = ~clk;
		

	initial begin
		reset = 1'b1;
		start = 1'b0;
		#10
		reset = 1'b0;
		#10
		start = 1'b1;
	end
	
endmodule