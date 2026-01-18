TYPE
  LOGLEVEL : (CRITICAL, WARNING, INFO, DEBUG) := INFO;
END_TYPE

FUNCTION_BLOCK LOGGER
  VAR_INPUT
    TRIG : BOOL;
    MSG : STRING;
    LEVEL : LOGLEVEL := INFO;
  END_VAR
  VAR
    TRIG0 : BOOL;
  END_VAR

  IF TRIG AND NOT TRIG0 THEN
  {{
   LogMessage(GetFbVar(LEVEL),(char*)GetFbVar(MSG, .body),GetFbVar(MSG, .len));
  }}
  END_IF;
  TRIG0:=TRIG;
END_FUNCTION_BLOCK


FUNCTION_BLOCK FB_AutoModeControl
  VAR_INPUT
    OperationEnable : BOOL;
    EntrySensor : BOOL;
    ExitSensor : BOOL;
    RejectRequired : BOOL;
  END_VAR
  VAR_OUTPUT
    AcceptPiece : BOOL;
    RejectActuator : BOOL;
    ConveyorRun : BOOL;
    PieceProcessedPulse : BOOL;
  END_VAR
  VAR
    SelectionPhase : BOOL;
    PieceLost : BOOL;
    Waiting : BOOL;
    TON0 : TON;
    TP0 : TP;
  END_VAR

  Waiting := NOT(PieceLost) AND NOT(SelectionPhase) AND NOT(EntrySensor) AND OperationEnable;
  SelectionPhase := NOT(ExitSensor) AND NOT(PieceLost) AND NOT(Waiting) AND (EntrySensor OR SelectionPhase) AND OperationEnable;
  TON0(IN := SelectionPhase AND OperationEnable, PT := T#10000ms);
  PieceLost := NOT(RejectRequired) AND (TON0.Q OR PieceLost AND OperationEnable);
  AcceptPiece := NOT(SelectionPhase) AND NOT(PieceLost) AND Waiting AND OperationEnable;
  TP0(IN := SelectionPhase AND OperationEnable, PT := T#10000ms);
  RejectActuator := SelectionPhase AND TP0.Q;
  ConveyorRun := NOT(SelectionPhase) AND NOT(PieceLost) AND Waiting AND OperationEnable;
  PieceProcessedPulse := SelectionPhase AND TP0.Q;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_MualModeControl
  VAR_INPUT
    OperationEnable : BOOL;
    ManualEntryEnable : BOOL;
    ManualDiverterCmd : BOOL;
    ManualConveyorCmd : BOOL;
  END_VAR
  VAR_OUTPUT
    EntryAllowed : BOOL;
    DiverterExtend : BOOL;
    ConveyorRun : BOOL;
  END_VAR

  EntryAllowed := ManualEntryEnable AND OperationEnable;
  ConveyorRun := ManualConveyorCmd AND OperationEnable;
  DiverterExtend := ManualDiverterCmd AND OperationEnable;
END_FUNCTION_BLOCK

PROGRAM program0
  VAR_INPUT
    Cmd_AutoMode : BOOL := 0;
    Cmd_ManualMode : BOOL := 0;
    EntrySensor : BOOL := 0;
    ExitSensor : BOOL := 0;
    RejectRequired : BOOL := 0;
    ManualEntryEnable : BOOL := 0;
    ManualDiverterCmd : BOOL := 0;
    ManualConveyorCmd : BOOL := 0;
    PieceCountReset : BOOL := 0;
    EmergyStop : BOOL := 0;
    Solucion : BOOL := 0;
  END_VAR
  VAR_OUTPUT
    BeltMotor : BOOL := 0;
    Diverter : BOOL := 0;
    EntryGate : BOOL := 0;
    PieceCountReached : BOOL := 0;
  END_VAR
  VAR
    Mode_Auto : BOOL := 0;
    Mode_Manual : BOOL := 0;
    FB_AutoModeControl0 : FB_AutoModeControl;
    FB_MualModeControl0 : FB_MualModeControl;
    CTU0 : CTU;
    PieceCountPulse : BOOL := 0;
    AcceptPiece : BOOL := 0;
    EntryAllowed : BOOL := 0;
    RejectActuator : BOOL := 0;
    DiverteExtend : BOOL := 0;
    ConveyorRun : BOOL := 0;
    ConveyorRunManual : BOOL := 0;
    EmergyStopMode : BOOL := 0;
    PermissoStop : BOOL := 0;
    R_TRIG1 : R_TRIG;
  END_VAR

  Mode_Auto := NOT(EmergyStopMode) AND NOT(Cmd_ManualMode) AND (Cmd_AutoMode OR Mode_Auto);
  Mode_Manual := NOT(EmergyStopMode) AND NOT(Cmd_AutoMode) AND (Cmd_ManualMode OR Mode_Manual);
  FB_AutoModeControl0(OperationEnable := Mode_Auto, EntrySensor := EntrySensor, ExitSensor := ExitSensor, RejectRequired := RejectRequired);
  RejectActuator := FB_AutoModeControl0.RejectActuator;
  AcceptPiece := FB_AutoModeControl0.AcceptPiece;
  R_TRIG1(CLK := PieceCountPulse);
  CTU0(CU := R_TRIG1.Q, R := EmergyStopMode OR PieceCountReset, PV := 255);
  PieceCountReached := CTU0.Q;
  ConveyorRun := FB_AutoModeControl0.ConveyorRun;
  FB_MualModeControl0(OperationEnable := Mode_Manual, ManualEntryEnable := ManualEntryEnable, ManualDiverterCmd := ManualDiverterCmd, ManualConveyorCmd := ManualConveyorCmd);
  DiverteExtend := FB_MualModeControl0.DiverterExtend;
  EntryAllowed := FB_MualModeControl0.EntryAllowed;
  ConveyorRunManual := FB_MualModeControl0.ConveyorRun;
  PieceCountPulse := FB_AutoModeControl0.PieceProcessedPulse;
  Diverter := DiverteExtend OR RejectActuator;
  EntryGate := AcceptPiece OR EntryAllowed;
  BeltMotor := ConveyorRun OR ConveyorRunManual;
  EmergyStopMode := PermissoStop AND NOT(Solucion) AND (EmergyStop OR EmergyStopMode);
  PermissoStop := TRUE;
END_PROGRAM


CONFIGURATION Config0

  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#20ms,PRIORITY := 0);
    PROGRAM instance0 WITH task0 : program0;
  END_RESOURCE
END_CONFIGURATION
