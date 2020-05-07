`include "const.vh"

module hdc_top_late
(
	// global ports
	input Clk_CI, Reset_RI, 

	// handshaking
	input ValidIn_SI, ReadyIn_SI,
	output ReadyOut_SO, ValidOut_SO,

	// inputs
	input [0:`CHANNEL_WIDTH*`INPUT_CHANNELS-1] Raw_DI,

	// outputs
    input sram1_ready, sram1_valid,
	input sram2_ready, sram2_valid,
	input sram3_ready, sram3_valid,
	input sram4_ready, sram4_valid,
	input sram5_ready, sram5_valid, 
	input sram6_ready, sram6_valid,
	input sram7_ready, sram7_valid,
	input sram8_ready, sram8_valid,
	input sram9_ready, sram9_valid,
	input [0:`HV_DIMENSION-1] IMOut_mod3_D,
	input [0:`HV_DIMENSION-1] projM_mod3_neg, 
	input [0:`HV_DIMENSION-1] projM_mod3_pos,
	output spatial_ready_1, spatial_ready_2, spatial_ready_3, spatial_valid_1, spatial_valid_2, spatial_valid_3,
	output [7:0] sram_addr,
	output [`LABEL_WIDTH-1:0] LabelOut_A_DO, LabelOut_V_DO,
	output [`DISTANCE_WIDTH-1:0] DistanceOut_A_DO, DistanceOut_V_DO,
);

// spatial -> temporal
wire Ready_ST, Valid_ST;
wire [0:`HV_DIMENSION-1] Hypervector_mod1_ST, Hypervector_mod2_ST, Hypervector_mod3_ST;

// temporal -> AM
wire Ready_TA, Valid_TA;
wire [0:`HV_DIMENSION-1] Hypervector_mod1_TA, Hypervector_mod2_TA, Hypervector_mod3_TA;

//AM -> output
reg [`LABEL_WIDTH-1:0] LabelOut;
reg [`DISTANCE_WIDTH-1:0] DistanceOut;

//always @(posedge Clk_CI) begin
//	if (~Reset_RI) begin
//		LabelOut <= {`LABEL_WIDTH{1'b0}};
//		DistanceOut <= {`DISTANCE_WIDTH{1'b0}};
//	end 
//  else if (ValidOut_SO) begin
//		LabelOut <= LabelOut_DO;
//		DistanceOut <= DistanceOut_DO;
//	end
//    else begin
//		LabelOut <= LabelOut;
//		DistanceOut <= DistanceOut;
//    end
//end

spatial_encoder_sram_late spatial_encoder_mod1(
	.Clk_CI           (Clk_CI),
	.Reset_RI         (Reset_RI),

	.ValidIn_SI    	  (ValidIn_SI),
	.ReadyOut_SO   	  (ReadyOut_SO),

	.ValidOut_SO      (Valid_ST),
	.ReadyIn_SI       (Ready_ST),

	.ChannelsInput_DI    (Raw_DI),

	.HypervectorOut_mod1_DO(Hypervector_mod1_ST),
	.HypervectorOut_mod2_DO(Hypervector_mod2_ST),
	.HypervectorOut_mod3_DO(Hypervector_mod3_ST),

	.sram1_ready(sram1_ready),
	.sram1_valid(sram1_valid),
	.sram2_ready(sram2_ready), 
	.sram2_valid(sram2_valid),
	.sram3_ready(sram3_ready),
	.sram3_valid(sram3_valid),
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
	.IMOut_mod3_D(IMOut_mod3_D),
	.projM_mod3_neg(projM_mod3_neg), 
	.projM_mod3_pos(projM_mod3_pos),
	.spatial_ready_1(spatial_ready_1),
	.spatial_ready_2(spatial_ready_2),
	.spatial_ready_3(spatial_ready_3),
	.spatial_valid_1(spatial_valid_1),
	.spatial_valid_2(spatial_valid_2),
	.spatial_valid_3(spatial_valid_3), 
	.sram_addr(sram_addr)
	);


temporal_encoder temporal_encoder_mod1(
	.Clk_CI           (Clk_CI),
	.Reset_RI         (Reset_RI),

	.ValidIn_SI    	  (Valid_ST),
	.ReadyOut_SO   	  (Ready_ST),

	.ValidOut_SO      (Valid_TA),
	.ReadyIn_SI       (Ready_TA),

	.HypervectorIn_DI (Hypervector_mod1_ST),

	.HypervectorOut_DO(Hypervector_mod1_TA)
	);

temporal_encoder temporal_encoder_mod2(
	.Clk_CI           (Clk_CI),
	.Reset_RI         (Reset_RI),

	.ValidIn_SI    	  (Valid_ST),
	.ReadyOut_SO   	  (Ready_ST),

	.ValidOut_SO      (Valid_TA),
	.ReadyIn_SI       (Ready_TA),

	.HypervectorIn_DI (Hypervector_mod2_ST),

	.HypervectorOut_DO(Hypervector_mod2_TA)
	);

temporal_encoder temporal_encoder_mod3(
	.Clk_CI           (Clk_CI),
	.Reset_RI         (Reset_RI),

	.ValidIn_SI    	  (Valid_ST),
	.ReadyOut_SO   	  (Ready_ST),

	.ValidOut_SO      (Valid_TA),
	.ReadyIn_SI       (Ready_TA),

	.HypervectorIn_DI (Hypervector_mod3_ST),

	.HypervectorOut_DO(Hypervector_mod3_TA)
	);

associative_memory_late_basic_fix associative_memory(
	.Clk_CI          (Clk_CI),
	.Reset_RI        (Reset_RI),

	.ValidIn_SI      (Valid_TA),
	.ReadyOut_SO     (Ready_TA),

	.ValidOut_SO     (ValidOut_SO),
	.ReadyIn_SI      (ReadyIn_SI),

	.HypervectorIn_mod1_DI(Hypervector_mod1_TA),
	.HypervectorIn_mod2_DI(Hypervector_mod2_TA),
	.HypervectorIn_mod3_DI(Hypervector_mod3_TA),

	.LabelOut_A_DO     (LabelOut_A_DO),
	.DistanceOut_A_DO  (DistanceOut_A_DO),
	.LabelOut_V_DO     (LabelOut_V_DO),
	.DistanceOut_V_DO  (DistanceOut_V_DO)
	);

endmodule











