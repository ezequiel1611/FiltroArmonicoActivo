module spwm
			#(
				parameter NB_DATA = 16	// S(16,15) para ambos casos
			)
			(

            input signed [NB_DATA-1:0] i_c,    // Moduladora (corriente de control/compensación)
            input signed [NB_DATA-1:0] i_p,    // Portadora

            output [1:0] pwm  // Señal de control pwm para el puente H

            );

// La moduladora tiene fs = 15 kHz
// La portadora tiene fs = 225 kHz
// La relación es 15 a 1 -> Entonces la frecuencia de la portadora es 7.5kHz
// Debería modular bien hasta el armónico 15 (750Hz)

reg g1, g4;	// Figura 6.14b Rashid 4ed pag.  310

wire signed [NB_DATA-1:0] i_c_n; // i_L invertido / desfasado 180°

wire signed [1:0] gQ;

assign i_c_n = ~i_c + {{NB_DATA-1{1'b0}},{1'b1}}; // CA2

always @(*) begin

        if(i_p<=i_c) // Figura 6.14a Rashid 4ed pag.  310
            g1 = 1'b1;

        else
            g1 = 1'b0;
			
			
/* --------------------------- */

    
        if(i_p<=i_c_n)
            g4 = 1'b1;

        else
            g4 = 1'b0;
    
end

assign gQ = g1 - g4; // Figura 6.14c Rashid 4ed pag.  310

// Señales de control para el inversor de puente completo
assign pwm[1] = gQ[1];
assign pwm[0] = gQ[1]^gQ[0];


endmodule