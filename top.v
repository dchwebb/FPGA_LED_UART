module top (
	input wire rstn,
	input wire uart_rx,
	output wire led, 
	output wire uart_tx,
	output wire uart_sample_point,
	output reg rgb_debug,
	output wire uart_sm_debug
);

// Clock and PLL settings
localparam CLOCK_FREQUENCY = 80000000;
wire osc_Clock;
wire Clock;
OSCH #(.NOM_FREQ("133.00")) rc_oscillator(.STDBY(1'b0), .OSC(osc_Clock), .SEDSTDBY());
PLL pll(.CLKI(osc_Clock), .CLKOP(Clock));

// Reset
wire Reset;
assign Reset = ~rstn;

// LED settings
reg led_on[2:0][2:0];
reg [7:0] led_shade[2:0][2:0];
wire led_ready;
reg led_start;

localparam red   = 2'b00;
localparam green = 2'b01;
localparam blue  = 2'b10;

localparam led1  = 2'b00;
localparam led2  = 2'b01;
localparam led3  = 2'b10;


// Wishbone master settings for controlling timer
reg wb_strobe;
reg wb_buscycle;
reg wb_we;
wire wb_ack;
reg [7:0] wb_addr;
wire [7:0] wb_data;


//---------------------------------------------------------------
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


//---------------------------------------------------------------
// Addressable LED module
WS2812 #(.CLOCK_FREQUENCY(CLOCK_FREQUENCY)) ws2812 (
	.i_Clock(Clock),
	.i_Reset(Reset),

	.i_Start(led_start),

	.i_LED1_R(led_shade[led1][red]),
	.i_LED1_G(led_shade[led1][green]),
	.i_LED1_B(led_shade[led1][blue]),
	
	.i_LED2_R(led_shade[led2][red]),
	.i_LED2_G(led_shade[led2][green]),
	.i_LED2_B(led_shade[led2][blue]),

	.i_LED3_R(led_shade[led3][red]),
	.i_LED3_G(led_shade[led3][green]),
	.i_LED3_B(led_shade[led3][blue]),
	
	.o_Led(led),
	.o_Ready(led_ready)
);

always @(posedge Clock or posedge Reset) begin
	if (Reset)
		led_start <= 1'b0;
	else
		led_start <= led_ready;
end




//---------------------------------------------------------------
// UART
reg uart_send;
reg uart_read;
reg [7:0] uart_tx_data;
wire [7:0] uart_rx_data;
wire uart_send_busy;
wire uart_sample_error;

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
		.sample_error(uart_sample_error),
		.sm_debug(uart_sm_debug),
		
		.i_Read_Data(uart_read),
		.o_Data(uart_rx_data),
		.o_Data_Ready(uart_fifo_ready)
			
	);

// UART state machine for led control (eg 'r1\n' to toggle led 1 red)
reg [2:0] SM_rgb_control;
localparam sm_rgb_waiting = 3'b000;
localparam sm_rgb_pause   = 3'b001;

reg [1:0] rgb_colour;
reg [1:0] rgb_number;
reg [2:0] char_count;

// UART loopback - sends out data when fifo is not empty
always @(posedge Clock or posedge Reset) begin
	if (Reset) begin
		SM_rgb_control <= sm_rgb_waiting;
//		led_on <= 1'h0;
//		led_shade <= 1'h0;

		
		uart_read <= 1'b0;
		uart_send <= 1'b0;
		char_count <= 3'b0;
		rgb_debug <= 1'b0;
		rgb_colour <= 2'd0;
		rgb_number <= 2'd0;
	end
	else begin
		case (SM_rgb_control)
				sm_rgb_waiting:
				begin
					uart_read <= 1'b0;
					uart_send <= 1'b0;
					
					if (uart_fifo_ready && ~uart_send_busy) begin
						uart_read <= 1'b1;
						uart_tx_data <= uart_rx_data;
						uart_send <= 1'b1;
						
						SM_rgb_control <= sm_rgb_pause;
						char_count <= char_count + 3'd1;

						case ({char_count, uart_rx_data})
							{3'd0, 8'h72}:		rgb_colour <= red;
							{3'd0, 8'h67}:		rgb_colour <= green;
							{3'd0, 8'h62}:		rgb_colour <= blue;
							{3'd1, 8'h31}:		rgb_number <= led1;
							{3'd1, 8'h32}:		rgb_number <= led2;
							{3'd1, 8'h33}:		rgb_number <= led3;
							{3'd2, 8'h0A}:
								begin
									char_count <= 3'd0;
									led_shade[rgb_number][rgb_colour] <= led_on[rgb_number][rgb_colour] ? 8'h0 : 8'h11;
									led_on[rgb_number][rgb_colour] <= ~led_on[rgb_number][rgb_colour];
								end
							default:		
								char_count <= 3'd0;
						endcase
						
					end
				end
				
			sm_rgb_pause:
				begin
					uart_read <= 1'b0;
					uart_send <= 1'b0;
					SM_rgb_control <= sm_rgb_waiting;
				end
				
		endcase
	end
end

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
			uart_tx_data <= uart_rx_data;
			uart_send <= 1'b1;
		end
		else begin
			uart_read <= 1'b0;
			uart_send <= 1'b0;
		end
	end
end
*/

endmodule

