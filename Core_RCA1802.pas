unit Core_RCA1802;

// Emulation core for the Cosmac VIP.
// Based in part on work done by Gulrak for the Cadmium emulator, with thanks.
// Without his help and guidance, this core would have taken a lot longer to implement.

interface

Uses Core_Def, Classes;

Type

  TRCA1802Core = Class(TCore)
    Cycles, FrameCount, sPos, sAcc: Integer;
    Regs: Array[0..$F] of Word;
    Memory: Array[0..$FFFF] of Byte;
    X, I, T, rRX, rPC: Word;
    DMABytes: Array[0..8 * 32 * 4] of Byte;
    IE, Q, ROMLatch, DisplayEnabled, EF1: Boolean;
    State, KeyVal, D, DF, N, P: Byte;
    PC, RX: pWord;
    EF: Array[1..4] of Byte;
    Procedure Reset; Override;
    Procedure Present; Override;
    Procedure SampleQ(Cycles: Integer);
    Procedure LoadSystemROM;
    Procedure LoadROM(Filename: String; DoReset: Boolean); Override;
    Procedure InstructionLoop; Override;
    Function  GetMem(Address: Integer): Byte; Override;
    Procedure SetMem(Address: Integer; Value: Byte);
    Procedure OutByte(Port, Value: Byte);
    Function  InByte(Port: Byte): Byte;
    Function  EFn(line: Integer): Boolean;
    Function  OpCode: Integer;
  End;

Const

  stIdle = 0;
  stRun  = 1;
  stInt  = 2;

  VIPRom: array[0..511] of Byte = ($F8, $80, $B2, $F8, $08, $A2, $E2, $D2, $64, $00, $62, $0C, $F8, $FF, $A1, $F8, $0F, $B1, $F8, $AA, $51, $01, $FB, $AA, $32, $22, $91, $FF, $04, $3B,
                                   $22, $B1, $30, $12, $36, $28, $90, $A0, $E0, $D0, $E1, $F8, $00, $73, $81, $FB, $AF, $3A, $29, $F8, $D2, $73, $F8, $9F, $51, $81, $A0, $91, $B0, $F8,
                                   $CF, $A1, $D0, $73, $20, $20, $40, $FF, $01, $20, $50, $FB, $82, $3A, $3E, $92, $B3, $F8, $51, $A3, $D3, $90, $B2, $BB, $BD, $F8, $81, $B1, $B4, $B5,
                                   $B7, $BA, $BC, $F8, $46, $A1, $F8, $AF, $A2, $F8, $DD, $A4, $F8, $C6, $A5, $F8, $BA, $A7, $F8, $A1, $AC, $E2, $69, $DC, $D7, $D7, $D7, $B6, $D7, $D7,
                                   $D7, $A6, $D4, $DC, $BE, $32, $F4, $FB, $0A, $32, $EF, $DC, $AE, $22, $61, $9E, $FB, $0B, $32, $C2, $9E, $FB, $0F, $3A, $8F, $F8, $6F, $AC, $F8, $40,
                                   $B9, $93, $F6, $DC, $29, $99, $3A, $97, $F8, $10, $A7, $F8, $08, $A9, $46, $B7, $93, $FE, $DC, $86, $3A, $AD, $2E, $97, $F6, $B7, $DC, $29, $89, $3A,
                                   $AD, $17, $87, $F6, $DC, $8E, $3A, $9E, $DC, $69, $26, $D4, $30, $C0, $F8, $83, $AC, $F8, $0A, $B9, $DC, $33, $C5, $29, $99, $3A, $C8, $DC, $3B, $CF,
                                   $F8, $09, $A9, $A7, $97, $76, $B7, $29, $DC, $89, $3A, $D6, $87, $F6, $33, $E3, $7B, $97, $56, $16, $86, $3A, $CF, $2E, $8E, $3A, $CF, $30, $BD, $DC,
                                   $16, $D4, $30, $EF, $D7, $D7, $D7, $56, $D4, $16, $30, $F4, $00, $00, $00, $00, $30, $39, $22, $2A, $3E, $20, $24, $34, $26, $28, $2E, $18, $14, $1C,
                                   $10, $12, $F0, $80, $F0, $80, $F0, $80, $80, $80, $F0, $50, $70, $50, $F0, $50, $50, $50, $F0, $80, $F0, $10, $F0, $80, $F0, $90, $F0, $90, $F0, $10,
                                   $F0, $10, $F0, $90, $F0, $90, $90, $90, $F0, $10, $10, $10, $10, $60, $20, $20, $20, $70, $A0, $A0, $F0, $20, $20, $7A, $42, $70, $22, $78, $22, $52,
                                   $C4, $19, $F8, $00, $A0, $9B, $B0, $E2, $E2, $80, $E2, $E2, $20, $A0, $E2, $20, $A0, $E2, $20, $A0, $3C, $53, $98, $32, $67, $AB, $2B, $8B, $B8, $88,
                                   $32, $43, $7B, $28, $30, $44, $D3, $F8, $0A, $3B, $76, $F8, $20, $17, $7B, $BF, $FF, $01, $3A, $78, $39, $6E, $7A, $9F, $30, $78, $D3, $F8, $10, $3D,
                                   $85, $3D, $8F, $FF, $01, $3A, $87, $17, $9C, $FE, $35, $90, $30, $82, $D3, $E2, $9C, $AF, $2F, $22, $8F, $52, $62, $E2, $E2, $3E, $98, $F8, $04, $A8,
                                   $88, $3A, $A4, $F8, $04, $A8, $36, $A7, $88, $31, $AA, $8F, $FA, $0F, $52, $30, $94, $00, $00, $00, $00, $D3, $DC, $FE, $FE, $FE, $FE, $AE, $DC, $8E,
                                   $F1, $30, $B9, $D4, $AA, $0A, $AA, $F8, $05, $AF, $4A, $5D, $8D, $FC, $08, $AD, $2F, $8F, $3A, $CC, $8D, $FC, $D9, $AD, $30, $C5, $D3, $22, $06, $73,
                                   $86, $73, $96, $52, $F8, $06, $AE, $F8, $D8, $AD, $02, $F6, $F6, $F6, $F6, $D5, $42, $FA, $0F, $D5, $8E, $F6, $AE, $32, $DC, $3B, $EA, $1D, $1D, $30,
                                   $EA, $01);

  Chip8: array[0..511] of Byte =  ($91, $BB, $FF, $01, $B2, $B6, $F8, $CF, $A2, $F8, $81, $B1, $F8, $46, $A1, $90, $B4, $F8, $1B, $A4, $F8, $01, $B5, $F8, $FC, $A5, $D4, $96, $B7, $E2,
                                   $94, $BC, $45, $AF, $F6, $F6, $F6, $F6, $32, $44, $F9, $50, $AC, $8F, $FA, $0F, $F9, $F0, $A6, $05, $F6, $F6, $F6, $F6, $F9, $F0, $A7, $4C, $B3, $8C,
                                   $FC, $0F, $AC, $0C, $A3, $D3, $30, $1B, $8F, $FA, $0F, $B3, $45, $30, $40, $22, $69, $12, $D4, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01, $01,
                                   $01, $01, $01, $00, $01, $01, $00, $7C, $75, $83, $8B, $95, $B4, $B7, $BC, $91, $EB, $A4, $D9, $70, $99, $05, $06, $FA, $07, $BE, $06, $FA, $3F, $F6,
                                   $F6, $F6, $22, $52, $07, $FA, $1F, $FE, $FE, $FE, $F1, $AC, $9B, $BC, $45, $FA, $0F, $AD, $A7, $F8, $D0, $A6, $93, $AF, $87, $32, $F3, $27, $4A, $BD,
                                   $9E, $AE, $8E, $32, $A4, $9D, $F6, $BD, $8F, $76, $AF, $2E, $30, $98, $9D, $56, $16, $8F, $56, $16, $30, $8E, $00, $EC, $F8, $D0, $A6, $93, $A7, $8D,
                                   $32, $D9, $06, $F2, $2D, $32, $BE, $F8, $01, $A7, $46, $F3, $5C, $02, $FB, $07, $32, $D2, $1C, $06, $F2, $32, $CE, $F8, $01, $A7, $06, $F3, $5C, $2C,
                                   $16, $8C, $FC, $08, $AC, $3B, $B3, $F8, $FF, $A6, $87, $56, $12, $D4, $9B, $BF, $F8, $FF, $AF, $93, $5F, $8F, $32, $DF, $2F, $30, $E5, $00, $42, $B5,
                                   $42, $A5, $D4, $8D, $A7, $87, $32, $AC, $2A, $27, $30, $F5, $00, $00, $00, $00, $00, $00, $00, $00, $00, $45, $A3, $98, $56, $D4, $F8, $81, $BC, $F8,
                                   $95, $AC, $22, $DC, $12, $56, $D4, $06, $B8, $D4, $06, $A8, $D4, $64, $0A, $01, $E6, $8A, $F4, $AA, $3B, $28, $9A, $FC, $01, $BA, $D4, $F8, $81, $BA,
                                   $06, $FA, $0F, $AA, $0A, $AA, $D4, $E6, $06, $BF, $93, $BE, $F8, $1B, $AE, $2A, $1A, $F8, $00, $5A, $0E, $F5, $3B, $4B, $56, $0A, $FC, $01, $5A, $30,
                                   $40, $4E, $F6, $3B, $3C, $9F, $56, $2A, $2A, $D4, $00, $22, $86, $52, $F8, $F0, $A7, $07, $5A, $87, $F3, $17, $1A, $3A, $5B, $12, $D4, $22, $86, $52,
                                   $F8, $F0, $A7, $0A, $57, $87, $F3, $17, $1A, $3A, $6B, $12, $D4, $15, $85, $22, $73, $95, $52, $25, $45, $A5, $86, $FA, $0F, $B5, $D4, $45, $E6, $F3,
                                   $3A, $82, $15, $15, $D4, $45, $E6, $F3, $3A, $88, $D4, $45, $07, $30, $8C, $45, $07, $30, $84, $E6, $62, $26, $45, $A3, $36, $88, $D4, $3E, $88, $D4,
                                   $F8, $F0, $A7, $E7, $45, $F4, $A5, $86, $FA, $0F, $3B, $B2, $FC, $01, $B5, $D4, $45, $56, $D4, $45, $E6, $F4, $56, $D4, $45, $FA, $0F, $3A, $C4, $07,
                                   $56, $D4, $AF, $22, $F8, $D3, $73, $8F, $F9, $F0, $52, $E6, $07, $D2, $56, $F8, $FF, $A6, $F8, $00, $7E, $56, $D4, $19, $89, $AE, $93, $BE, $99, $EE,
                                   $F4, $56, $76, $E6, $F4, $B9, $56, $45, $F2, $56, $D4, $45, $AA, $86, $FA, $0F, $BA, $D4, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $E0,
                                   $00, $4B);


implementation

Uses Windows, SysUtils, SyncObjs, Math, Display, Sound, Chip8Int;

Procedure TRCA1802Core.Present;
Var
  Idx, j, b, bt, Addr: Integer;
Begin

  If DisplayEnabled Then Begin

    DisplayLock.Enter;

    Addr := 0;
    idx := 0;
    While idx < 1024 Do Begin
      b := DMABytes[idx];
      bt := 128;
      While bt > 0 Do Begin
        For j := 0 to 3 Do Begin
          pLongWord(@PresentDisplay[Addr])^ := Palette[Ord(b And bt <> 0)];
          Inc(Addr, 4);
        End;
        bt := bt Shr 1;
      End;
      Inc(idx);
    End;

    DisplayUpdate := True;
    DisplayLock.Leave;

  End;

End;

Procedure TRCA1802Core.Reset;
Begin

  Inherited;

  I := 0;
  N := 0;
  P := 0;
  PC := @Regs[P];
  Q := False;
  rrx := 1;
  RX := @Regs[rrx];
  Regs[0] := 0;
  Regs[1] := 0;
  IE := True;
  Cycles := 0;
  State := stRun;
  ROMLatch := True;
  FrameCount := 0;

  FillMemory(@DMABytes[0], 1024, 0);
  FillMemory(@Memory[0], $FFFF, 0);

  FPS := 60;
  MakeSoundBuffers(FPS, Audio);
  SetDisplay(256, 128, 32);
  DisplayEnabled := False;
  BuzzerTone := 1400;
  EF1 := False;
  sPos := 0;
  sAcc := 0;

  LoadSystemROM;

End;

Procedure TRCA1802Core.LoadSystemROM;
Var
  idx: Integer;
Begin

  For idx := 0 To $1FF Do Begin
    Memory[idx + $8000] := VIPRom[idx];
    Memory[idx]         :=  Chip8[idx];
  End;

End;

Procedure TRCA1802Core.LoadROM(Filename: String; DoReset: Boolean);
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

    If DoReset Then Reset;

    for idx := 0 to Min(High(bin), High(Memory) - $200) do
      Memory[idx + $200] := bin[idx];

  End;

End;

Procedure TRCA1802Core.SampleQ(Cycles: Integer);
Var
  oSample: SmallInt;
  SampleFreq: Integer;
  t, StepSize: Double;
Const
  CycleLength = 1024;
Begin

  emuFrameLength := GetTicks - emuLastTicks;

  With Audio^ Do Begin

    Inc(sAcc, Cycles);
    SampleFreq := Round(3668 / (BuffSize Div 4));
    stepSize := (BuzzerTone * CycleLength) / sHz;
    While sAcc >= SampleFreq Do Begin
      t := sBuffPos * 6.283 / CycleLength;
      oSample := Ord(Q) * Round(16384 * (Sin(t) + Sin(t * 3) / 3));
      pWord(@FrameBuffer[sPos])^ := oSample;
      pWord(@FrameBuffer[sPos + 2])^ := oSample;
      sBuffPos := FMod(sBuffPos + stepSize, CycleLength);
      Inc(sPos, 4);
      If sPos >= BuffSize Then Begin
        InjectSound(Audio, Not FullSpeed);
        Dec(sPos, BuffSize);
      End;
      Dec(sAcc, SampleFreq);
    End;

  End;

End;

Procedure TRCA1802Core.InstructionLoop;
Var
  nsStart, DMAOffs, idx, intCnt, prC: Integer;
Begin

  nsStart := 80 * 14 + 4;
  intCnt := 0;
  DMAOffs := 0;

  Repeat

    inc(iCnt);
    prC := Cycles;
    If state = stIdle Then
      Inc(Cycles)
    Else
      Inc(Cycles, Opcode);

    If (IntCnt = 0) And (Cycles >= 78 * 14 + 2) Then Begin

      Inc(intCnt);

      If IE And DisplayEnabled Then Begin
        // Interrupt for the 1861 to do its thang
        IE := False;
        EF1 := True; // Set EF1 low
        T := (rrx Shl 4) Or P;
        P := 1;
        rrx := 2;
        PC := @Regs[P];
        RX := @Regs[rrx];
        nsStart := Cycles + 29;
        DMAOffs := 0;
        Inc(intCnt);
        Inc(Cycles);
        If state = stIdle Then
          state := stRun;
      End;

    End;

    If DisplayEnabled Then Begin

      If Not IE And EF1 And (Cycles >= nsStart) Then Begin
        // DMA those bytes out
        For idx := 0 To 7 Do Begin
          DMABytes[(DMAOffs)] := GetMem(Regs[0]);
          Inc(Cycles);
          Inc(DMAOffs);
          Inc(Regs[0]);
        End;
        If DMAOffs > 1023 Then
          EF1 := False; // Ef1 high
        Inc(nsStart, 14);
      End;

    End;

    SampleQ(Cycles - prC);

  Until FrameDone(Cycles >= 3668);

  // End of Frame. Create the display

  Present;

  // Metrics

  GetTimings;
  ipf := iCnt;
  iCnt := 0;

  Dec(Cycles, 3668);

End;

Function TRCA1802Core.GetMem(Address: Integer): Byte;
Begin

  If ROMLatch And (Address < $200) Then
    Address := $8000 + Address;

  If Address > $8000 Then
    Address := $8000 + (Address And $1FF);

  If (Address >= $1000) And (Address < $8000) Then
    Result := $FF
  Else
    Result := Memory[Address And $FFFF];

End;

Procedure TRCA1802Core.SetMem(Address: Integer; Value: Byte);
Begin

  If Not ROMLatch Then
    Memory[Address And $FFFF] := Value;

End;

Procedure TRCA1802Core.OutByte(Port, Value: Byte);
Begin

  Case Port Of
    1:
      Begin // Video
        DisplayEnabled := False;
      End;
    2:
      Begin // Keypad
        KeyVal := Value And $F;
      End;
    4:
      Begin // Memory to ROM latch
        ROMLatch := False;
      End;
  End;

End;

Function TRCA1802Core.InByte(Port: Byte): Byte;
Begin

  Case Port Of
    1: // Signal the 1861 to get its shit together
      Begin
        DisplayEnabled := True;
      End;
  End;
  Result := 0;

End;

Function TRCA1802Core.Efn(Line: Integer): Boolean;
Begin

  Result := True;

  Case Line of
    0: // Display building
      Begin
        Result := Not EF1;
      End;
    1: // Tape input bit
      Begin
      End;
    2: // Keypad
      Begin
        Result := KeyStates[KeyVal];
      End;
  End;

End;

Function TRCA1802Core.OpCode: Integer;
Var
  b, lb, hb, a: Byte;
  aa, tt: Word;
Begin

  b := GetMem(PC^);
  Inc(PC^);

  lb := b And $F;
  hb := b Shr 4 And $F;
  Result := 2 + Ord(hb = $C);

  Case Hb Of
    0:
      Begin
        if lb = 0 Then Begin
          // IDL
          state := stIdle;
        End Else Begin
          // D = RegN
          D := GetMem(Regs[lb]);
        End;
      End;
    1:
      Begin
        // INC RegN
        Inc(Regs[lb]);
      End;
    2:
      Begin
        // Dec RegN
        Dec(Regs[lb]);
      End;
    3:
      Begin
        aa := Word((PC^ And $FF00) Or GetMem(PC^));
        Inc(PC^);
        Case lb of
          0:
            Begin
              // BR aa
              PC^ := aa;
            End;
          1:
            Begin
              // BR Q aa
              If Q Then PC^ := aa;
            End;
          2:
            Begin
              // BR Z aa
              If D = 0 Then PC^ := aa;
            End;
          3:
            Begin
              // BR DF aa
              If DF And 1 = 1 Then PC^ := aa
            End;
          4 .. 7:
            Begin
              // BR EFn aa
              If EFn(lb - 4) Then PC^ := aa
            End;
          8:
            Begin
              // Skip 1 - already done above
            End;
          9:
            Begin
              // BR NQ aa
              If Not Q Then PC^ := aa
            End;
         $A:
            Begin
              // BR NZ aa
              If D <> 0 Then PC^ := aa
            End;
         $B:
            Begin
              // BR N DF aa
              If DF = 0 Then PC^ := aa
            End;
         $C .. $F:
            Begin
              // BR N EFn aa
              If Not EFn(lb - $C) Then PC^ := aa
            End;
        End;
      End;
    4:
      Begin
        // LDA n
        D := GetMem(Regs[lb]);
        Inc(Regs[lb]);
      End;
    5:
      Begin
        // STR n
        SetMem(Regs[lb], D);
      End;
    6:
      Begin
        // INC X
        If lb = 0 Then
          Inc(RX^)
        Else
          // OUT 1-7, X
          If lb < 8 Then Begin
            OutByte(lb, GetMem(RX^));
            Inc(RX^);
          End Else
            If lb = 8 Then
              // NOP
              Dec(PC^)
            Else Begin
              // INP X
              D := InByte(lb And 7);
              SetMem(RX^, D);
            End;
      End;
    7:
      Begin
        Case lb of
          0:
            Begin
              // RET
              a := GetMem(RX^);
              Inc(RX^);
              P := a And $F;
              PC := @Regs[P];
              rrx := a Shr 4;
              RX := @Regs[rrx];
              IE := True;
            End;
          1:
            Begin
              // DIS
              a := GetMem(RX^);
              Inc(RX^);
              P := a And $F;
              PC := @Regs[P];
              rrx := a Shr 4;
              RX := @Regs[rrx];
              IE := False;
            End;
          2:
            Begin
              // LDXA
              D := GetMem(RX^);
              Inc(RX^);
            End;
          3:
            Begin
              // STXD
              SetMem(RX^, D);
              Dec(RX^);
            End;
          4:
            Begin
              // ADC
              tt := Word(GetMem(RX^) + D + DF);
              DF := tt Shr 8 And 1;
              D := tt And  $FF;
            End;
          5:
            Begin
              // SDB
              tt := Word(GetMem(RX^) + (D Xor $FF) + DF);
              DF := tt Shr 8 And 1;
              D := tt And $FF;
            End;
          6:
            Begin
              // SHRC
              tt := Word((DF And 1) Shl 7);
              DF := D And 1;
              D := (D Shr 1) Or (tt And $FF);
            End;
          7:
            Begin
              // SMB
              tt := Word(GetMem(RX^ Xor $FF) + D + DF);
              DF := tt Shr 8 And 1;
              D := tt And $FF;
            End;
          8:
            Begin
              // SAV
              SetMem(RX^, T);
            End;
          9:
            Begin
              // MARK
              T := (rrx Shl 4) or P;
              SetMem(Regs[2], T);
              rrX := P;
              RX := @Regs[rrx];
              Dec(Regs[2]);
            End;
         $A:
            Begin
              // REQ
              Q := False;
            End;
         $B:
            Begin
              // SEQ
              Q := True;
            End;
         $C:
            Begin
              // ADCI
              tt := Word(GetMem(PC^) + D + DF);
              Inc(PC^);
              DF := tt Shr 8 And 1;
              D := tt And $FF;
            End;
         $D:
            Begin
              // SDBI
              tt := Word(GetMem(PC^) + (D Xor $FF) + DF);
              Inc(PC^);
              DF := tt Shr 8 And 1;
              D := tt And $FF;
            End;
         $E:
            Begin
              // SHLC
              tt := DF;
              DF := D Shr 7 And 1;
              D := Byte(D Shl 1 Or (tt And $FF));
            End;
         $F:
            Begin
              // SMBI
              tt := Word((GetMem(PC^) Xor $FF) + D + DF);
              DF := tt Shr 8 And 1;
              D := tt And $FF;
            End;
        End;
      End;
    8:
      Begin
        // GLO n
        D := Regs[lb] And $FF;
      End;
    9:
      Begin
        // GHI n
        D := Regs[lb] Shr 8;
      End;
   $A:
      Begin
        // PLO n
        Regs[lb] := (Regs[lb] And $FF00) Or D;
      End;
   $B:
      Begin
        // PHI n
        Regs[lb] := Word((Regs[lb] And $FF) Or (D Shl 8));
      End;
   $C:
      Begin
        aa := Word((GetMem(PC^) Shr 8) Or GetMem(PC^ + 1));
        Case lb Of
          0:
            Begin
              // LBR
              PC^ := aa;
            End;
          1:
            Begin
              // LBQ
              If Q Then
                PC^ := aa
              Else
                Inc(PC^, 2);
            End;
          2:
            Begin
              // LBZ
              If D = 0 Then
                PC^ := aa
              Else
                Inc(PC^, 2);
            End;
          3:
            Begin
              // LBDF
              If DF = 1 Then
                PC^ := aa
              Else
                Inc(PC^, 2);
            End;
          4:
            Begin
              // NOP
            End;
          5:
            Begin
              // LSNQ
              If Not Q Then
                Inc(PC^, 2);
            End;
          6:
            Begin
              // LSNZ
              If D <> 0 Then
                Inc(PC^, 2);
            End;
          7:
            Begin
              // LSNF
              If DF = 0 Then
                Inc(PC^, 2);
            End;
          8:
            Begin
              // LSKP
              Inc(PC^, 2);
            End;
          9:
            Begin
              // LBNQ
              If Not Q Then
                PC^ := aa
              Else
                Inc(PC^, 2);
            End;
         $A:
            Begin
              // LBNZ
              If D <> 0 Then
                PC^ := aa
              Else
                Inc(PC^, 2);
            End;
         $B:
            Begin
              // LBNF
              If DF = 0 Then
                PC^ := aa
              Else
                Inc(PC^, 2);
            End;
         $C:
            Begin
              // LSIE
              If IE Then
                Inc(PC^, 2);
            End;
         $D:
            Begin
              // LSQ
              If Q Then
                Inc(PC^, 2);
            End;
         $E:
            Begin
              // LSZ
              If D = 0 Then
                Inc(PC^, 2);
            End;
         $F:
            Begin
              // LSDF
              If DF <> 0 Then
                Inc(PC^, 2);
            End;
        End;
      End;
    $D:
      Begin
        // SEP N
        P := lb And $F;
        PC := @Regs[P];
      End;
    $E:
      Begin
        // SEX n
        rrx := lb;
        RX := @Regs[rrx];
      End;
    $F:
      Begin
      Case lb Of
        0:
          Begin
            // LDX
            D := GetMem(RX^);
          End;
        1:
          Begin
            // OR
            D := D Or GetMem(RX^);
          End;
        2:
          Begin
            // AND
            D := D And GetMem(RX^);
          End;
        3:
          Begin
            // XOR
            D := D Xor GetMem(RX^);
          End;
        4:
          Begin
            // ADD
            tt := Word(GetMem(RX^) + D);
            DF := (tt Shr 8) And 1;
            D := tt And $FF;
          End;
        5:
          Begin
            // SD
            tt := Word(GetMem(RX^) + (D Xor $FF) + 1);
            DF := tt Shr 8 And 1;
            D := tt And $FF;
          End;
        6:
          Begin
            // SHR
            DF := D And 1;
            D := D Shr 1;
          End;
        7:
          Begin
            // SM
            tt := Word((GetMem(RX^) Xor $FF) + D + 1);
            DF := tt Shr 8 And 1;
            D := tt And $FF;
          End;
        8:
          Begin
            // LDI
            D := GetMem(PC^);
            Inc(PC^);
          End;
        9:
          Begin
            // ORI
            D := D Or GetMem(PC^);
            Inc(PC^);
          End;
       $A:
          Begin
            // ANI
            D := D And GetMem(PC^);
            Inc(PC^);
          End;
       $B:
          Begin
            // XRI
            D := D Xor GetMem(PC^);
            Inc(PC^);
          End;
       $C:
          Begin
            // ADI
            tt := Word(GetMem(PC^) + D);
            Inc(PC^);
            DF := tt shr 8 And 1;
            D := tt And $FF;
          End;
       $D:
          Begin
            // SDI
            tt := Word(GetMem(PC^) + (D Xor $FF) + 1);
            Inc(PC^);
            DF := tt shr 8 And 1;
            D := tt And $FF;
          End;
       $E:
          Begin
            // SHL
            DF := (D Shr 7) And 1;
            D := D Shl 1;
          End;
       $F:
          Begin
            // SMI
            tt := Word((GetMem(PC^) Xor $FF) + D + 1);
            Inc(PC^);
            DF := tt shr 8 And 1;
            D := tt And $FF;
          End;
      End;
    End;
  End;

End;

end.
