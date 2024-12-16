module top_PF
        #(
			parameter NB_CLOCK_COUNTER 		= 10,     	// Bits del contador
			parameter COUNT_LIM  			= 10'd180, 	// Hasta dónde cuenta el contador

            parameter MAF1 					= 100, 		// MAF 20th order -> 5-bit growth acum
			parameter MAF2 					= 60,	 	// MAF 12th order -> 4-bit growth acum2
            parameter NB_MAF_COUNTER        = 7,
			
			parameter NB_SAMPLE  			= 8,
            parameter NBF_SAMPLE 			= 7,
            parameter NB_COEFF   			= 16,
            parameter NBF_COEFF  			= 16, 		// Que no tengan bits enteros (sino revisar truncado yn)
			
            parameter FILTER_ORDER 			= 30,		// Cantidad de coeficientes
			parameter NB_FILTER_COUNTER		= 5     	// Bits del contador (cuenta hasta FILTER_ORDER)
        )
        (
        input signed [NB_SAMPLE-1:0] i_signals,    		// Señal multiplexada

        input clk,  									// 27 MHz -> Gowin
        input rst,										// Active low -> Gowin
		
		output o_clock,									// Clock de salida a 6kHz (para la pico)

		output signed [NB_SAMPLE-1:0] o_signal,			// Señal de error o de control

        output [1:0] pwm  								// Señal de control pwm para el puente H
        );
		
		
localparam COUNT_LIM2 =24;	// (PONER SOLO 24 NO 5'd24 PORQUE NO ANDA)
		
// Clock 6kHz para señales multiplexadas
wire ls_clock;
// Clock 3kHz para señales demultiplexadas
wire demux_clock;
// Clock de 225kHz para la portadora triangular
wire carrier_clock;
// Señal de tensión a filtrar
wire signed [NB_SAMPLE-1:0] i_xn_to_filter;
// Señal de tensión filtrada
wire signed [NB_SAMPLE-1:0] i_xn_filtered; // S(16,15)
// Corriente de carga
wire signed [NB_SAMPLE-1:0] i_dn;
// Corriente de control S(16,15)
wire signed [NB_COEFF-1:0] w_o_en;
// Señal portadora
wire signed [NB_COEFF-1:0] carrier_signal;
// PWM sin tiempo muerto
wire [1:0] w_pwm;

assign o_clock = ls_clock;

wire clk_o;
wire signed [NB_SAMPLE-1:0] i_signals_aux; // Conversión no signado a signado
wire signed [NB_SAMPLE-1:0] o_signal_aux;  // Conversión no signado a signado

assign i_signals_aux = {~i_signals[NB_SAMPLE-1],i_signals   [NB_SAMPLE-2:0]};
assign o_signal =   {~o_signal_aux[NB_SAMPLE-1],o_signal_aux[NB_SAMPLE-2:0]};

assign o_signal_aux = w_o_en[NB_COEFF-1-:NB_SAMPLE];

// From 27 MHz to 5.4 MHz
Gowin_CLKDIV your_instance_name(
        .clkout(clk_o), //output clkout
        .hclkin(clk), //input hclkin
        .resetn(rst) //input resetn
    );
		

// Instanciando bloques
LSCLK	// Low Speed Clock (Reloj rústico)
        #(
            .NB_COUNTER(NB_CLOCK_COUNTER),    	// Bits del contador
			.COUNT_LIM (COUNT_LIM )				// Hasta dónde cuenta el contador
        )
		u_LSCLK
        (
        .clk	(clk_o),		// Clock de entrada (5.4MHz)
        .rst	(~rst),
        .o_clock(ls_clock)	// Clock de salida (6kHz)
        );

LSCLK	// Low Speed Clock (Reloj rústico)
        #(
           .NB_COUNTER(NB_CLOCK_COUNTER),    	// Bits del contador
			.COUNT_LIM (24)				// Hasta dónde cuenta el contador
        )
		u_LSCLK2
        (
        .clk	(clk_o),		// Clock de entrada (5.4MHz)
        .rst	(~rst),
        .o_clock(carrier_clock)	// Clock de salida 225kHz
        );
		
signal_demux 
        #(
            .NB_SAMPLE(NB_SAMPLE)
        )
		u_signal_demux
        (

        .i_signals	(i_signals_aux),		// Voltaje y corriente multiplexados
        .clk		(clk_o),				// 5.4MHz del CLOCKDIV
        .rst		(~rst),				// Active low
		.i_enable	(ls_clock),			// Clock real (6kHz) -> Bloque LSCLK
        .o_demux	(demux_clock),		// 3 KHz -> Clock para los sig. bloques
        .o_xn		(i_xn_to_filter),	// Voltaje de red
        .o_dn 		(i_dn) 				// Corriente de carga

        );

MAF
        #(
            .NB_SAMPLE	(NB_SAMPLE	),
            .NB_COEFF 	(NB_COEFF 	),
            .MAF1 		(MAF1 		),   // MAF 20th order -> 5-bit growth acum
			.MAF2 		(MAF2 		),	 // MAF 12th order -> 4-bit growth acum2
            .NB_COUNTER(NB_MAF_COUNTER)
        )
		u_MAF
        (
        .i_xn		(i_xn_to_filter), 	// Voltaje de red sin filtrar
        .clk		(clk_o), 				// 5.4 MHz
        .rst		(~rst),
		.i_enable	(demux_clock),  	// Clock real de 3kHz (proviene del demultiplexor)
        .o_signal	(i_xn_filtered) 	// Voltaje de red filtrado
        );

AF 
        #(
            .NB_SAMPLE		(NB_SAMPLE		  ),
            .NBF_SAMPLE		(NBF_SAMPLE		  ),
            .NB_COEFF		(NB_COEFF		  ),
            .NBF_COEFF		(NBF_COEFF		  ), 	// Que no tengan bits enteros (sino revisar truncado yn)
            .FILTER_ORDER	(FILTER_ORDER	  ),	// Cantidad de coeficientes
			.NB_COUNTER		(NB_FILTER_COUNTER)     // Bits del contador (cuenta hasta FILTER_ORDER)
        )
		u_AF
        (

        .i_dn		(i_dn),    				// Corriente de carga			S(8,7)
        .i_xn		(i_xn_filtered),    	// Voltaje de red (Referencia)	S(8,7)
        .clk		(clk_o),  				// 5.4MHz -> Gowin FPGA
        .rst		(~rst),					// Active low -> Gowin FPGA
		.i_enable	(demux_clock),			// 3kHz (demux_clock)
        .o_en		(w_o_en)   			// Señal de control inversor	S(8,7)

        );

portadora
		#(
			.NB_DATA 	(16),	// 16-bit la portadora S(16,15)
			.NB_COUNT	(5 ),	// 2^5=32 -> cuenta hasta NB_SAMPLE
			.NB_SAMPLE	(30)
		)
		u_portadora
		(
        .i_clock	(clk_o),
        .i_reset	(~rst),
		.i_enable	(carrier_clock),
        .o_signal	(carrier_signal)                 
        );

spwm
			#(
				.NB_DATA (16)	// S(16,15) para ambos casos
			)
			u_spwm
			(

            .i_c(w_o_en),    // Moduladora (corriente de control/compensación)
            .i_p(carrier_signal),    // Portadora
            .pwm(w_pwm)     // Señal de control pwm para el puente H

            );

dead_time
	u_DT
				(
				.i_pwm	(w_pwm),	// pwm sin tiempo muerto
				.clk	(clk_o),			// 5.4MHz
				.rst	(~rst),
				.o_pwm	(pwm)	// pwm con tiempo muerto
				);


		
endmodule