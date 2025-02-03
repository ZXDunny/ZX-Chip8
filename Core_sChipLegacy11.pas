unit Core_sChipLegacy11;

interface

Uses Core_Def, Core_sChipLegacy10;

Type

  TSChipLegacy11Core = Class(TSChipLegacy10Core)

    Procedure BuildTables; Override;
    Procedure Reset; Override;

    // SChip 1.1 Legacy opcodes - Dxyn handles Dxy0 too for simplicity

    Procedure Op00Cn; Virtual;  Procedure Op00FB; Virtual;  Procedure Op00FC; Virtual;
    Procedure OpFx30; Virtual;  Procedure Op00FD; Override; Procedure Op00FE; Override;
    Procedure Op00FF; Override; Procedure OpFx29; Override; Procedure OpFx55; Override;
    Procedure OpFx65; Override; Procedure OpDxyn; Override;

  End;

implementation

Uses Windows, SysUtils, Classes, Math, Chip8Int, Display, Fonts;

Procedure TSChipLegacy11Core.BuildTables;
Var
  idx: Integer;
Begin

  Inherited;

  Opcodes0[$FB] := Op00FB; Opcodes0[$FC] := Op00FC;
  Opcodes0[$FD] := Op00FD; Opcodes0[$FE] := Op00FE;
  Opcodes0[$FF] := Op00FF; Opcodes[$D]   := OpDxyn;

  For idx := 0 to $F Do
    Opcodes0[$C0 or idx] := Op00Cn;

  OpcodesF[$29] := OpFx29; OpcodesF[$30] := OpFx30;
  OpcodesF[$55] := OpFx55; OpcodesF[$65] := OpFx65;

End;

Procedure TSChipLegacy11Core.Reset;
Begin

  Inherited;
  LoadFont(Self, Font_Large_sChip11);

End;

// Begin Core opcodes

Procedure TSChipLegacy11Core.Op00Cn;
var
  x, y: Integer;
Begin
  // $00Cn - Scroll display down n pixels.
  n := ci And $F;
  For y := 63 DownTo n Do
    For x := 0 To 127 Do
      DisplayMem[y * 128 + x] := DisplayMem[(y - n) * 128 + x];
  For y := 0 To n-1 Do
    For x := 0 To 127 Do
      DisplayMem[y * 128 + x] := 0;
  DisplayFlag := True;
End;

Procedure TSChipLegacy11Core.Op00FB;
Var
  x, y: Integer;
Begin
  // $00FB - Scroll right 4 pixels
  For y := 0 To 63 Do Begin
    For x := 127 DownTo 4 Do
      DisplayMem[y * 128 + x] := DisplayMem[y * 128 + x - 4];
    For x := 0 To 3 Do
      DisplayMem[y * 128 + x] := 0;
  End;
  DisplayFlag := True;
End;

Procedure TSChipLegacy11Core.Op00FC;
Var
  x, y: Integer;
Begin
  // $00FC - Scroll left 4 pixels
  For y := 0 To 63 Do Begin
    For x := 0 To 123 Do
      DisplayMem[y * 128 + x] := DisplayMem[y * 128 + x + 4];
    For x := 124 To 127 Do
      DisplayMem[y * 128 + x] := 0;
  End;
  DisplayFlag := True;
End;

Procedure TSChipLegacy11Core.Op00FD;
Begin
  // $00FD - HALT
  Dec(PC, 2);
End;

Procedure TSChipLegacy11Core.Op00FE;
Begin
  // $00FE - Switch to Lowres mode, DO NOT clear display
  hiresMode := False;
  DisplayFlag := True;
End;

Procedure TSChipLegacy11Core.Op00FF;
Begin
  // $00FF - Switch to Hires mode, DO NOT clear display
  hiresMode := True;
  DisplayFlag := True;
End;

Procedure TSChipLegacy11Core.OpDxyn;
Begin

  // $Dxyn - In 1.1 Legacy Superchip, we add clipped rows to the collision count in hires mode

  ClipCol := 0;

  Inherited;

  If HiresMode Then
    Regs[$F] := clipCol;

End;

Procedure TSChipLegacy11Core.OpFX29;
Begin
  // Fx29 - i = Character address in Reg X
  i := $50 + (Regs[(ci Shr 8) And $F] And $F) * 5;
End;

Procedure TSChipLegacy11Core.OpFX30;
Begin
  // Fx30 - i = Hires Character address in Reg X
  i := $A0 + (Regs[(ci Shr 8) And $F] And $F) * 10;
End;

Procedure TSChipLegacy11Core.OpFx55;
Var
  idx: Integer;
Begin
  // Fx55 - Store x regs to RAM
  x := (ci Shr 8) And $F;
  For idx := 0 To x Do WriteMem(i + idx, Regs[idx]);
End;

Procedure TSChipLegacy11Core.OpFx65;
Var
  idx: Integer;
Begin
  // Fx65 - Get x regs from RAM
  x := (ci Shr 8) And $F;
  For idx := 0 To x Do Regs[idx] := GetMem(i + idx);
End;

end.
