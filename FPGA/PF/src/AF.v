module AF 
        #(
            parameter NB_SAMPLE  = 8,
            parameter NBF_SAMPLE = 7,
            parameter NB_COEFF   = 16,
            parameter NBF_COEFF  = 16, // Que no tengan bits enteros (sino revisar truncado yn)
			
            parameter FILTER_ORDER = 30,		// Cantidad de coeficientes
			parameter NB_COUNTER   = 5     		// Bits del contador (cuenta hasta FILTER_ORDER)
        )
        (

        input signed [NB_SAMPLE-1:0] i_dn,    	// Corriente de carga			S(8,7)
        input signed [NB_SAMPLE-1:0] i_xn,    	// Voltaje de red (Referencia)	S(8,7)

        input clk,  							// 5.4MHz -> Gowin FPGA
        input rst,								// Active low -> Gowin FPGA
		
		input i_enable,							// 3kHz (demux_clock)

        output signed [NB_COEFF-1:0] o_en   	// Señal de control inversor	S(16,15)

        );
		
// --------------- PARAMETROS LOCALES --------------- //

localparam NB_SAT  = 5;  //Log2(FILTER_ORDER) -> bits carry acumulador
localparam NB_PROD = NB_SAMPLE + NB_COEFF; 		// 8 + 16
localparam NB_ADD  = NB_PROD + NB_SAT; 	   		// 8 + 16 + 5

// ---------------					 --------------- //



// --------------- VARIABLES DE CONTROL --------------- //

// Controla el clock proveniente de i_enable
reg flag_enable;
// Contador y puntero de operaciones
reg [NB_COUNTER-1:0] op_count;

//---------------				         ---------------//



// --------------- SEÑALES DEL FILTRO --------------- //

reg  signed [NB_SAMPLE-1:0] r_i_xn [FILTER_ORDER-1:1];  // Muestras pasadas de i_xn S(8,7)
wire signed [NB_COEFF -1:0] w_i_dn;						// Versión S(16,15) de i_dn
wire signed [NB_COEFF	:0] w_o_en;


// ---------------					 --------------- //



// --------------- COEFICIENTES DEL FILTRO --------------- //

reg signed [NB_COEFF-1:0] hn0 [FILTER_ORDER-1:0];  // Coeficientes del filtro adaptativo tiempo actual    S(16,16)
reg signed [NB_COEFF  :0] hn1 [FILTER_ORDER-1:0];  // Coeficientes del filtro adaptativo tiempo siguiente S(17,16)

// --------------- 						   --------------- //



// --------------- OPERACIONES DEL FILTRO FIR --------------- //

reg signed [NB_PROD -1:0] prod;  // Productos hn0*xn (N productos) S(16,16)*S(8,7) = S(24,23)
reg signed [NB_ADD  -1:0] acum;  // Sumas de productos (N-1 sumas) 					 S(29,23)
reg signed [NB_COEFF-1:0] yn; 	 // Salida del filtro 								 S(16,15)

// --------------- 							 --------------- //



// --------------- OPERACIONES DEL FILTRO ADAPTATIVO --------------- //

// Parámetro del filtro LMS mu*2 S(16,16)
wire signed [NB_COEFF-1:0] mu2;	// S(16,16)
// Producto 2*mu*e[n]
wire signed [NB_COEFF + NB_COEFF : 0] mu2en; // S(33,31)
// Producto entre el resultado anterior y x[n]
reg signed [NB_COEFF + NB_COEFF + NB_SAMPLE : 0] mu2enxn; // S(33,31)*S(8,7) = S(41,38)
// Parámetro del filtro LMS Leackage Factor (LF) -> LF*hn0
wire signed [NB_COEFF-1:0] LF;	// S(16,15)
// Producto LF*h0[n]
reg signed [NB_COEFF-1 + NB_COEFF : 0] LFhn0; // S(16,15)*S(16,16)=S(32,31)
// Factor de compensación CF S(16,14)
wire signed [NB_COEFF-1:0] CF;	// S(16,14)
// Salida compensada S(16,14)*S(16,15)=S(32,29)
wire signed [NB_COEFF+NB_COEFF-1:0] yn_comp;	// S(32,29)


// --------------- 							 --------------- //


assign mu2	= 16'h0021;		// = 5e-4
assign LF 	= 16'd32735;	// 0.9989
assign CF	= 16'd16384;	// 1.778 (Asume una atenuación de -5dB) -> A 3.3V la fundamental debería tener 0.93Vpp

integer ptr1;
integer ptr2;
always @(posedge clk or posedge rst) begin

	if(rst) begin
		flag_enable <= 1'b0;
		op_count	<= {NB_COUNTER{1'b0}};
		prod	<= {NB_PROD{1'b0}};
		acum	<= {NB_ADD{1'b0}};
		yn		<= {NB_COEFF{1'b0}};
		mu2enxn	<= {NB_COEFF + NB_COEFF + NB_SAMPLE + 1{1'b0}}; // Son 41 bits
		for(ptr1=0;ptr1<FILTER_ORDER;ptr1=ptr1+1) begin:reiniciar
			hn1[ptr1]  	<= {NB_COEFF+1{1'b0}};
			hn0[ptr1]  	<= {NB_COEFF{1'b0}};
			if(ptr1)
				r_i_xn[ptr1]<= {NB_SAMPLE{1'b0}};
        end

	end
	
	else begin
	
	
		// --------------- REGION 3KHz --------------- //
		if(i_enable && flag_enable) begin
			// --------------- VARIABLES DE CONTROL --------------- //
			op_count 	<= {NB_COUNTER{1'b0}}; // Reinicio contador de operaciones
			flag_enable <= 1'b0;
			//---------------						---------------//
			
			
			
			// --------------- VARIABLES FILTRO FIR --------------- //

			r_i_xn[1] 	<= i_xn; // Registro de señal de referencia
			// Registros de desplazamiento de entradas y coeficientes
			for(ptr2=0;ptr2<FILTER_ORDER;ptr2=ptr2+1) begin:actualizar
				if(ptr2>1)
					r_i_xn[ptr2] <= r_i_xn[ptr2-1];
				// Actualización de coeficientes	
				hn0[ptr2] <= hn1[ptr2][NB_COEFF-1:0];
			end 
			//---------------						---------------//
			
			
			
			// --------------- VARIABLES FILTRO ADAPTATIVO --------------- //
			
			yn 		<= acum[NB_ADD-1 - NB_SAT -: NB_COEFF];	// S(16,15)
			
			//---------------								---------------//
		
		end
		
		else if(!i_enable && !flag_enable)
			flag_enable <= 1'b1;
		//---------------				---------------//
		
		
		
		// --------------- REGION 5.4MHz --------------- //
		if(op_count<FILTER_ORDER) begin
		
			op_count <= op_count + {{NB_COUNTER-1{1'b0}},{1'b1}}; // Incremento contador
			
			// Operaciones aritméticas:
					   
			if(op_count) begin
			
				prod <= hn0[op_count] * r_i_xn[op_count];	// S(32,31)
				acum <= acum + {{NB_SAT{prod[NB_PROD-1]}},{prod}}; // Alineación de la coma a S(37,31)
				mu2enxn <= mu2en * r_i_xn[op_count];	// S(41,38)
				
			end
			else begin
			
				prod <= hn0[op_count] * i_xn;
				mu2enxn <= mu2en * i_xn;	// S(41,38)
				acum <= {{NB_SAT{prod[NB_PROD-1]}},{prod}};
				
			end
			
			hn1[op_count] <= LFhn0[30-:NB_COEFF] + mu2enxn[37-:NB_COEFF]; // S(17,16)
		
		end
		
		
		//---------------			      ---------------//
		
		
	
	end

end

always@(*) begin

	if(op_count<FILTER_ORDER)
		LFhn0 = LF * hn0[op_count];
	else
		LFhn0 = LF * hn0[op_count-1];

end

assign mu2en = mu2 * w_o_en; // S(33,31)

assign w_i_dn = {i_dn,{NB_COEFF-NB_SAMPLE{1'b0}}};	// S(8,7) a S(16,15) -> Alineación de las comas

//assign yn_comp= CF * yn;	// S(32,29)
//wire signed [NB_COEFF-1:0] yn_comp_aux;
//assign yn_comp_aux = yn_comp[29-:NB_COEFF];	// Sino no hace bien la resta
//assign w_o_en = w_i_dn - yn_comp_aux;	// S(17,15)


assign w_o_en = w_i_dn - yn;	// S(17,15)
assign o_en = w_o_en[NB_COEFF-1 -: NB_COEFF]; // Trunco a S(16,15)
		
endmodule


