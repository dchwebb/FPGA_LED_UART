module top (
	output wire led, 
	output wire clk, 
	input wire rstn
);

wire Reset;
assign Reset = ~rstn;

wire Osc_Clock;
wire Clock;
OSCH #(.NOM_FREQ("133.00")) rc_oscillator(.STDBY(1'b0), .OSC(Osc_Clock));
PLL pll(.CLKI(Osc_Clock), .CLKOP(Clock));

// LED settings
wire ledReady;
reg ledStart;
reg [11:0] ledColour;

// Implement wishbone master functionality for interacting with timer
reg wb_strobe;
reg wb_buscycle;
reg wb_we;
wire wb_ack;
reg [7:0] wb_addr;
wire [7:0] wb_data;

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

reg [7:0] ledTimerColour;
reg [2:0] SM_wishbone;
localparam sm_wb_waiting = 2'b00;
localparam sm_wb_assert  = 2'b01;
localparam sm_wb_waitack = 2'b10;
localparam sm_wb_read    = 2'b11;

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
					wb_addr <= 8'h66;					// TCCNT1 - top 8 bits of counter
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




WS2812 ws2812 (
	.i_Reset(Reset),
	.i_Clock(Clock),
	.i_Start(ledStart),
	.i_Colour(ledTimerColour),
	//.i_Colour(ledColour[11:4]),
	.o_Led(led),
	.o_Ready(ledReady)
);


always @(posedge Clock or posedge Reset) begin
	if (Reset) begin
		ledColour <= 8'd0;
		ledStart <= 1'b0;
	end
	else if (ledReady) begin
		if (!ledStart)
			ledColour <= ledColour + 1;
		ledStart <= 1'b1;
	end
	else
		ledStart <= 1'b0;

end



assign clk = ledTimerColour[7];		// Debug for timer

endmodule

