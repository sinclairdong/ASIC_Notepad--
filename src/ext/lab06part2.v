module lab06part2
	(
		input CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
      input [3:0] KEY,
      input [9:0]  SW,
		// The ports below are for the VGA output.  Do not change.
		output VGA_CLK,   						//	VGA Clock
		output VGA_HS,							//	VGA H_SYNC
		output VGA_VS,							//	VGA V_SYNC
		output VGA_BLANK_N,					//	VGA BLANK
		output VGA_SYNC_N,						//	VGA SYNC
		output [9:0] VGA_R,   						//	VGA Red[9:0]
		output [9:0] VGA_G,	 						//	VGA Green[9:0]
		output [9:0] VGA_B,   						//	VGA Blue[9:0]
		output [6:0] HEX0,
		output [6:0] HEX1,
		output [6:0] HEX2,
		output [6:0] HEX3,
		output [6:0] HEX4
	);
	
	wire resetn;
	wire reset_c;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;
	wire [4:0] counter_transfer;
	wire increment_transfer, ld_x_transfer, ld_y_transfer;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
    
   // Instantiate datapath
	datapath d0(.x_out(x),
			.y_out(y),
			.colour_out(colour),
			.counter(counter_transfer),
			.clk(CLOCK_50),
			.reset_n(~resetn),
			.coord_in(SW[6:0]),
			.colour_in(SW[9:7]),
			.increment_counter(increment_transfer),
			.reset_counter(reset_c),
			.ld_x(ld_x_transfer),
			.ld_y(ld_y_transfer));

    // Instantiate FSM control
    control_FSM c0(.plot(writeEn),
			.increment_counter(increment_transfer),
			.reset_counter(reset_c),
			.ld_x(ld_x_transfer),
			.ld_y(ld_y_transfer),
			.clk(CLOCK_50),
			.reset_n(~resetn),
			.next_val(~KEY[3]),
			.go(~KEY[1]),
			.counter_in(counter_transfer));
		
		hex_display h0(.IN(x[3:0]),
							.OUT(HEX0));
		hex_display h1(.IN(x[7:4]),
							.OUT(HEX1));
		hex_display h2(.IN(y[3:0]),
							.OUT(HEX2));
		hex_display h3(.IN({1'b0, y[6:4]}),
							.OUT(HEX3));
		hex_display h4(.IN(counter_transfer),
							.OUT(HEX4));
endmodule


module counter_5bit(Q_OUT, EN, CLK, CLR);
	output reg [4:0] Q_OUT;
	input CLK, CLR, EN;

	always @(posedge CLK)
	begin
		if (EN == 1'b1 | CLR == 1'b1)
		begin
//		Q_OUT <= CLR == 1'b1 or Q_OUT = 1'b1111 ? 0 : Q_OUT + 1'b1;
			if (CLR == 1'b1 | Q_OUT == 5'b11111)
				Q_OUT[4:0] <= 0;
			else if (CLK == 1'b1)
			   Q_OUT[4:0] <= Q_OUT[4:0] + 5'b00001;
		end
	end
endmodule

module datapath(
	output reg [7:0] x_out,
	output reg [6:0] y_out,
	output [2:0] colour_out,
	output [4:0] counter, 
	input clk,
	input reset_n, 
	input [6:0] coord_in,
	input [2:0] colour_in,
	input increment_counter,
	input reset_counter,
	input ld_x, 
	input ld_y);

	reg [7:0] x;
	reg [6:0] y;

	localparam MAX = 4'd15;
	
	assign colour_out = colour_in;
	
	initial
	begin
		x = 8'b0000_0000;
		y = 7'b0000_000;
	end

	always @(negedge clk)
	begin: coordinate_loader
		if (ld_x)
			x = {1'b0, coord_in};
		if (ld_y)
			y = coord_in;	
	end // coordinate_loader

	always @(posedge clk)
	begin: coordinate_shifter
		if (~increment_counter)
		begin
			x_out = x + counter[1:0];
			y_out = y + counter[3:2];
		end
	end // coordinate_shifter
	
	counter_5bit c0(.Q_OUT(counter), .EN(increment_counter), .CLK(clk), .CLR(reset_counter));
	
	//always @(*)
	//begin: counter_4bit
	//	if (reset_n || reset_counter)
	//		counter = 4'b0;
	//	else if (increment_counter)
	//		counter = counter + 1'b1;
	//end // counter_4bit

endmodule

module control_FSM(
	output reg plot, 
	output reg increment_counter,
	output reg reset_counter,
	output reg ld_x,
	output reg ld_y,
	input clk,
	input reset_n,
	input next_val,
	input go,
	input [4:0] counter_in);

	reg [2:0] current_state, next_state;

	localparam MAX = 4'd15;
	localparam 	S_LOAD_X				= 3'd0,
				S_LOAD_X_WAIT			= 3'd1,
				S_LOAD_Y					= 3'd2,
				S_LOAD_Y_WAIT			= 3'd3,
				S_PLOT_XY				= 3'd4,
				S_PLOT_WAIT				= 3'd7,
				S_INCREMENT_COUNTER	= 3'd5,
				S_INCREMENT_WAIT		= 3'd6;

	always @(*)
	begin: state_table
		case (current_state)
			S_LOAD_X: 				next_state = next_val ? S_LOAD_X_WAIT : S_LOAD_X;
			S_LOAD_X_WAIT: 		next_state = ~next_val ? S_LOAD_Y : S_LOAD_X_WAIT;
			S_LOAD_Y: 				next_state = go ? S_LOAD_Y_WAIT : S_LOAD_Y;
			S_LOAD_Y_WAIT:		 	next_state = ~go ? S_PLOT_XY : S_LOAD_Y_WAIT;
			S_PLOT_XY: 				next_state = S_PLOT_WAIT;
			S_PLOT_WAIT:			next_state = S_INCREMENT_COUNTER;
			S_INCREMENT_COUNTER:	next_state = S_INCREMENT_WAIT;
			S_INCREMENT_WAIT: 	next_state = (counter_in <= MAX) ? S_PLOT_XY : S_LOAD_X;
			default: 				next_state = S_LOAD_X;
		endcase
	end // state_table
	
	always @(negedge clk)
	begin: enable_signals
		ld_x = 1'b0;
		ld_y = 1'b0;
		increment_counter = 1'b0;
		plot = 1'b0;
		reset_counter = 1'b0;
		case (current_state)
			S_LOAD_X:
				begin
					ld_x						= 1'b1;
					reset_counter			= 1'b1;
				end
			S_LOAD_Y: 					ld_y 						= 1'b1;
			S_PLOT_XY: 					plot 						= 1'b1;
			S_INCREMENT_COUNTER: 	increment_counter 	= 1'b1;
		endcase
	end // enable_signals
	
	always @(posedge clk)
	begin: state_FFs
		current_state = reset_n ? S_LOAD_X : next_state;
	end // state_FFs
endmodule

module hex_display(IN, OUT);
    input [3:0] IN;
	 output reg [6:0] OUT;
	 
	 always @(*)
	 begin
		case(IN[3:0])
			4'b0000: OUT = 7'b1000000;
			4'b0001: OUT = 7'b1111001;
			4'b0010: OUT = 7'b0100100;
			4'b0011: OUT = 7'b0110000;
			4'b0100: OUT = 7'b0011001;
			4'b0101: OUT = 7'b0010010;
			4'b0110: OUT = 7'b0000010;
			4'b0111: OUT = 7'b1111000;
			4'b1000: OUT = 7'b0000000;
			4'b1001: OUT = 7'b0011000;
			4'b1010: OUT = 7'b0001000;
			4'b1011: OUT = 7'b0000011;
			4'b1100: OUT = 7'b1000110;
			4'b1101: OUT = 7'b0100001;
			4'b1110: OUT = 7'b0000110;
			4'b1111: OUT = 7'b0001110;
			default: OUT = 7'b0111111;
		endcase

	end
endmodule
