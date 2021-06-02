`timescale 1ns / 1ns

module testbench;
reg Clock = 1'b0;
reg Reset;

wire uart_tx;
reg uart_rx;
wire uart_received;
wire uart_sample_point;
wire uart_send_busy;
wire uart_fifo_ready;
reg uart_send;
reg uart_read;
reg [7:0] uart_tx_data;
wire [7:0] uart_fifo_data;


GSR GSR_INST (.GSR(1'b1));
PUR PUR_INST (.PUR(1'b1));

// UART
UART uart_module (
	.i_Clock(Clock),
	.i_Reset(Reset),
	
	.i_Start(uart_send),
	.i_Data(uart_tx_data),
	.o_TX(uart_tx),
	.o_Busy_TX(uart_send_busy),
	
	.i_RX(uart_rx),
	.sample_point(uart_sample_point),
	
	.i_Read_Data(uart_read),
	.o_Data(uart_fifo_data),
	.o_Data_Ready(uart_fifo_ready)
	
);



// UART loopback - sends out data when fifo is not empty
always @(posedge Clock or posedge Reset) begin
	if (Reset) begin
		uart_read <= 1'b0;
		uart_send <= 1'b0;
	end
	else begin
		
		if (uart_fifo_ready && ~uart_send_busy) begin
			uart_read <= 1'b1;
			uart_tx_data <= uart_fifo_data;
			uart_send <= 1'b1;
		end
		else begin
			uart_read <= 1'b0;
			uart_send <= 1'b0;
		end
	end
end



always begin
	#6 Clock = ~Clock;
	#6 Clock = ~Clock;
	#6 Clock = ~Clock;
	#7 Clock = ~Clock;
end
	
// 8600 is one uart clock cycle
initial begin
	Reset = 1'b1;
	uart_rx = 1'b1;
	#10
	Reset = 1'b0;
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