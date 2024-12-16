module LSCLK	// Low Speed Clock (Reloj a base de contador)
        #(
            parameter NB_COUNTER = 11,     // Bits del contador
			parameter COUNT_LIM  = 11'd900 // Hasta dónde cuenta el contador
        )
        (
		
        input clk,  // Clock de entrada
        input rst,

        output o_clock // Clock de salida

        );
		
// Registro o_clock
reg r_o_clock;
// Contador de relojs
reg [NB_COUNTER-1:0] clock_counter;

always @(posedge clk or posedge rst) begin

	if(rst) begin
	
		r_o_clock 	  <= 1'b0;
		clock_counter <= {NB_COUNTER{1'b0}};
	
	end
	
	else begin
	
		if(clock_counter == COUNT_LIM/2 - 1) begin
		
		r_o_clock     <= 1'b1;        								// Pongo en alto o_clock
        clock_counter <= clock_counter + {{NB_COUNTER-1{1'b0}},{1'b1}}; // Incremento el contador
		
		end
		
		else if(clock_counter == COUNT_LIM - 1) begin
		
		    r_o_clock       <= 1'b0;  				// Pongo en bajo o_clock
            clock_counter   <= {NB_COUNTER{1'b0}};  // Reinicio el contador
		
		end
		
		else begin
		
			clock_counter <= clock_counter + {{NB_COUNTER-1{1'b0}},{1'b1}}; // Incremento el contador
		
		end
	
	end

end

assign o_clock = r_o_clock;

endmodule