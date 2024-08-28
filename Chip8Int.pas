unit Chip8Int;

interface

Uses SysUtils, Types, Classes, Windows, Math;

Type

  TChip8Interpreter = Class(TThread)
    PC, StackPtr: LongWord;
    ROMName: String;
    Regs: Array [0..15] of Byte;
    Memory: Array [0..4095] of Byte;
    Stack: Array[0..1023] of LongWord;
    Display: Array[0..64*32-1] of Byte;
    KeyStates: Array[0..15] of Boolean;
    NeedPause, NeedResume, Paused, DisplayFlag: Boolean;
    Timer, sTimer, mCycles, NextFrame, i, icnt, ipf: Integer;
    Procedure Reset;
    Procedure InstructionLoop;
    Procedure Execute; Override;
    Procedure Frame(Cycles: Integer);
    Procedure LoadROM(Filename: String);
    Function  GetNextFrameTime: Integer;
    Function  ReadRAM(Address: Integer): Byte; inline;
    Procedure WriteRAM(Address: Integer; Value: Byte); inline;
  End;

  Procedure PauseInterpreter(Interpreter: TChip8Interpreter);
  Procedure ResumeInterpreter(Interpreter: TChip8Interpreter);

Const

  Font: Array [0..79] of Byte = ($F0, $90, $90, $90, $F0, $20, $60, $20, $20, $70, $F0, $10, $F0, $80, $F0, $F0, $10, $F0, $10, $F0,
                                 $90, $90, $F0, $10, $10, $F0, $80, $F0, $10, $F0, $F0, $80, $F0, $90, $F0, $F0, $10, $20, $40, $40,
                                 $F0, $90, $F0, $90, $F0, $F0, $90, $F0, $10, $F0, $F0, $90, $F0, $90, $90, $E0, $90, $E0, $90, $E0,
                                 $F0, $80, $80, $80, $F0, $E0, $90, $90, $90, $E0, $F0, $80, $F0, $80, $F0, $F0, $80, $F0, $80, $80);

implementation

Uses Display;

Procedure PauseInterpreter(Interpreter: TChip8Interpreter);
Begin

  DisplayUpdate := False;
  Interpreter.NeedPause := True;
  While Not Interpreter.Paused Do
    FrameLoop;

End;

Procedure ResumeInterpreter(Interpreter: TChip8Interpreter);
Begin

  Interpreter.NeedResume := True;
  While Interpreter.Paused Do
    FrameLoop;

End;

Function TChip8Interpreter.GetNextFrameTime: Integer;
Begin

  Dec(mCycles, 3668);
  Result := ((mCycles + 2572) div 3668) * 3668 + 1096;

End;

Procedure TChip8Interpreter.Reset;
var
  idx: Integer;
Begin

  StackPtr := 0;
  mCycles := 0;
  PC := $200;

  for idx := 0 to 79 Do
    Memory[idx + 80] := Font[idx];

  If ROMName <> '' Then
    LoadROM(ROMName);

  FillMemory(@Display[0], Length(Display), 0);
  DisplayFlag := True;

End;

Procedure TChip8Interpreter.Execute;
Begin

  Reset;

  Repeat

    If NeedPause Then Begin
      Paused := True;
      NeedPause := False;
    End;

    If Not Paused Then InstructionLoop;

    If NeedResume Then Begin
      Paused := False;
      NeedResume := False;
    End;

    WaitForSync;

  Until Terminated;

End;

Procedure TChip8Interpreter.LoadROM(Filename: String);
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

    for idx := 0 to High(bin) do
      Memory[idx + 512] := bin[idx];

    PC := 512;
    mCycles := 3250;
    NextFrame := GetNextFrameTime;
  End;

End;

Function TChip8Interpreter.ReadRAM(Address: Integer): Byte;
Begin

  Result := Memory[Address And $FFF];

End;

Procedure TChip8Interpreter.WriteRAM(Address: Integer; Value: Byte);
Begin

  Memory[Address And $FFF] := Value;

End;

Procedure TChip8Interpreter.InstructionLoop;
Var
  ci, cil, n, nn, nnn, x, y, v, t, keyStage, cx, cy, dAddr, j, a, db, dx, col, icnt: NativeUInt;
  v1, v2, v3, vv, bOffs, Bit: Byte;
  cycles, pCycles, olc, lc: Integer;
  c: Array[0..1] Of NativeInt;
Begin

  icnt := 0;
  Cycles := 0;
  KeyStage := 0;

  Repeat

    cil := ReadRAM(PC);
    Inc(PC);
    ci := (cil shl 8) + ReadRAM(PC);
    Inc(PC);

    v := ci Shr 12;
    x := (ci Shr 8) And $F;
    y := (ci Shr 4) And $F;
    n := ci And $F;
    nn := ci And $FF;
    nnn := ci And $FFF;

    Frame(40 + 28 * Ord((cil And $F0) > 0));

    Case v of
      $0:
        Begin
          Case nnn of
            $0:
              Begin
                // $0000 we will handle as a looping NOP.
                Dec(PC, 2);
              End;
            $E0:
              Begin
                // $00E0 - Clear display
                FillMemory(@Display[0], Length(Display), 0);
                DisplayFlag := True;
                Cycles := 3078;
              End;
            $EE:
              Begin
                // $00EE - RET
                PC := Stack[StackPtr];
                StackPtr := (StackPtr -1) And $3FF;
                Cycles := 10;
              End;
          End;
        End;
      $1:
        Begin
          // 1nnn - GOTO
          PC := nnn;
          Cycles := 12;
        End;
      $2:
        Begin
          // 2nnn - CALL
          StackPtr := (StackPtr +1) And $3FF;
          Stack[StackPtr] := PC;
          PC := nnn;
          Cycles := 26;
        End;
      $3:
        Begin
          // 3xnn - Skip if Reg X = nn
          If Regs[x] = nn Then Begin
            Inc(PC, 2);
            Cycles := 14;
          End Else
            Cycles := 10;
        End;
      $4:
        Begin
          // 4xnn - Skip if Reg X <> nn
          If Regs[x] <> nn Then Begin
            Inc(PC, 2);
            Cycles := 14;
          End Else
            Cycles := 10;
        End;
      $5:
        Begin
          // 5xy0 - Skip if Reg X = Reg Y
          If Regs[x] = Regs[y] Then Begin
            Inc(PC, 2);
            Cycles := 14;
          End Else
            Cycles := 10;
        End;
      $6:
        Begin
          // 6xnn - LET Regs X = nn
          Regs[x] := nn;
          Cycles := 6;
        End;
      $7:
        Begin
          // 7xnn - Regs X += nn
          Regs[x] := (Regs[x] + nn) And $FF;
          Cycles := 10;
        End;
      $8:
        Begin
          // 8XYN Instructions
          Case n of
            $0:
              Begin
                // 8xy0 - Reg X = Reg Y
                Regs[x] := Regs[y];
                Cycles := 12;
              End;
            $1:
              Begin
                // 8xy1 - Reg X OR Reg Y
                Regs[x] := Regs[x] Or Regs[y];
                Regs[$F] := 0;
                Cycles := 44;
              End;
            $2:
              Begin
                // 8xy2 - Reg X AND Reg Y
                Regs[x] := Regs[x] And Regs[y];
                Regs[$F] := 0;
                Cycles := 44;
              End;
            $3:
              Begin
                // 8xy3 - Reg X XOR Reg y
                Regs[x] := Regs[x] Xor Regs[y];
                Regs[$F] := 0;
                Cycles := 44;
              End;
            $4:
              Begin
                // 8xy4 - Add Reg Y to Reg X
                t := Ord(Regs[x] + Regs[y] > $FF);
                Inc(Regs[x], Regs[y]);
                Regs[$F] := t;
                Cycles := 44;
              End;
            $5:
              Begin
                // 8xy5 - Subtract Reg Y from Reg X
                t := Ord(Regs[x] >= Regs[y]);
                Dec(Regs[x], Regs[y]);
                Regs[$F] := t;
                Cycles := 44;
              End;
            $6:
              Begin
                // 8xy6 - Shift Reg X right
                t := Regs[y] And 1;
                Regs[x] := Byte(Regs[y] Shr 1);
                Regs[$F] := t;
                Cycles := 44;
              End;
            $7:
              Begin
                // 8xy7 - Value of Subtract Reg X from Reg Y into Reg X
                t := Ord(Regs[y] >= Regs[x]);
                Regs[x] := Byte(Regs[y] - Regs[x]);
                Regs[$F] := t;
                Cycles := 44;
              End;
            $E:
              Begin
                // 8xyE - Shift Reg X left
                t := Ord((Regs[y] And 128) > 0);
                Regs[x] := Byte(Regs[y] Shl 1);
                Regs[$F] := t;
                Cycles := 44;
              End;
          End;
        End;
      $9:
        Begin
          // 9xy0 - Skip if Reg X <> Reg Y
          If Regs[x] <> Regs[y] Then Begin
            Inc(PC, 2);
            Cycles := 18;
          End Else
            Cycles := 14;
        End;
      $A:
        Begin
          // Annn - Set I to nnn
          i := nnn;
          Cycles := 12;
        End;
      $B:
        Begin
          // Bnnn - Jump to Offset
          t := nnn Shr 8;
          PC := nnn + Regs[0];
          Cycles := 22 + 2 * Ord((PC Shr 8) <> t);
        End;
      $C:
        Begin
          // Cxnn - Reg X = Random & nn
          Regs[x] := Random(255) And nn;
          Cycles := 36;
        End;
      $D:
        Begin
          // Dxyn - draw "sprite"
          t := 0;
          cx := Regs[x] And 63;
          cy := Regs[y] And 31;
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
            db := ReadRAM(i + a);
            bit := $80;
            c[0] := 0; c[1] := 0;
            For dx := cx To Min(cx + 7, 63) Do Begin
              j := Ord((db And Bit) > 0);
              Bit := Bit Shr 1;
              dAddr := dx + cy * 64;
              col := Ord(j And Display[dAddr]);
              t := t Or col;
              Display[dAddr] := Display[dAddr] Xor j;
              If col > 0 Then
                c[Ord((dx - cx + bOffs) >= 8)] := 4;
            End;
            Inc(cy);
            Inc(Cycles, 34 + c[0] + c[1] + (16 * Ord(cx < 56)));
          End;
          Regs[$F] := t;
          DisplayFlag := True;
        End;
      $E:
        Begin
          // Ex9E/ExA1 - Key state
          Case nn of
            $9E, $A1:
              Begin
                t := 2 * Ord(KeyStates[Regs[x] And 15] = (nn = $9E));
                Inc(PC, t);
                Cycles := 14 + 2 * t;
              End;
          End;
        End;
      $F:
        Begin
          // Fxnn Opcodes
          Frame(4);
          Case nn of
            $07:
              Begin
                // Fx07 - Reg X = Timer
                Regs[x] := Timer;
                Cycles := 10;
              End;
            $0A:
              Begin
                // Fx0A - Wait for KeyPress
                Dec(PC, 2);
                Cycles := NextFrame - mCycles;
                Case keyStage of
                  0: keyStage := 1;
                  1:
                    Begin
                      For t := 0 To 15 Do
                        If KeyStates[t] Then Begin
                          Regs[x] := t;
                          keyStage := 2;
                        End;
                    End;
                  2:
                    If Not KeyStates[Regs[x]] Then Begin
                      KeyStage := 0;
                      Inc(PC, 2);
                      Cycles := 8;
                    End;
                End;
              End;
            $15:
              Begin
                // Fx15 - Timer = Reg X
                Timer := Regs[x];
                Cycles := 6;
              End;
            $18:
              Begin
                // Fx18 - Sound timer = Reg X
                sTimer := Regs[x];
                Cycles := 6;
              End;
            $1E:
              Begin
                // Fx1E - Index += Reg X
                t := i Shr 8;
                i := (i + Regs[x]) And $FFF;
                Cycles := 12 + 6 * Ord((i Shr 8) <> t);
              End;
            $29:
              Begin
                // Fx29 - i = Character address in Reg X
                i := $50 + (Regs[X] And $F) * 5;
                Cycles := 16;
              End;
            $33:
              Begin
                // Fx33 - BCD to RAM at i.
                vv := Regs[x];
                v1 := vv Div 100;
                v2 := (vv Div 10) Mod 10;
                v3 := vv mod 10;
                WriteRAM(i, v1);
                WriteRAM(i + 1, v2);
                WriteRAM(i + 2, v3);
                Cycles := 80 + (v1 + v2 + v3) * 16;
              End;
            $55:
              Begin
                // Fx55 - Store x regs to RAM
                Frame(14);
                Cycles := 0;
                For t := 0 To x Do Begin
                  WriteRAM(i + t, Regs[t]);
                  Frame(14);
                End;
                Inc(i, x -1);
              End;
            $65:
              Begin
                // Fx65 - Get x regs from RAM
                Frame(14);
                Cycles := 0;
                For t := 0 To x Do Begin
                  Regs[t] := ReadRAM(i + t);
                  Frame(14);
                End;
                Inc(i, x -1);
              End;
          End;
        End;

    End;

    Inc(icnt);

    If Cycles > 0 Then
      Frame(Cycles);

  Until NeedPause or Terminated;

End;

Procedure TChip8Interpreter.Frame(Cycles: Integer);
Begin

  Inc(mCycles, Cycles);
  If mCycles >= NextFrame Then Begin
    If Not NeedPause Then WaitForSync;
    If Timer > 0 then Dec(Timer);
    If sTimer > 0 Then Dec(sTimer);
    If DisplayFlag Then Begin
      DisplayUpdate := True;
      DisplayFlag := False;
    End;
    Inc(mCycles, 1832 + (Ord(stimer <> 0) * 4) + (Ord(timer <> 0) * 8));
    NextFrame := GetNextFrameTime;
  End;

End;

end.
