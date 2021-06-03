module WS2812 
	#(parameter CLOCK_FREQUENCY = 100000000)
	(
		input wire i_Clock,
		input wire i_Reset,

		input wire i_Start,

		input wire [7:0] i_LED1_R,
		input wire [7:0] i_LED1_G,
		input wire [7:0] i_LED1_B,
		
		input wire [7:0] i_LED2_R,
		input wire [7:0] i_LED2_G,
		input wire [7:0] i_LED2_B,
		
		input wire [7:0] i_LED3_R,
		input wire [7:0] i_LED3_G,
		input wire [7:0] i_LED3_B,

		output reg o_Led,
		output reg o_Ready
	);


// colour order: GRB
wire [71:0] output_rgb;assign output_rgb = {i_LED1_G, i_LED1_R, i_LED1_B, i_LED2_G, i_LED2_R, i_LED2_B, i_LED3_G, i_LED3_R, i_LED3_B};

reg [8:0] clk_counter;
reg [8:0] led_counter;
reg led_clock = 1'b0;


// Each pulse must be around .42us (= 2.38MHz); 3 pulses needed for each bit: 3 * .42 = 1.26us
localparam [8:0] clock_divider_0 = CLOCK_FREQUENCY / 2380000;
localparam [8:0] clock_divider_1 = clock_divider_0 / 2;

always @(posedge i_Clock or posedge i_Reset) begin
	if (i_Reset)
		clk_counter <= 0;
	else if (clk_counter == clock_divider_1) begin
		led_clock <= 1'b1;
		clk_counter <= clk_counter + 1'b1;
	end
	else if (clk_counter == clock_divider_0) begin
		led_clock <= 1'b0;
		clk_counter <= 0;
	end
	else
		clk_counter <= clk_counter + 1'b1;
end



// State machine
reg [2:0] SM;
localparam sm_waiting = 3'b000;
localparam sm_phase1  = 3'b001;			// First phase of output bit (always 1)
localparam sm_phase2  = 3'b010;			// Second phase (1 or 0)
localparam sm_phase3  = 3'b011;			// Third phase (always 0)
localparam sm_reset   = 3'b100;			// Wait until ready to send again


// clock the ready output
always @(posedge led_clock) begin
	o_Ready <= (SM == sm_waiting);
end

// clock the start intput
reg start;

always @(posedge i_Clock) begin
	if (i_Start)
		start <= 1'b1;
	
	else if (SM != sm_waiting)
		start <= 1'b0;
end


// Main LED output loop
always @(posedge led_clock or posedge i_Reset) begin
	if (i_Reset) begin
		o_Led <= 1'b0;
		led_counter = 8'b0;
		SM <= sm_waiting;
	end
	else begin
		case (SM)
			sm_waiting:
				if (start) begin
					led_counter <= 8'd71;			// 72 = 3 leds x 24 colour bits
					o_Led <= 1'b1;
					SM <= sm_phase2;
				end
			sm_phase1:
				begin
					o_Led <= 1'b1;
					SM <= sm_phase2;
				end
			sm_phase2:
				begin
					o_Led <= output_rgb[led_counter];
					led_counter <= led_counter - 1'b1;
					if (led_counter == 8'd0) begin
						SM <= sm_reset;
					end
					else
						SM <= sm_phase3;
				end
			sm_phase3:
				begin
					o_Led <= 1'b0;
					SM <= sm_phase1;
				end
			sm_reset:
				begin
					o_Led <= 1'b0;
					led_counter <= led_counter + 1'b1;
					if (led_counter == 250)		// 120 = 50uS (minimum gap from datasheet, but in practice needs to be longer)
						SM <= sm_waiting;
				end
		endcase
	end
end


endmodule

