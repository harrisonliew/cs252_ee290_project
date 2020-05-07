`include "const.vh"

module associative_memory_late_basic_fix
(
	// global inputs
	input Clk_CI, Reset_RI, 

	// handshaking
	input ValidIn_SI, ReadyIn_SI, 
	output reg ReadyOut_SO, ValidOut_SO,

	// inputs
	input [0:`HV_DIMENSION-1] HypervectorIn_mod1_DI, HypervectorIn_mod2_DI, HypervectorIn_mod3_DI,
	
	// outputs
	output [`LABEL_WIDTH-1:0] LabelOut_A_DO, LabelOut_V_DO,
	output [`DISTANCE_WIDTH-1:0] DistanceOut_A_DO, DistanceOut_V_DO
);

localparam [0:`AM_WIDTH-1] AM_A = `AM_A;
localparam [0:`AM_WIDTH-1] AM_V = `AM_V;

reg [0:`HV_DIMENSION-1] AM_A_class_P;
reg [0:`HV_DIMENSION-1] AM_V_class_P;
reg [0:`HV_DIMENSION-1] AM_A_class_N;
reg [0:`HV_DIMENSION-1] AM_V_class_N;

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
reg [`DISTANCE_WIDTH-1:0] AdderOut_A_D_N, AdderOut_V_D_N;
wire CompRegisterSEN_A_S, CompRegisterSEN_V_S;
reg OutputBuffersEN_S, ShiftMemoryEN_S, QueryHypervectorEN_S, CompRegisterEN_S, CompRegisterCLR_S, ShiftCntrEN_S, ShiftCntrCLR_S, next_V_class, next_A_class, current_A_class, current_V_class;
wire ShiftComplete_S;

//Set next input data
assign QueryHypervector_DN  = (HypervectorIn_mod1_DI & HypervectorIn_mod2_DI) | (HypervectorIn_mod1_DI & HypervectorIn_mod3_DI) | (HypervectorIn_mod2_DI & HypervectorIn_mod3_DI);

// set next class
always @(*) begin
		if (ShiftCntr_SP == 2'd2)
			next_A_class <= 1'b0;
		else
			next_A_class <= 1'b1;
end
always @(*) begin
		if (ShiftCntr_SP == 2'd2)
			next_V_class <= 1'b0;
		else
			next_V_class <= 1'b1;
end

//generate classes in each AM
assign AM_A_class0 = AM_A[0:`HV_DIMENSION-1];
assign AM_A_class1 = AM_A[`HV_DIMENSION:`HV_DIMENSION+`HV_DIMENSION-1];

assign AM_V_class0 = AM_V[0:`HV_DIMENSION-1];
assign AM_V_class1 = AM_V[`HV_DIMENSION:`HV_DIMENSION+`HV_DIMENSION-1];

//Similarity depending on which class
assign SimilarityOut_A_D = (current_A_class) ? (AM_A_class1 ^ QueryHypervector_DP) : (AM_A_class0 ^ QueryHypervector_DP);
assign SimilarityOut_V_D = (current_V_class) ? (AM_V_class1 ^ QueryHypervector_DP) : (AM_V_class0 ^ QueryHypervector_DP);

//adders
integer j;
always @(*) begin
	AdderOut_A_D_N = {`DISTANCE_WIDTH{1'b0}};
	for (j=0; j<`HV_DIMENSION; j=j+1) begin
		AdderOut_A_D_N = AdderOut_A_D_N + SimilarityOut_A_D[j];
	end
end

integer y;
always @(*) begin
	AdderOut_V_D_N = {`DISTANCE_WIDTH{1'b0}};
	for (y=0; y<`HV_DIMENSION; y=y+1) begin
		AdderOut_V_D_N = AdderOut_V_D_N + SimilarityOut_V_D[j];
	end
end

//comparison
//Comparator Registers
assign CompLabel_A_DN = (ShiftCntr_SP == 2'd2) ? 1'b1 : 1'b0;
assign CompDistance_A_DN = AdderOut_A_D_N;

assign CompLabel_V_DN = (ShiftCntr_SP == 2'd2) ? 1'b1 : 1'b0;
assign CompDistance_V_DN = AdderOut_V_D_N;

// Comparison
assign CompRegisterSEN_A_S = AdderOut_A_D_N < CompDistance_A_DP;
assign CompRegisterSEN_V_S = AdderOut_V_D_N < CompDistance_V_DP;

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
assign ShiftCntr_SN = (ShiftCntr_SP == 2'd2) ? 2'd1 : 2'd0;
assign ShiftComplete_S = ShiftCntr_SP == 2'd0;


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
      			ShiftCntrEN_S = 1'b1;
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
	end 
	else if (OutputBuffersEN_S) begin
		LabelOut_A_DP  <= LabelOut_A_DN;
		LabelOut_V_DP  <= LabelOut_V_DN;
    	DistanceOut_A_DP <= DistanceOut_A_DN;
    	DistanceOut_V_DP <= DistanceOut_V_DN;
	end
	else begin
		LabelOut_A_DP  <= LabelOut_A_DP;
		LabelOut_V_DP  <= LabelOut_V_DP;
    	DistanceOut_A_DP <= DistanceOut_A_DP;
    	DistanceOut_V_DP <= DistanceOut_V_DP;
	end
end

//AM class 
always @ (posedge Clk_CI) begin
	if (Reset_RI||ShiftCntrCLR_S) begin
		current_V_class <= 1'b1;
		current_A_class <= 1'b1;
	end
	else if (ShiftMemoryEN_S) begin
		current_A_class <= next_A_class;
		current_V_class <= next_V_class;
	end
	else begin
		current_A_class <= current_A_class;
		current_V_class <= current_V_class;
	end
end

// input data
always @ (posedge Clk_CI) begin
	if (Reset_RI) begin
		QueryHypervector_DP = {`HV_DIMENSION{1'b0}}
	end
	else if (QueryHypervectorEN_S) begin
		QueryHypervector_DP = QueryHypervector_DN;
	end
	else begin
		QueryHypervector_DP = QueryHypervector_DP;
	end
end

// comparator registers
always @ (posedge Clk_CI) begin
	if (Reset_RI || CompRegisterCLR_S) begin
		CompDistance_A_DP <= {`DISTANCE_WIDTH{1'b1}};
		CompDistance_V_DP <= {`DISTANCE_WIDTH{1'b1}};
    	CompLabel_A_DP <= 1'b1;
    	CompLabel_V_DP <= 1'b1;
	end 
	else if (CompRegisterSEN_A_S && CompRegisterEN_S) begin
		CompDistance_A_DP <= CompDistance_A_DN;
		CompLabel_A_DP <= CompLabel_A_DN;
	end
	else if (CompRegisterSEN_V_S && CompRegisterEN_S) begin
		CompDistance_V_DP <= CompDistance_V_DN;
    	CompLabel_V_DP <= CompLabel_V_DN;
    end
    else begin
    	CompDistance_A_DP <= CompDistance_A_DP;
		CompDistance_V_DP <= CompDistance_V_DP;
    	CompLabel_A_DP <= CompLabel_A_DP;
    	CompLabel_V_DP <= CompLabel_V_DP;
    end
end

// rotating memory counter register
always @ (posedge Clk_CI) begin
	if (Reset_RI || ShiftCntrCLR_S)
		ShiftCntr_SP <= 2'd2;
	else if (ShiftCntrEN_S)
		ShiftCntr_SP <= ShiftCntr_SN;
	else
		ShiftCntr_SP <= ShiftCntr_SP;
end


// FSM transition register
always @ (posedge Clk_CI) begin
	if (Reset_RI)
		prev_state <= IDLE;
	else
		prev_state <= next_state;
end 

endmodule











