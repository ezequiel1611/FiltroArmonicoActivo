module MAF
        #(
            parameter NB_SAMPLE = 8 ,
            parameter NB_COEFF 	= 16,
            parameter MAF1 		= 20, 	// MAF 20th order -> 5-bit growth acum
			parameter MAF2 		= 12,	// MAF 12th order -> 4-bit growth acum2
			parameter NB_COUNTER= 6  	// Log2(MAF1) 
        )
        (
        input signed [NB_SAMPLE-1:0] i_xn,   	// Tensión de red

        input clk,  						  	// 5.4 MHz del CLKDIV
        input rst,

        input i_enable, 						// Clock real de 3kHz (proviene del demultiplexor)

        output signed [NB_SAMPLE-1:0] o_signal  // Voltaje de red filtrado
        );
		
// Parámetros locales
localparam NB_SAT  		= NB_COUNTER;  //Log2(MAF1) -> bits carry acumulador
localparam NB_ADD  		= NB_SAMPLE + NB_SAT; // Porque primero acumula las entradas, y luego realiza la multiplicación
localparam NBF_SAMPLE	= 7;	
localparam NBF_COEFF 	= 15;

// Constantes
wire signed [NB_COEFF-1:0] N1; // N1-taps for MAF1
wire signed [NB_COEFF-1:0] N2; // N2-taps for MAF2
wire signed [NB_COEFF-1:0] CF; // Factor de compensasión (1.287) S(16,14)

// Coeficientes de cada filtro MAF
assign N1 = 16'd328;  // = 1/40  S(16,15)
assign N2 = 16'd546;  // = 1/24  S(16,15)
assign CF = 16'd18500; // = 1.279 S(16,14)

// Variables del primer filtro de media móvil
reg  signed [NB_SAMPLE-1:0] 			r_xn [MAF1-1:1]; 	// Muestras pasadas de i_xn
reg signed  [NB_ADD   -1:0] 			acum;				// Suma de las entradas para el MAF 20
reg signed  [NB_ADD   + NB_COEFF-1 :0] 	y1; 				// Salida MAF 20. S(13,7)*S(16,15) = S(29,22)-> Lo trunco a S(8,7)

// Variables del segundo filtro de media móvil
reg  signed [NB_SAMPLE	-1:0] 			r_yn [MAF2-1:1]; 	// Salidas pasadas del primer MAF S(8,7)
reg signed  [NB_ADD   	-2:0] 			acum2;				// Acumula 12 muestras pasadas de y1
reg signed  [NB_ADD	-1+ NB_COEFF-1 :0] 	y2; 			 	// Salida MAF 12. S(12,7)*S(16,15) = S(28,22) -> Lo trunco a S(16,15)
wire signed [NB_COEFF	-1:0] 			y2_aux;				// Versión truncada en S(16,15) de y2
wire signed [NB_COEFF + NB_COEFF-1 :0] 	y3;  			 	// Salida compensada. S(16,15)*S(16,14) = S(32,29) -> Lo trunco a S(8,7)

// Controla el clock proveniente de i_enable
reg flag_enable;
// Contador y puntero de operaciones
reg [NB_COUNTER-1:0] op_count; // Cuenta hasta MAF1

integer ptr1;
integer ptr2;
always @(posedge clk or posedge rst) begin

	if(rst) begin
		flag_enable <= 1'b0;
		op_count	<= {NB_COUNTER{1'b0}};
		acum 		<= {NB_ADD{1'b0}};
		acum2		<= {NB_ADD - 1{1'b0}};
		y1			<= {NB_ADD + NB_COEFF{1'b0}};
		y2			<= {NB_ADD + NB_COEFF - 1{1'b0}};
		for(ptr1=1;ptr1<MAF1;ptr1=ptr1+1) begin:reiniciar
			r_xn[ptr1] <= {NB_SAMPLE{1'b0}};
			if(ptr1<MAF2)
				r_yn[ptr1] <= {NB_SAMPLE{1'b0}};
        end
	end
	
	else begin
	
		// 					Región 3kHz
		
		// Con esto fuerzo a que i_enable haga de clock
		if(i_enable && flag_enable) begin
		
			flag_enable <= 1'b0;
			op_count 	<= {NB_COUNTER{1'b0}}; // Reinicio contador de operaciones

			// Registro de desplazamiento de ambos filtros		
			for(ptr2=1;ptr2<MAF1;ptr2=ptr2+1) begin:actualizar
				if(ptr2==1) begin
				
					// Entrada primer MAF
					r_xn[ptr2] <= i_xn;
					// Entrada segundo MAF
					r_yn[ptr2] <= y1[NBF_SAMPLE+NBF_COEFF -: NB_SAMPLE];
				
				end
				
				else begin
				
					r_xn[ptr2] <= r_xn[ptr2-1];
					if(ptr2<MAF2)
						r_yn[ptr2] <= r_yn[ptr2-1]; // Registro las salidas del primer MAF
				
				end

			end
			
			y1 <= acum  * N1; // S(29,22) -> 7 bits enteros
		    y2 <= acum2 * N2; // S(28,22) -> 6 bits enteros
			
		end
		
		else if(!i_enable && !flag_enable)
			flag_enable <= 1'b1;
			
		//				Región 5.4MHz

		if(op_count<MAF1) begin
		
			op_count <= op_count + {{NB_COUNTER-1{1'b0}},{1'b1}}; // Incremento contador
					   
			if(op_count) begin

				acum <= acum + r_xn[op_count];
				
				if(op_count<MAF2) begin
				
					acum2 <= acum2 + r_yn[op_count];
				
				end

			end
			else begin
			
				acum <= {{NB_SAT{i_xn[NB_SAMPLE-1]}},{i_xn}}; 				// S(8,7) -> S(13,7) (Extiendo el signo)
				acum2 <= y1[NBF_SAMPLE+NBF_COEFF + NB_SAT-1 -: NB_ADD-1];	// S(28,22) -> S(12,7)
				
			end
		
		end

	end

end

// Sino hago esto no me hace el producto signado// Sino hago esto no me hace el producto signado
assign y2_aux = y2[NBF_SAMPLE+NBF_COEFF -: NB_COEFF];	// Estoy reduciendo y2 de S(28,22) a S(16,15)
assign y3 = y2_aux * CF; // S(16,15)*S(16,14) = S(32,29)

// Salida del filtro registrada
assign o_signal = y3[NB_COEFF + NB_COEFF-3-:NB_SAMPLE]; // S(16,15)

//assign o_signal = r_xn[1];

		
endmodule





