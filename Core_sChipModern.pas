unit Core_sChipModern;

interface

Uses Core_Def, Core_sChipLegacy11;

Type

  TSChipModernCore = Class(TSChipLegacy11Core)
    Procedure BuildTables; Override;
    Procedure Reset; Override;

    // Basic Chip8 opcodes

    Procedure OpDxyn; Override;

    // Modern SChip opcodes - Dxyn handles Dxy0 too for simplicity

    Procedure Op00Cn; Override; Procedure Op00FB; Override; Procedure Op00FC; Override; Procedure Op00FE; Override; Procedure Op00FF; Override;

  End;

implementation

Uses Windows, SysUtils, Classes, Math, Chip8Int, Display, Sound, Fonts;

Procedure TSChipModernCore.BuildTables;
Var
  idx: Integer;
Begin

  Inherited;

  Opcodes[13] := OpDxyn;
  Opcodes0[$FB] := Op00FB; Opcodes0[$FC] := Op00FC;
  Opcodes0[$FE] := Op00FE; Opcodes0[$FF] := Op00FF;

  For idx := 0 to $F Do Opcodes0[$C0 or idx] := Op00Cn;

End;

Procedure TSChipModernCore.Reset;
Begin

  Inherited;

  FillMemory(@Memory[0], Length(Memory), 0);
  LoadFont(Self, Font_Small_VIP);
  LoadFont(Self, Font_Large_schip11);
  FPS := 60;
  MakeSoundBuffers(FPS, Audio);
  DisplayWait := False;

End;

// Begin Core opcodes

Procedure TSChipModernCore.Op00Cn;
var
  x, y: Integer;
Begin
  // $00Cn - Scroll display down n pixels.
  n := (ci And $F) * (1 + Ord(Not HiResMode));
  For y := 63 DownTo n Do
    For x := 0 To 127 Do
      DisplayMem[y * 128 + x] := DisplayMem[(y - n) * 128 + x];
  For y := 0 To n-1 Do
    For x := 0 To 127 Do
      DisplayMem[y * 128 + x] := 0;
  DisplayFlag := True;
End;

Procedure TSChipModernCore.Op00FB;
Var
  x, y, n: Integer;
Begin
  // $00FB - Scroll right 4 pixels
  n := 4 * (1 + Ord(Not HiResMode));
  For y := 0 To 63 Do Begin
    For x := 127 DownTo n Do
      DisplayMem[y * 128 + x] := DisplayMem[y * 128 + x - n];
    For x := 0 To n - 1 Do
      DisplayMem[y * 128 + x] := 0;
  End;
  DisplayFlag := True;
End;

Procedure TSChipModernCore.Op00FC;
Var
  x, y, n: Integer;
Begin
  // $00FC - Scroll left 4 pixels
  n := 4 * (1 + Ord(Not HiResMode));
  For y := 0 To 63 Do Begin
    For x := 0 To 127 - n Do
      DisplayMem[y * 128 + x] := DisplayMem[y * 128 + x + n];
    For x := 127 - n + 1 To 127 Do
      DisplayMem[y * 128 + x] := 0;
  End;
  DisplayFlag := True;
End;

Procedure TSChipModernCore.Op00FE;
Begin
  // $00FE - Switch to Lowres mode, clear display
  hiresMode := False;
  FillMemory(@DisplayMem[0], Length(DisplayMem), 0);
  DisplayFlag := True;
End;

Procedure TSChipModernCore.Op00FF;
Begin
  // $00FF - Switch to Hires mode, clear display
  hiresMode := True;
  FillMemory(@DisplayMem[0], Length(DisplayMem), 0);
  DisplayFlag := True;
End;

Procedure TSChipModernCore.OpDxyn;
Var
  cc, row, col, c, w, h, lx, ly: Integer;
  bit, b, bts, Addr: LongWord;
  np: Word;

  Procedure XorPixel;
  Begin
    If HiResMode Then begin
      Addr := ((x + col) And 127) + ((y + row) And 63) * 128;
      If DisplayMem[Addr] <> 0 Then c := c Or 1;
      DisplayMem[Addr] := DisplayMem[Addr] Xor bts;
    End Else Begin
      Addr := (((x * 2) + (Col * 2)) And 127) + (((y * 2) + row * 2) And 63) * 128;
      If DisplayMem[Addr] <> 0 Then c := c Or 1;
      np := DisplayMem[Addr] Xor bts; np := (np Shl 8) Or np;
      pWord(@DisplayMem[Addr])^ := np;
      pWord(@DisplayMem[Addr + 128])^ := np;
    End;
  End;

Begin
  // Dxyn - draw "sprite"
  n := ci And $F;
  x := ((ci Shr 8) And $F);
  y := ((ci Shr 4) And $F);
  cc := 0;
  w := 127 Shr Ord(Not HiresMode);
  h := 63 Shr Ord(Not HiresMode);
  x := Regs[x] And w;
  y := Regs[y] And h;
  If n = 0 Then Begin
    // Dxy0 - 16x16 sprite
    If Not DoQuirks or Not DxynWrap Then
      ly := Min(15, h - y)
    Else
      ly := 15;
    For row := 0 to ly Do Begin
      b := GetMem(i + row * 2) Shl 8 + GetMem(i + 1 + row * 2);
      bit := $8000;
      c := 0;
      If Not DoQuirks or Not DxynWrap Then
        lx := Min(15, w - x)
      Else
        lx := 15;
      For col := 0 To lx Do Begin
        bts := Ord(b And bit > 0);
        bit := bit Shr 1;
        If bts > 0 Then XorPixel;
      End;
      If c > 0 Then
        Inc(cc);
    End;
  End Else Begin
    // Dxyn - 8xn sprite
    If Not DoQuirks or Not DxynWrap Then
      ly := Min(n - 1, h - y)
    Else
      ly := n - 1;
    For row := 0 To ly Do Begin
      b := GetMem(i + row);
      bit := $80;
      c := 0;
      If Not DoQuirks or Not DxynWrap Then
        lx := Min(7, w - x)
      Else
        lx := 7;
      For col := 0 To lx Do Begin
        bts := Ord(b And bit > 0);
        bit := bit Shr 1;
        If bts > 0 Then XorPixel;
      End;
      If c > 0 Then
        Inc(cc);
    End;
  End;
  Regs[$F] := Ord(cc <> 0);
  If DisplayWait Then iCnt := maxipf -1;
  DisplayFlag := True;
End;

end.
