module signal_demux 
        #(
            parameter NB_SAMPLE = 8
        )
        (

        input signed [NB_SAMPLE-1:0] i_signals, // Voltaje y corriente multiplexados

        input clk,  							// 5.4MHz del CLOCKDIV
        input rst,
		
		input i_enable,							// Clock real (6kHz) -> Bloque LSCLK

        output o_demux, 						// 3 KHz -> Clock para los sig. bloques

        output signed [NB_SAMPLE-1:0] o_xn,		// Señal de referencia
        output signed [NB_SAMPLE-1:0] o_dn 		// Señal contaminada 

        );
		

// Controla el clock proveniente de i_enable
reg flag_enable;
// Permite separar las dos señales provenientes de i_signals
reg r_demux;
// Señales demultiplexadas
reg [NB_SAMPLE-1:0] r_i_dn;
reg [NB_SAMPLE-1:0] r_i_xn;
reg [NB_SAMPLE-1:0] r_i_xn_aux; // Para alinear las muestras demultiplexadas

always @(posedge clk or posedge rst) begin

	if(rst) begin
	
		flag_enable <= 1'b0;
		r_demux		<= 1'b0;
		r_i_dn      <= {NB_SAMPLE{1'b0}};
        r_i_xn      <= {NB_SAMPLE{1'b0}};
		r_i_xn_aux  <= {NB_SAMPLE{1'b0}};
	
	end
	
	else begin
		// Con esto fuerzo a que i_enable haga de clock
		if(i_enable && flag_enable) begin
		
			flag_enable <= 1'b0;
			
			if(r_demux) begin
			
                r_i_dn  <= i_signals;   // Separo la primera señal en el primer flanco positivo
				r_i_xn_aux<=r_i_xn;		// Le meto otro retardo para alinearlo con r_i_dn
                r_demux <= 1'b0;        // Conmuto la bandera
				
            end
            else begin
			
                r_i_xn  <= i_signals;   // Separo la segunda señal en el siguiente flanco positivo
                r_demux <= 1'b1;        // Conmuto la bandera
				
            end
		
		end
		
		else if(!i_enable && !flag_enable)
			flag_enable <= 1'b1;
	
	end

end

assign o_xn = r_i_xn_aux;
assign o_dn = r_i_dn;
assign o_demux = ~r_demux;
		
endmodule