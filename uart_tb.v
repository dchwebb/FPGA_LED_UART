`timescale 1ns / 1ns

module testbench;
reg Clock = 1'b0;
reg Reset;

wire uart_tx;
reg uart_rx;
wire uart_received;
wire uart_sample_point;
wire uart_busy;
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
	.o_Busy_TX(uart_busy),
	
	.i_RX(uart_rx),
	.o_Received(uart_received),
	.sample_point(uart_sample_point),
	
	.i_Read_FIFO(uart_read),
	.o_Data(uart_fifo_data),
	.o_Data_Ready(uart_fifo_ready)
	
);



// UART loopback state machine - sends out data when fifo is not empty
reg [1:0] SM_uart;
localparam sm_waiting = 2'b00;
localparam sm_wait    = 2'b01;
localparam sm_store   = 2'b10;
localparam sm_send    = 2'b11;


always @(posedge Clock or posedge Reset) begin
	if (Reset) begin
		uart_read <= 1'b0;
		uart_send <= 1'b0;
		SM_uart <= sm_waiting;
	end
	else begin
		case (SM_uart)
			sm_waiting:
				begin
					if (uart_received && ~uart_busy) begin
						uart_read <= 1'b1;
						SM_uart <= sm_wait;
					end
					else begin
						uart_send <= 1'b0;
					end
				end

			sm_wait:
				begin
					uart_read <= 1'b0;
					
					if (uart_fifo_ready)
						SM_uart <= sm_send;
				end

			sm_send:
				begin
					uart_tx_data <= uart_fifo_data;
					uart_send <= 1'b1;
					SM_uart <= sm_waiting;
				end
				
		endcase
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