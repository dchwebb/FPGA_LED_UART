module WS2812 (
	input wire i_Reset,
	input wire i_Clock,
	input wire i_Start,
	input wire [7:0] i_Colour,
	output wire o_Led,
	output wire o_Ready
);

//GRB
//reg [71:0] output_rgb = 72'h110000001100000011;
//reg [23:0] output_rgb1 = 24'h550000;
wire [32:0] output_rgb1;
assign output_rgb1 = {i_Colour, 16'h0000};
reg [23:0] output_rgb2 = 24'h00FF00;
reg [23:0] output_rgb3 = 24'h000011;
wire [71:0] output_rgb;assign output_rgb = {output_rgb1, output_rgb2, output_rgb3};

reg [8:0] clk_counter;
reg [8:0] led_counter;
reg led_clock = 1'b0;
reg led_state = 1'b0;
assign o_Led = led_state;
reg ledReady;

// Each pulse must be around .42us; 3 pulses needed for each bit: 3 * .42 = 1.26us
always @(posedge i_Clock or posedge i_Reset) begin
	if (i_Reset)
		clk_counter <= 0;
	else if (clk_counter == 8'd24) begin
		led_clock <= 1'b1;
		clk_counter <= clk_counter + 1;
	end
	else if (clk_counter == 8'd42) begin
		led_clock <= 1'b0;
		clk_counter <= 0;
	end
	else
		clk_counter <= clk_counter + 1;
end

assign o_Clock = led_clock;



// State machine
reg [3:0] SM;
localparam sm_waiting = 4'b0000;
localparam sm_phase1  = 4'b0001;			// First phase of output bit (always 1)
localparam sm_phase2  = 4'b0010;			// Second phase (1 or 0)
localparam sm_phase3  = 4'b0011;			// Third phase (always 0)
localparam sm_reset   = 4'b0100;			// Wait until ready to send again


// clock the ready output
always @(posedge led_clock) begin
	ledReady <= (SM == sm_waiting);
end

// clock the start intput
reg start;
always @(posedge i_Start or posedge led_clock) begin
	if (SM == sm_waiting) begin
		start <= i_Start;
	end
	else begin
		start <= 1'b0;
	end
end


// Main LED output loop
always @(posedge led_clock or posedge i_Reset) begin
	if (i_Reset) begin
		led_state <= 1'b0;
		led_counter = 8'b0;
		SM <= sm_waiting;
	end
	else begin
		case (SM)
			sm_waiting:
				if (start) begin
					led_counter <= 8'd71;
					led_state <= 1'b1;
					SM <= sm_phase2;
				end
			sm_phase1:
				begin
					led_state <= 1'b1;
					SM <= sm_phase2;
				end
			sm_phase2:
				begin
					led_state <= output_rgb[led_counter];
					led_counter <= led_counter - 1;
					if (led_counter == 8'd0) begin
						SM <= sm_reset;
					end
					else
						SM <= sm_phase3;
				end
			sm_phase3:
				begin
					led_state <= 1'b0;
					SM <= sm_phase1;
				end
			sm_reset:
				begin
					led_state <= 1'b0;
					led_counter <= led_counter + 1;
					if (led_counter == 250)		// 120= 50uS (minimum gap from datasheet, but in practice needs to be longer)
						SM <= sm_waiting;
				end
		endcase
	end
end

assign o_Ready = ledReady;
//assign o_Ready = (SM == sm_waiting) && !i_Start;

endmodule

