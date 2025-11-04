unit Core_MegaChip;

interface

Uses SyncObjs, Core_Def, Core_sChipLegacy11;

Type

  TClr = packed record
    case Integer of
      0: (B, G, R, A: Byte);
      1: (ARGB: LongWord);
    End;

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
    iSample: TSampleBuffer;
    SamplePlaying: Boolean;

    Procedure InstructionLoop; Override;
    Procedure BuildTables; Override;
    Procedure Reset; Override;
    Procedure Present; Override;
    Function  GetMem(Address: Integer): Byte; Override;
    Procedure WriteMem(Address: Integer; Value: Byte); Override;
    Function  AlphaBlend(rgb1, rgb2: LongWord; t: Byte): Longword; inline;
    Function  Blend(rgb1, rgb2: TClr): TClr;
    Procedure DoSoundTimer; Override;
    Procedure BlendBuffers;
    Procedure FlipBuffers;
    Procedure Skip01nn;

    Procedure Op0nnn; Override; Procedure OpBnnn; Override; Procedure OpDxyn; Override; Procedure Op00FE; Override;
    Procedure Op00FF; Override; Procedure Op3xnn; Override; Procedure Op4xnn; Override; Procedure Op5xy0; Override;
    Procedure Op9xy0; Override; Procedure OpEx9E; Override; Procedure OpExA1; Override; Procedure Op00E0; Override;
    Procedure Op00Cn; Override; Procedure Op00FB; Override; Procedure Op00FC; Override; Procedure OpFx0A; Override;
    Procedure OpFx1E; Override;

    Procedure Op0010; Procedure Op0011; Procedure Op01nn; Procedure Op02nn; Procedure Op03nn; Procedure Op04nn;
    Procedure Op05nn; Procedure Op060n; Procedure Op0700; Procedure Op080n; Procedure Op09nn; Procedure Op00Bn;
  End;

  Function IntColorMult(color1, color2: Byte): Byte; inline;

implementation

Uses SysUtils, Classes, Windows, Math, Chip8Int, Display, Sound, Fonts;

Const

  Opacities: Array[0..5] of Byte = (255, 64, 128, 192, 255, 255);

Procedure TMegaChipCore.FlipBuffers;
Begin

  CurBuffer := 1 - CurBuffer;

End;

Function TMegaChipCore.AlphaBlend(rgb1, rgb2: LongWord; t: Byte): Longword;
Var
  s: LongWord;
Begin

  s := 255 - t;
  Result := ((((rgb1 And $FF) * s + (rgb2 And $FF) * t) Shr 8)) Or
            (((((rgb1 Shr 8) And $ff) * s + ((rgb2 Shr 8) And $ff) * t)) And Not $ff) Or
            (((((rgb1 Shr 16) And $ff) * s + ((rgb2 Shr 16) And $ff) * t) Shl 8) And Not $ffff) Or
            (((((rgb1 Shr 24) And $ff) * s + ((rgb2 Shr 24) And $ff) * t) Shl 16) And Not $ffffff);
End;

Function IntColorMult(color1, color2: Byte): Byte;
Begin
  Result := ((color1 * (color2 or color2 shl 8)) + $8080) shr 16;
End;

Function TMegaChipCore.Blend(rgb1, rgb2: TClr): TClr;
Var
  Am: Byte;
Begin

  rgb1.A := IntColorMult(rgb1.A, Opacities[SprBlend]);

  If rgb1.A = 0 Then

    Result := rgb2

  Else Begin

    Case SprBlend of
      0..3: // Normal, varying opacity
        Begin
          Result.ARGB := rgb1.ARGB;
        End;
      4:
        Begin // Additive
          Result.ARGB := (Min(rgb1.R + rgb2.R, $FF) Shl 16) or (Min(rgb1.G + rgb2.G, $FF) Shl 8) or Min(rgb1.B + rgb2.B, $FF);
        End;
      5:
        Begin // Multiply
          Result.ARGB := (IntColorMult(rgb1.R, rgb2.R) Shl 16) or (IntColorMult(rgb1.G, rgb2.G) Shl 8) or IntColorMult(rgb1.B, rgb2.B);
        End;
    End;

    If rgb1.A < $FF Then Begin
      Am := 255 - rgb1.A;
      Result.ARGB := (($FF And IntColorMult(rgb2.R, Am) + IntColorMult(Result.R, rgb1.A)) Shl 16) or
                     (($FF And IntColorMult(rgb2.G, Am) + IntColorMult(Result.G, rgb1.A)) Shl 8) or
                      ($FF And IntColorMult(rgb2.B, Am) + IntColorMult(Result.B, rgb1.A));
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

  Opcodes[$D] := OpDxyn; Opcodes0[$FE] := Op00FE; Opcodes0[$FF] := Op00FF; Opcodes0[$B]  := Op00Bn;
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
  LoadFont(Self, Font_Large_Fish);

  FPS := 50;
  MakeSoundBuffers(FPS, Audio);
  DisplayFlag := True;

  MegaPalette[0]   := $FF000000;
  MegaPalette[255] := $FFFFFFFF;
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

  Until FrameDone(iCnt >= maxipf);

  If Timer > 0 then Dec(Timer);
  Inc(iFrameCount);
  emuFrameLength := GetTicks - emuLastTicks;

  DoSoundTimer;

  If DisplayFlag And Not MegaChipMode Then Begin
    Present;
    DisplayUpdate := True;
    DisplayFlag := False;
  End;

  InjectSound(Audio, Not FullSpeed);

  // Metrics

  GetTimings;
  If FullSpeed Then
    Inc(ipf, icnt)
  Else Begin
    ipf := icnt;
  End;

  Dec(icnt, maxIpf);

End;

Procedure TMegaChipCore.Present;
Var
  src: pByte;
  dst1, dst2: pLongWord;
  clr: LongWord;
  py, px: Integer;
Begin

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

  With Audio^ Do Begin

    // If Sound Timer > 0 then generate a tone.
    If sTimer > 0 Then Begin
      Dec(sTimer);
      dcIn := LastS = 0;
      dcOut := sTimer = 0;
      sPos := 0;
      stepSize := (BuzzerTone * CycleLength) / sHz;
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
      DeClick(dcIn, dcOut, Audio);
      SoundFlag := 1;
    End Else
      For Idx := 0 To BuffSize -1 Do
        FrameBuffer[Idx] := 0;

    // If there's a sample playing, then mix it in now.

    If SamplePlaying Then Begin

      sPos := 0;
      While sPos < BuffSize Do Begin
        pSample := (ShortInt(iSample.Data[Trunc(iSample.Position)]) - 128) * 256;
        pSample := pSample Or ((pSample Shr 8) And $FF);
        pSmallInt(@FrameBuffer[sPos])^     := Mix(pSample, pSmallInt(@FrameBuffer[sPos])^);
        pSmallInt(@FrameBuffer[sPos + 2])^ := Mix(pSample, pSmallInt(@FrameBuffer[sPos + 2])^);
        Inc(sPos, 4);
        iSample.Position := iSample.Position + iSample.Delta;
        If iSample.Position >= iSample.Length Then
          If iSample.Loop Then
            iSample.Position := iSample.Position - iSample.Length
          Else Begin
            SamplePlaying := False;
            Break;
          End;
      End;
      SoundFlag := 1;
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
  icnt := ipf -1;
  HiResMode := False;
  DisplayFlag := True;
End;

Procedure TMegaChipCore.Op0011;
Begin
  // 0011 - Enable MegaChip mode
  MegaChipMode := True;
  ipf := 3000;
  icnt := ipf -1;
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
    FlipBuffers;
    FillMemory(@DisplayBuffers[CurBuffer][0], 256 * 192 * 4, 0);
    FillMemory(@CollMap[0], 256 * 192, 0);
    icnt := maxipf -1;
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
  idx, l, clickStart: Integer;
  oSample, Scalar, ScaleInc: Double;
Begin
  // 060n - Play sample at I. Loop if n = 0, else one-shot
  SamplePlaying := True;
  iSample.Rate := (GetMem(i) Shl 8) + GetMem(i + 1);
  iSample.Length := (GetMem(i + 2) Shl 16) + (GetMem(i + 3) Shl 8) + GetMem(i + 4);
  SetLength(iSample.Data, iSample.Length);
  For idx := 0 To iSample.Length -1 Do
    iSample.Data[idx] := GetMem(i + 8 + idx);
  iSample.Loop := (ci And $F) = 0;
  iSample.Position := 0;
  iSample.Delta := iSample.Rate / sHz;
  // De-Click the end of the buffer if it's not looped
  If Not iSample.Loop Then Begin
    clickStart := iSample.Length -1;
    l := Min(43, clickStart);
    Scalar := 0;
    ScaleInc := 1/l;
    For idx := 0 to l Do Begin
      oSample := (pByte(@iSample.Data[clickStart - idx])^ - 128) * Scalar;
      pByte(@iSample.Data[clickStart - idx])^ := Trunc(oSample + 128);
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
  row, col, cy, cx, idx, pIdx, dOffs, mult, icnt2: Integer;
  b, bts, bit: Byte;
  p: LongWord;
  vF: Boolean;

  Function fixedScale8(x: Byte; y: Word): Byte;
  Begin
    result := Min(255, (x * (y * 257) + $8080) shr 16);
  End;

Begin
  // Dxyn - Draw Sprite
  If Not MegaChipMode Then Begin
    icnt2 := icnt;
    Inherited;
    Regs[$F] := colFlag;
    icnt := icnt2; // Do not display wait. At all.
  End Else Begin
    vF := False;
    x := Regs[(ci Shr 8) And $F] And $FF;
    y := Regs[(ci Shr 4) And $F] And $FF;
    If i <= $FF Then Begin
      // I < 256 means a font draw, so use the old Dxyn for that one.
      n := ci And $F;
      For row := 0 To Min(n -1, 191 - y) Do Begin
        mult := 255 - n * row;
        p := (FixedScale8(mult, 264) Shl 16) or (FixedScale8(mult, 291) Shl 8) or (FixedScale8(mult, 309));
        b := GetMem(i + row);
        bit := $80;
        For col := 0 To Min(7, 255 - x) Do Begin
          bts := Ord(b And bit > 0);
          bit := bit Shr 1;
          If bts > 0 Then Begin
            dOffs := (row + y) * 256 + (col + x);
            vF := vF Or (CollMap[dOffs] = 255);
            CollMap[dOffs] := 255;
            DisplayBuffers[CurBuffer][dOffs] := p;
          End;
        End;
      End;
    End Else Begin
      For row := 0 To SprHeight -1 Do Begin
        cy := row + y;
        If cy > 255 Then
          If DxynWrap Then
            cy := cy And 255
          Else
            Break;
        If cy < 192 Then Begin
          idx := row * SprWidth;
          For col := 0 To SprWidth -1 Do Begin
            cx := x + col;
            If cx > 255 Then
              If DxynWrap Then
                cx := cx And 255
              Else
                Break;
            pIdx := GetMem(I + idx);
            If pIdx <> 0 Then Begin
              dOffs := cy * 256 + cx;
              vF := vF Or (CollMap[dOffs] = CollClr);
              CollMap[dOffs] := pIdx;
              DisplayBuffers[CurBuffer][dOffs] := Blend(TClr(MegaPalette[pIdx]), TClr(DisplayBuffers[CurBuffer][dOffs])).ARGB;
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
Var
  Key: integer;
Begin
  // Advance PC if key in x is down
  Key := Regs[(ci Shr 8) And $F] And $F;
  If Press_Fx0A And (Key = LastFx0A) Then
    t := 0
  Else
    t := 2 * Ord(KeyStates[Key]);
  If t > 0 Then Skip01nn;
  Inc(PC, t);
End;

Procedure TMegaChipCore.OpExA1;
Var
  Key: integer;
Begin
  // Advance PC if key in x is up
  Key := Regs[(ci Shr 8) And $F] And $F;
  If Press_Fx0A And (Key = LastFx0A) Then
    t := 2
  Else
    t := 2 * Ord(Not KeyStates[Key]);
  If t > 0 Then Skip01nn;
  Inc(PC, t);
End;

Procedure TMegaChipCore.OpFx0A;
Begin
  // Fx0A - Wait for KeyPress
  Present;
  Inherited;
  If KeyStage <> 0 Then
    icnt := maxipf -1;
End;

Procedure TMegaChipCore.OpFx1E;
Begin
  // Fx1E - Index += Reg X
  i := (i + Regs[(ci Shr 8) And $F]) And $FFFFFF;
End;

end.
