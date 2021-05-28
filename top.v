module top (
	output wire led, 
	output wire clk,
	output wire uart,
	input wire rstn
);

// Clock settings
wire Osc_Clock;
wire Clock;
OSCH #(.NOM_FREQ("133.00")) rc_oscillator(.STDBY(1'b0), .OSC(Osc_Clock), .SEDSTDBY());
PLL pll(.CLKI(Osc_Clock), .CLKOP(Clock));

// Reset
wire Reset;
assign Reset = ~rstn;

// LED settings
wire ledReady;
reg ledStart;

// UART
reg uart_start;

// Wishbone settings
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

// Use wishbone bus to retrieve current counter setting to use as led colour
reg [7:0] ledTimerColour;
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
		ledTimerColour <= 8'h0;
	end
	else begin
		case(SM_wishbone)
			sm_wb_waiting:
				if (!ledStart) begin
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
					ledTimerColour <= wb_data;
					SM_wishbone <= sm_wb_waiting;
				end
		endcase
	end
end



// Addressable LED module
WS2812 ws2812 (
	.i_Reset(Reset),
	.i_Clock(Clock),
	.i_Start(ledStart),
	.i_Colour(ledTimerColour),
	.o_Led(led),
	.o_Ready(ledReady)
);

always @(posedge Clock or posedge Reset) begin
	if (Reset)
		ledStart <= 1'b0;
	else
		ledStart <= ledReady;
end


assign clk = ledTimerColour[7];		// Debug for timer



// UART
UART uart_module (
	.i_Clock(Clock),
	.i_Reset(Reset),
	.i_Start(ledStart),
	.i_Data(ledTimerColour),
	.o_UART(uart)
);

endmodule

