module dead_time
				(
				input [1:0] i_pwm,	// pwm sin tiempo muerto
				
				input clk,			// 5.4MHz
				input rst,
				
				output [1:0] o_pwm	// pwm con tiempo muerto
				);
				

localparam N = 10;	// Cuenta 5 clocks -> 926 ns de dead time


// Registra qué evento da inicio al dead_counter
reg [1:0] r_pwm[N-1:1];
// Bandera que impone el tiempo muerto en ambos canales del pwm
reg dead_time_control;
				
integer ptr1;
integer ptr2;
always@(posedge clk or posedge rst) begin

	if(rst) begin
		
		for(ptr1=1;ptr1<N;ptr1=ptr1+1) begin:reiniciar
			r_pwm[ptr1] <= {2{1'b0}};
        end
	
	end
	
	else begin
	
		// Registro de desplazamiento de ambos filtros		
		for(ptr2=1;ptr2<N;ptr2=ptr2+1) begin:actualizar
			if(ptr2==1)			
				r_pwm[ptr2] <= i_pwm;			
			else			
				r_pwm[ptr2] <= r_pwm[ptr2-1];
		end
	
	end

end

always@(*) begin

		if((r_pwm[N-1]==2'b01 && i_pwm==2'b10) || (r_pwm[N-1]==2'b10 && i_pwm==2'b01))
			dead_time_control = 1'b1;

		else
			dead_time_control = 1'b0;

end

assign o_pwm[0] = (dead_time_control) ? (1'b0) : i_pwm[0];
assign o_pwm[1] = (dead_time_control) ? (1'b0) : i_pwm[1];

endmodule