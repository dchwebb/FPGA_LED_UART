`timescale 1ns / 1ns

module testbench;
reg Clock = 1'b0;
reg reset;
reg uart_send;

wire uart_tx;
reg uart_rx;
wire uart_received;
wire uart_sample_point;
wire uart_busy;
reg [7:0] uart_rx_data;
wire [7:0] uart_data_in;

//assign uart_in = uart_out;

// UART
always @(posedge Clock or posedge uart_received) begin
	if (uart_received) begin
		uart_rx_data <= uart_data_in;
		uart_send <= 1'b1;
	end
	else
		uart_send <= 1'b0;
		
end

UART uart_module (
	.i_Clock(Clock),
	.i_Reset(reset),
	.i_Start(uart_send),
	.i_Data(uart_rx_data),
	.o_TX(uart_tx),
	.i_RX(uart_rx),
	.o_Received(uart_received),
	.o_Data(uart_data_in),
	.busy(uart_busy),
	.sample_point(uart_sample_point)
);




always begin
	#6 Clock = ~Clock;
	#6 Clock = ~Clock;
	#6 Clock = ~Clock;
	#7 Clock = ~Clock;
end
	
// 8600 is one uart clock cycle
initial begin
	reset = 1'b1;
	uart_rx = 1'b1;
	#10
	reset = 1'b0;
	#1000

	// 0x61
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;
	#8600


	// 0x62
	uart_rx = 1'b0;		// start bit
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;		// end bit
	#8600

	// 0x0A
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;


end

endmodule