module associate_memory_cmb_arc #
	(
	parameter LABEL_WIDTH = 8, //what is this
	parameter HV_DIMENSION = 8, //what is this
	parameter DISTANCE_WIDTH = 8, //what is this
	parameter CLASSES = 16, //what is this
	) 
	(
	input CLK_CI, Reset_RI, ValidIn_SI, ReadyIn_SI, 
	input [1:0] ModeIn_SI, 
	input [LABEL_WIDTH-1:0] LabelIn_DI, 
	input [0:HV_DIMENSION-1] HypervectorIn_DI,
	output ReadyOut_SO, ValidOut_SO,
	output [LABEL_WIDTH-1:0] LabelOut_DO,
	output [DISTANCE_WIDTH-1:0] DistanceOut_DO
	);

	reg [LABEL_WIDTH-1:0] LabelOut_DP, LabelOut_DN;
	reg [DISTANCE_WIDTH-1:0] DistanceOut_DP, DistanceOut_DN;
	reg [0:CLASSES-1][0:HV_DIMENSION-1] TrainedMemory_DP; 
	wire [0:CLASSES-1][0:HV_DIMENSION-1]TrainedMemory_DN;
	wire [0:HV_DIMENSION-1] QueryHypervector_DP, QueryHypervector_DN;
	reg [1:0] FSM_SP, FSM_SN;
	localparam 
		idle = 2'd0,
		distance_calculated = 2'd1,
		output_stable = 2'd3;
	reg [0:CLASSES-1][0:HV_DIMENSION-1] SimilarityOut_D;
	reg [0:CLASSES-1][DISTANCE_WIDTH-1:0] AdderOut_D;
	reg [DISTANCE_WIDTH-1:0] min_temp;
	reg [LABEL_WIDTH-1:0] label_temp;
	reg [0:CLASSES-1] IdentifyLabel_S;
	wire OutputBuffersEN_S;
	wire [0:CLASSES-1] TrainedMemoryEN_S;
	wire QueryHypervectorEN_S;
	//integer i, j, sum;
	integer j, sum;
	genvar i;

	//setup initial flip flop inputs 
	generate
		for (i=0; i<CLASSES; i = i+1) begin
			assign TrainedMemory_DN(i) = HypervectorIn_DI;
		end
	endgenerate
	
	assign QueryHypervector_DN = HypervectorIn_DI;

	//binding
	//setup initial flip flop inputs 
	generate
		for (i=0; i<CLASSES; i = i+1) begin
			assign SimilarityOut_D(i) = TrainedMemory_DP(i) ^ QueryHypervector_DP;
		end
	endgenerate

	//add
	generate
		for (i=0; i<CLASSES; i = i+1) begin
			always @ (SimilarityOut_D) begin
				sum = 0;
				for (j=0; j<HV_DIMENSION; j = j+1) begin
					if (SimilarityOut_D(i)(j) == 1'b1) begin
						sum = sum + 1;
					end
				end
				AdderOut_D(i) <= sum;
			end
		end
	endgenerate

	//comparison
	always @ (AdderOut_D) begin
		min_temp = AdderOut_D(0);
		label_temp = 0;
		for (i=0; i<CLASSES; i = i+1) begin
			if (AdderOut_D(i) < min_temp) begin
				min_temp = AdderOut_D(i);
				label_temp = i;
			end
		end
		LabelOut_DN = label_temp;
		DistanceOut_DN = min_temp;
	end

	//assign outputs
	assign LabelOut_DO = LabelOut_DP;
	assign DistanceOut_DO = DistanceOut_DP;

	//setup training vector select
	generate
		for (i=0; i<CLASSES; i = i+1) begin
			assign IdentifyLabel_S(i) = (LabelIn_DI == i) ? 1'b1 : 1'b0;
		end
	endgenerate

	//FSM
	always @ (FSM_SP, IdentifyLabel_S, ModeIn_SI, ReadyIn_SI, ValidIn_SI) begin
		FSM_SN <= idle;
		ReadyOut_SO <= 1'b0;
		ValidOut_SO <= 1'b0;
		OutputBuffersEN_S    <= 1'b0;
		TrainedMemoryEN_S    <= {CLASSES{1'b0}};
		QueryHypervectorEN_S <= 1'b0;
		case (FSM_SP) 

			idle: begin
				ReadyOut_SO = 1'b1;
				if (ValidIn_SI == 1'b0) begin
					FSM_SN <= idle;
				end
       			else if (ModeIn_SI == mode_train) begin
           			FSM_SN <= idle;
            		TrainedMemoryEN_S <= IdentifyLabel_S;
            	end
         		else begin
           			FSM_SN <= distance_calculated;
            		QueryHypervectorEN_S <= 1'b1;
            	end
			end

			distance_calculated: begin
				FSM_SN <= output_stable;
       			OutputBuffersEN_S <= 1'b1;
			end

			output_stable: begin
				FSM_SN = (ReadyIn_SI == 1'b0) ? output_stable : idle;
        		ValidOut_SO <= 1'b1;
			end

		endcase
	end


	//output flip flop
	always @ (posedge CLK_CI) begin
		if (Reset_RI == 1'b1) begin
			LabelOut_DP  <= {LABEL_WIDTH{1'b0}};
        	DistanceOut_DP <= {DISTANCE_WIDTH{1'b0}};
		end
		else if (OutputBuffersEN_S == 1'b1) begin
			LabelOut_DP  <= LabelOut_DN;
        	DistanceOut_DP <= DistanceOut_DN;
		end
	end

	//memory flip flop
	generate
		for (i=0; i<CLASSES; i = i+1) begin
			always @ (posedge CLK_CI) begin
				if (Reset_RI == 1'b1) begin
					TrainedMemory_DP(i) <= {HV_DIMENSION{1'b0}};
				end
				else if (TrainedMemoryEN_S(i) == 1'b1) begin
					TrainedMemory_DP <= TrainedMemory_DN;
				end
			end
		end
	endgenerate

	//input hypervector flip flop
	always @ (posedge CLK_CI) begin
		if (Reset_RI == 1'b1) begin
			QueryHypervector_DP <= {HV_DIMENSION{1'b0}};
		end
		else if (QueryHypervectorEN_S == 1'b1) begin
			QueryHypervector_DP <= QueryHypervector_DN;
		end
	end

	//FSM control
	always @ (posedge CLK_CI) begin
		if (Reset_RI == 1'b1) begin
			FSM_SP <= idle;
		end
		else begin
			FSM_SP <= FSM_SN;
		end
	end 

endmodule












