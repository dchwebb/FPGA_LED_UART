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

wire ledReady;
reg ledStart;
reg [11:0] ledColour;

WS2812 ws2812 (
	.i_Reset(Reset),
	.i_Clock(Clock),
	.i_Start(ledStart),
	.i_Colour(ledColour[11:4]),
	.o_Led(led),
	.o_Ready(ledReady)
);

assign clk = ledReady;

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



//wire timerInterrupt;

wire wb_strobe;
reg [7:0] wb_addr;
reg [7:0] wb_data;

EFB_Timer timer (
	.wb_clk_i(Clock),
	.wb_rst_i(rstn),
	.wb_cyc_i( ),
	.wb_stb_i(wb_strobe), 
	.wb_we_i( ),
	.wb_adr_i(wb_addr),
	.wb_dat_i(wb_data),
	.wb_dat_o( ),
	.wb_ack_o( ), 
	.tc_clki(Clock),
	.tc_rstn(rstn),
	.tc_ic( ),
	.tc_int( ),
	.tc_oc( )
);



endmodule

