unit Core_BytePusher;

interface

Uses Core_Def, Classes;

Type

  TBytePusherCore = Class(TCore)
    sPos, sAcc: Integer;
    bpPalette: Array[0..255] of LongWord;
    Procedure Reset; Override;
    Procedure Present; Override;
    Procedure DoSoundTimer;
    Procedure LoadROM(Filename: String; DoReset: Boolean); Override;
    Procedure InstructionLoop; Override;
  End;

implementation

Uses Windows, SysUtils, Math, SyncObjs, Chip8Int, Display, Sound;

Procedure TBytePusherCore.Present;
Var
  idx, Addr: LongWord;
Begin

  DisplayLock.Enter;

  Addr := Memory[5] Shl 16;

  idx := 0;
  Repeat
    pLongWord(@PresentDisplay[idx * 4])^ := bpPalette[Memory[idx + Addr]];
    Inc(idx);
  Until Idx = 65536;

  DisplayUpdate := True;
  DisplayLock.Leave;

End;

Procedure TBytePusherCore.Reset;
var
  r, g, b: Integer;
Begin

  SetLength(Memory, $1000008);
  FillMemory(@Memory[0], $1000008, 0);

  Fillmemory(@bpPalette[0], 256 * SizeOf(LongWord), 0);

  For r := 0 To 5 Do
    For g := 0 To 5 Do
      For b := 0 To 5 Do
        bpPalette[(r * 36) + (g * 6) + b] := ((r * $33) Shl 16) or ((g * $33) Shl 8) or (b * $33);

  For r := 216 To 255 Do
    bpPalette[r] := 0;

  FPS := 60;
  MakeSoundBuffers(FPS, Audio);
  SetDisplay(256, 256, 32);

End;

Procedure TBytePusherCore.LoadROM(Filename: String; DoReset: Boolean);
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

    for idx := 0 to Min(High(bin), High(Memory)) do
      Memory[idx] := bin[idx];

  End;

End;

Procedure TBytePusherCore.DoSoundTimer;
Var
  frameSamples, i, j, MemOfs, Addr: Integer;
  nSample, Sample1, Sample2: SmallInt;
  t, iSam: Double;
  b: Byte;
Const
  SampleCount = 256;
Begin
  With Audio^ Do Begin
    frameSamples := BuffSize Div 4;
    t := SampleCount / frameSamples;
    MemOfs := (Memory[6] Shl 16) + (Memory[7] Shl 8);
    j := 0;
    For i := 0 To FrameSamples - 1 Do Begin
      iSam := (i * t);
      Addr := MemOfs + Floor(iSam);
      b := Memory[Addr];
      Sample1 := b or (b Shl 8);
      If iSam < SampleCount -1 then
        b := Memory[Addr +1];
      Sample2 := b or (b Shl 8);
      nSample := Round(Sample1 + (Sample2 - Sample1) * Frac(iSam));
      pSmallInt(@FrameBuffer[j])^ := nSample;
      pSmallInt(@FrameBuffer[j + 2])^ := nSample;
      Inc(j, 4);
    End;
    InjectSound(Audio, Not FullSpeed);
  End;
End;

Procedure TBytePusherCore.InstructionLoop;
Var
  Kb: Word;
  PC: pByte;
  idx: Integer;
Begin

  PC := @Memory[(Memory[2] shl 16) or (Memory[3] shl 8) or Memory[4]];
  iCnt := 0;

  Repeat

    Memory[(PC[3] shl 16) or (PC[4] shl 8) or PC[5]] := Memory[(PC[0] shl 16) or (PC[1] shl 8) or PC[2]];
    PC := @Memory[(PC[6] shl 16) or (PC[7] shl 8) or PC[8]];
    Inc(iCnt);

  Until FrameDone(iCnt = 65536);

  // End of Frame. Create the display and send sound

  Present;
  emuFrameLength := GetTicks - emuLastTicks;
  DoSoundTimer;
  Inc(iFrameCount);

  // Set the keyboard state

  kb := 0;
  For idx := 0 To 15 Do
    Kb := kb or (Ord(KeyStates[idx]) shl idx);
  kb := ((kb And $FF) Shl 8) or ((kb And $FF00) Shr 8);
  pWord(@Memory[0])^ := kb;

  // Metrics

  GetTimings;
  ipf := iCnt;
  iCnt := 0;

End;


end.
