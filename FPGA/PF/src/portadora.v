module portadora
				#(
					parameter NB_DATA 	= 16,	// 16-bit la portadora S(16,15)
					parameter NB_COUNT	= 5 ,	// 2^5=32 -> cuenta hasta NB_SAMPLE
					parameter NB_SAMPLE	= 30
				)
				(
                 i_clock,
                 i_reset,
				 i_enable,
                 o_signal                 
                 );


   localparam MEM_INIT_FILE = "triang30.hex";
   

   // Ports
   output [NB_DATA - 1 : 0] o_signal;
   reg    [NB_DATA - 1 : 0] w_signal;
   input                    i_clock;	// 5.4MHz
   input                    i_reset;
   input					i_enable;	// 225kHz

   // Vars
   reg [NB_COUNT - 1 : 0] counter; 				// Solo necesito 5 bits para direccionar 30 muestras
   reg [NB_DATA  - 1 : 0] data[NB_SAMPLE-1:0]/*synthesis syn_romstyle="distributed_rom"*/; 	// 30 muestras en memoria de 16 bits c/u
   
   // Controla el clock proveniente de i_enable
	reg flag_enable;

  initial begin
    if (MEM_INIT_FILE != "") begin
      $readmemh(MEM_INIT_FILE, data);
    end
  end

   always@(posedge i_clock or posedge i_reset) begin

      if(i_reset) begin
		 flag_enable <= 1'b0;
         counter  <= {NB_COUNT{1'b0}};
	  end
      else begin
	  
		// Con esto fuerzo a que i_enable haga de clock
		if(i_enable && flag_enable) begin
		
		flag_enable <= 1'b0;
		
			if(counter<NB_SAMPLE) 
				counter  <= counter + {{NB_COUNT-1{1'b0}},{1'b1}};
			else
				counter  <= {NB_COUNT{1'b0}};
		
		end
		
		else if(!i_enable && !flag_enable)
			flag_enable <= 1'b1;
	  
	  end

   end

   assign o_signal = w_signal;
   
	always@(*) begin
	
		if(counter<NB_SAMPLE)
			w_signal = data[counter];
		else
			w_signal = data[0];
	
	end

endmodule



