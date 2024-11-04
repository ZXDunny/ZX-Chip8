unit Core_Chip8;

interface

Uses SyncObjs, Core_Def, Sound;

Type

  TChip8Core = Class(TCore)
    Function  GetDisplayInfo: TDisplayInfo; Override;
    Procedure SetDisplay(Width, Height, Depth: Integer);
    Procedure BuildTables; Virtual;
    Procedure Reset; Override;
    Procedure LoadROM(Filename: String); Override;
    Procedure InstructionLoop; Override;
    Procedure Frame(AddCycles: Integer); Virtual;
    Function  GetMem(Address: Integer): Byte; Virtual;
    Procedure WriteMem(Address: Integer; Value: Byte); Virtual;
    Procedure DoSoundTimer; Virtual;

    Procedure Op0nnn; Virtual; Procedure Op0000; Virtual; Procedure Op00E0; Virtual; Procedure Op00EE; Virtual;
    Procedure Op1nnn; Virtual; Procedure Op2nnn; Virtual; Procedure Op3xnn; Virtual; Procedure Op4xnn; Virtual;
    Procedure Op5xy0; Virtual; Procedure Op6xnn; Virtual; Procedure Op7xnn; Virtual; Procedure Op8xyn; Virtual;
    Procedure Op8xy0; Virtual; Procedure Op8xy1; Virtual; Procedure Op8xy2; Virtual; Procedure Op8xy3; Virtual;
    Procedure Op8xy4; Virtual; Procedure Op8xy5; Virtual; Procedure Op8xy6; Virtual; Procedure Op8xy7; Virtual;
    Procedure Op8xyE; Virtual; Procedure Op9xy0; Virtual; Procedure OpAnnn; Virtual; Procedure OpBnnn; Virtual;
    Procedure OpCxnn; Virtual; Procedure OpDxyn; Virtual; Procedure OpExnn; Virtual; Procedure OpEx9E; Virtual;
    Procedure OpExA1; Virtual; Procedure OpFxnn; Virtual; Procedure OpFx07; Virtual; Procedure OpFx0A; Virtual;
    Procedure OpFx15; Virtual; Procedure OpFx18; Virtual; Procedure OpFx1E; Virtual; Procedure OpFx29; Virtual;
    Procedure OpFx33; Virtual; Procedure OpFx55; Virtual; Procedure OpFx65; Virtual;
  End;

implementation

Uses Windows, SysUtils, Classes, Math, Chip8Int, Display;

Function TChip8Core.GetDisplayInfo: TDisplayInfo;
Begin

  DisplayLock.Enter;

  With Result Do Begin
    Data := @PresentDisplay[0];
    Width := DispWidth;
    Height := DispHeight;
    Depth := DispDepth;
  End;

  DisplayLock.Leave;

End;

Procedure TChip8Core.SetDisplay(Width, Height, Depth: Integer);
Begin

  SetLength(DisplayMem, Width * Height);
  SetLength(PresentDisplay, Length(DisplayMem));
  DispWidth := Width; DispHeight := Height;
  DispDepth := Depth;

End;

Procedure TChip8Core.BuildTables;
Var
  idx: Integer;
Begin

  SetDisplay(64, 32, 8);

  For idx := 0 To 255 Do Begin
    Opcodes[idx]  := Op0000;
    Opcodes0[idx] := Op0000;
    Opcodes5[idx] := Op0000;
    Opcodes8[idx] := Op0000;
    OpcodesE[idx] := Op0000;
    OpcodesF[idx] := Op0000;
    OpcodesM[idx] := Op0000;
  End;

  Opcodes[0]  := Op0nnn; Opcodes[1]  := Op1nnn; Opcodes[2]  := Op2nnn; Opcodes[3]  := Op3xnn;
  Opcodes[4]  := Op4xnn; Opcodes[5]  := Op5xy0; Opcodes[6]  := Op6xnn; Opcodes[7]  := Op7xnn;
  Opcodes[8]  := Op8xyn; Opcodes[9]  := Op9xy0; Opcodes[10] := OpAnnn; Opcodes[11] := OpBnnn;
  Opcodes[12] := OpCxnn; Opcodes[13] := OpDxyn; Opcodes[14] := OpExnn; Opcodes[15] := OpFxnn;

  Opcodes0[$E0] := Op00E0; Opcodes0[$EE] := Op00EE;

  Opcodes8[0]  := Op8xy0; Opcodes8[1] := Op8xy1; Opcodes8[2] := Op8xy2; Opcodes8[3]  := Op8xy3;
  Opcodes8[4]  := Op8xy4; Opcodes8[5] := Op8xy5; Opcodes8[6] := Op8xy6; Opcodes8[7]  := Op8xy7;
  Opcodes8[$E] := Op8xyE;

  OpcodesE[$9E] := OpEx9E; OpcodesE[$A1] := OpExA1;

  OpcodesF[7]   := OpFx07; OpcodesF[$A]  := OpFx0A; OpcodesF[$15] := OpFx15; OpcodesF[$18] := OpFx18;
  OpcodesF[$1E] := OpFx1E; OpcodesF[$29] := OpFx29; OpcodesF[$33] := OpFx33; OpcodesF[$55] := OpFx55;
  OpcodesF[$65] := OpFx65;

End;

Function TChip8Core.GetMem(Address: Integer): Byte;
Begin

  If (Address < 0) or (Address > $FFF) Then
    Result := 0
  Else
    Result := Memory[Address And $FFF];

End;

Procedure TChip8Core.WriteMem(Address: Integer; Value: Byte);
Begin

  If (Address > 0) and (Address <= $FFF) Then
    Memory[Address] := Value;

End;

Procedure TChip8Core.Reset;
var
  idx: Integer;
Begin

  {$IFDEF DEBUG}
  If FileExists(LogFilename) Then
    DeleteFile(LogFilename);
  {$ENDIF}

  icnt := 0;
  LastFrameCount := 0;
  StackPtr := 0;
  mCycles := 0;
  PC := $200;

  MakeSoundBuffers(60, 4);
  sBuffPos := 0;
  LastS := 0;

  SetLength(Memory, $FFFF);
  For idx := 0 To Length(Memory) -1 Do
    Memory[Idx] := Random(256);

  For idx := 0 To 15 Do
    Regs[idx] := 0;

  for idx := 0 to 79 Do
    Memory[idx + 80] := Font[idx];

  If Length(DisplayMem) > 0 Then
    FillMemory(@DisplayMem[0], Length(DisplayMem), 0);
  DisplayFlag := True;

  BuildTables;

End;

Procedure TChip8Core.LoadROM(Filename: String);
Var
  f: TFileStream;
  bin: Array of Byte;
  idx: Integer;
Begin

  if FileExists(Filename) Then Begin
    ROMName := Filename;
    f := TFileStream.Create(Filename, fmOpenRead or fmShareDenyNone);
    SetLength(bin, f.Size);
    f.Read(bin[0], f.Size);
    f.Free;

    Reset;

    for idx := 0 to Min(High(bin), High(Memory)) do
      Memory[idx + 512] := bin[idx];

    PC := 512;
    mCycles := 3250;
    NextFrame := 3668;

  End;

End;

Procedure TChip8Core.InstructionLoop;
Begin

  ExitLoop := False;

  Repeat

    cil := GetMem(PC);
    Inc(PC);
    ci := (cil shl 8) + GetMem(PC);
    Inc(PC);

    Frame(40 + 28 * Ord((cil And $F0) > 0));

    OpCodes[ci Shr 12];
    Inc(icnt);

    If Cycles > 0 Then
      Frame(Cycles);

  Until ExitLoop;

End;

Procedure TChip8Core.DoSoundTimer;
Var
  idx, sPos: Integer;
  oSample: Word;
  dcIn, dcOut: Boolean;
  t: Double;
Begin
  // If Sound Timer > 0 then generate a tone.
  If sTimer > 0 Then Begin
    Dec(sTimer);
    dcIn := LastS = 0;
    dcOut := sTimer = 0;
    sPos := 0;
    While sPos < BuffSize Do Begin
      t := sBuffPos * 6.283 / 64;
      oSample := Round(16384 * (sin(t)+sin(t*3)/3));
      pWord(@FrameBuffer[sPos])^ := oSample;
      pWord(@FrameBuffer[sPos + 2])^ := oSample;
      sBuffPos := sBuffPos + (64 * 1400) div 44100;
      sBuffPos := sBuffPos mod 64;
      Inc(sPos, 4);
    end;
    DeClick(dcIn, dcOut);
  End Else
    For Idx := 0 To BuffSize -1 Do
      FrameBuffer[Idx] := 0;
  LastS := sTimer;
End;

Procedure TChip8Core.Frame(AddCycles: Integer);
Begin

  // If the frame is done, signal for the next.

  Inc(mCycles, AddCycles);

  If mCycles >= NextFrame Then Begin
    If Timer > 0 then Dec(Timer);
    DoSoundTimer;
    If DisplayFlag Then Begin
      DisplayLock.Enter;
      CopyMemory(@PresentDisplay[0], @DisplayMem[0], DispWidth * DispHeight);
      DisplayUpdate := True;
      DisplayFlag := False;
      DisplayLock.Leave;
    End;
    InjectSound(@FrameBuffer[0], Not FullSpeed);
    Inc(mCycles, 1832 + (Ord(stimer <> 0) * 4) + (Ord(timer <> 0) * 8) - 3668);
    NextFrame := ((mCycles + 2572) div 3668) * 3668 + 1096;
    ExitLoop := True;
    ipf := icnt;
    icnt := 0;
  End;

End;

// Begin Core opcodes

Procedure TChip8Core.Op0nnn;
Begin
  Opcodes0[ci And $FF];
End;

Procedure TChip8Core.Op0000;
Begin
  // $0000 we will handle as a looping NOP.
  Dec(PC, 2);
  Cycles := 4;
End;

Procedure TChip8Core.Op00E0;
Begin
  // $00E0 - Clear display
  FillMemory(@DisplayMem[0], Length(DisplayMem), 0);
  DisplayFlag := True;
  Cycles := 3078;
End;

Procedure TChip8Core.Op00EE;
Begin
  // $00EE - RET
  PC := Stack[StackPtr];
  StackPtr := (StackPtr -1) And $3FF;
  Cycles := 10;
End;

Procedure TChip8Core.Op1nnn;
Begin
  // 1nnn - GOTO
  PC := ci And $FFF;
  Cycles := 12;
End;

Procedure TChip8Core.Op2nnn;
Begin
  // 2nnn - CALL
  StackPtr := (StackPtr +1) And $3FF;
  Stack[StackPtr] := PC;
  PC := ci And $FFF;
  Cycles := 26;
End;

Procedure TChip8Core.Op3xnn;
Begin
  // 3xnn - Skip if Reg X = nn
  If Regs[(ci Shr 8) And $F] = ci And $FF Then Begin
    Inc(PC, 2);
    Cycles := 14;
  End Else
    Cycles := 10;
End;

Procedure TChip8Core.Op4xnn;
Begin
  // 4xnn - Skip if Reg X <> nn
  If Regs[(ci Shr 8) And $F] <> ci And $FF Then Begin
    Inc(PC, 2);
    Cycles := 14;
  End Else
    Cycles := 10;
End;

Procedure TChip8Core.Op5xy0;
Begin
  // 5xy0 - Skip if Reg X = Reg Y
  If Regs[(ci Shr 8) And $F] = Regs[(ci Shr 4) And $F] Then Begin
    Inc(PC, 2);
    Cycles := 14;
  End Else
    Cycles := 10;
End;

Procedure TChip8Core.Op6xnn;
Begin
  // 6xnn - LET Regs X = nn
  Regs[(ci Shr 8) And $F] := ci And $FF;
  Cycles := 6;
End;

Procedure TChip8Core.Op7xnn;
Begin
  // 7xnn - Regs X += nn
  Inc(Regs[(ci Shr 8) And $F], ci And $FF);
  Cycles := 10;
End;

Procedure TChip8Core.Op8xyn;
Begin
  Opcodes8[ci And $F];
End;

Procedure TChip8Core.Op8xy0;
Begin
  // 8xy0 - Reg X = Reg Y
  Regs[(ci Shr 8) And $F] := Regs[(ci Shr 4) And $F];
  Cycles := 12;
End;

Procedure TChip8Core.Op8xy1;
Begin
  // 8xy1 - Reg X OR Reg Y
  t := (ci Shr 8) And $F;
  Regs[t] := Regs[t] Or Regs[(ci Shr 4) And $F];
  Regs[$F] := 0;
  Cycles := 44;
End;

Procedure TChip8Core.Op8xy2;
Begin
  // 8xy2 - Reg X AND Reg Y
  t := (ci Shr 8) And $F;
  Regs[t] := Regs[t] And Regs[(ci Shr 4) And $F];
  Regs[$F] := 0;
  Cycles := 44;
End;

Procedure TChip8Core.Op8xy3;
Begin
  // 8xy3 - Reg X XOR Reg y
  t := (ci Shr 8) And $F;
  Regs[t] := Regs[t] Xor Regs[(ci Shr 4) And $F];
  Regs[$F] := 0;
  Cycles := 44;
End;

Procedure TChip8Core.Op8xy4;
Begin
  // 8xy4 - Add Reg Y to Reg X
  x := (ci Shr 8) And $F;
  y := (ci Shr 4) And $F;
  t := Ord(Regs[x] + Regs[y] > $FF);
  Inc(Regs[x], Regs[y]);
  Regs[$F] := t;
  Cycles := 44;
End;

Procedure TChip8Core.Op8xy5;
Begin
  // 8xy5 - Subtract Reg Y from Reg X
  x := (ci Shr 8) And $F;
  y := (ci Shr 4) And $F;
  t := Ord(Regs[x] >= Regs[y]);
  Dec(Regs[x], Regs[y]);
  Regs[$F] := t;
  Cycles := 44;
End;

Procedure TChip8Core.Op8xy6;
Begin
  // 8xy6 - Shift Reg X right
  y := (ci Shr 4) And $F;
  t := Regs[y] And 1;
  Regs[(ci Shr 8) And $F] := Regs[y] Shr 1;
  Regs[$F] := t;
  Cycles := 44;
End;

Procedure TChip8Core.Op8xy7;
Begin
  // 8xy7 - Value of Subtract Reg X from Reg Y into Reg X
  x := (ci Shr 8) And $F;
  y := (ci Shr 4) And $F;
  t := Ord(Regs[y] >= Regs[x]);
  Regs[x] := Regs[y] - Regs[x];
  Regs[$F] := t;
  Cycles := 44;
End;

Procedure TChip8Core.Op8xyE;
Begin
  // 8xyE - Shift Reg X left
  y := (ci Shr 4) And $F;
  t := Regs[y] Shr 7;
  Regs[(ci Shr 8) And $F] := Regs[y] Shl 1;
  Regs[$F] := t;
  Cycles := 44;
End;

Procedure TChip8Core.Op9xy0;
Begin
  // 9xy0 - Skip if Reg X <> Reg Y
  If Regs[(ci Shr 8) And $F] <> Regs[(ci Shr 4) And $F] Then Begin
    Inc(PC, 2);
    Cycles := 18;
  End Else
    Cycles := 14;
End;

Procedure TChip8Core.OpAnnn;
Begin
  // Annn - Set I to nnn
  i := ci And $FFF;
  Cycles := 12;
End;

Procedure TChip8Core.OpBnnn;
Begin
  // Bnnn - Jump to Offset
  nnn := ci And $FFF;
  PC := nnn + Regs[0];
  Cycles := 22 + 2 * Ord((PC Shr 8) <> LongWord(nnn Shr 8));
End;

Procedure TChip8Core.OpCxnn;
Begin
  // Cxnn - Reg X = Random & nn
  Regs[(ci Shr 8) And $F] := Random(255) And (ci And $FF);
  Cycles := 36;
End;

Procedure TChip8Core.OpDxyn;
Var
  cx, cy, dx, j, dAddr, col, bOffs, pCycles, lc, olc, a: integer;
  Bit, db: Byte;
  c: Array[0..1] of Integer;
Begin
  // Dxyn - draw "sprite"
  t := 0;
  n := ci And $F;
  cx := Regs[(ci Shr 8) And $F] And 63;
  cy := Regs[(ci Shr 4) And $F] And 31;
  bOffs := cx And 7;
  pCycles := 68 + n * (46 + 20 * bOffs);
  Cycles := NextFrame - mCycles;
  lc := Max(pCycles - Cycles, 0);
  Repeat
    Frame(Cycles);
    olc := lc;
    If lc > 0 Then Begin
      If lc > NextFrame - mCycles Then
        Dec(lc, NextFrame - mCycles)
      Else
        lc := 0;
      Cycles := NextFrame - mCycles;
    End;
  Until olc <= 0;
  Cycles := 26;
  For a := 0 To Min(n - 1, 32 - cy -1) Do Begin
    db := GetMem(i + a);
    bit := $80;
    c[0] := 0; c[1] := 0;
    For dx := cx To Min(cx + 7, 63) Do Begin
      j := Ord((db And Bit) > 0);
      Bit := Bit Shr 1;
      dAddr := dx + cy * 64;
      col := Ord(j And DisplayMem[dAddr]);
      t := t Or col;
      DisplayMem[dAddr] := DisplayMem[dAddr] Xor j;
      If col > 0 Then
        c[Ord((dx - cx + bOffs) >= 8)] := 4;
    End;
    Inc(cy);
    Inc(Cycles, 34 + c[0] + c[1] + (16 * Ord(cx < 56)));
  End;
  Regs[$F] := t;
  DisplayFlag := True;
End;

Procedure TChip8Core.OpExnn;
Begin
  OpcodesE[ci And $FF];
End;

Procedure TChip8Core.OpEx9E;
Begin
  // Advance PC if key in x is down
  t := 2 * Ord(KeyStates[Regs[(ci Shr 8) And $F] And $F]);
  Inc(PC, t);
  Cycles := 14 + 2 * t;
End;

Procedure TChip8Core.OpExA1;
Begin
  // Advance PC if key in x is up
  t := 2 * Ord(Not KeyStates[Regs[(ci Shr 8) And $F] And $F]);
  Inc(PC, t);
  Cycles := 14 + 2 * t;
End;

Procedure TChip8Core.OpFxnn;
Begin
  Frame(4);
  OpcodesF[ci And $FF];
End;

Procedure TChip8Core.OpFx07;
Begin
  // Fx07 - Reg X = Timer
  Regs[(ci Shr 8) And $F] := Timer;
  Cycles := 10;
End;

Procedure TChip8Core.OpFx0A;
Var
  idx: Byte;
Begin
  // Fx0A - Wait for KeyPress
  Dec(PC, 2);
  Cycles := NextFrame - mCycles;
  Case keyStage of
    0: keyStage := 1;
    1:
      Begin
        For idx := 0 To 15 Do
          If KeyStates[idx] Then Begin
            Regs[(ci Shr 8) And $F] := idx;
            keyStage := 2;
            Break;
          End;
      End;
    2:
      If Not KeyStates[Regs[(ci Shr 8) And $F]] Then Begin
        KeyStage := 0;
        Inc(PC, 2);
        Cycles := 8;
      End;
  End;
End;

Procedure TChip8Core.OpFx15;
Begin
  // Fx15 - Timer = Reg X
  Timer := Regs[(ci Shr 8) And $F];
  Cycles := 6;
End;

Procedure TChip8Core.OpFx18;
Begin
  // Fx18 - Sound timer = Reg X
  sTimer := Regs[(ci Shr 8) And $F];
  Cycles := 6;
End;

Procedure TChip8Core.OpFx1E;
Begin
  // Fx1E - Index += Reg X
  t := i Shr 8;
  i := (i + Regs[(ci Shr 8) And $F]) And $FFF;
  Cycles := 12 + 6 * Ord((i Shr 8) <> t);
End;

Procedure TChip8Core.OpFX29;
Begin
  // Fx29 - i = Character address in Reg X
  i := $50 + (Regs[(ci Shr 8) And $F] And $F) * 5;
  Cycles := 16;
End;

Procedure TChip8Core.OpFx33;
Var
  vv, v1, v2, v3: Byte;
Begin
  // Fx33 - BCD to RAM at i.
  vv := Regs[(ci Shr 8) And $F];
  v1 := vv Div 100;
  v2 := (vv Div 10) Mod 10;
  v3 := vv mod 10;
  WriteMem(i, v1);
  WriteMem(i + 1, v2);
  WriteMem(i + 2, v3);
  Cycles := 80 + (v1 + v2 + v3) * 16;
End;

Procedure TChip8Core.OpFx55;
Var
  idx: Integer;
Begin
  // Fx55 - Store x regs to RAM
  Frame(14);
  Cycles := 0;
  x := (ci Shr 8) And $F;
  For idx := 0 To x Do Begin
    WriteMem(i + idx, Regs[idx]);
    Frame(14);
  End;
  Inc(i, x +1);
End;

Procedure TChip8Core.OpFx65;
Var
  idx: Integer;
Begin
  // Fx65 - Get x regs from RAM
  Frame(14);
  Cycles := 0;
  x := (ci Shr 8) And $F;
  For idx := 0 To x Do Begin
    Regs[idx] := GetMem(i + idx);
    Frame(14);
  End;
  Inc(i, x +1);
End;


end.
