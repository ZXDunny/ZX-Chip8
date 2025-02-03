unit Core_Chip8x;

interface

Uses SyncObjs, Core_Def, Core_Chip8;

Type

  TChip8XCore = Class(TChip8Core)
    BackClr: Integer;
    ColourMap: Array[0..255] of Byte;
    ColourMode: Boolean; // True = highres, False = lowres
    KeyStates2: Array[0..15] Of Boolean;

    Procedure BuildTables; Override;
    Procedure Reset; Override;
    Procedure Present; Override;
    Procedure LoadROM(Filename: String; DoReset: Boolean); Override;
    Procedure KeyDown(Key: Integer); Override;
    Procedure KeyUp(Key: Integer); Override;

    Procedure Op5xy0; Override;
    Procedure OpFxF8; Procedure OpFxFB; Procedure OpExF2;
    Procedure OpExF5; Procedure OpBxyn; Procedure Op02A0;
    Procedure Op5xy1;

  End;

Const

  KeyCodes2: Array[0..$F] of Char =
    ('N', '5', '6', '7',
     'T', 'Y', 'U', 'G',
     'H', 'J', 'B', 'M',
     '8', 'I', 'K', ',');

  Palette8X_FG: Array[0..7] of LongWord = ($111111, $C00000, $0000C0, $C000C0, $00C000, $C0C000, $00C0C0, $C0C0C0);
  Palette8X_BG: Array[0..7] of LongWord = ($000000, $800000, $000080, $800080, $008000, $808000, $008080, $808080);

implementation

Uses Windows, SysUtils, Classes, Math, Display, Sound, Chip8Int;

Procedure TChip8XCore.BuildTables;
Begin

  Inherited;

  SetLength(PresentDisplay, 64 * 32 * 4);
  DispDepth := 32;

  Opcodes[$0B]  := OpBxyn;
  OpcodesF[$F8] := OpFxF8;
  OpcodesF[$FB] := OpFxFB;
  OpcodesE[$F2] := OpExF2;
  OpcodesE[$F5] := OpExF5;
  Opcodes0[$A0] := Op02A0;
  Opcodes[$05]  := Op5xy0;

End;

Procedure TChip8XCore.LoadROM(Filename: String; DoReset: Boolean);
Var
  f: TFileStream;
  bin: Array of Byte;
  idx: Integer;
Begin

  if FileExists(Filename) Then Begin
    f := TFileStream.Create(Filename, fmOpenRead or fmShareDenyNone);
    SetLength(bin, f.Size);
    f.Read(bin[0], f.Size);
    f.Free;

    If DoReset then Reset;

    for idx := 0 to Min(High(bin), High(Memory) - 768) do
      Memory[idx + 768] := bin[idx];

    PC := 768;
    mCycles := 3250;
    NextFrame := 3668;

  End;

End;

Procedure TChip8XCore.Reset;
Begin

  Inherited;

  // Set the colours to white on blue.

  BackClr := 2;
  ColourMode := False;
  FillMemory(@ColourMap[0], 256, 0);
  FillMemory(@DisplayMem[0], 64 * 32, 0);
  ColourMap[0] := 2;

  FPS := 61;
  MakeSoundBuffers(FPS, Audio);
  BuzzerTone := 213;

End;

Procedure TChip8xCore.Present;
Var
  x, y, idx, ch: Integer;
Begin

  DisplayLock.Enter;

  ch := Ord(Not ColourMode) * 3 + 1;
  For y := 0 To DispHeight -1 Do
    For x := 0 To DispWidth -1 Do Begin
      idx := x + y * DispWidth;
      If DisplayMem[idx] = 0 Then
        pLongWord(@PresentDisplay[idx * 4])^ := Palette8x_BG[BackClr]
      Else
        pLongWord(@PresentDisplay[idx * 4])^ := Palette8x_FG[ColourMap[((y div ch) * ch * 8) + (x Div 8)]];
    End;

  DisplayUpdate := True;
  DisplayFlag := False;

  DisplayLock.Leave;

End;

Procedure TChip8XCore.KeyDown(Key: Integer);
Var
  idx: Integer;
Begin

  inherited;

  For idx := 0 To 15 Do
    If Key = Ord(KeyCodes2[idx]) Then
      KeyStates2[idx] := True;

End;

Procedure TChip8XCore.KeyUp(Key: Integer);
Var
  idx: Integer;
Begin

  inherited;

  For idx := 0 To 15 Do
    If Key = Ord(KeyCodes2[idx]) Then
      KeyStates2[idx] := False;

End;

// Opcodes

Procedure TChip8XCore.Op5xy0;
Begin
  // 5xy0 - Skip if Reg X = Reg Y
  If ci And $F = 1 Then
    Op5xy1
  Else
    If Regs[(ci Shr 8) And $F] = Regs[(ci Shr 4) And $F] Then Begin
      Inc(PC, 2);
      Cycles := 14;
    End Else
      Cycles := 10;
End;

Procedure TChip8XCore.OpFxF8;
Begin
  // FxF8 - Output to Sound board port
  x := Regs[(ci Shr 8) And $F];
  If x = 0 Then x := $80;
  BuzzerTone := 440000/((x+1) * 16);
End;

Procedure TChip8XCore.OpFxFB;
Var
  idx: Byte;
Begin
  // FxFB - Get input from Keypad 2 into vX
  Dec(PC, 2);
  Cycles := NextFrame - mCycles;
  Case keyStage of
    0: keyStage := 1;
    1:
      Begin
        For idx := 0 To 15 Do
          If KeyStates2[idx] Then Begin
            Regs[(ci Shr 8) And $F] := idx;
            keyStage := 2;
            Break;
          End;
      End;
    2:
      If Not KeyStates2[Regs[(ci Shr 8) And $F]] Then Begin
        KeyStage := 0;
        Inc(PC, 2);
        Cycles := 8;
      End;
  End;
End;

Procedure TChip8XCore.OpExF2;
Begin
  // ExF2 - Skip if Key in vX is down on Keypad 2
  t := 2 * Ord(KeyStates2[Regs[(ci Shr 8) And $F] And $F]);
  Inc(PC, t);
  Cycles := 14 + 2 * t;
End;

Procedure TChip8XCore.OpExF5;
Begin
  // ExF5 - Skip if key in vX is up on Keypad 2
  t := 2 * Ord(Not KeyStates2[Regs[(ci Shr 8) And $F] And $F]);
  Inc(PC, t);
  Cycles := 14 + 2 * t;
End;

Procedure TChip8XCore.OpBxyn;
Var
  row, Col, Clr, xx: Integer;
  HPos, HSize, VPos, VSize: Byte;
Begin
  // Bxy0 and Bxyn - Handle colours
  If ci And $F = 0 Then Begin
    // Bxy0
    x := (ci Shr 8) And $F;
    y := (ci Shr 4) And $F;
    Clr := Regs[y] And 7;

    xx := Regs[x];
    HSize := xx Shr 4;
    HPos  := xx And $F;

    xx := Regs[x + 1];
    VSize := xx Shr 4;
    VPos := xx And $F;

    ColourMode := False;
    For row := VPos To VPos + VSize Do
      For col := HPos To HPos + HSize Do
        ColourMap[(col Mod 8) + (((row * 4) And 31) * 8)] := Clr;
  End Else Begin
    // Bxyn
    x := (ci Shr 8) And $F;
    y := (ci Shr 4) And $F;
    n := ci And $F;

    Clr := Regs[y] And 7;
    HPos := (Regs[x] Shr 3) And 7;
    VPos := Regs[x + 1] And 31;

    ColourMode := True;
    For row := VPos To VPos + n - 1 Do
      ColourMap[(HPos Mod 8) + ((row And 31) * 8)] := Clr;
  End;
  DisplayFlag := True;
End;

Procedure TChip8XCore.Op02A0;
Begin
  // 02A0 - Step background colour
  Case BackClr of
    2: BackClr := 0;
    0: BackClr := 4;
    4: BackClr := 1;
    1: BackClr := 2;
  End;
End;

Procedure TChip8XCore.Op5xy1;
Var
  H, L: Byte;
Begin
  // 5xy1 - Add vX to vY
  x := (ci Shr 8) And $F;
  y := (ci Shr 4) And $F;
  H := (((Regs[x] Shr 4) And $F) + ((Regs[y] Shr 4) And $F)) And 7;
  L := ((Regs[x] And $F) + (Regs[y] And $F)) And 7;
  Regs[x] := (H Shl 4) Or L;
End;

end.
