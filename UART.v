module UART (
	input wire i_Clock,
	input wire i_Reset,

	input wire i_Start,
	input wire [7:0] i_Data,
	output reg o_TX,

	input wire i_RX,
	input wire i_Read_FIFO,
	output wire o_Received,
	output reg [7:0] o_Data,
	output reg busy,
	output reg sample_point
);


// UART TX registers
reg start_tx;
reg [3:0] bitCounter_tx;
reg [7:0] data_tx;
reg [15:0] clock_count_tx;

// UART RX registers
reg [3:0] bitCounter_rx;
reg [7:0] data_rx;
reg [15:0] clock_count_rx;

// RX FIFO
reg fifo_write;
reg fifo_read;
wire fifo_empty;
wire [7:0] fifo_data_out;

assign o_Received = ~fifo_empty;

UART_FIFO fifo (
	.Data(data_rx),
	.WrClock(i_Clock),
	.RdClock(i_Clock),
	.WrEn(fifo_write),
	.RdEn(fifo_read),
	.Reset(Reset),
	.RPReset(Reset),
	.Q(fifo_data_out),
	.Empty(fifo_empty),
	.Full( ),
	.AlmostEmpty( ), 
	.AlmostFull( )
);


// TX Clock divider: divide clock to 115200 baud
reg [15:0] clockDivider;
reg uartClock;
localparam clock_speed = 80000000;
localparam [15:0] uart_divider = clock_speed / 115200;
localparam [15:0] first_sample = 1.5 * uart_divider;		// When receiving first sample point is 1.5 uart clocks after start bit



//----------------------------------------------------------------
// UART TX state machine
reg [1:0] SM_uart_tx;
localparam sm_waiting_tx = 2'b00;
localparam sm_data_tx    = 2'b01;
localparam sm_stopbit_tx = 2'b10;

always @(posedge i_Clock or posedge i_Reset) begin
	if (i_Reset) begin
		o_TX <= 1'b1;
		busy <= 1'b0;
		SM_uart_tx <= sm_waiting_tx;
	end
	else begin
		case (SM_uart_tx)
			sm_waiting_tx:
				begin
					if (i_Start) begin
						data_tx <= i_Data;		// Store send data in register
						o_TX <= 1'b0;				// Send start bit
						busy <= 1'b1;
						bitCounter_tx <= 4'd0;
						clock_count_tx <= uart_divider;
						SM_uart_tx <= sm_data_tx;
					end
					else begin
						o_TX <= 1'b1;
						busy <= 1'b0;
					end
				end

			sm_data_tx:
				begin
					clock_count_tx <= clock_count_tx - 1'b1;
					
					if (clock_count_tx == 16'd0) begin
						o_TX <= data_tx[bitCounter_tx];
						bitCounter_tx <= bitCounter_tx + 1'b1;
						clock_count_tx <= uart_divider;
						
						if (bitCounter_tx == 4'd8) begin
							SM_uart_tx <= sm_stopbit_tx;
						end
					end
				end

			sm_stopbit_tx:
				begin
					clock_count_tx <= clock_count_tx - 1'b1;
					o_TX <= 1'b1;
					
					if (clock_count_tx == 16'd0) begin
						busy <= 1'b0;
						SM_uart_tx <= sm_waiting_tx;
					end
				end
		endcase
	end
end



//----------------------------------------------------------------
// UART RX state machine
reg [1:0] SM_uart_rx;
localparam sm_waiting_rx = 2'b00;
localparam sm_data_rx    = 2'b01;
localparam sm_write_rx   = 2'b10;

always @(posedge i_Clock or posedge i_Reset) begin
	if (i_Reset) begin
		SM_uart_rx <= sm_waiting_rx;
		sample_point <= 1'b0;
		data_rx <= 8'd0;
		fifo_write <= 1'b0;
	end
	else
		case (SM_uart_rx)
			sm_waiting_rx:
				if (i_RX == 1'b0) begin
					bitCounter_rx <= 4'd0;
					clock_count_rx <= first_sample;		// First sample point is 1.5 * (100MHz / 11520) ie one uart period (start bit) plus a half period (for the sample point)
					data_rx <= 8'd0;
					sample_point <= 1'b0;
					SM_uart_rx <= sm_data_rx;
				end
				else
					fifo_write <= 1'b0;

			sm_data_rx:
				if (clock_count_rx == 16'd0) begin
					bitCounter_rx <= bitCounter_rx + 1'b1;
					clock_count_rx <= uart_divider;		// Set counter to next sample point
					sample_point <= ~sample_point;
					
					// 9th bit should be = 1 (stop bit)
					if (bitCounter_rx == 4'd8) begin
						fifo_write <= (i_RX == 1'b1);
						SM_uart_rx <= sm_waiting_rx;
					end
					else begin
						data_rx[bitCounter_rx] <= i_RX;
					end
				end
				else begin
					clock_count_rx <= clock_count_rx - 1'b1;
				end
				
		endcase

end



//----------------------------------------------------------------
// UART FIFO read received data state machine
reg [1:0] SM_uart_fifo;
localparam sm_waiting_fifo = 2'b00;
localparam sm_wait_fifo    = 2'b01;
localparam sm_data_fifo    = 2'b10;

always @(posedge i_Clock or posedge i_Reset) begin
	if (i_Reset) begin
		SM_uart_fifo <= sm_waiting_fifo;
		fifo_read <= 1'b0;
	end
	else
		case (SM_uart_fifo)
			sm_waiting_fifo:
				if (i_Read_FIFO && o_Received) begin
					fifo_read <= 1'b1;
					SM_uart_fifo <= sm_wait_fifo;
				end
				else
					fifo_read <= 1'b0;
					
			sm_wait_fifo:
				SM_uart_fifo <= sm_data_fifo;			// FIFO seems to take two clock cycles to return data

			sm_data_fifo:
				begin
					o_Data <= fifo_data_out;
					SM_uart_fifo <= sm_waiting_fifo;
				end

		endcase
end


endmodule


	