unit Core_xoChip;

interface

Uses Core_Def, Core_sChipModern;

Type

  TXOChipCore = Class(TSChipModernCore)
    DisplayMask: Byte;

    Procedure BuildTables; Override;
    Procedure Reset; Override;
    Function  GetMem(Address: Integer): Byte; Override;
    Procedure WriteMem(Address: Integer; Value: Byte); Override;
    Procedure SkipF000; inline;
    Procedure ApplyMask(Dest: pByte; Value: Byte); inline;

    Procedure Op00E0; Override; Procedure Op3xnn; Override; Procedure Op4xnn; Override; Procedure Op5xy0; Override;
    Procedure Op9xy0; Override; Procedure OpDxyn; Override; Procedure OpEx9E; Override; Procedure OpExA1; Override;
    Procedure Op00Cn; Override; Procedure Op00FB; Override; Procedure Op00FC; Override; Procedure Op8xy6; Override;
    Procedure OpFx55; Override; Procedure OpFx65; Override; Procedure OpBnnn; Override; Procedure Op8xyE; Override;
    Procedure OpFx1E; Override; Procedure OpFx75; Override; Procedure OpFx85; Override; Procedure OpFx3A;

    // New xo-Chip opcodes

    Procedure Op00Dn; Procedure Op5nnn; Procedure Op5xy2; Procedure Op5xy3; Procedure OpF000; Procedure OpFn01; Procedure OpF002;
    Procedure Op5xy4;

  End;

implementation

Uses Windows, SysUtils, Classes, Math, Chip8Int, Display;

Procedure TXOChipCore.BuildTables;
Var
  idx: Integer;
Begin

  Inherited;

  maxipf := 1000;

  Opcodes[3]  := Op3xnn; Opcodes[4]  := Op4xnn; Opcodes[5]  := Op5nnn;
  Opcodes[9]  := Op9xy0; Opcodes[11] := OpBnnn; Opcodes[13] := OpDxyn;

  Opcodes0[$E0] := Op00E0;
  Opcodes0[$FB] := Op00FB; Opcodes0[$FC] := Op00FC;

  For idx := 0 to $F Do Begin
    Opcodes0[$C0 or idx] := Op00Cn;
    Opcodes0[$D0 or idx] := Op00Dn;
  End;

  Opcodes5[0] := Op5xy0; Opcodes5[2] := Op5xy2; Opcodes5[3] := Op5xy3; Opcodes5[4] := Op5xy4;
  Opcodes8[6] := Op8xy6; Opcodes8[$E] := Op8xyE; OpcodesE[$9E] := OpEx9E; OpcodesE[$A1] := OpExA1;
  OpcodesF[$1E] := OpFx1E; OpcodesF[$55] := OpFx55; OpcodesF[$65] := OpFx65; OpcodesF[$75] := OpFx75;
  OpcodesF[$85] := OpFx85; OpcodesF[$00] := OpF000; OpcodesF[$01] := OpFn01; OpcodesF[$02] := OpF002;
  OpcodesF[$3A] := OpFx3A;

End;

Function TXOChipCore.GetMem(Address: Integer): Byte;
Begin

  Result := Memory[Address And $FFFF];

End;

Procedure TXOChipCore.WriteMem(Address: Integer; Value: Byte);
Begin

  Memory[Address And $FFFF] := Value;

End;

Procedure TXOChipCore.Reset;
var
  idx: Integer;
Begin

  Inherited;
  DisplayMask := 1;
  for idx := 0 to 159 Do Memory[idx + 160] := xoChipFont[idx];

End;

Procedure TXOChipCore.SkipF000;
Begin
  If (GetMem(PC) Shl 8) + GetMem(PC + 1) = $F000 Then
    Inc(PC, 2);
End;

Procedure TXOChipCore.ApplyMask(Dest: pByte; Value: Byte);
Begin
  Dest^ := (Dest^ and Not DisplayMask) or (Value And DisplayMask);
End;

// Begin Core opcodes

Procedure TXOChipCore.Op00Cn;
var
  x, y: Integer;
Begin
  // $00Cn - Scroll display down n pixels.
  n := (ci And $F) * (1 + Ord(Not HiResMode));
  For y := 63 DownTo n Do
    For x := 0 To 127 Do
      ApplyMask(@DisplayMem[y * 128 + x], DisplayMem[(y - n) * 128 + x]);
  For y := 0 To n-1 Do
    For x := 0 To 127 Do
      ApplyMask(@DisplayMem[y * 128 + x], 0);
  DisplayFlag := True;
End;

Procedure TXOChipCore.Op00Dn;
var
  x, y: Integer;
Begin
  // $00Dn - Scroll display up n pixels.
  n := (ci And $F) * (1 + Ord(Not HiResMode));
  For y := 0 To 63 - n Do
    For x := 0 To 127 Do
      ApplyMask(@DisplayMem[y * 128 + x], DisplayMem[(y + n) * 128 + x]);
  For y := 63 - n + 1 To 63 Do
    For x := 0 To 127 Do
      ApplyMask(@DisplayMem[y * 128 + x], 0);
  DisplayFlag := True;
End;

Procedure TXOChipCore.Op00E0;
var
  idx: Integer;
Begin
  // $00E0 - Clear display
  For idx := 0 To Length(DisplayMem) -1 Do
    ApplyMask(@DisplayMem[idx], 0);
  DisplayFlag := True;
End;

Procedure TXOChipCore.Op00FB;
Var
  x, y, n: Integer;
Begin
  // $00FB - Scroll right 4 pixels
  n := 4 * (1 + Ord(Not HiResMode));
  For y := 0 To 63 Do Begin
    For x := 127 DownTo n Do
      ApplyMask(@DisplayMem[y * 128 + x], DisplayMem[y * 128 + x -n]);
    For x := 0 To n - 1 Do
      ApplyMask(@DisplayMem[y * 128 + x], 0);
  End;
  DisplayFlag := True;
End;

Procedure TXOChipCore.Op00FC;
Var
  x, y, n: Integer;
Begin
  // $00FC - Scroll left 4 pixels
  n := 4 * (1 + Ord(Not HiResMode));
  For y := 0 To 63 Do Begin
    For x := 0 To 127 - n Do
      ApplyMask(@DisplayMem[y * 128 + x], DisplayMem[y * 128 + x + n]);
    For x := 127 - n + 1 To 127 Do
      ApplyMask(@DisplayMem[y * 128 + x], 0);
  End;
  DisplayFlag := True;
End;

Procedure TXOChipCore.Op3xnn;
Begin
  // 3xnn - Skip if Reg X = nn
  If Regs[(ci Shr 8) And $F] = ci And $FF Then Begin
    SkipF000;
    Inc(PC, 2);
  End;
End;

Procedure TXOChipCore.Op4xnn;
Begin
  // 4xnn - Skip if Reg X <> nn
  If Regs[(ci Shr 8) And $F] <> ci And $FF Then Begin
    SkipF000;
    Inc(PC, 2);
  End;
End;

Procedure TXOChipCore.Op5nnn;
Begin
  Opcodes5[ci And $F];
End;

Procedure TXOChipCore.Op5xy0;
Begin
  // 5xy0 - Skip if Reg X = Reg Y
  If Regs[(ci Shr 8) And $F] = Regs[(ci Shr 4) And $F] Then Begin
    SkipF000;
    Inc(PC, 2);
  End;
End;

Procedure TXOChipCore.Op5xy2;
Var
  z: Integer;
Begin
  // 5xy2 - Store Vx to Vy in memory at I
  x := (ci Shr 8) And $F;
  y := (ci Shr 4) And $F;
  If x < y Then Begin
    For z := 0 To Abs(x - y) Do
      Memory[i + z] := Regs[x + z];
  End Else
    For z := 0 To Abs(x - y) Do
      Memory[i + z] := Regs[x - z];
End;

Procedure TXOChipCore.Op5xy3;
Var
  z: Integer;
Begin
  // 5xy2 - Restore Vx to Vy from memory at I
  x := (ci Shr 8) And $F;
  y := (ci Shr 4) And $F;
  If x < y Then Begin
    For z := 0 To Abs(x - y) Do
      Regs[x + z] := Memory[i + z];
  End Else
    For z := 0 To Abs(x - y) Do
      Regs[x - z] := Memory[i + z];
End;

Procedure TXOChipCore.op5xy4;
Begin
  // Nop
End;

Procedure TXOChipCore.Op8xy6;
Begin
  // 8xy6 - Shift Reg X right
  y := (ci Shr 4) And $F;
  t := Regs[y] And 1;
  Regs[(ci Shr 8) And $F] := Regs[y] Shr 1;
  Regs[$F] := t;
End;

Procedure TXOChipCore.Op8xyE;
Begin
  // 8xyE - Shift Reg X left
  y := (ci Shr 4) And $F;
  t := Regs[y] Shr 7;
  Regs[(ci Shr 8) And $F] := Regs[y] Shl 1;
  Regs[$F] := t;
End;

Procedure TXOChipCore.Op9xy0;
Begin
  // 9xy0 - Skip if Reg X <> Reg Y
  If Regs[(ci Shr 8) And $F] <> Regs[(ci Shr 4) And $F] Then Begin
    SkipF000;
    Inc(PC, 2);
  End;
End;

Procedure TXOChipCore.OpBnnn;
Begin
  // Bnnn - Jump to Offset
  nnn := ci And $FFF;
  PC := nnn + Regs[0];
End;

Procedure TXOChipCore.OpDxyn;
Var
  cc, row, col, c, w, h, p, ox, oy, ic: Integer;
  bit, b, bts, Addr: LongWord;
  np, pm: Byte;

  Procedure XorPixel;
  Begin
    If HiresMode Then Begin
      Addr := ((x + col) Mod 128) + ((y + row) Mod 64) * 128;
      If DisplayMem[Addr] And pm <> 0 Then c := c Or 1;
      DisplayMem[Addr] := (DisplayMem[Addr] And Not pm) Or (DisplayMem[Addr] Xor pm);
    End Else Begin
      Addr := (((x * 2) + (Col * 2)) Mod 128) + (((y * 2) + row * 2) mod 64) * 128;
      If DisplayMem[Addr] And pm <> 0 Then c := c Or 1;
      np := (DisplayMem[Addr] And Not pm) or (DisplayMem[Addr] Xor pm);
      DisplayMem[Addr] := np;
      DisplayMem[Addr + 1] := np;
      DisplayMem[Addr + 128] := np;
      DisplayMem[Addr + 129] := np;
    End;
  End;

Begin
  // Dxyn - draw "sprite"
  n := ci And $F;
  ic := i;
  x := ((ci Shr 8) And $F);
  y := ((ci Shr 4) And $F);
  cc := 0;
  w := 127 Shr Ord(Not HiresMode);
  h := 63 Shr Ord(Not HiresMode);
  ox := Regs[x] And w;
  oy := Regs[y] And h;
  For p := 0 To 3 Do Begin
    x := ox;
    y := oy;
    pm := 1 Shl p;
    If DisplayMask And pm <> 0 Then
      If n = 0 Then Begin
        // Dxy0 - 16x16 sprite
        For row := 0 to 15 Do Begin
          b := GetMem(ic + row * 2) Shl 8 + GetMem(ic + 1 + row * 2);
          bit := $8000;
          c := 0;
          For col := 0 To 15 Do Begin
            bts := Ord(b And bit > 0);
            bit := bit Shr 1;
            If bts > 0 Then XorPixel;
          End;
          If c > 0 Then
            Inc(cc);
        End;
        Inc(ic, 32);
      End Else Begin
        // Dxyn - 8xn sprite
        For row := 0 To n -1 Do Begin
          b := GetMem(ic + row);
          bit := $80;
          c := 0;
          For col := 0 To 7 Do Begin
            bts := Ord(b And bit > 0);
            bit := bit Shr 1;
            If bts > 0 Then XorPixel;
          End;
          If c > 0 Then
            Inc(cc);
        End;
        Inc(ic, n);
      End;
  End;
  Regs[$F] := Ord(cc <> 0);

  DisplayFlag := True;
End;

Procedure TXOChipCore.OpEx9E;
Begin
  // Advance PC if key in x is down
  t := 2 * Ord(KeyStates[Regs[(ci Shr 8) And $F] And $F]);
  If t > 0 Then SkipF000;
  Inc(PC, t);
End;

Procedure TXOChipCore.OpExA1;
Begin
  // Advance PC if key in x is up
  t := 2 * Ord(Not KeyStates[Regs[(ci Shr 8) And $F] And $F]);
  If t > 0 Then SkipF000;
  Inc(PC, t);
End;

Procedure TXOChipCore.OpF000;
Begin
  // Load I with 16bit address in nnnn
  i := (GetMem(PC) Shl 8) + GetMem(PC + 1);
  Inc(PC, 2);
End;

Procedure TXOChipCore.OpFn01;
Begin
  // Set display mask to n
  DisplayMask := (ci Shr 8) And $F;
End;

Procedure TXOChipCore.OpF002;
Begin
  // Store 16bytes of audio into the play buffer from I
End;

Procedure TXOChipCore.OpFx1E;
Begin
  // Fx1E - Index += Reg X
  t := i Shr 8;
  i := (i + Regs[(ci Shr 8) And $F]) And $FFFF;
End;

Procedure TXOChipCore.OpFx3A;
Begin
  // Set pitch register to Regs[x];
  x := Regs[(ci Shr 8) And $F];
End;

Procedure TXOChipCore.OpFx55;
Var
  idx: Integer;
Begin
  // Fx55 - Store x regs to RAM
  x := (ci Shr 8) And $F;
  For idx := 0 To x Do WriteMem(i + idx, Regs[idx]);
  Inc(i, x +1);
End;

Procedure TXOChipCore.OpFx65;
Var
  idx: Integer;
Begin
  // Fx65 - Get x regs from RAM
  x := (ci Shr 8) And $F;
  For idx := 0 To x Do Regs[idx] := GetMem(i + idx);
  Inc(i, x +1);
End;

Procedure TXOChipCore.OpFx75;
Var
  i: Integer;
Begin
  // Fx75 - Save registers to storage
  x := (ci Shr 8) And $F;
  For i := 0 To Min(x, 15) Do
    Storage[i] := Regs[i];
End;

Procedure TXOChipCore.OpFx85;
Var
  i: Integer;
Begin
  // Fx85 - Load registers from storage
  x := (ci Shr 8) And $F;
  For i := 0 To Min(x, 15) Do
    Regs[i] := Storage[i];
End;

end.
