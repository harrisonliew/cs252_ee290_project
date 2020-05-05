`include "const.vh"

module associative_memory
(
	// global inputs
	input Clk_CI, Reset_RI, 

	// handshaking
	input ValidIn_SI, ReadyIn_SI, 
	output reg ReadyOut_SO, ValidOut_SO,

	// inputs
	input [0:`HV_DIMENSION-1] HypervectorIn_DI,
	
	// outputs
	output [`LABEL_WIDTH-1:0] LabelOut_A_DO, LabelOut_V_DO,
	output [`DISTANCE_WIDTH-1:0] DistanceOut_A_DO, DistanceOut_V_DO
);

localparam [0:`AM_WIDTH-1] AM_A = `AM_A;
localparam [0:`AM_WIDTH-1] AM_V = `AM_V;

reg [0:`HV_DIMENSION-1] AM_A_class_P;
reg [0:`HV_DIMENSION-1] AM_V_class_P;
wire [0:`HV_DIMENSION-1] AM_A_class_N;
wire [0:`HV_DIMENSION-1] AM_V_class_N;

// output buffers
reg [`LABEL_WIDTH-1:0] LabelOut_A_DP, LabelOut_V_DP;
wire [`LABEL_WIDTH-1:0] LabelOut_A_DN, LabelOut_V_DN;
reg [`DISTANCE_WIDTH-1:0] DistanceOut_A_DP, DistanceOut_V_DP;
wire [`DISTANCE_WIDTH-1:0] DistanceOut_A_DN, DistanceOut_V_DN;

// data registers
reg [0:`HV_DIMENSION-1] QueryHypervector_DP;
wire [0:`HV_DIMENSION-1] QueryHypervector_DN;

reg [`DISTANCE_WIDTH-1:0] CompDistance_A_DP, CompDistance_V_DP;
wire [`DISTANCE_WIDTH-1:0] CompDistance_A_DN, CompDistance_V_DN;

reg [`LABEL_WIDTH-1:0] CompLabel_A_DP, CompLabel_V_DP;
wire [`LABEL_WIDTH-1:0] CompLabel_A_DN, CompLabel_V_DN;


// FSM state definitions and control signals
reg [1:0] prev_state, next_state;
localparam IDLE = 2'd0;
localparam FIND_MIN_DIST = 2'd1;
localparam OUTPUT_STABLE = 2'd2;
localparam classes_p1 = `CLASSES+1;
localparam SHIFT_CNTR_WIDTH = `ceilLog2(classes_p1);

// shift counter
reg [SHIFT_CNTR_WIDTH-1:0] ShiftCntr_SP; 
wire [SHIFT_CNTR_WIDTH-1:0] ShiftCntr_SN;

// Datapath signals
wire [0:`HV_DIMENSION-1] SimilarityOut_A_D, SimilarityOut_V_D, AM_A_class0, AM_A_class1, AM_V_class0, AM_V_class1;
reg [`DISTANCE_WIDTH-1:0] AdderOut_A_D, AdderOut_V_D;
wire CompRegisterSEN_A_S, CompRegisterSEN_V_S;
reg OutputBuffersEN_S, ShiftMemoryEN_S, QueryHypervectorEN_S, CompRegisterEN_S, CompRegisterCLR_S, ShiftCntrEN_S, ShiftCntrCLR_S;
wire ShiftComplete_S; 
wire [12:0] shift_start, shift_end;


//rotating memory
//always @(*) begin
//		TrainedMemory_DN[0] = TrainedMemory_DP[`CLASSES-1];
//		LabelMemory_DN[0] = LabelMemory_DP[`CLASSES-1];
//end

//trained and label memory shift register
//generate
//	for (i=1; i<`CLASSES; i=i+1) begin
//		always @(*) begin
//			TrainedMemory_DN[i] = TrainedMemory_DP[i-1];
//			LabelMemory_DN[i] = LabelMemory_DP[i-1];
//		end
//	end
//endgenerate

//Set next input data
assign QueryHypervector_DN = HypervectorIn_DI;

reg [0:`HV_DIMENSION-1] next_A_class, next_V_class;
always @(*) begin
	if (ShiftComplete_S)
		next_A_class <= AM_A_class_P;
	else begin
		if (ShiftCntr_SP == 1'b1)
			next_A_class <= AM_A_class1;
		else
			next_A_class <= AM_A_class0;
	end
end

always @(*) begin
	if (ShiftComplete_S)
		next_V_class <= AM_V_class_P;
	else begin
		if (ShiftCntr_SP == 1'b1)
			next_V_class <= AM_V_class1;
		else
			next_V_class <= AM_V_class0;
	end
end

//assign shift_start = (ShiftCntr_SP-1)*`HV_DIMENSION;
//assign shift_end = (ShiftCntr_SP-1)*`HV_DIMENSION+`HV_DIMENSION-1;

assign AM_A_class0 = AM_A[0:`HV_DIMENSION-1];
assign AM_A_class1 = AM_A[`HV_DIMENSION:`HV_DIMENSION+`HV_DIMENSION-1];

assign AM_V_class0 = AM_V[0:`HV_DIMENSION-1];
assign AM_V_class1 = AM_V[`HV_DIMENSION:`HV_DIMENSION+`HV_DIMENSION-1];
//A
//Set next class
assign AM_A_class_N = next_A_class;
//Similarity
assign SimilarityOut_A_D = AM_A_class_P ^ QueryHypervector_DP;

//V
//Set next class
assign AM_V_class_N = next_V_class;
//Similarity
assign SimilarityOut_V_D = AM_V_class_P ^ QueryHypervector_DP;

//adders
integer j;
always @(*) begin
	AdderOut_A_D = {`DISTANCE_WIDTH{1'b0}};
	for (j=0; j<`HV_DIMENSION; j=j+1) begin
		AdderOut_A_D = AdderOut_A_D + SimilarityOut_A_D[j];
	end
end

integer y;
always @(*) begin
	AdderOut_V_D = {`DISTANCE_WIDTH{1'b0}};
	for (y=0; y<`HV_DIMENSION; j=j+1) begin
		AdderOut_V_D = AdderOut_V_D + SimilarityOut_V_D[j];
	end
end

//comparison
//Comparator Registers
assign CompLabel_A_DN = ShiftCntr_SP-1;
assign CompDistance_A_DN = AdderOut_A_D;

assign CompLabel_V_DN = ShiftCntr_SP-1;
assign CompDistance_V_DN = AdderOut_V_D;

// Comparison
assign CompRegisterSEN_A_S = (CompDistance_A_DN < CompDistance_A_DP);
assign CompRegisterSEN_V_S = (CompDistance_V_DN < CompDistance_V_DP);

//Output Buffers
assign LabelOut_A_DN = CompLabel_A_DP;
assign DistanceOut_A_DN = CompDistance_A_DP;
assign LabelOut_V_DN = CompLabel_V_DP;
assign DistanceOut_V_DN = CompDistance_V_DP;

//output signals
assign LabelOut_A_DO = LabelOut_A_DP;
assign DistanceOut_A_DO = DistanceOut_A_DP;
assign LabelOut_V_DO = LabelOut_V_DP;
assign DistanceOut_V_DO = DistanceOut_V_DP;

// Shift counter
assign ShiftCntr_SN = ShiftCntr_SP - 1;
assign ShiftComplete_S = ~|ShiftCntr_SP;

//FSM
always @(*) begin
	//Default Assignments
	next_state = IDLE;

	ReadyOut_SO = 1'b0;
	ValidOut_SO = 1'b0;

	OutputBuffersEN_S    	= 1'b0;
	ShiftMemoryEN_S      	= 1'b0;
	QueryHypervectorEN_S 	= 1'b0;
	CompRegisterEN_S     	= 1'b0;
	CompRegisterCLR_S    	= 1'b0;
	ShiftCntrEN_S       	= 1'b0;
	ShiftCntrCLR_S       	= 1'b0;

	case (prev_state)
		IDLE: begin
			ReadyOut_SO = 1'b1;
			if (ValidIn_SI == 1'b0) begin
				next_state = IDLE;
			end else begin
   				next_state = FIND_MIN_DIST;
      			QueryHypervectorEN_S = 1'b1;
        	end
		end
		FIND_MIN_DIST: begin
			if (ShiftComplete_S == 1'b0) begin
      			next_state = FIND_MIN_DIST;
      			ShiftMemoryEN_S  = 1'b1;
      			CompRegisterEN_S = 1'b1;
      			ShiftCntrEN_S    = 1'b1;
      		end else begin
      			next_state = OUTPUT_STABLE;
      			OutputBuffersEN_S = 1'b1;
      			CompRegisterCLR_S = 1'b1;
      			ShiftCntrCLR_S    = 1'b1;
    		end
		end
		OUTPUT_STABLE: begin
			next_state = (ReadyIn_SI) ? IDLE : OUTPUT_STABLE;
    		ValidOut_SO = 1'b1;
		end

	endcase
end

//Memories
//Output buffers
always @ (posedge Clk_CI) begin
	if (Reset_RI) begin
		LabelOut_A_DP  <= {`LABEL_WIDTH{1'b0}};
		LabelOut_V_DP  <= {`LABEL_WIDTH{1'b0}};
    	DistanceOut_A_DP <= {`DISTANCE_WIDTH{1'b0}};
    	DistanceOut_V_DP <= {`DISTANCE_WIDTH{1'b0}};
	end else if (OutputBuffersEN_S) begin
		LabelOut_A_DP  <= LabelOut_A_DN;
		LabelOut_V_DP  <= LabelOut_V_DN;
    	DistanceOut_A_DP <= DistanceOut_A_DN;
    	DistanceOut_V_DP <= DistanceOut_V_DN;
	end
end

//AM class 
always @(posedge Clk_CI) begin
	if (Reset_RI) 
		AM_A_class_P = {`HV_DIMENSION{1'b0}};
	else if(ShiftMemoryEN_S == 1'b1)
		AM_A_class_P = AM_A_class_N;
end

always @(posedge Clk_CI) begin
	if (Reset_RI) 
		AM_V_class_P = {`HV_DIMENSION{1'b0}};
	else if(ShiftMemoryEN_S == 1'b1)
		AM_V_class_P = AM_V_class_N;
end

// query hypervector register
always @ (posedge Clk_CI) begin
	if (Reset_RI) 
		QueryHypervector_DP <= {`HV_DIMENSION{1'b0}};
	else if (QueryHypervectorEN_S)
		QueryHypervector_DP <= QueryHypervector_DN;
end

// comparator registers
always @ (posedge Clk_CI) begin
	if (Reset_RI || CompRegisterCLR_S) begin
		CompDistance_A_DP <= {`DISTANCE_WIDTH{1'b1}};
		CompDistance_V_DP <= {`DISTANCE_WIDTH{1'b1}};
    	CompLabel_A_DP <= {`LABEL_WIDTH{1'b0}};
    	CompLabel_V_DP <= {`LABEL_WIDTH{1'b0}};
	end else if (CompRegisterEN_S) begin
		if (CompRegisterSEN_A_S) begin
			CompDistance_A_DP <= CompDistance_A_DN;
			CompLabel_A_DP <= CompLabel_A_DN;
		end
		if (CompRegisterSEN_V_S) begin
			CompDistance_V_DP <= CompDistance_V_DN;
    		CompLabel_V_DP <= CompLabel_V_DN;
    	end
	end
end

// rotating memory counter register
always @ (posedge Clk_CI) begin
	if (Reset_RI || ShiftCntrCLR_S)
		ShiftCntr_SP <= `CLASSES;
	else if (ShiftCntrEN_S)
		ShiftCntr_SP <= ShiftCntr_SN;
end

// FSM transition register
always @ (posedge Clk_CI) begin
	if (Reset_RI)
		prev_state <= IDLE;
	else
		prev_state <= next_state;
end 

endmodule












