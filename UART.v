module UART (
	input wire i_Clock,
	input wire i_Reset,
	input wire i_Start,
	input wire [7:0] i_Data,
	output wire o_UART
);

// divide clock to 11520 baud (100MHz / 11520 = 8,680.55)
reg [15:0] clockDivider;
reg uartClock;

always @(posedge i_Clock or posedge i_Reset) begin
	if (i_Reset) begin
		clockDivider <= 16'd0;
		uartClock <= 1'b0;
	end
	else begin
		if (clockDivider == 16'd8680) begin
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
reg busy;
reg [3:0] bitCounter;
reg [7:0] sendData;
reg parity;
reg uart_val;
assign o_UART = uart_val;

// UART state machine
reg [1:0] SM_uart;
localparam sm_waiting = 2'b00;
localparam sm_data    = 2'b01;
localparam sm_parity  = 2'b10;
localparam sm_stopbit = 2'b11;


always @(posedge uartClock or posedge i_Reset) begin
	if (i_Reset) begin
		uart_val <= 1'b1;
		busy <= 1'b0;
		SM_uart <= sm_waiting;
	end
	else begin
		case (SM_uart)
			sm_waiting:
				begin
					if (start) begin
						sendData <= i_Data;		// Store send data in register
						uart_val <= 1'b0;			// Send start bit
						bitCounter <= 1'b0;
						parity <= 1'b0;
						busy <= 1'b1;
						SM_uart <= sm_data;
					end
					else begin
						uart_val <= 1'b1;
						busy <= 1'b0;
					end
				end

			sm_data:
				begin
					uart_val <= sendData[bitCounter];
					parity <= parity ^ sendData[bitCounter];
					bitCounter <= bitCounter + 1'b1;
					if (bitCounter == 3'd7)
						SM_uart <= sm_parity;
				end

			sm_parity:
				begin
					uart_val <= parity;
					SM_uart <= sm_stopbit;
				end
				
			sm_stopbit:
				begin
					uart_val <= 1'b1;
					SM_uart <= sm_waiting;
				end
		endcase
	end
end


// Clock start command
always @(posedge i_Start or posedge busy) begin
	if (busy)
		start <= 1'b0;
	else
		start <= i_Start;
end


endmodule


	