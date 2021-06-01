module UART (
	input wire i_Clock,
	input wire i_Reset,

	input wire i_Start,
	input wire [7:0] i_Data,
	output reg o_TX,

	input wire i_RX,
	output reg o_Received,
	output reg [7:0] o_Data,
	output reg busy,
	output reg sample_point,
	output wire uart_sending
);

localparam clock_speed = 80000000;
localparam uart_divider = clock_speed / 115200;
localparam first_sample = 1.5 * uart_divider;

// divide clock to 11520 baud (100MHz / 11520 = 8,680.55)
reg [15:0] clockDivider;
reg uartClock;

always @(posedge i_Clock or posedge i_Reset) begin
	if (i_Reset) begin
		clockDivider <= 16'd0;
		uartClock <= 1'b0;
	end
	else begin
		if (clockDivider == uart_divider) begin
			uartClock <= 1'b1;
			clockDivider <= 16'd0;
		end
		else begin
			clockDivider <= clockDivider + 1'b1;
			uartClock <= 1'b0;
		end
	end
end


// UART vars
reg start;
//reg busy;
reg [3:0] bitCounter_tx;
reg [7:0] sendData;


// Clock start command
always @(posedge i_Start or posedge busy) begin
	start <= i_Start;
end
assign uart_sending = start;


// UART TX state machine
reg [1:0] SM_uart_tx;
localparam sm_waiting_tx = 2'b00;
localparam sm_data_tx    = 2'b01;
localparam sm_stopbit_tx = 2'b10;


always @(posedge uartClock or posedge i_Reset) begin
	if (i_Reset) begin
		o_TX <= 1'b1;
		busy <= 1'b0;
		SM_uart_tx <= sm_waiting_tx;
	end
	else begin
		case (SM_uart_tx)
			sm_waiting_tx:
				begin
					if (start) begin
						sendData <= i_Data;		// Store send data in register
						o_TX <= 1'b0;				// Send start bit
						bitCounter_tx <= 4'd0;
						busy <= 1'b1;
						SM_uart_tx <= sm_data_tx;
					end
					else begin
						o_TX <= 1'b1;
						busy <= 1'b0;
					end
				end

			sm_data_tx:
				begin
					o_TX <= sendData[bitCounter_tx];
					bitCounter_tx <= bitCounter_tx + 1'b1;
					if (bitCounter_tx == 3'd7)
						SM_uart_tx <= sm_stopbit_tx;
				end

			sm_stopbit_tx:
				begin
					o_TX <= 1'b1;
					busy <= 1'b0;
					SM_uart_tx <= sm_waiting_tx;
				end
		endcase
	end
end



// UART Receive state machine
//reg sample_point;
reg [1:0] SM_uart_rx;
localparam sm_waiting_rx = 2'b00;
localparam sm_data_rx    = 2'b01;

reg [3:0] bitCounter_rx;
reg [15:0] clock_count_rx;


always @(posedge i_Clock or posedge i_Reset) begin
	if (i_Reset) begin
		SM_uart_rx <= sm_waiting_rx;
		sample_point <= 1'b0;
		o_Received <= 1'b0;
		o_Data <= 8'd0;
	end
	else
		case (SM_uart_rx)
			sm_waiting_rx:
				if (i_RX == 1'b0) begin
					bitCounter_rx <= 4'd0;
					o_Received <= 1'b0;
					clock_count_rx <= first_sample;		// First sample point is 1.5 * (100MHz / 11520) ie one uart period (start bit) plus a half period (for the sample point)
					o_Data <= 8'd0;
					sample_point <= 1'b0;
					SM_uart_rx <= sm_data_rx;
				end

			sm_data_rx:
				if (clock_count_rx == 16'd0) begin
					bitCounter_rx <= bitCounter_rx + 1'b1;
					clock_count_rx <= uart_divider;		// Set counter to next sample point
					sample_point <= ~sample_point;
					
					// 9th bit should be = 1 (stop bit)
					if (bitCounter_rx == 4'd8) begin
						o_Received <= (i_RX == 1'b1);
						SM_uart_rx <= sm_waiting_rx;
					end
					else begin
						o_Data[bitCounter_rx] <= i_RX;
					end
				end
				else begin
					clock_count_rx <= clock_count_rx - 1'b1;
				end
		
		endcase

end


endmodule


	