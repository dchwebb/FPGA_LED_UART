module UART (
	input wire i_Clock,
	input wire i_Reset,
	input wire i_Start,
	input wire [7:0] i_Data,
	output reg o_UART
);

// divide clock to 11520 baud (100MHz / 11520 = 8,680.55)
reg [15:0] clockDivider;
reg uartClock;

always @(posedge i_Clock or posedge i_Reset) begin
	if (i_Reset) begin
		clockDivider <= 16'd0;
		uartClock <= 1'b0;
	end
	else
		if (clockDivider == 8680) begin
			uartClock <= 1'b1;
			clockDivider <= 16'd0;
		end
		else begin
			clockDivider <= clockDivider + 1;
			uartClock <= 1'b0;
		end
	
end


// Clock start command
reg start;
always @(posedge i_Start or posedge i_Reset) begin
	if (i_Reset) begin
		start <= 1'b0;
	end
	else
		start <= i_Start;
end


// UART vars
reg [3:0] bitCounter;
reg [7:0] sendData;
reg parity;

// UART state machine
reg [2:0] SM_uart;
localparam sm_waiting = 3'b000;
localparam sm_data    = 3'b001;
localparam sm_parity  = 3'b010;

/*

localparam sm_waiting = 3'b000;
localparam sm_waiting = 3'b000;
localparam sm_waiting = 3'b000;
localparam sm_waiting = 3'b000;
*/


always @(posedge uartClock or posedge i_Reset) begin
	if (i_Reset) begin
		o_UART <= 1'b1;
		SM_uart <= sm_waiting;
	end
	else begin
		case (SM_uart)
			sm_waiting:
				begin
					if (start) begin
						sendData <= i_Data;		// Store send data in register
						o_UART <= 1'b0;			// Send start bit
						bitCounter <= 1'b0;
						parity <= 1'b0;
						SM_uart <= sm_data;
					end
					else
						o_UART <= 1'b1;
				end

			sm_data:
				begin
					o_UART <= sendData[bitCounter];
					parity <= parity ^ sendData[bitCounter];
					bitCounter <= bitCounter + 1;
					if (bitCounter == 3'd7)
						SM_uart <= sm_parity;
				end

			sm_parity:
			
		endcase
	end
end

endmodule


	