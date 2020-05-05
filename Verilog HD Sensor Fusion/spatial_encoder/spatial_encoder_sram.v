`include "const.vh"

module spatial_encoder
(
	// global ports
	input Clk_CI, Reset_RI, 

	// handshaking
	input ValidIn_SI, ReadyIn_SI,
	output reg ReadyOut_SO, ValidOut_SO,

	// inputs
	input [`MODE_WIDTH-1:0] ModeIn_SI,
	input [`LABEL_WIDTH-1:0] LabelIn_DI, 
	input [0:`CHANNEL_WIDTH*`INPUT_CHANNELS-1] ChannelsInput_DI,

	// outputs
	output [`MODE_WIDTH-1:0] ModeOut_SO,
	output [`LABEL_WIDTH-1:0] LabelOut_DO,
	output [0:`HV_DIMENSION-1] HypervectorOut_DO,

	//SRAM
	//sram1 = iM1, modality 1 - IMOut_mod1_D
	//sram2 = projm1_neg, modality 1 - projM_mod1_neg
	//sram3 = projm1_pos, modality 1 - projM_mod1_pos
	//sram4 = iM2, modality 2 - IMOut_mod2_D
	//sram5 = projm2_neg, modality 2 - projM_mod2_neg
	//sram6 = projm2_pos, modality 2 - projM_mod2_pos
	//sram7 = iM3, modality 3 - IMOut_mod3_D
	//sram8 = projm3_neg, modality 3 - projM_mod3_neg
	//sram9 = projm3_pos, modality 3 - projM_mod3_pos
	input sram1_ready, sram1_valid,
	input sram2_ready, sram2_valid,
	input sram3_ready, sram3_valid,
	input sram4_ready, sram4_valid,
	input sram5_ready, sram5_valid, 
	input sram6_ready, sram6_valid,
	input sram7_ready, sram7_valid,
	input sram8_ready, sram8_valid,
	input sram9_ready, sram9_valid,
	input [0:`HV_DIMENSION-1] IMOut_mod1_D, IMOut_mod2_D, IMOut_mod3_D,
	input [0:`HV_DIMENSION-1] projM_mod1_neg, projM_mod2_neg, projM_mod3_neg, 
	input [0:`HV_DIMENSION-1] projM_mod1_pos, projM_mod2_pos, projM_mod3_pos,
	// spatial encoder ready and valid signals, 1 for each modality
	output spatial_ready_1, spatial_ready_2, spatial_ready_3,
	output spatial_valid_1, spatial_valid_2, spatial_valid_3,
	// use same address for each iM, projM_neg and projM_pos for the corresponding modality
	output [`ceilLog2(`INPUT_CHANNELS)-1:0] addr_mod1, addr_mod2, addr_mod3
);

// FSM state definitions
localparam IDLE = 0;
localparam DATA_RECEIVED = 1;
localparam ACCUM_FED = 2;
localparam CHANNELS_MAPPED = 3;

// FSM and control signals
reg [1:0] prev_state, next_state;
reg InputBuffersEN_S, AccumulatorEN_mod1_S, AccumulatorEN_mod2_S, AccumulatorEN_mod3_S, CellAutoEN_S, CellAutoCLR_S, CycleCntrEN_S, CycleCntrCLR_S;
reg FirstHypervector_S;
wire LastChannel_S;
wire sram_mod1_valid, sram_mod2_valid, sram_mod3_valid;
reg mod1_valid, mod2_valid, mod3_valid;

// Cycle (channel) counter
reg [`ceilLog2(`INPUT_CHANNELS)-1:0] CycleCntr_SP;
wire [`ceilLog2(`INPUT_CHANNELS)-1:0] CycleCntr_SN;

// datapath internal wires
wire [`MODE_WIDTH-1:0] ModeIn_SN;
wire [`LABEL_WIDTH-1:0] LabelIn_DN;
wire [`CHANNEL_WIDTH-1:0] ChannelsIn_DN [0:`INPUT_CHANNELS-1];

reg [`MODE_WIDTH-1:0] ModeIn_SP;
reg [`LABEL_WIDTH-1:0] LabelIn_DP;
reg [`CHANNEL_WIDTH-1:0] ChannelsIn_DP [0:`INPUT_CHANNELS-1];

wire [`CHANNEL_WIDTH-1:0] ChannelFeature_mod1_D, ChannelFeature_mod2_D, ChannelFeature_mod3_D;

//wire [0:`HV_DIMENSION-1] IMOut_mod1_D, IMOut_mod2_D, IMOut_mod3_D;
//wire [0:`HV_DIMENSION-1] projM_mod1_neg, projM_mod1_pos, projM_mod2_neg, projM_mod2_pos, projM_mod3_neg, projM_mod3_pos;
wire [0:`HV_DIMENSION-1] HypervectorOut_mod1_DO, HypervectorOut_mod2_DO, HypervectorOut_mod3_DO;
wire xor_mod1_final, xor_mod2_final, xor_mod3_final, store_second;

wire [`ceilLog2(`INPUT_CHANNELS)-1:0] addr_mod1;
wire [`ceilLog2(`INPUT_CHANNELS)-1:0] addr_mod2;
wire [`ceilLog2(`INPUT_CHANNELS)-1:0] addr_mod3;

// DATAPATH

// latch input signals
assign ModeIn_SN = ModeIn_SI;
assign LabelIn_DN = LabelIn_DI;

// assign ChannelsIn_DN = ChannelsIn_DI;
genvar j;
generate
	for (j=0; j<`INPUT_CHANNELS; j=j+1) begin
		assign ChannelsIn_DN[j] = ChannelsInput_DI[(`CHANNEL_WIDTH*j):(`CHANNEL_WIDTH-1+(`CHANNEL_WIDTH*j))];
	end
endgenerate

//registers for training/inference mode, training label, and incoming data
integer i;
always @(posedge Clk_CI) begin
	if (Reset_RI) begin
		ModeIn_SP <= {`MODE_WIDTH{1'b0}};
		LabelIn_DP <= {`LABEL_WIDTH{1'b0}};
		for (i=0; i < `INPUT_CHANNELS; i=i+1) ChannelsIn_DP[i] <= {`CHANNEL_WIDTH{1'b0}};
	end else if (InputBuffersEN_S) begin
		ModeIn_SP <= ModeIn_SN;
		LabelIn_DP <= LabelIn_DN;
		for (i=0; i < `INPUT_CHANNELS; i=i+1) ChannelsIn_DP[i] <= ChannelsIn_DN[i];
	end
end


assign addr_mod1 = cycle_count;
assign addr_mod2 = cycle_count + `FIRST_MODALITY_CHANNELS;
assign addr_mod3 = cycle_count + `FIRST_MODALITY_CHANNELS + `SECOND_MODALITY_CHANNELS;

// get current feature value
assign ChannelFeature_mod1_D = ChannelsIn_DP[addr_mod1];
assign ChannelFeature_mod2_D = ChannelsIn_DP[addr_mod2];
assign ChannelFeature_mod3_D = ChannelsIn_DP[addr_mod3];

assign sram_mod1_valid = sram1_valid && sram2_valid && sram3_valid;
assign sram_mod2_valid = sram4_valid && sram5_valid && sram6_valid;
assign sram_mod3_valid = sram7_valid && sram8_valid && sram9_valid;


// cellular automaton
//cellular_automaton Cell_Auto(
//	.Clk_CI(Clk_CI),
//	.Reset_RI(Reset_RI),
//	.Enable_SI(CellAutoEN_S),
//	.Clear_SI(CellAutoCLR_S),
//	.CellValueOut_DO(IMOut_D),
//	.projM_neg(projM_neg),
//	.projM_pos(projM_pos)
//);

//somehow get projM_pos, projM_neg and IMout_D from this block
//channel_vectors_retr channel_vectors_retr(
	//.Clk_CI(Clk_CI),
	//.Reset_RI(Reset_RI),
	//.Enable_SI(CellAutoEN_S),
	//.Clear_SI(CellAutoCLR_S),
//	.channel_mod1.(addr_mod1),
//	.channel_mod2.(addr_mod2),
//	.channel_mod3.(addr_mod3),
//	.CellValueOut_mod1_DO(IMOut_mod1_D),
//	.projM_mod1_neg(projM_mod1_neg),
//	.projM_mod1_pos(projM_mod1_pos),
//	.CellValueOut_mod2_DO(IMOut_mod2_D),
//	.projM_mod2_neg(projM_mod2_neg),
//	.projM_mod2_pos(projM_mod2_pos),
//	.CellValueOut_mod3_DO(IMOut_mod3_D),
//	.projM_mod3_neg(projM_mod3_neg),
//	.projM_mod3_pos(projM_mod3_pos)
	//.cycle_count(CycleCntr_SP)
//);

// accumulator
spatial_accumulator Spat_Accum_mod1(
	.Clk_CI(Clk_CI),
	.Reset_RI(Reset_RI),
	.Enable_SI(AccumulatorEN_mod1_S),
	.xor_final(xor_mod1_final),
	.store_second(store_second)
	.FirstHypervector_SI(FirstHypervector_S),
	.HypervectorIn_DI(IMOut_mod1_D),
	.projM_negIN(projM_mod1_neg),
	.projM_posIN(projM_mod1_pos),
	.FeatureIn_DI(ChannelFeature_mod1_D),
	.HypervectorOut_DO(HypervectorOut_mod1_DO),
);

spatial_accumulator Spat_Accum_mod2(
	.Clk_CI(Clk_CI),
	.Reset_RI(Reset_RI),
	.Enable_SI(AccumulatorEN_mod2_S),
	.xor_final(xor_mod2_final),
	.store_second(store_second)
	.FirstHypervector_SI(FirstHypervector_S),
	.HypervectorIn_DI(IMOut_mod2_D),
	.projM_negIN(projM_mod2_neg),
	.projM_posIN(projM_mod2_pos),
	.FeatureIn_DI(ChannelFeature_mod2_D),
	.HypervectorOut_DO(HypervectorOut_mod2_DO),
);

spatial_accumulator Spat_Accum_mod3(
	.Clk_CI(Clk_CI),
	.Reset_RI(Reset_RI),
	.Enable_SI(AccumulatorEN_mod3_S),
	.xor_final(xor_mod3_final),
	.store_second(store_second)
	.FirstHypervector_SI(FirstHypervector_S),
	.HypervectorIn_DI(IMOut_mod3_D),
	.projM_negIN(projM_mod3_neg),
	.projM_posIN(projM_mod3_pos),
	.FeatureIn_DI(ChannelFeature_mod3_D),
	.HypervectorOut_DO(HypervectorOut_mod3_DO),
);

genvar k;
for (k=0; k<`HV_DIMENSION; k=k+1) begin
	//take majority of 3 modalities
	assign HypervectorOut_DO[k]  = (HypervectorOut_mod1_DO[k] && HypervectorOut_mod2_DO[k]) || (HypervectorOut_mod1_DO[k] && HypervectorOut_mod3_DO[k]) || (HypervectorOut_mod2_DO[k] && HypervectorOut_mod3_DO[k]);
end


assign ModeOut_SO = ModeIn_SP;
assign LabelOut_DO = LabelIn_DP;

// CONTROLLER
// signals for looping through channels
assign LastChannel_S = (CycleCntr_SP == `THIRD_MODALITY_CHANNELS-1);
assign CycleCntr_SN = CycleCntr_SP + 1;
// Want to store channel into second_channel register on either 2nd channel, 34th channel, or 111th channel
//assign store_second = (CycleCntr_SP == {`ceilLog2(`INPUT_CHANNELS)-1{1'b0},1'b1} || CycleCntr_SP == {`ceilLog2(`INPUT_CHANNELS)-6{1'b0},6'b100001} || CycleCntr_SP == {`ceilLog2(`INPUT_CHANNELS)-7{1'b0},7'b1101110} )
assign store_second = (CycleCntr_SP == {`ceilLog2(`INPUT_CHANNELS)-1{1'b0},1'b1});
// Want to XOR and add into accumulation on 32nd channel, 109th channel or 214th channel
assign xor_mod1_final = (CycleCntr_SP == {`ceilLog2(`INPUT_CHANNELS)-5{1'b0},5'b11111});
assign xor_mod2_final = (CycleCntr_SP == {`ceilLog2(`INPUT_CHANNELS)-7{1'b0},7'b1101100});
assign xor_mod3_final = (CycleCntr_SP == {`ceilLog2(`INPUT_CHANNELS)-8{1'b0},8'b11010101});

//modalities enabled until final channel for that modality
assign mod1_run = (CycleCntr_SP <= {`ceilLog2(`INPUT_CHANNELS)-5{1'b0},5'b11111});
assign mod2_run = (CycleCntr_SP <= {`ceilLog2(`INPUT_CHANNELS)-7{1'b0},7'b1101100});
assign mod3_run = (CycleCntr_SP <= {`ceilLog2(`INPUT_CHANNELS)-8{1'b0},8'b11010101});

//enable each modality
assign AccumulatorEN_mod1_S = AccumulatorEN_S && mod1_run;
assign AccumulatorEN_mod2_S = AccumulatorEN_S && mod2_run;
assign AccumulatorEN_mod2_S = AccumulatorEN_S && mod3_run;

//set valid and ready for specific modalities
assign spatial_valid_1 = spatial_valid && mod1_run;
assign spatial_valid_2 = spatial_valid && mod2_run;
assign spatial_valid_3 = spatial_valid && mod3_run;
assign spatial_ready_1 = spatial_ready && mod1_run;
assign spatial_ready_2 = spatial_ready && mod2_run;
assign spatial_ready_3 = spatial_ready && mod3_run;


// FSM
always @(*) begin
	// default values
	next_state = IDLE;
	
	ReadyOut_SO = 1'b0;
	ValidOut_SO = 1'b0;

	InputBuffersEN_S = 1'b0;
	AccumulatorEN_S = 1'b0;
	CellAutoEN_S = 1'b0;
	CellAutoCLR_S = 1'b0;
	CycleCntrEN_S = 1'b0;
	CycleCntrCLR_S = 1'b0;

	FirstHypervector_S = 1'b0;

	case (prev_state)
		IDLE: begin
			next_state = ValidIn_SI ? DATA_RECEIVED : IDLE;
			ReadyOut_SO = 1;
			InputBuffersEN_S = ValidIn_SI ? 1'b1 : 1'b0;
		end
		DATA_RECEIVED: begin
			spatial_valid = 1'b1;
			spatial_ready = 1'b1;
			if (mod1_valid && mod2_valid && mod3_valid) begin
				AccumulatorEN_S = 1'b1;
				CellAutoEN_S = 1'b1;
				CycleCntrEN_S = 1'b1;
				FirstHypervector_S = 1'b1;
				next_state = ACCUM_FED;
			end
			else begin
				next_state = DATA_RECEIVED
			end
		end
		ACCUM_FED: begin
			spatial_valid = 1'b1;
			spatial_ready = 1'b1;
			if (mod1_valid && mod2_valid && mod3_valid) begin
				AccumulatorEN_S = 1'b1;
				if (LastChannel_S) begin
					CellAutoCLR_S = 1'b1;
					CycleCntrCLR_S  = 1'b1;
				end else begin
					CellAutoEN_S = 1'b1;
					CycleCntrEN_S = 1'b1;
				end
				next_state = LastChannel_S ? CHANNELS_MAPPED : ACCUM_FED;
			end
			else begin
				next_state = ACCUM_FED;
			end
		end
		CHANNELS_MAPPED: begin
			next_state = ReadyIn_SI ? IDLE : CHANNELS_MAPPED;
			ValidOut_SO = 1'b1;
		end
		default: ;
	endcase // prev_state
end

//for sram, if the sram is valid and the modality is used, then valid, if the modality is used and sram is not valid, then not valid, if modality is not used, just go ahead, valid
always @ (*) begin
	if (mod1_run) begin
		if (sram_mod1_valid)
			mod1_valid = 1'b1;
		else
			mod1_valid = 1'b0;
	end
	else
		mod1_valid = 1'b1;
end
always @ (*) begin
	if (mod2_run) begin
		if (sram_mod2_valid)
			mod2_valid = 1'b1;
		else
			mod2_valid = 1'b0;
	end
	else
		mod2_valid = 1'b1;
end
always @ (*) begin
	if (mod3_run) begin
		if (sram_mod3_valid)
			mod3_valid = 1'b1;
		else
			mod3_valid = 1'b0;
	end
	else
		mod3_valid = 1'b1;
end

// FSM state transitions
always @(posedge Clk_CI) begin
	if (Reset_RI)
		prev_state <= IDLE;
	else
		prev_state <= next_state;
end

// Cycle (channel) counter
always @(posedge Clk_CI) begin
	if (Reset_RI || CycleCntrCLR_S) 
		CycleCntr_SP <= {`ceilLog2(`INPUT_CHANNELS){1'b0}};
	else if (CycleCntrEN_S)
		CycleCntr_SP <= CycleCntr_SN;
end

endmodule






