`include "const.vh"

module hdc_top
(
	// global ports
	input Clk_CI, Reset_RI, 

	// handshaking
	input ValidIn_SI, ReadyIn_SI,
	output ReadyOut_SO, ValidOut_SO,

	// inputs
	input [`MODE_WIDTH-1:0] ModeIn_SI,
	input [`LABEL_WIDTH-1:0] LabelIn_DI, 
	// input [`RAW_WIDTH*`INPUT_CHANNELS-1:0] Raw_DI,
    // make it compatible with ADC FIFO width
    input [0:`CHANNEL_WIDTH*`INPUT_CHANNELS-1] Raw_DI,

	// outputs
	output [`LABEL_WIDTH-1:0] LabelOut_DO,
	output [`DISTANCE_WIDTH-1:0] DistanceOut_DO,
    output [1023:0] Gest_Raw_Out,
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
	output spatial_ready_1, spatial_ready_2, spatial_ready_3, spatial_valid_1, spatial_valid_2, spatial_valid_3,
	// use same address for each iM, projM_neg and projM_pos for the corresponding modality
	output [`ceilLog2(`INPUT_CHANNELS)-1:0] addr_mod1, addr_mod2, addr_mod3
);

// feature -> spatial
//wire [959:0] Raw_DI_mapped;
wire Ready_FS, Valid_FS;
wire [`MODE_WIDTH-1:0] Mode_FS;
wire [`LABEL_WIDTH-1:0] Label_FS;
wire [`CHANNEL_WIDTH*`INPUT_CHANNELS-1:0] Channels_FS;

// spatial -> temporal
wire Ready_ST, Valid_ST;
wire [`MODE_WIDTH-1:0] Mode_ST;
wire [`LABEL_WIDTH-1:0] Label_ST;
wire [0:`HV_DIMENSION-1] Hypervector_ST;

// temporal -> AM
wire Ready_TA, Valid_TA;
wire [`MODE_WIDTH-1:0] Mode_TA;
wire [`LABEL_WIDTH-1:0] Label_TA;
wire [0:`HV_DIMENSION-1] Hypervector_TA;

reg [`LABEL_WIDTH-1:0] LabelOut;
reg [`DISTANCE_WIDTH-1:0] DistanceOut;

//generate
//	genvar j;
//	for (j=0; j < `INPUT_CHANNELS; j=j+1) begin
//		assign Raw_DI_mapped[(j+1)*15-1:j*15] = Raw_DI[(j+1)*16-2:j*16];
//	end
//endgenerate

assign Gest_Raw_Out = {Raw_DI[1023:32], {(16-`LABEL_WIDTH){1'b0}}, LabelOut, {(16-`DISTANCE_WIDTH){1'b0}}, DistanceOut};

always @(posedge Clk_CI) begin
	if (~Reset_RI) begin
		LabelOut <= {`LABEL_WIDTH{1'b0}};
		DistanceOut <= {`DISTANCE_WIDTH{1'b0}};
	end 
    else if (ValidOut_SO) begin
		LabelOut <= LabelOut_DO;
		DistanceOut <= DistanceOut_DO;
	end
    else begin
		LabelOut <= LabelOut;
		DistanceOut <= DistanceOut;
    end
end

//feature_encoder feature_encoder(
//	.Clk_CI        (Clk_CI),
//	.Reset_RI      (~Reset_RI),
//
//	.ValidIn_SI    (ValidIn_SI),
//	.ReadyOut_SO   (ReadyOut_SO),
//
//	.ValidOut_SO   (Valid_FS),
//	.ReadyIn_SI    (Ready_FS),
//
//	.ModeIn_SI     (ModeIn_SI),
//	.LabelIn_DI    (LabelIn_DI),
//	.Raw_DI        (Raw_DI_mapped),
//
//	.ModeOut_SO    (Mode_FS),
//	.LabelOut_DO   (Label_FS),
//	.ChannelsOut_DO(Channels_FS)
//	);

spatial_encoder spatial_encoder_mod1(
	.Clk_CI           (Clk_CI),
	.Reset_RI         (~Reset_RI),

	.ValidIn_SI    	  (ValidIn_SI),
	.ReadyOut_SO   	  (ReadyOut_SO),

	.ValidOut_SO      (Valid_ST),
	.ReadyIn_SI       (Ready_ST),

	.ModeIn_SI        (ModeIn_SI),
	.LabelIn_DI       (LabelIn_DI),
	.ChannelsInput_DI    (Raw_DI),

	.ModeOut_SO       (Mode_ST),
	.LabelOut_DO      (Label_ST),
	.HypervectorOut_DO(Hypervector_ST),
	.sram1_ready(sram1_ready),
	.sram1_valid(sram1_valid),
	.sram2_ready(sram2_ready), 
	.sram2_valid(sram2_valid),
	.sram3_ready(sram3_ready,
	.sram3_valid(sram3_valid,
	.sram4_ready(sram4_ready),
	.sram4_valid(sram4_valid),
	.sram5_ready(sram5_ready),
	.sram5_valid(sram5_valid), 
	.sram6_ready(sram6_ready), 
	.sram6_valid(sram6_valid),
	.sram7_ready(sram7_ready), 
	.sram7_valid(sram7_valid),
	.sram8_ready(sram8_ready),
	.sram8_valid(sram8_valid),
	.sram9_ready(sram9_ready),
	.sram9_valid(sram9_valid),
	.IMOut_mod1_D(IMOut_mod1_D),
	.IMOut_mod2_D(IMOut_mod2_D),
	.IMOut_mod3_D(IMOut_mod3_D),
	.projM_mod1_neg(projM_mod1_neg), 
	.projM_mod2_neg(projM_mod2_neg), 
	.projM_mod3_neg(projM_mod3_neg), 
	.projM_mod1_pos(projM_mod1_pos), 
	.projM_mod2_pos(projM_mod2_pos), 
	.projM_mod3_pos(projM_mod3_pos),
	.spatial_ready_1(spatial_ready_1),
	.spatial_ready_2(spatial_ready_2),
	.spatial_ready_3(spatial_ready_3),
	.spatial_valid_1(spatial_valid_1),
	.spatial_valid_2(spatial_valid_2),
	.spatial_valid_3(spatial_valid_3),
	.addr_mod1(addr_mod1), 
	.addr_mod2(addr_mod2), 
	.addr_mod3(addr_mod3)
	);


temporal_encoder temporal_encoder(
	.Clk_CI           (Clk_CI),
	.Reset_RI         (~Reset_RI),

	.ValidIn_SI    	  (Valid_ST),
	.ReadyOut_SO   	  (Ready_ST),

	.ValidOut_SO      (Valid_TA),
	.ReadyIn_SI       (Ready_TA),

	.ModeIn_SI        (Mode_ST),
	.LabelIn_DI       (Label_ST),
	.HypervectorIn_DI (Hypervector_ST),

	.ModeOut_SO       (Mode_TA),
	.LabelOut_DO      (Label_TA),
	.HypervectorOut_DO(Hypervector_TA)
	);

associative_memory associative_memory(
	.Clk_CI          (Clk_CI),
	.Reset_RI        (~Reset_RI),

	.ValidIn_SI      (Valid_TA),
	.ReadyOut_SO     (Ready_TA),

	.ValidOut_SO     (ValidOut_SO),
	.ReadyIn_SI      (ReadyIn_SI),

	.ModeIn_SI       (Mode_TA),
	.LabelIn_DI      (Label_TA),
	.HypervectorIn_DI(Hypervector_TA),

	.LabelOut_DO     (LabelOut_DO),
	.DistanceOut_DO  (DistanceOut_DO)
	);

endmodule











