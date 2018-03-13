module shifter_128bit
	(
		output result,
		input [127:0] load_val,
		input load_n, 
		input shift, 
		input reset, 
		input clock
	);
    
    reg pixel[127:0];
    
    assign result = pixel[127];
    
    always @(posedge clock)
	begin 
        if(reset == 1'b0)
            pixel <= 128'd0;
        else if (load_n == 1'b1)
            pixel <= load_val;
        else if (shift == 1'b1)
            pixel << 1'b1;
    end

endmodule