module top (
	input wire rstn,
	input wire uart_rx,
	output wire led, 
	output wire uart_tx,
	output wire uart_sample_point
);

// Clock and PLL settings
localparam CLOCK_FREQUENCY = 80000000;
wire Osc_Clock;
wire Clock;
OSCH #(.NOM_FREQ("133.00")) rc_oscillator(.STDBY(1'b0), .OSC(Osc_Clock), .SEDSTDBY());
PLL pll(.CLKI(Osc_Clock), .CLKOP(Clock));

// Reset
wire Reset;
assign Reset = ~rstn;

// LED settings
wire led_ready;
reg led_start;


// Wishbone master for controlling timer
reg wb_strobe;
reg wb_buscycle;
reg wb_we;
wire wb_ack;
reg [7:0] wb_addr;
wire [7:0] wb_data;


// EFB (Embedded function blocks): implement wishbone master functionality for interacting with timer
EFB_Timer timer (
	.wb_clk_i(Clock),
	.wb_rst_i(rstn),
	.wb_cyc_i(wb_buscycle),
	.wb_stb_i(wb_strobe), 
	.wb_we_i(1'b0),
	.wb_adr_i(wb_addr),
	.wb_dat_i(),
	.wb_dat_o(wb_data),
	.wb_ack_o(wb_ack), 
	.tc_clki(Clock),
	.tc_rstn(rstn),
	.tc_ic( ),
	.tc_int( ),
	.tc_oc( )
);

// State machine to retrieve current counter setting using Wishbone register
reg [7:0] timer_value;
reg SM_wishbone;
localparam sm_wb_waiting = 1'b0;
localparam sm_wb_waitack = 1'b1;

always @(posedge Clock or posedge Reset) begin
	if (Reset) begin
		SM_wishbone <= sm_wb_waiting;
		wb_strobe <= 1'b0;
		wb_buscycle <= 1'b0;
		wb_we <= 1'b0;
		wb_addr <= 8'h0;
		timer_value <= 8'h0;
	end
	else begin
		case(SM_wishbone)
			sm_wb_waiting:
				if (!led_start) begin
					wb_strobe <= 1'b1;
					wb_buscycle <= 1'b1;
					wb_we <= 1'b0;
					wb_addr <= 8'h66;					// register TCCNT1 - top 8 bits of 16 bit counter
					SM_wishbone <= sm_wb_waitack;
				end
			sm_wb_waitack:
				if (wb_ack) begin
					wb_strobe <= 1'b0;
					wb_buscycle <= 1'b0;	
					timer_value <= wb_data;
					SM_wishbone <= sm_wb_waiting;
				end
		endcase
	end
end



// Addressable LED module
WS2812 #(.CLOCK_FREQUENCY(CLOCK_FREQUENCY)) ws2812 (
	.i_Clock(Clock),
	.i_Reset(Reset),

	.i_Start(led_start),
	.i_Colour(timer_value),
	.o_Led(led),
	.o_Ready(led_ready)
);

always @(posedge Clock or posedge Reset) begin
	if (Reset)
		led_start <= 1'b0;
	else
		led_start <= led_ready;
end





// UART
reg uart_send;
reg uart_read;
reg [7:0] uart_tx_data;
wire [7:0] uart_fifo_data;
wire uart_send_busy;


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


endmodule

