unit Core_Def;

interface

Type

  TOpcode = Procedure of Object;
  pOpcode = ^TOpcode;

  TOpRec = Record
    Idx: Integer;
    Opcode: pOpcode;
  End;

  TCore = Class
    Opcodes, Opcodes0, Opcodes5, Opcodes8, OpcodesE, OpcodesF: Array[0..255] of TOpcode;
    Memory: Array [0..$FFFF] of Byte;
    Regs: Array[0..15] of Byte;
    Stack: Array[0..1023] of LongWord;
    PC, StackPtr: LongWord;
    ci, cil, Cycles, mCycles, LastFrameCount,
    Timer, sTimer, NextFrame, icnt, i,
    nnn, LastKey, keyStage: Integer;
    t, x, y, n: Byte;
    ExitLoop: Boolean;
    ipf, maxipf: Integer;
    DispWidth, DispHeight: Integer;
    KeyStates: Array[0..15] of Boolean;
    DisplayMem: Array of Byte;
    Procedure Reset; Virtual;
    Procedure LoadROM(Filename: String); Virtual;
    Procedure InstructionLoop; Virtual;
  End;

implementation

Procedure TCore.Reset;
Begin
  //
End;

Procedure TCore.LoadROM(Filename: String);
Begin
  //
End;

Procedure TCore.InstructionLoop;
Begin
  //
End;

end.
