package example

import chisel3._
import chisel3.util._
import chisel3.experimental.{IntParam, BaseModule}
import freechips.rocketchip.amba.axi4._
import freechips.rocketchip.subsystem.BaseSubsystem
import freechips.rocketchip.config.{Parameters, Field}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.regmapper.{HasRegMap, RegField}
import freechips.rocketchip.tilelink._
import freechips.rocketchip.util.UIntIsOneOf

case class FusionParams(
  early_late: String = "early",
  address: BigInt = 0x2000,
  hvDim: Int = 2000,
  classes: Int = 2,
  modeWidth: Int = 2,
  labelWidth: Int = 1,
  channelWidth: Int = 2,
  inputChannels: Int = 214,
  channelsGSR: Int = 32,
  channelsECG: Int = 77,
  channelsEEG: Int = 105,
  distanceWidth: Int = 11)

case object FusionKey extends Field[Option[FusionParams]](None)

class FusionIO(val c: FusionParams) extends Bundle {
  // global
  val Clk_CI = Input(Clock())
  val Reset_RI = Input(Bool())

  // handshaking
  val ValidIn_SI, ReadyIn_SI = Input(Bool())
  val ReadyOut_SO, ValidOut_SO = Output(Bool())

  // inputs
  val Raw_DI = Input(UInt((c.channelWidth*c.inputChannels).W))

  // outputs
  val LabelOut_A_DO, LabelOut_V_DO = Output(UInt(c.labelWidth.W))
  val DistanceOut_A_DO, DistanceOut_V_DO = Output(UInt(c.distanceWidth.W))

  // memory
  val sram1_ready, sram1_valid, sram2_ready, sram2_valid, sram3_ready, sram3_valid, sram4_ready, sram4_valid, sram5_ready, sram5_valid, sram6_ready, sram6_valid, sram7_ready, sram7_valid, sram8_ready, sram8_valid, sram9_ready, sram9_valid = Input(Bool())
  val IMOut_mod3_D, projM_mod3_neg, projM_mod3_pos = Input(UInt(c.hvDim.W))
  val spatial_ready_1, spatial_ready_2, spatial_ready_3, spatial_valid_1, spatial_valid_2, spatial_valid_3 = Output(Bool())
  val sram_addr = Output(UInt(log2Ceil(c.inputChannels).W)) // TODO: should actually be log2Ceil(channelsEEG)
}

trait FusionTopIO extends Bundle {
  def params: FusionParams
  def c = params

  val dataIn = Input(UInt((c.channelWidth*c.inputChannels).W))
  val labelOutA, labelOutV = Output(UInt(c.labelWidth.W))
  val distOutA, distOutV = Output(UInt(c.distanceWidth.W))
  val fusion_busy = Output(Bool())
}

class FusionMMIOBlackBox(val c: FusionParams) extends BlackBox with HasBlackBoxResource
{
  val io = IO(new FusionIO(c))

  override def desiredName = if (c.early_late == "early") "hdc_top" else "hdc_top_late"

  if (c.early_late == "early") {
    addResource("/vsrc/hdc_top.v")
    addResource("/vsrc/const.vh")
    addResource("/vsrc/associative_memory/associative_memory.v")
    addResource("/vsrc/spatial_encoder/spatial_encoder_sram.v")
    addResource("/vsrc/temporal_encoder/temporal_encoder.v")
    addResource("/vsrc/support_circuits/spatial_accumulator.v")
  } else {
    addResource("/vsrc/hdc_top_late.v")
    addResource("/vsrc/const.vh")
    addResource("/vsrc/associative_memory/associative_memory_late.v")
    addResource("/vsrc/spatial_encoder/spatial_encoder_sram_late.v")
    addResource("/vsrc/temporal_encoder/temporal_encoder.v")
    addResource("/vsrc/support_circuits/spatial_accumulator.v")
  }
}

class FusionMemory(val width: Int, val addrBits: Int) extends Module {
  val io = IO(new Bundle{
    val in = Input(UInt(width.W))
    val out = Output(UInt(width.W))
    val addr = Input(UInt(addrBits.W))
    val wr = Input(Bool()) // 0 = read, 1 = write
  })

  val mem = SyncReadMem(scala.math.pow(2, addrBits).toInt, UInt(width.W))

  val rwPort = mem(io.addr)
  when(io.wr) {
    rwPort := io.in
    io.out := 0.U.asTypeOf(io.out)
  } .otherwise {
    io.out := rwPort
  }
}

trait FusionModule extends HasRegMap {
  val io: FusionTopIO
  dontTouch(io)

  implicit val p: Parameters
  def params: FusionParams
  def c = params
  val clock: Clock
  val reset: Reset

  // How many clock cycles in a PWM cycle?
  val status = Wire(UInt(8.W))

  val impl = Module(new FusionMMIOBlackBox(c))

  // memories
  // val AM_A, AM_V = Module(new FusionMemory(c.hvDim, log2Ceil(c.classes)))
  val projM_pos, projM_neg, iM = Module(new FusionMemory(c.hvDim, log2Ceil(c.channelsEEG))).io
  val projM_pos_data, projM_neg_data, iM_data = Reg(UInt(32.W))
  val filln = c.hvDim/32+1

  // state machine 
  // val idle :: load_mems :: train :: update :: predict :: Nil = Enum(5)
  val idle :: load_mems :: predict :: Nil = Enum(3)

  val state = RegInit(idle)
  val load = RegInit(false.B)
  val memCnt = RegInit(0.U(log2Ceil(c.inputChannels).W))

  switch (state) {
    is (idle) {
      state := Mux(load, load_mems, idle)
    }
    is (load_mems) {
      // TODO: memory loading sequence from training
      state := Mux(memCnt < c.channelsEEG.U, load_mems, predict)
    }
    is (predict) {
      state := predict
    }
  }
  memCnt := memCnt + (state === load_mems).asUInt()

  // hook up memories & blackbox
  Seq(projM_pos, projM_neg, iM).foreach{mem => 
    mem.wr := state === load_mems
    mem.addr := Mux(state === load_mems, memCnt, impl.io.sram_addr)
  }

  projM_pos.in := Fill(filln, projM_pos_data)
  projM_neg.in := Fill(filln, projM_neg_data)
  iM.in := Fill(filln, iM_data)

  impl.io.Clk_CI := clock
  impl.io.Reset_RI := reset.asBool

  // not real handshaking
  Seq(impl.io.ValidIn_SI, impl.io.ReadyIn_SI, impl.io.sram1_ready, impl.io.sram1_valid, impl.io.sram2_ready, impl.io.sram2_valid, impl.io.sram3_ready, impl.io.sram3_valid, impl.io.sram4_ready, impl.io.sram4_valid, impl.io.sram5_ready, impl.io.sram5_valid, impl.io.sram6_ready, impl.io.sram6_valid, impl.io.sram7_ready, impl.io.sram7_valid, impl.io.sram8_ready, impl.io.sram8_valid, impl.io.sram9_ready, impl.io.sram9_valid).foreach{rv => rv := state === predict}
  status := Cat(Seq(impl.io.ReadyOut_SO, impl.io.ValidOut_SO, impl.io.spatial_ready_1, impl.io.spatial_ready_2, impl.io.spatial_ready_3, impl.io.spatial_valid_1, impl.io.spatial_valid_2, impl.io.spatial_valid_3))

  // connect labels & data
  impl.io.Raw_DI := io.dataIn
  io.labelOutA := impl.io.LabelOut_A_DO
  io.labelOutV := impl.io.LabelOut_A_DO
  io.distOutA := impl.io.DistanceOut_A_DO
  io.distOutV := impl.io.DistanceOut_V_DO

  impl.io.projM_mod3_pos := projM_pos.out
  impl.io.projM_mod3_neg := projM_neg.out
  impl.io.IMOut_mod3_D := iM.out

  // output busy
  io.fusion_busy := state =/= idle

  regmap(
    0x00 -> Seq(
      RegField.r(8, status)), // a read-only register capturing current status
    0x04 -> Seq(
      RegField.r(2, state)),
    0x08 -> Seq(
      RegField.w(32, projM_pos_data)),
    0x0C -> Seq(
      RegField.w(32, projM_neg_data)),
    0x10 -> Seq(
      RegField.w(32, iM_data)),
    0x14 -> Seq(
      RegField.w(1, load)),
  )
}

class FusionTL(val params: FusionParams, beatBytes: Int)(implicit p: Parameters)
  extends TLRegisterRouter(
    params.address, "fusion", Seq("ucbbar,fusion"),
    beatBytes = beatBytes)(
      new TLRegBundle(params, _) with FusionTopIO)(
      new TLRegModule(params, _, _) with FusionModule)

trait CanHavePeripheryFusion { this: BaseSubsystem =>
  private val portName = "fusion"

  val fusion = p(FusionKey) match {
    case Some(params) => {
      val fusion = LazyModule(new FusionTL(params, pbus.beatBytes)(p))
      pbus.toVariableWidthSlave(Some(portName)) { fusion.node }
      Some(fusion)
    }
    case None => None
  }
}

trait CanHavePeripheryFusionModuleImp extends LazyModuleImp {
  val outer: CanHavePeripheryFusion
  val fusion_busy = outer.fusion match {
    case Some(fusion) => {
      val busy = IO(Output(Bool()))
      busy := fusion.module.io.fusion_busy
      Some(busy)
    }
    case None => None
  }
}
