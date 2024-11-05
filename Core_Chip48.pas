unit Core_Chip48;

interface

Uses Core_Def, Core_Chip8;

Type

  TChip48Core = Class(TChip8Core)

    Procedure InstructionLoop; Override;
    Procedure BuildTables; Override;
    Procedure Reset; Override;

    Procedure OpFx55; Override; Procedure OpFx65; Override;
    Procedure Op8xy6; Override; Procedure Op8xyE; Override;
    Procedure OpBnnn; Override;

  End;

implementation

Uses Windows, Display, Sound, Chip8Int;

Procedure TChip48Core.BuildTables;
Begin

  Inherited;

  Opcodes[11]   := OpBnnn;
  Opcodes8[7]   := Op8xy7;
  Opcodes8[$E]  := Op8xyE;
  OpcodesF[$55] := OpFx55;
  OpcodesF[$65] := OpFx65;

End;

Procedure TChip48Core.Reset;
Begin

  Inherited;

  maxipf := 20;
  MakeSoundBuffers(64, 4);

End;

Procedure TChip48Core.InstructionLoop;
Begin

  Repeat

    cil := GetMem(PC);
    Inc(PC);
    ci := (cil shl 8) + GetMem(PC);
    Inc(PC);

    OpCodes[ci Shr 12];
    Inc(icnt);

  Until iCnt >= maxipf;

  If Timer > 0 then Dec(Timer);
  DoSoundTimer;

  If DisplayFlag Then Present;

  InjectSound(@FrameBuffer[0], Not FullSpeed);

  If FullSpeed Then
    Inc(ipf, icnt)
  Else Begin
    ipf := icnt;
  End;
  icnt := 0;

End;

// Opcodes

Procedure TChip48Core.OpBnnn;
Begin
  // Bxnn - Jump to Offset
  nnn := ci And $FFF;
  x := (ci Shr 8) And $F;
  PC := nnn + Regs[x];
End;

Procedure TChip48Core.OpFx55;
Var
  idx: Integer;
Begin
  // Fx55 - Store x regs to RAM
  x := (ci Shr 8) And $F;
  For idx := 0 To x Do
    WriteMem(i + idx, Regs[idx]);
  Inc(i, x);
End;

Procedure TChip48Core.OpFx65;
Var
  idx: Integer;
Begin
  // Fx65 - Get x regs from RAM
  x := (ci Shr 8) And $F;
  For idx := 0 To x Do
    Regs[idx] := GetMem(i + idx);
  Inc(i, x);
End;

Procedure TChip48Core.Op8xy6;
Begin
  // 8xy6 - Shift Reg X right
  x := (ci Shr 4) And $F;
  t := Regs[x] And 1;
  Regs[(ci Shr 8) And $F] := Regs[x] Shr 1;
  Regs[$F] := t;
End;

Procedure TChip48Core.Op8xyE;
Begin
  // 8xyE - Shift Reg X left
  x := (ci Shr 4) And $F;
  t := Regs[x] Shr 7;
  Regs[(ci Shr 8) And $F] := Regs[x] Shl 1;
  Regs[$F] := t;
End;

end.
