unit Core_Custom;

interface

Uses Core_Def, Core_Chip8;

Type

  TQuirkSettings = Record
    CPUType: Integer;
    Shifting,
    Clipping,
    Jumping,
    DispWait,
    VFReset: Boolean;
    MemIncMethod: Integer;
    TargetIPF: Integer;
  End;
  pQuirkSettings = ^TQuirkSettings;

  TCustomCore = Class(TCore)
    BaseType: TCore;
    CurCPUModel: Integer;
    Quirks: TQuirkSettings;
    DoFrame: Boolean;
    Procedure SetCustomSettings(SetQuirks: TQuirkSettings);
    Procedure Reset; Override;
    Procedure LoadROM(Filename: String; DoReset: Boolean); Override;
    Procedure InstructionLoop; Override;
    Procedure SetDisplay(Width, Height, Depth: Integer); Override;
    Function  GetDisplayInfo: TDisplayInfo; Override;
    Procedure Present; Override;
    Procedure KeyDown(Key: Integer); Override;
    Procedure KeyUp(Key: Integer); Override;
    Procedure ApplyQuirks;
    Procedure Frame(AddCycles: Integer); Override;

    Procedure Op8xy1_Quirk;   Procedure Op8xy1_Regular;
    Procedure Op8xy2_Quirk;   Procedure Op8xy2_Regular;
    Procedure Op8xy3_Quirk;   Procedure Op8xy3_Regular;
    Procedure Op8xy6_Quirk;   Procedure Op8xy6_Regular;
    Procedure Op8xyE_Quirk;   Procedure Op8xyE_Regular;
    Procedure OpFx55_NoI;     Procedure OpFx65_NoI;
    Procedure OpFx55_IX;      Procedure OpFx65_IX;
    Procedure OpFx55_IX1;     Procedure OpFx65_IX1;
    Procedure OpBnnn_Regular; Procedure OpBxnn_Quirk;

  End;

Const

  MemIncNone = 0;
  MemIncX    = 1;
  MemIncX1   = 2;

implementation

Uses Windows, Chip8Int, Core_Chip8X, Core_Chip48, Core_sChipLegacy10, Core_sChipLegacy11, Core_sChipModern, Core_xoChip, Core_MegaChip;

Procedure TCustomCore.SetCustomSettings(SetQuirks: TQuirkSettings);
Begin

  CurCPUModel := SetQuirks.CPUType;

  Case CurCPUModel of
    Chip8_VIP:
      BaseType := TChip8Core.Create;
    Chip8_Chip8x:
      BaseType := TChip8xCore.Create;
    Chip8_Chip48:
      BaseType := TChip48Core.Create;
    Chip8_SChip_Legacy10:
      BaseType := TSChipLegacy10Core.Create;
    Chip8_SChip_Legacy11:
      BaseType := TSChipLegacy11Core.Create;
    Chip8_SChip_Modern:
      BaseType := TSChipModernCore.Create;
    Chip8_XOChip:
      BaseType := TXOChipCore.Create;
    Chip8_MegaChip:
      BaseType := TMegaChipCore.Create;
  End;

  CopyMemory(@Quirks.CPUType, @SetQuirks.CPUType, SizeOf(TQuirkSettings));

End;

Procedure TCustomCore.ApplyQuirks;
Begin

  DoQuirks := True;

  With Quirks, BaseType Do Begin

    DxynWrap := Not Clipping;
    DisplayWait := DispWait;

    If Shifting Then Begin
      // SChips, Chip48, MegaChip
      Opcodes8[6] := Op8xy6_Quirk;
      Opcodes8[$E] := Op8xyE_Quirk;
    End Else Begin
      // VIP, XOChip
      Opcodes8[6] := Op8xy6_Regular;
      Opcodes8[$E] := Op8xyE_Regular;
    End;

    Case MemIncMethod Of
      0: // Leave I unchanged (sChipLegacy11)
        Begin
          OpcodesF[$55] := OpFx55_NoI;
          OpcodesF[$65] := OpFx65_NoI;
        End;
      1:  // Inc by X (Chip48, sChipLegacy10)
        Begin
          OpcodesF[$55] := OpFx55_IX;
          OpcodesF[$65] := OpFx65_IX;
        End;
      2:  // Inc by x+1 (VIP Chip8, XOChip)
        Begin
          OpcodesF[$55] := OpFx55_IX1;
          OpcodesF[$65] := OpFx65_IX1;
        End;

    End;

    If Jumping Then Begin
      // All others
      Opcodes[11] := OpBxnn_Quirk;
    End Else Begin
      // VIP, Xo, MegaChip
      Opcodes[11] := OpBnnn_Regular;
    End;

    If VFReset Then Begin
      // VIP, Chip8X, Chip48
      Opcodes8[1] := Op8xy1_Regular;
      Opcodes8[2] := Op8xy2_Regular;
      Opcodes8[3] := Op8xy3_Regular;
    End Else Begin
      // All After SChip10
      Opcodes8[1] := Op8xy1_Quirk;
      Opcodes8[2] := Op8xy2_Quirk;
      Opcodes8[3] := Op8xy3_Quirk;
    End;

    MaxIPF := TargetIPF;

  End;

  DoFrame := CurCPUModel in [Chip8_VIP, Chip8_Chip8X];

End;

Procedure TCustomCore.Reset;
Begin
  BaseType.Reset;
  ApplyQuirks;
End;

Procedure TCustomCore.LoadROM(Filename: String; DoReset: Boolean);
Begin
  If DoReset Then Reset;
  BaseType.LoadROM(Filename, False);
End;

Procedure TCustomCore.InstructionLoop;
Begin
  BaseType.InstructionLoop;
End;

Procedure TCustomCore.SetDisplay(Width, Height, Depth: Integer);
Begin
  BaseType.SetDisplay(Width, Height, Depth);
End;

Function  TCustomCore.GetDisplayInfo: TDisplayInfo;
Begin
  ipf := BaseType.ipf;
  Result := BaseType.GetDisplayInfo;
End;

Procedure TCustomCore.Present;
Begin
  BaseType.Present;
End;

Procedure TCustomCore.KeyDown(Key: Integer);
Begin
  BaseType.KeyDown(Key);
End;

Procedure TCustomCore.KeyUp(Key: Integer);
Begin
  BaseType.KeyUp(Key);
End;

Procedure TCustomCore.Frame(AddCycles: Integer);
Begin
  If DoFrame Then Inherited;
End;

// Quirk Opcodes

Procedure TCustomCore.Op8xy6_Regular;
Begin
  // 8xy6 - Shift Reg X right
  With BaseType Do Begin
    y := (ci Shr 4) And $F;
    t := Regs[y] And 1;
    Regs[(ci Shr 8) And $F] := Regs[y] Shr 1;
    Regs[$F] := t;
    Cycles := 44;
  End;
End;

Procedure TCustomCore.Op8xy6_Quirk;
Begin
  // 8xy6 - Shift Reg X right
  With BaseType Do Begin
    x := (ci Shr 8) And $F;
    t := Regs[x] And 1;
    Regs[x] := Regs[x] Shr 1;
    Regs[$F] := t;
    Cycles := 44;
  End;
End;

Procedure TCustomCore.Op8xyE_Regular;
Begin
  // 8xyE - Shift Reg X left
  With BaseType Do Begin
    y := (ci Shr 4) And $F;
    t := Regs[y] Shr 7;
    Regs[(ci Shr 8) And $F] := Regs[y] Shl 1;
    Regs[$F] := t;
    Cycles := 44;
  End;
End;

Procedure TCustomCore.Op8xyE_Quirk;
Begin
  // 8xyE - Shift Reg X left
  With BaseType Do Begin
    x := (ci Shr 8) And $F;
    t := Regs[x] Shr 7;
    Regs[x] := Regs[x] Shl 1;
    Regs[$F] := t;
    Cycles := 44;
  End;
End;

Procedure TCustomCore.OpFx55_IX1;
Var
  idx: Integer;
Begin
  // Fx55 - Store x regs to RAM
  With BaseType Do Begin
    If DoFrame Then Frame(14);
    Cycles := 0;
    x := (ci Shr 8) And $F;
    For idx := 0 To x Do Begin
      WriteMem(i + idx, Regs[idx]);
      If DoFrame Then Frame(14);
    End;
    Inc(i, x +1);
  End;
End;

Procedure TCustomCore.OpFx65_IX1;
Var
  idx: Integer;
Begin
  // Fx65 - Get x regs from RAM
  With BaseType Do Begin
    If DoFrame Then Frame(14);
    Cycles := 0;
    x := (ci Shr 8) And $F;
    For idx := 0 To x Do Begin
      Regs[idx] := BaseType.GetMem(i + idx);
      If DoFrame Then Frame(14);
    End;
    Inc(i, x +1);
  End;
End;

Procedure TCustomCore.OpFx55_IX;
Var
  idx: Integer;
Begin
  // Fx55 - Store x regs to RAM
  With BaseType Do Begin
    If DoFrame Then Frame(14);
    Cycles := 0;
    x := (ci Shr 8) And $F;
    For idx := 0 To x Do Begin
      WriteMem(i + idx, Regs[idx]);
      If DoFrame Then Frame(14);
    End;
    Inc(i, x);
  End;
End;

Procedure TCustomCore.OpFx65_IX;
Var
  idx: Integer;
Begin
  // Fx65 - Get x regs from RAM
  With BaseType Do Begin
    If DoFrame Then Frame(14);
    Cycles := 0;
    x := (ci Shr 8) And $F;
    For idx := 0 To x Do Begin
      Regs[idx] := GetMem(i + idx);
      If DoFrame Then Frame(14);
    End;
    Inc(i, x);
  End;
End;

Procedure TCustomCore.OpFx55_NoI;
Var
  idx: Integer;
Begin
  // Fx55 - Store x regs to RAM
  With BaseType Do Begin
    If DoFrame Then Frame(14);
    Cycles := 0;
    x := (ci Shr 8) And $F;
    For idx := 0 To x Do Begin
      WriteMem(i + idx, Regs[idx]);
      If DoFrame Then Frame(14);
    End;
  End;
End;

Procedure TCustomCore.OpFx65_NoI;
Var
  idx: Integer;
Begin
  // Fx65 - Get x regs from RAM
  With BaseType Do Begin
    If DoFrame Then Frame(14);
    Cycles := 0;
    x := (ci Shr 8) And $F;
    For idx := 0 To x Do Begin
      Regs[idx] := GetMem(i + idx);
      If DoFrame Then Frame(14);
    End;
  End;
End;

Procedure TCustomCore.OpBnnn_Regular;
Begin
  // Bnnn - Jump to Offset
  With BaseType Do Begin
    nnn := ci And $FFF;
    PC := nnn + Regs[0];
    Cycles := 22 + 2 * Ord((PC Shr 8) <> LongWord(nnn Shr 8));
  End;
End;

Procedure TCustomCore.OpBxnn_Quirk;
Begin
  // Bxnn - Jump to Offset
  With BaseType Do Begin
    nnn := ci And $FFF;
    x := (ci Shr 8) And $F;
    PC := nnn + Regs[x];
    Cycles := 22 + 2 * Ord((PC Shr 8) <> LongWord(nnn Shr 8));
  End;
End;

Procedure TCustomCore.Op8xy1_Regular;
Begin
  // 8xy1 - Reg X OR Reg Y
  With BaseType Do Begin
    t := (ci Shr 8) And $F;
    Regs[t] := Regs[t] Or Regs[(ci Shr 4) And $F];
    Regs[$F] := 0;
    Cycles := 44;
  End;
End;

Procedure TCustomCore.Op8xy2_Regular;
Begin
  // 8xy2 - Reg X AND Reg Y
  With BaseType Do Begin
    t := (ci Shr 8) And $F;
    Regs[t] := Regs[t] And Regs[(ci Shr 4) And $F];
    Regs[$F] := 0;
    Cycles := 44;
  End;
End;

Procedure TCustomCore.Op8xy3_Regular;
Begin
  // 8xy3 - Reg X XOR Reg y
  With BaseType Do Begin
    t := (ci Shr 8) And $F;
    Regs[t] := Regs[t] Xor Regs[(ci Shr 4) And $F];
    Regs[$F] := 0;
    Cycles := 44;
  End;
End;

Procedure TCustomCore.Op8xy1_Quirk;
Begin
  // 8xy1 - Reg X OR Reg Y
  With BaseType Do Begin
    t := (ci Shr 8) And $F;
    Regs[t] := Regs[t] Or Regs[(ci Shr 4) And $F];
    Cycles := 44;
  End;
End;

Procedure TCustomCore.Op8xy2_Quirk;
Begin
  // 8xy2 - Reg X AND Reg Y
  With BaseType Do Begin
    t := (ci Shr 8) And $F;
    Regs[t] := Regs[t] And Regs[(ci Shr 4) And $F];
    Cycles := 44;
  End;
End;

Procedure TCustomCore.Op8xy3_Quirk;
Begin
  // 8xy3 - Reg X XOR Reg y
  With BaseType Do Begin
    t := (ci Shr 8) And $F;
    Regs[t] := Regs[t] Xor Regs[(ci Shr 4) And $F];
    Cycles := 44;
  End;
End;


end.
