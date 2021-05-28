`timescale 1ns / 1ns

module testbench;
	
	wire uart;
	reg reset;
	reg start;
	reg clk = 1'b0;
	reg [7:0] data;
	
// UART
UART uart_module (
	.i_Clock(clk),
	.i_Reset(reset),
	.i_Start(start),
	.i_Data(data),
	.o_UART(uart)
);
	
	always
		#2 clk = ~clk;
		

	initial begin
		reset = 1'b1;
		start = 1'b0;
		#10
		reset = 1'b0;
		data = 8'h55;
		#10
		start = 1'b1;
		#10000
		start = 1'b0;
		#600000
		start = 1'b1;
		#10
		start = 1'b0;
	end
	
endmodule