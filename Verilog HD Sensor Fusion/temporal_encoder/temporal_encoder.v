`include "const.vh"

module temporal_encoder
(
	// global ports
	input Clk_CI, Reset_RI,

	// handshaking
	input ValidIn_SI, ReadyIn_SI,
	output reg ReadyOut_SO, ValidOut_SO,

	// inputs
	input [0:`HV_DIMENSION-1] HypervectorIn_DI,
	
	output [0:`HV_DIMENSION-1] HypervectorOut_DO
);

reg [0:`HV_DIMENSION-1] NGram_DP [1:`NGRAM_SIZE-1]; 
wire [0:`HV_DIMENSION-1] NGram_DN [1:`NGRAM_SIZE-1];
reg [1:0] FSM_SP, FSM_SN;
reg [0 : `HV_DIMENSION-1] result_N, result_P;
reg NGramEN_S;

localparam 
  idle = 2'd0,
  forward_training = 2'd1,
  accept_input = 2'd2,
  forward_query = 2'd3;

integer i, sum;
genvar y;

//NGram permutation
assign NGram_DN[1] = (NGramEN_S) ? {HypervectorIn_DI[`HV_DIMENSION-1], HypervectorIn_DI[0:`HV_DIMENSION-2]} : NGram_DP[1];
generate 
  for (y=2; y<`NGRAM_SIZE; y=y+1) begin
      assign NGram_DN[y] = (NGramEN_S) ? {NGram_DP[y-1][`HV_DIMENSION-1], NGram_DP[y-1][0:`HV_DIMENSION-2]} : NGram_DP[y];
  end
endgenerate

//output
assign HypervectorOut_DO = result_P;

//NGram binding
always @ (*) begin
  if (NGramEN_S) begin
    result_N = HypervectorIn_DI;
    for (i=1; i<`NGRAM_SIZE; i=i+1) begin
      result_N = result_N ^ NGram_DP[i];
    end
  else begin
    result_N = result_P;
  end
end

//FSM
always @ (*) begin
  FSM_SN = idle;
  ReadyOut_SO = 1'b0;
  ValidOut_SO = 1'b0;
  NGramEN_S = 1'b0;
  case(FSM_SP)
    idle: begin
      if (ValidIn_SI == 1'b0) begin
        FSM_SN = idle;
        ReadyOut_SO = 1'b1;
      end 
      else begin
        FSM_SN                 = forward_query;
        ReadyOut_SO            = 1'b1;
        NGramEN_S              = 1'b1;
      end
    end
    forward_query: begin
      FSM_SN = (ReadyIn_SI == 1'b0) ? forward_query : idle;
      ValidOut_SO = 1'b1;
    end
  endcase
end

//Data registers
//NGram
always @ (posedge Clk_CI) begin
  if (Reset_RI == 1'b1) begin
    for (i=1; i < `NGRAM_SIZE; i=i+1) NGram_DP[i] <= {`HV_DIMENSION{1'b0}};
  end 
  else begin
    for (i=1; i < `NGRAM_SIZE; i=i+1) NGram_DP[i] <= NGram_DN[i];
  end
end

//buffer output
always @ (posedge Clk_CI) begin
  if (Reset_RI == 1'b1) begin
    result_P = {`HV_DIMENSION{1'b0}};
  end
  else begin
    result_P = result_N;
  end
end

//FSM
always @ (posedge Clk_CI) begin
  if (Reset_RI == 1'b1) begin
    FSM_SP <= idle;
  end 
  else begin
    FSM_SP <= FSM_SN;
  end
end
    
endmodule












