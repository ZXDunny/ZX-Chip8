unit Core_sChipLegacy10;

interface

Uses Core_Def, Core_Chip8;

Type

  TSChipLegacy10Core = Class(TChip8Core)

    Storage: Array[0..15] of Byte;
    nn: Word;
    hiresMode: Boolean;

    Procedure BuildTables; Override;
    Procedure Reset; Override;
    Procedure InstructionLoop; Override;
    Function  GetMem(Address: Integer): Byte; Override;
    Procedure WriteMem(Address: Integer; Value: Byte); Override;

    // Basic Chip8 opcodes overrides for quirks

    Procedure Op00E0; Override; Procedure Op8xy1; Override; Procedure Op8xy2; Override; Procedure Op8xy3; Override;
    Procedure Op8xy6; Override; Procedure Op8xyE; Override; Procedure OpBnnn; Override; Procedure OpDxyn; Override;
    Procedure OpFxnn; Override; Procedure OpFx29; Override; Procedure OpFx55; Override; Procedure OpFx65; Override;

    // SChip 1.0 Legacy opcodes - Dxyn handles Dxy0 too for simplicity

    Procedure Op00FD; Virtual; Procedure Op00FE; Virtual; Procedure Op00FF; Virtual; Procedure OpFx75; Virtual; Procedure OpFx85; Virtual;

  End;

implementation

Uses Windows, SysUtils, Classes, Math, Chip8Int, Display;

Procedure TSChipLegacy10Core.BuildTables;
Begin

  Inherited;

  maxipf := 30;
  SetLength(DisplayMem, 128 * 64);
  DispWidth := 128; DispHeight := 64;

  Opcodes[3] := Op3xnn; Opcodes[11] := OpBnnn; Opcodes[13] := OpDxyn; Opcodes[15] := OpFxnn;
  Opcodes0[$E0] := Op00E0; Opcodes0[$FD] := Op00FD; Opcodes0[$FE] := Op00FE; Opcodes0[$FF] := Op00FF;
  Opcodes8[1] := Op8xy1; Opcodes8[2] := Op8xy2; Opcodes8[3] := Op8xy3; Opcodes8[6] := Op8xy6; Opcodes8[$E] := Op8xyE;
  OpcodesF[$29] := OpFx29; OpcodesF[$55] := OpFx55; OpcodesF[$65] := OpFx65; OpcodesF[$75] := OpFx75; OpcodesF[$85] := OpFx85;

End;

Function TSChipLegacy10Core.GetMem(Address: Integer): Byte;
Begin

  Result := Memory[Address And $FFF];

End;

Procedure TSChipLegacy10Core.WriteMem(Address: Integer; Value: Byte);
Begin

  Memory[Address And $FFF] := Value;

End;

Procedure TSChipLegacy10Core.Reset;
var
  idx: Integer;
Begin

  Inherited;
  hiresMode := False;
  for idx := 0 to 99 Do Memory[idx + 160] := HiresFont10[idx];

End;

Procedure TSChipLegacy10Core.InstructionLoop;
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
  If sTimer > 0 Then Dec(sTimer);
  If DisplayFlag Then Begin
    DisplayUpdate := True;
    DisplayFlag := False;
  End;
  WaitForSync;
  ipf := icnt;
  icnt := 0;

End;

// Begin Core opcodes

Procedure TSChipLegacy10Core.Op00E0;
Begin
  // $00E0 - Clear display
  FillMemory(@DisplayMem[0], Length(DisplayMem), 0);
  DisplayFlag := True;
  icnt := maxipf;
End;

Procedure TSChipLegacy10Core.Op00FD;
Begin
  // $00FD - HALT
  Dec(PC, 2);
End;

Procedure TSChipLegacy10Core.Op00FE;
Begin
  // $00FE - Switch to Lowres mode, DO NOT clear display
  hiresMode := False;
  DisplayFlag := True;
End;

Procedure TSChipLegacy10Core.Op00FF;
Begin
  // $00FF - Switch to Hires mode, DO NOT clear display
  hiresMode := True;
  DisplayFlag := True;
End;

Procedure TSChipLegacy10Core.Op8xy1;
Begin
  // 8xy1 - Reg X OR Reg Y
  t := (ci Shr 8) And $F;
  Regs[t] := Regs[t] Or Regs[(ci Shr 4) And $F];
End;

Procedure TSChipLegacy10Core.Op8xy2;
Begin
  // 8xy2 - Reg X AND Reg Y
  t := (ci Shr 8) And $F;
  Regs[t] := Regs[t] And Regs[(ci Shr 4) And $F];
End;

Procedure TSChipLegacy10Core.Op8xy3;
Begin
  // 8xy3 - Reg X XOR Reg y
  t := (ci Shr 8) And $F;
  Regs[t] := Regs[t] Xor Regs[(ci Shr 4) And $F];
End;

Procedure TSChipLegacy10Core.Op8xy6;
Begin
  // 8xy6 - Shift Reg X right
  x := (ci Shr 8) And $F;
  t := Regs[x] And 1;
  Regs[x] := Regs[x] Shr 1;
  Regs[$F] := t;
End;

Procedure TSChipLegacy10Core.Op8xyE;
Begin
  // 8xyE - Shift Reg X left
  x := (ci Shr 8) And $F;
  t := Regs[x] Shr 7;
  Regs[x] := Regs[x] Shl 1;
  Regs[$F] := t;
End;

Procedure TSChipLegacy10Core.OpBnnn;
Begin
  // Bxnn - Jump to Offset
  nnn := ci And $FFF;
  x := (ci Shr 8) And $F;
  PC := nnn + Regs[x];
End;

Procedure TSChipLegacy10Core.OpDxyn;
Var
  cc, row, col, c: Integer;
  bit, b, bts, Addr, pOfs, np: LongWord;

  Function Bloat(b: LongWord): LongWord; inline;
  Begin
    If b = 0 Then
      Result := 0
    Else Begin
      b := (b Or (b Shl 4)) And $0F0F;
	    b := (b Or (b Shl 2)) And $3333;
	    b := (b Or (b Shl 1)) And $5555;
	    Result := b Or (b Shl 1);
    End;
  End;

Begin
  // Dxyn - draw "sprite"
  n := ci And $F;
  x := (ci Shr 8) And $F;
  y := (ci Shr 4) And $F;
  cc := 0;
  If hiresMode Then Begin
    x := Regs[x] And 127;
    y := Regs[y] And 63;
    If n = 0 Then Begin
      // Dxy0 - 16x16 sprite
      For row := 0 to Min(15, 63 - y) Do Begin
        b := GetMem(i + row * 2) Shl 8 + GetMem(i + 1 + row * 2);
        bit := $8000;
        c := 0;
        For col := 0 To Min(15, 127 - x) Do Begin
          bts := Ord(b And bit > 0);
          bit := bit Shr 1;
          If bts > 0 Then Begin
            Addr := x + col + (y + row) * 128;
            If DisplayMem[Addr] <> 0 Then c := c Or 1;
            DisplayMem[Addr] := DisplayMem[Addr] Xor bts;
          End;
        End;
        If c > 0 Then
          Inc(cc);
      End;
    End Else Begin
      // Dxyn - 8xn sprite
      For row := 0 To Min(n -1, 63 - y) Do Begin
        b := GetMem(i + row);
        bit := $80;
        c := 0;
        For col := 0 To Min(7, 127 - x) Do Begin
          bts := Ord(b And bit > 0);
          bit := bit Shr 1;
          If bts > 0 Then Begin
            Addr := x + col + (y + row) * 128;
            If DisplayMem[Addr] <> 0 Then c := c Or 1;
            DisplayMem[Addr] := DisplayMem[Addr] Xor bts;
          End;
        End;
        If c > 0 Then
          Inc(cc);
      End;
    End;
    Regs[$F] := cc;
  End Else Begin
    // Lowres mode SChip
    If n = 0 Then n := 16;
    x := Regs[x];
    y := Regs[y];
    pOfs := 16 - ((x Mod 8) * 2);
    x := (x * 2) And 112; y := (y * 2) And 62;
    Regs[$F] := 0;
    For row := 0 To Min(n -1, (62 - y) Div 2) Do Begin
      b := GetMem(i + row);
      b := Bloat(b) Shl pOfs;
      bit := $80000000;
      For col := 0 To Min(31, 127 - x) Do Begin
        bts := Ord(b And bit > 0);
        bit := bit Shr 1;
        Addr := x + col + (y + row * 2) * 128;
        If DisplayMem[Addr] <> 0 Then Inc(cc);
        np := DisplayMem[Addr] Xor bts;
        DisplayMem[Addr] := np;
        DisplayMem[Addr + 128] := np;
      End;
    End;
    If cc > 0 Then Regs[$F] := 1;
    icnt := maxipf;
  End;
  DisplayFlag := True;
End;

Procedure TSChipLegacy10Core.OpFxnn;
Begin
  OpcodesF[ci And $FF];
End;

Procedure TSChipLegacy10Core.OpFX29;
Begin
  // Fx29 - i = Character address in Reg X
  x := (ci Shr 8) And $F;
  If Regs[x] And $F0 = 1 Then
    i := $A0 + (Regs[x] And $F) * 10
  Else
    i := $50 + (Regs[x] And $F) * 5;
End;

Procedure TSChipLegacy10Core.OpFx55;
Var
  idx: Integer;
Begin
  // Fx55 - Store x regs to RAM
  x := (ci Shr 8) And $F;
  For idx := 0 To x Do WriteMem(i + idx, Regs[idx]);
  Inc(i, x);
End;

Procedure TSChipLegacy10Core.OpFx65;
Var
  idx: Integer;
Begin
  // Fx65 - Get x regs from RAM
  x := (ci Shr 8) And $F;
  For idx := 0 To x Do Regs[idx] := GetMem(i + idx);
  Inc(i, x);
End;

Procedure TSChipLegacy10Core.OpFx75;
Var
  i: Integer;
Begin
  // Fx75 - Save registers to storage
  x := (ci Shr 8) And $F;
  For i := 0 To x Do
    Storage[i] := Regs[i];
End;

Procedure TSChipLegacy10Core.OpFx85;
Var
  i: Integer;
Begin
  // Fx85 - Load registers from storage
  x := (ci Shr 8) And $F;
  For i := 0 To x Do
    Regs[i] := Storage[i];
End;

end.
