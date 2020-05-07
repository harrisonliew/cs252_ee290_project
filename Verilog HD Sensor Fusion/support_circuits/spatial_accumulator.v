`include "const.vh"

module spatial_accumulator
(
	// global ports
	input Clk_CI, Reset_RI, 

	// control signals
	input Enable_SI, FirstHypervector_SI,

	// input values
	input [0:`SPATIAL_DIMENSION-1] HypervectorIn_DI,
	input [`CHANNEL_WIDTH-1:0] FeatureIn_DI,
	input [0:`SPATIAL_DIMENSION-1] projM_negIN,
	input [0:`SPATIAL_DIMENSION-1] projM_posIN,
	input xor_final, store_second,


	// output value
	output [0:`HV_DIMENSION-1] HypervectorOut_DO
);
	// accumulator register
	reg [`SPATIAL_WIDTH-1:0] Accumulator_DP [0:`SPATIAL_DIMENSION-1];
	reg [`SPATIAL_WIDTH-1:0] Accumulator_DN [0:`SPATIAL_DIMENSION-1];
	wire [0:`SPATIAL_DIMENSION-1] XOR_output;
	reg [0:`SPATIAL_DIMENSION-1] bit_by_bit;
	reg [0:`SPATIAL_DIMENSION-1] mod_second_channel_P;
	wire [0:`SPATIAL_DIMENSION-1] mod_second_channel_N;
	wire [0:`SPATIAL_DIMENSION-1] xor_final_channel;


	assign xor_final_channel = mod_second_channel_P ^ HypervectorIn_DI;

	//define based on combinatorially defined logic
	assign XOR_output = bit_by_bit; 
	assign mod_second_channel_N = XOR_output;
	localparam sub_2 = `SPATIAL_WIDTH-2;
	localparam sub_1 = `SPATIAL_WIDTH-1;
	localparam sub_7 = `SPATIAL_WIDTH-7;

	// accumulate
	integer i;
	always @(*) begin
		for (i=0; i<`SPATIAL_DIMENSION; i=i+1) begin
			//define what XOR_output should be
			if (FeatureIn_DI == 2'd1) begin
				bit_by_bit[i] = projM_posIN[i] ^ HypervectorIn_DI[i];
			end
			else if (FeatureIn_DI == 2'd2) begin
				bit_by_bit[i] = projM_negIN[i] ^ HypervectorIn_DI[i];
			end
			else begin
				bit_by_bit[i] = 1'b0;
			end

			//accumulate using XOR_output and include xor(second_channel, final channel) on last channel of modality
			if (FirstHypervector_SI) begin
				Accumulator_DN[i] = XOR_output[i];
			end
			else if (XOR_output[i]) begin
				if (xor_final) begin
					if (xor_final_channel[i])
						Accumulator_DN[i] = Accumulator_DP[i] + {{sub_2{1'b0}},2'b10};
					else 
						Accumulator_DN[i] = Accumulator_DP[i] + {{sub_1{1'b0}},1'b1};
				end
				else begin
					Accumulator_DN[i] = Accumulator_DP[i] + {{sub_1{1'b0}},1'b1};
				end
			end
			else
				Accumulator_DN[i] = Accumulator_DP[i];
		end
	end

	// assign output==1 if majority for that bit
	genvar j;
	for (j=0; j<`SPATIAL_DIMENSION; j=j+1) begin
		//if greater than number of channels (217) / 2
		assign HypervectorOut_DO[j] = (Accumulator_DP[j] > {{sub_7{1'b0}},7'b1101100}) ? 1'b1 : 1'b0;
	end

	// update accumulator reg
	always @(posedge Clk_CI) begin
		if (Reset_RI)
			for (i=0; i<`SPATIAL_DIMENSION; i=i+1) Accumulator_DP[i] = {`SPATIAL_WIDTH{1'b0}};
		else if (Enable_SI)
			for (i=0; i<`SPATIAL_DIMENSION; i=i+1) Accumulator_DP[i] = Accumulator_DN[i];
		else begin
			for (i=0; i<`SPATIAL_DIMENSION; i=i+1) Accumulator_DP[i] = Accumulator_DP[i];
		end
	end

	// store second channel reg
	always @(posedge Clk_CI) begin
		if (Reset_RI)
			mod_second_channel_P = {`SPATIAL_DIMENSION{1'b0}};
		else if (store_second && Enable_SI)
			mod_second_channel_P = mod_second_channel_N;
		else begin
			mod_second_channel_P = mod_second_channel_P;
		end
	end

endmodule
