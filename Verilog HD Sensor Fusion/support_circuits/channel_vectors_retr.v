`include "const.vh"

module channel_vectors_retr #
(	
	parameter WIDTH = `HV_DIMENSION,
	//parameter NEIGHBORHOOD_WIDTH = 3,
	//parameter RULE = 30
)
(
	// global ports
	//input Clk_CI, Reset_RI, 

	// control signals
	//input Enable_SI, Clear_SI,
	//input [`ceilLog2(`INPUT_CHANNELS)-1:0] cycle_count,
	input [`ceilLog2(`INPUT_CHANNELS)-1:0] channel_mod1, channel_mod2, channel_mod3,

	// output value
	output [0:WIDTH-1] CellValueOut_mod1_DO, CellValueOut_mod2_DO, CellValueOut_mod3_DO,
	output [0:WIDTH-1] projM_mod1_pos, projM_mod2_pos, projM_mod3_pos,
	output [0:WIDTH-1] projM_mod1_neg, projM_mod2_neg, projM_mod3_neg
);


localparam [0:`iM_WIDTH-1] iM_full = `iM;
localparam [0:`projM_neg_WIDTH-1] projM_neg_full = `projM_neg;
localparam [0:`projM_pos_WIDTH-1] projM_pos_full = `projM_pos;

assign CellValueOut_mod1_DO = iM_full[(channel_mod1*WIDTH):(channel_mod1*WIDTH+WIDTH-1)];
assign projM_mod1_pos = projM_pos_full[(channel_mod1*WIDTH):(channel_mod1*WIDTH+WIDTH-1)];
assign projM_mod1_neg = projM_neg_full[(channel_mod1*WIDTH):(channel_mod1*WIDTH+WIDTH-1)];

assign CellValueOut_mod2_DO = iM_full[(channel_mod2*WIDTH):(channel_mod2*WIDTH+WIDTH-1)];
assign projM_mod2_pos = projM_pos_full[(channel_mod2*WIDTH):(channel_mod2*WIDTH+WIDTH-1)];
assign projM_mod2_neg = projM_neg_full[(channel_mod2*WIDTH):(channel_mod2*WIDTH+WIDTH-1)];

assign CellValueOut_mod3_DO = iM_full[(channel_mod3*WIDTH):(channel_mod3*WIDTH+WIDTH-1)];
assign projM_mod3_pos = projM_pos_full[(channel_mod3*WIDTH):(channel_mod3*WIDTH+WIDTH-1)];
assign projM_mod3_neg = projM_neg_full[(channel_mod3*WIDTH):(channel_mod3*WIDTH+WIDTH-1)];

//pull iM for channel
//always @(*) begin
//	for (i=0; i<`HV_DIMENSION; i=i+1) begin
//		or_column = 1'b0;
//		for (j=0; j<`MAX_BUNDLE_CYCLES; j=j+1) begin
//			if (CONNECTIVITY_MATRIX[i+(j*`HV_DIMENSION)] == 1'b1) begin
//				or_column = or_column | ManipulatorIn_DI[j];
//			end
//		end
//		CellValueOut_DO[i] <= HypervectorIn_DI[i] ^ or_column;
//	end
//end




endmodule