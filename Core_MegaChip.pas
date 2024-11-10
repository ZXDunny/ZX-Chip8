unit Core_MegaChip;

interface

Uses SyncObjs, Core_Def, Core_sChipLegacy11;

Type

  TSampleBuffer = Record
    Data: Array of Byte;
    Rate, Length: Integer;
    Position, Delta: Double;
    Loop: Boolean;
  End;

  TMegaChipCore = Class(TSChipLegacy11Core)
    MegaChipMode: Boolean;
    MegaPalette: Array[0..$FF] of LongWord;
    DisplayBuffers: Array[0..1] of Array[0..256 * 192 -1] of LongWord;
    CollMap: Array[0..256 * 192 -1] of Byte;
    SprWidth, SprHeight, SprBlend: integer;
    Alpha, CollClr: Byte;
    CurBuffer: Integer;
    Sample: TSampleBuffer;
    SamplePlaying: Boolean;

    Procedure InstructionLoop; Override;
    Procedure BuildTables; Override;
    Procedure Reset; Override;
    Procedure Present; Override;
    Function  GetMem(Address: Integer): Byte; Override;
    Procedure WriteMem(Address: Integer; Value: Byte); Override;
    Function  AlphaBlend(rgb1, rgb2: LongWord; t: Byte): Longword; inline;
    Function  Blend(rgb1, rgb2: LongWord): LongWord;
    Procedure DoSoundTimer; Override;
    Procedure BlendBuffers;
    Procedure Skip01nn;

    Procedure Op0nnn; Override; Procedure OpBnnn; Override; Procedure OpDxyn; Override; Procedure Op00FE; Override;
    Procedure Op00FF; Override; Procedure Op3xnn; Override; Procedure Op4xnn; Override; Procedure Op5xy0; Override;
    Procedure Op9xy0; Override; Procedure OpEx9E; Override; Procedure OpExA1; Override; Procedure Op00E0; Override;
    Procedure Op00Cn; Override; Procedure Op00FB; Override; Procedure Op00FC; Override; Procedure OpFx0A; Override;
    Procedure OpFx1E; Override;

    Procedure Op0010; Procedure Op0011; Procedure Op01nn; Procedure Op02nn; Procedure Op03nn;
    Procedure Op04nn; Procedure Op05nn; Procedure Op060n; Procedure Op0700; Procedure Op080n; Procedure Op09nn;
    Procedure Op00Bn;
  End;

Var

  LastInstruction: Integer;

implementation

Uses SysUtils, Classes, Windows, Math, Chip8Int, Display, Sound;

Function TMegaChipCore.AlphaBlend(rgb1, rgb2: LongWord; t: Byte): Longword;
Var
  s: LongWord;
Begin
  s := 255 - t;
  Result := (((((rgb1 Shr 0) And $FF) * s + ((rgb2 Shr 0) And $FF) * t) Shr 8)) Or (((((rgb1 Shr 8) And $ff) * s + ((rgb2 Shr 8) And $ff) * t)) And Not $ff) Or
            (((((rgb1 Shr 16) And $ff) * s + ((rgb2 Shr 16) And $ff) * t) Shl 8) And Not $ffff) Or (((((rgb1 Shr 24) And $ff) * s + ((rgb2 Shr 24) And $ff) * t) Shl 16) And Not $ffffff);
End;

Function TMegaChipCore.Blend(rgb1, rgb2: LongWord): LongWord;
Begin

  // Blend
  Case SprBlend of
    0: // Normal
      Begin
        Result := rgb2;
      End;
    1: // 25%
      Begin
        Result := ((rgb2 and $FCFCFCFC) shr 2) * 1 + ((rgb1 and $FCFCFCFC) shr 2) * 3;
      End;
    2: // 50%
      Begin
        Result := ((rgb1 and $FEFEFEFE) shr 1) + ((rgb2 and $FEFEFEFE) shr 1);
      End;
    3: // 75%
      Begin
        Result := ((rgb1 and $FCFCFCFC) shr 2) * 1 + ((rgb2 and $FCFCFCFC) shr 2) * 3;
      End;
    4: // Additive
      Begin
        Result := (Min(((rgb1 shr 24) and $FF) + ((rgb2 shr 24) and $FF), 255) shl 24) or
                  (Min(((rgb1 shr 16) and $FF) + ((rgb2 shr 16) and $FF), 255) shl 16) or
                  (Min(((rgb1 shr  8) and $FF) + ((rgb2 shr  8) and $FF), 255) shl  8) or
                   Min((rgb1 and $FF) + (rgb2 and $FF), 255);
      End;
    5: // Multiply
      Begin
        Result := (((((rgb1 shr 24) and $FF) * ((rgb2 shr 24) and $FF)) div 255) shl 24) or
                  (((((rgb1 shr 16) and $FF) * ((rgb2 shr 16) and $FF)) div 255) shl 16) or
                  (((((rgb1 shr  8) and $FF) * ((rgb2 shr  8) and $FF)) div 255) shl  8) or
                  (((rgb1 and $FF) * (rgb2 and $FF)) div 255);
      End;
  Else
    Begin
      Result := rgb2;
    End;
  End;
End;

Procedure TMegaChipCore.Skip01nn;
Begin
  If GetMem(PC) = $01 Then Inc(PC, 2);
End;

Procedure TMegaChipCore.BuildTables;
Var
  idx: Integer;
Begin

  Inherited;

  SetDisplay(128, 64, 8);

  // Override the display as we have two of them now.

  SetLength(PresentDisplay, 256 * 192 * 4);
  DispWidth := 256;
  DispHeight := 192;
  DispDepth := 32;

  // And continue.

  maxipf := 3000;

  Opcodes[11] := OpBnnn;

  Opcodes[$D] := OpDxyn; Opcodes0[$FE] := Op00FE; Opcodes0[$FF] := Op00FF; Opcodes[$B]   := Op00Bn;
  Opcodes[3]  := Op3xnn; Opcodes[4]    := Op4xnn; Opcodes[5]    := Op5xy0; OpcodesF[$1E] := OpFx1E;
  Opcodes[9]  := Op9xy0; OpcodesE[$9E] := OpEx9E; OpcodesE[$A1] := OpExA1;

  OpCodes0[$10] := Op0010; Opcodes0[$11] := Op0011;

  For idx := 0 to $F Do Opcodes0[$B0 or idx] := Op00Bn;

  OpCodesM[1] := Op01nn; OpCodesM[2] := Op02nn; OpCodesM[3] := Op03nn; OpCodesM[4] := Op04nn;
  OpCodesM[5] := Op05nn; OpCodesM[6] := Op060n; OpCodesM[7] := Op0700; OpCodesM[8] := Op080n;
  OpCodesM[9] := Op09nn;

  OpcodesF[$A] := OpFx0A;

End;

Procedure TMegaChipCore.Reset;
Begin

  Inherited;
  SetLength(Memory, 1024 * 1024 * 16);
  FillMemory(@DisplayBuffers[0][0], 256 * 192 * 4, 0);
  FillMemory(@DisplayBuffers[1][0], 256 * 192 * 4, 0);
  FillMemory(@CollMap[0], 256 * 192, 0);
  FillMemory(@DisplayMem[0], Length(DisplayMem), 0);
  MakeSoundBuffers(50, 4);
  DisplayFlag := True;

  MegaPalette[0]   := $00000000;
  MegaPalette[255] := $00FFFFFF;
  MegaPalette[254] := $FFE4DCD4;

  MegaChipMode := False;
  SprBlend := 0;
  SprWidth := 0;
  SprHeight := 0;
  CurBuffer := 0;

  SamplePlaying := False;

End;

Function TMegaChipCore.GetMem(Address: Integer): Byte;
Begin

  Result := Memory[Address And $FFFFFF];

End;

Procedure TMegaChipCore.WriteMem(Address: Integer; Value: Byte);
Begin

  Memory[Address And $FFFFFF] := Value;

End;

Procedure TMegaChipCore.InstructionLoop;
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

  If DisplayFlag And Not MegaChipMode Then Begin
    Present;
    DisplayUpdate := True;
    DisplayFlag := False;
  End;

  InjectSound(@FrameBuffer[0], Not FullSpeed);

  If FullSpeed Then
    Inc(ipf, icnt)
  Else Begin
    ipf := icnt;
  End;
  icnt := 0;

End;

Procedure TMegaChipCore.Present;
Var
  src: pByte;
  dst1, dst2: pLongWord;
  clr: LongWord;
  py, px: Integer;
Begin

  // Prepare the display for update.

  DisplayLock.Enter;

  If Not MegaChipMode Then Begin
    FillMemory(@PresentDisplay[0], 256 * 192 * 4, 0);
    src := @DisplayMem[0];
    For py := 0 To 63 Do Begin
      dst1 := @PresentDisplay[(py * 2 + 32) * 256 * 4];
      dst2 := @PresentDisplay[(py * 2 + 33) * 256 * 4];
      For px := 0 To 127 Do Begin
        clr := Palette[src^];
        dst1^ := clr;
        dst2^ := clr;
        Inc(dst1);
        Inc(dst2);
        dst1^ := clr;
        dst2^ := clr;
        Inc(dst1);
        Inc(dst2);
        Inc(src);
      End;
    End;
  End Else Begin
    CopyMemory(@PresentDisplay[0], @DisplayBuffers[CurBuffer][0], 256 * 192 * 4);
    DisplayUpdate := True;
    CurBuffer := 1 - CurBuffer;
  End;

  DisplayLock.Leave;

End;

Procedure TMegaChipCore.BlendBuffers;
Var
  idx: Integer;
  src1, src2, dst: pLongword;
Begin

  src1 := @DisplayBuffers[1 - CurBuffer][0];
  src2 := @DisplayBuffers[CurBuffer][0];
  dst := @PresentDisplay[0];

  For idx := 0 To 256 * 192 Do Begin
    dst^ := AlphaBlend(src1^, src2^, 255 - ((src1^ And $FF000000) Shr 24));
    Inc(src1);
    Inc(src2);
    Inc(dst);
  End;

  DisplayUpdate := True;

End;

Procedure TMegaChipCore.DoSoundTimer;
Var
  idx, sPos: Integer;
  oSample: Word;
  dcIn, dcOut: Boolean;
  pSample: SmallInt;
  t, StepSize: Double;

  Function Mix(SampleA, SampleB: SmallInt): SmallInt;
  Begin
    Result := SmallInt((SampleA + SampleB) - SampleA * SampleB * Sign(SampleA + SampleB));
  End;

Const
  CycleLength = 1024;

Begin
  // If Sound Timer > 0 then generate a tone.
  If sTimer > 0 Then Begin
    Dec(sTimer);
    dcIn := LastS = 0;
    dcOut := sTimer = 0;
    sPos := 0;
    stepSize := (BuzzerTone * CycleLength) / 44100;
    While sPos < BuffSize Do Begin
      t := sBuffPos * 6.283 / CycleLength;
      oSample := Round(16384 * (sin(t) + sin(t * 3) / 3));
      pWord(@FrameBuffer[sPos])^ := oSample;
      pWord(@FrameBuffer[sPos + 2])^ := oSample;
      sBuffPos := sBuffPos + stepSize;
      if sBuffPos >= CycleLength then
        sBuffPos := sBuffPos - CycleLength;
      Inc(sPos, 4);
    end;
    DeClick(dcIn, dcOut);
  End Else
    For Idx := 0 To BuffSize -1 Do
      FrameBuffer[Idx] := 0;

  // If there's a sample playing, then mix it in now.

  If SamplePlaying Then Begin

    sPos := 0;
    While sPos < BuffSize Do Begin
      pSample := (Byte(Sample.Data[Trunc(Sample.Position)]) - 128) Shl 8;
      pSample := pSample Or ((pSample Shr 8) And $FF);
      pSmallInt(@FrameBuffer[sPos])^     := Mix(pSample, pSmallInt(@FrameBuffer[sPos])^);
      pSmallInt(@FrameBuffer[sPos + 2])^ := Mix(pSample, pSmallInt(@FrameBuffer[sPos + 2])^);
      Inc(sPos, 4);
      Sample.Position := Sample.Position + Sample.Delta;
      If Sample.Position > Sample.Length Then
        If Sample.Loop Then
          Sample.Position := Sample.Position - Sample.Length
        Else Begin
          SamplePlaying := False;
          Break;
        End;
    End;
  End;

  LastS := sTimer;
End;

// Opcodes

Procedure TMegaChipCore.Op0nnn;
Begin
  If (ci Shr 8) And $FF = 0 Then
    Opcodes0[ci And $FF]
  Else
    OpcodesM[(ci Shr 8) And $F];
End;

Procedure TMegaChipCore.Op0010;
Begin
  // 0010 - Disable MegaChip mode
  MegaChipMode := False;
  ipf := 30;
  icnt := ipf;
  HiResMode := False;
  DisplayFlag := True;
End;

Procedure TMegaChipCore.Op0011;
Begin
  // 0011 - Enable MegaChip mode
  MegaChipMode := True;
  ipf := 3000;
  icnt := ipf;
  Present;
End;

Procedure TMegaChipCore.Op00Cn;
var
  x, y: Integer;
Begin
  // $00Cn - Scroll display down n pixels.
  If not MegaChipMode Then
    Inherited
  Else Begin
    n := ci And $F;
    For y := 191 DownTo n Do
      For x := 0 To 255 Do
        DisplayBuffers[1 - CurBuffer][y * 256 + x] := DisplayBuffers[1 - CurBuffer][(y - n) * 256 + x];
    For y := 0 To n - 1 Do
      For x := 0 To 255 Do
        DisplayBuffers[1 - CurBuffer][y * 256 + x] := 0;
    BlendBuffers;
  End;
End;

Procedure TMegaChipCore.Op00FB;
Var
  x, y: Integer;
Begin
  // $00FB - Scroll right 4 pixels
  If Not MegaChipMode Then
    Inherited
  Else Begin
    For y := 0 To 191 Do Begin
      For x := 255 DownTo 4 Do
        DisplayBuffers[1 - CurBuffer][y * 256 + x] := DisplayBuffers[1 - CurBuffer][y * 256 + x - 4];
      For x := 0 To 3 Do
        DisplayBuffers[1 - CurBuffer][y * 256 + x] := 0;
    End;
    BlendBuffers;
  End;
End;

Procedure TMegaChipCore.Op00FC;
Var
  x, y: Integer;
Begin
  // $00FC - Scroll left 4 pixels
  If Not MegaChipMode Then
    Inherited
  Else Begin
    For y := 0 To 191 Do Begin
      For x := 0 To 251 Do
        DisplayBuffers[1 - CurBuffer][y * 256 + x] := DisplayBuffers[1 - CurBuffer][y * 256 + x + 4];
      For x := 252 To 255 Do
        DisplayBuffers[1 - CurBuffer][y * 256 + x] := 0;
    End;
    BlendBuffers;
  End;
End;

Procedure TMegaChipCore.Op00E0;
Begin
  // $00E0 - Clear display
  If MegaChipMode Then Begin
    Present;
    FillMemory(@DisplayBuffers[CurBuffer][0], 256 * 192 * 4, 0);
    FillMemory(@CollMap[0], 256 * 192, 0);
    icnt := maxipf;
  End Else Begin
    FillMemory(@DisplayMem[0], Length(DisplayMem), 0);
    DisplayFlag := True;
  End;
End;

Procedure TMegaChipCore.Op01nn;
Begin
  // 01nn nnnn - Set I to nnnnnn (24bit addressing)
  i := (GetMem(PC) Shl 8) + GetMem(PC + 1) + ((ci And $FF) Shl 16);
  Inc(PC, 2);
End;

Procedure TMegaChipCore.Op02nn;
Var
  j, idx: Integer;
Begin
  // 02nn - Load Palette with nn colours from I
  idx := i;
  For j := 1 To ci and $FF Do Begin
    MegaPalette[j] := (GetMem(idx) Shl 24) + (GetMem(idx + 1) Shl 16) + (GetMem(idx + 2) Shl 8) + GetMem(idx + 3);
    Inc(idx, 4);
  End;
End;

Procedure TMegaChipCore.Op03nn;
Begin
  // 03nn - Sprite Width = nn
  SprWidth := ci And $FF;
  If SprWidth = 0 Then SprWidth := 256;
End;

Procedure TMegaChipCore.Op04nn;
Begin
  // 04nn - Sprite Height = nn
  SprHeight := ci And $FF;
  If SprHeight = 0 Then SprHeight := 256;
End;

Procedure TMegaChipCore.Op05nn;
Begin
  // 05nn - Screen Alpha = nn
  Alpha := ci And $FF;
End;

Procedure TMegaChipCore.Op060n;
Var
  idx, l: Integer;
  oSample, Scalar, ScaleInc: Double;
Begin
  // 060n - Play sample at I. Loop if n = 0, else one-shot
  SamplePlaying := True;
  Sample.Rate := (GetMem(i) Shl 8) + GetMem(i + 1);
  Sample.Length := (GetMem(i + 2) Shl 16) + (GetMem(i + 3) Shl 8) + GetMem(i + 4);
  SetLength(Sample.Data, Sample.Length);
  For idx := 0 To Sample.Length -1 Do
    Sample.Data[idx] := GetMem(i + 8 + idx);
  Sample.Loop := (ci And $F) = 0;
  Sample.Position := 0;
  Sample.Delta := Sample.Rate / 44100;
  // De-Click the end of the buffer if it's not looped
  If Not Sample.Loop Then Begin
    l := Min(43, Sample.Length);
    Scalar := 0;
    ScaleInc := 1/l;
    For idx := 0 to l Do Begin
      oSample := (pByte(@Sample.Data[Sample.Length - (idx + 1)])^ - 128) * Scalar;
      pByte(@Sample.Data[Sample.Length - (idx + 1)])^ := Trunc(oSample + 128);
      Scalar := Scalar + ScaleInc;
    End;
  End;

End;

Procedure TMegaChipCore.Op0700;
Begin
  // 0700 - Stop sample playback
  SamplePlaying := False;
End;

Procedure TMegaChipCore.Op080n;
Begin
  // 080n - Sprite blend mode = n, 0 to 5
  SprBlend := Min(ci And $F, 5);
End;

Procedure TMegaChipCore.Op09nn;
Begin
  // 09nn - Set collision colour.
  CollClr := ci And $FF;
End;

Procedure TMegaChipCore.Op00Bn;
var
  x, y: Integer;
Begin
  // 00Bn - Scroll up n pixels
  If not MegaChipMode Then Begin
    n := (ci And $F) * (1 + Ord(Not HiResMode));
    For y := 0 To 63 - n Do
      For x := 0 To 127 Do
        DisplayMem[y * 128 + x] := DisplayMem[(y + n) * 128 + x];
    For y := 63 - n + 1 To 63 Do
      For x := 0 To 127 Do
        DisplayMem[y * 128 + x] := 0;
    DisplayFlag := True;
  End Else Begin
    n := ci And $F;
    For y := 0 To 191 - n Do
      For x := 0 To 255 Do
        DisplayBuffers[1 - CurBuffer][y * 256 + x] := DisplayBuffers[1 - CurBuffer][(y + n) * 256 + x];
    For y := 191 - n + 1 To 191 Do
      For x := 0 To 255 Do
        DisplayBuffers[1 - CurBuffer][y * 256 + x] := 0;
    BlendBuffers;
  End;
End;

Procedure TMegaChipCore.Op00FE;
Begin
  // 00FE - in non-MegaChip mode, disable hires mode
  If Not MegaChipMode Then Begin
    hiresMode := False;
    DisplayFlag := True;
  End;
End;

Procedure TMegaChipCore.Op00FF;
Begin
  // 00FF - in non-MegaChip mode, enable Hires mode
  If Not MegaChipMode Then Begin
    hiresMode := True;
    DisplayFlag := True;
  End;
End;

Procedure TMegaChipCore.Op3xnn;
Begin
  // 3xnn - Skip if Reg X = nn
  If Regs[(ci Shr 8) And $F] = ci And $FF Then Begin
    Skip01nn;
    Inc(PC, 2);
  End;
End;

Procedure TMegaChipCore.Op4xnn;
Begin
  // 4xnn - Skip if Reg X <> nn
  If Regs[(ci Shr 8) And $F] <> ci And $FF Then Begin
    Skip01nn;
    Inc(PC, 2);
  End;
End;

Procedure TMegaChipCore.Op5xy0;
Begin
  // 5xy0 - Skip if Reg X = Reg Y
  If Regs[(ci Shr 8) And $F] = Regs[(ci Shr 4) And $F] Then Begin
    Skip01nn;
    Inc(PC, 2);
  End;
End;

Procedure TMegaChipCore.Op9xy0;
Begin
  // 9xy0 - Skip if Reg X <> Reg Y
  If Regs[(ci Shr 8) And $F] <> Regs[(ci Shr 4) And $F] Then Begin
    Skip01nn;
    Inc(PC, 2);
  End;
End;

Procedure TMegaChipCore.OpBnnn;
Begin
  // Bnnn - Jump to Offset, same as VIP.
  nnn := ci And $FFF;
  PC := nnn + Regs[0];
End;

Procedure TMegaChipCore.OpDxyn;
Var
  row, col, cy, cx, idx, pIdx, dOffs: Integer;
  b, bts, bit: Byte;
  vF: Boolean;
Const
  Wrapping = False;
Begin
  // Dxyn - Draw Sprite
  If Not MegaChipMode Then
    Inherited
  Else Begin
    vF := False;
    x := Regs[(ci Shr 8) And $F] And $FF;
    y := Regs[(ci Shr 4) And $F] And $FF;
    If i <= $FF Then Begin
      // I < 256 means a font draw, so use the old Dxyn for that one.
      n := ci And $F;
      For row := 0 To Min(n -1, 191 - y) Do Begin
        b := GetMem(i + row);
        bit := $80;
        For col := 0 To Min(7, 255 - x) Do Begin
          bts := Ord(b And bit > 0);
          bit := bit Shr 1;
          If bts > 0 Then Begin
            dOffs := (row + y) * 256 + (col + x);
            vF := vF Or (CollMap[dOffs] = 255);
            CollMap[dOffs] := 255;
            DisplayBuffers[CurBuffer][dOffs] := Palette[1];
          End;
        End;
      End;
    End Else Begin
      For row := 0 To SprHeight -1 Do Begin
        cy := row + y;
        If cy > 255 Then
          If Wrapping Then
            cy := cy And 255
          Else
            Break;
        If cy < 192 Then Begin
          idx := row * SprWidth;
          For col := 0 To SprWidth -1 Do Begin
            cx := x + col;
            If cx > 255 Then
              If Wrapping Then
                cx := cx And 255
              Else
                Break;
            pIdx := GetMem(I + idx);
            If pIdx <> 0 Then Begin
              dOffs := cy * 256 + cx;
              vF := vF Or (CollMap[dOffs] = CollClr);
              CollMap[dOffs] := pIdx;
              DisplayBuffers[CurBuffer][dOffs] := Blend(DisplayBuffers[CurBuffer][dOffs], MegaPalette[pIdx]);
            End;
            Inc(idx);
          End;
        End;
      End;
    End;
    Regs[$F] := Ord(vF);
  End;
End;

Procedure TMegaChipCore.OpEx9E;
Begin
  // Advance PC if key in x is down
  t := 2 * Ord(KeyStates[Regs[(ci Shr 8) And $F] And $F]);
  If t > 0 Then Skip01nn;
  Inc(PC, t);
End;

Procedure TMegaChipCore.OpExA1;
Begin
  // Advance PC if key in x is up
  t := 2 * Ord(Not KeyStates[Regs[(ci Shr 8) And $F] And $F]);
  If t > 0 Then Skip01nn;
  Inc(PC, t);
End;

Procedure TMegaChipCore.OpFx0A;
Begin
  // Fx0A - Wait for KeyPress
  Present;
  Inherited;
  If KeyStage <> 0 Then
    icnt := maxipf;
End;

Procedure TMegaChipCore.OpFx1E;
Begin
  // Fx1E - Index += Reg X
  i := (i + Regs[(ci Shr 8) And $F]) And $FFFFFF;
End;

end.
