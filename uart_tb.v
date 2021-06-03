`timescale 1ns / 1ns

module testbench;

localparam CLOCK_FREQUENCY = 80000000;
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
wire [7:0] uart_rx_data;
reg led1_r_on;
reg [7:0] led1_r;
reg rgb_debug;

GSR GSR_INST (.GSR(1'b1));
PUR PUR_INST (.PUR(1'b1));

// UART
UART #(.CLOCK_FREQUENCY(CLOCK_FREQUENCY)) uart_module (
	.i_Clock(Clock),
	.i_Reset(Reset),
	
	.i_Start(uart_send),
	.i_Data(uart_tx_data),
	.o_TX(uart_tx),
	.o_Busy_TX(uart_send_busy),
	
	.i_RX(uart_rx),
	.sample_point(uart_sample_point),
	
	.i_Read_Data(uart_read),
	.o_Data(uart_rx_data),
	.o_Data_Ready(uart_fifo_ready)
	
);


/*
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
*/

// UART state machine for led control (eg 'r1\n' to toggle led 1 red)
reg [2:0] SM_rgb_control;
localparam sm_rgb_waiting = 3'b000;
localparam sm_rgb_pause1  = 3'b001;
localparam sm_rgb_led_no  = 3'b010;
localparam sm_rgb_pause2  = 3'b011;
localparam sm_rgb_send    = 3'b100;


localparam red   = 2'b00;
localparam green = 2'b01;
localparam blue  = 2'b10;
reg [1:0] rgb_colour;
reg [1:0] rgb_number;

// UART loopback - sends out data when fifo is not empty
always @(posedge Clock or posedge Reset) begin
	if (Reset) begin
		SM_rgb_control <= sm_rgb_waiting;
		led1_r_on <= 1'b0;
		led1_r <= 8'h0;
		uart_read <= 1'b0;
		uart_send <= 1'b0;
		rgb_debug <= 1'b0;
		rgb_colour <= 2'd0;
		rgb_number <= 2'd0;
	end
	else begin
		case (SM_rgb_control)
			sm_rgb_waiting:
				begin
					//rgb_debug <= 1'b0;					
					uart_read <= 1'b0;
					uart_send <= 1'b0;
					if (uart_fifo_ready && ~uart_send_busy) begin
						uart_read <= 1'b1;
						uart_tx_data <= uart_rx_data;
						uart_send <= 1'b1;
						
						SM_rgb_control <= sm_rgb_pause1;
						case (uart_rx_data)
							8'h72:		rgb_colour <= red;
							8'h67:		rgb_colour <= green;
							8'h62:		rgb_colour <= blue;
							default:		SM_rgb_control <= sm_rgb_waiting;
						endcase
					end
				end
				
			sm_rgb_pause1:
				begin
					uart_read <= 1'b0;
					uart_send <= 1'b0;
					SM_rgb_control <= sm_rgb_led_no;
				end
				
			sm_rgb_led_no:
				begin
					rgb_debug <= 1'b1;

					if (uart_fifo_ready && ~uart_send_busy) begin
						uart_read <= 1'b1;
						uart_tx_data <= uart_rx_data;
						uart_send <= 1'b1;
						
						SM_rgb_control <= sm_rgb_pause2;
						case (uart_rx_data)
							8'h31:		rgb_number <= 2'd0;
							8'h32:		rgb_number <= 2'd1;
							8'h33:		rgb_number <= 2'd2;
							default:		SM_rgb_control <= sm_rgb_waiting;
						endcase
					end
				end
				
			sm_rgb_pause2:
				begin
					uart_read <= 1'b0;
					uart_send <= 1'b0;
					SM_rgb_control <= sm_rgb_send;
				end				
				
			sm_rgb_send:
				begin
					uart_read <= 1'b0;
					uart_send <= 1'b0;
					if (uart_fifo_ready && ~uart_send_busy) begin
						uart_read <= 1'b1;
						uart_tx_data <= uart_rx_data;
						uart_send <= 1'b1;
						
						if (uart_rx_data == 8'h0A) begin
							led1_r <= led1_r_on ? 8'h0 : 8'h11;
							led1_r_on <= ~led1_r_on;
						end
						SM_rgb_control <= sm_rgb_waiting;
						
					end
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
	

	// 0x72 'r'
	uart_rx = 1'b0;		// start bit
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;		// end bit
	#8600

	// 0x78 'x'
	uart_rx = 1'b0;		// start bit
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
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b1;
	#8600
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;		// end bit
	#8600


	// 0x31 '1'
	uart_rx = 1'b0;		// start bit
	#8600
	uart_rx = 1'b1;
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
	uart_rx = 1'b0;
	#8600
	uart_rx = 1'b1;		// end bit
	#8600

	// 0x0A '\n'
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