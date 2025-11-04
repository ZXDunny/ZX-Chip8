unit Sound;

interface

Uses Windows, Math, Bass;

Type

  TSoundObject = Record
    Enabled: Boolean;
    BuffSize, BuffCount, AudioLen, Sample, FrameMS: NativeInt;
    AudioBuffer, FrameBuffer: Array of Byte;
    Channel: HChannel;
    PeakRMS, FrameMS_d: Double;
  End;
  pSoundObject = ^TSoundObject;


Procedure InitSound(Freq: integer);
Procedure InjectSound(Obj: pSoundObject; WaitForSync: Boolean);
Function  GetSoundPos(Obj: pSoundObject): Integer;
Function  MakeSoundBuffers(Hz: Integer; Obj: pSoundObject): Integer;
Procedure PauseSound(Obj: pSoundObject);
Procedure ResumeSound(Obj: pSoundObject);
Procedure StopSound(Obj: pSoundObject);
Procedure StopAllSounds;
Procedure CloseSound;
Procedure DeClick(dcIn, dcOut: Boolean; Obj: pSoundObject);
Function  SemiTonesToHz(SemiTone: Double): Double;

Var

  sHz, sChans, sBits: LongWord;
  SoundObjects: Array of pSoundObject;

Const

  NumSoundBuffers = 16;

implementation

Uses Display, Core_Def, sysutils;

Procedure InitSound(Freq: Integer);
Begin

  // Initialise BASS.

  sHz := Freq;
  BASS_SetConfig(BASS_CONFIG_DEV_DEFAULT, 1);
  BASS_Init(-1, sHz, 0, 0, nil);

End;

Procedure StopAllSounds;
Var
  idx: Integer;
Begin

  For idx := 0 To High(SoundObjects) Do
    StopSound(SoundObjects[idx]);

End;

Procedure StopSound(Obj: pSoundObject);
Begin

  If Assigned(Obj) Then
    With Obj^ Do
      If Enabled Then Begin
        If Channel <> 0 Then BASS_ChannelStop(Channel);
        If Sample <> 0 Then Begin
          BASS_SampleStop(Sample);
          BASS_SampleFree(Sample);
        End;
      End;

End;

Procedure CloseSound;
Begin

  BASS_Free;

End;

Function GetSoundPos(Obj: pSoundObject): Integer;
Begin

  If Obj^.Enabled Then
    Result := BASS_ChannelGetPosition(Obj^.Channel, BASS_POS_BYTE)
  Else
    Result := 0;

End;

Function MakeSoundBuffers(Hz: Integer; Obj: pSoundObject): Integer;
Var
  Idx: Integer;
Begin

  StopSound(Obj);

  // Allocate a buffer of (num) buffers, each of which are one frame in length at the specified framerate (Hz)
  // Not to be confused with video frame rates! Video can update independently of the emulation.

  With Obj^ Do Begin

    FrameMS_D := 1000/Hz;
    FrameMs := Round(FrameMS_D);

    BuffSize := Trunc(sHz / Hz) * 2 * 2;
    BuffCount := NumSoundBuffers;
    AudioLen := BuffSize * BuffCount;
    SetLength(AudioBuffer, AudioLen);

    SetLength(FrameBuffer, BuffSize);

    // Start the buffer playing

    If Enabled Then Begin
      Sample := BASS_SampleCreate(AudioLen, sHz, 2, 128, BASS_SAMPLE_OVER_POS or BASS_SAMPLE_LOOP);
      BASS_SampleSetData(Sample, @AudioBuffer[0]);

      Channel := BASS_SampleGetChannel(Sample, False);

      BASS_ChannelSetAttribute(Channel, BASS_ATTRIB_FREQ, sHz);
      BASS_ChannelSetAttribute(Channel, BASS_ATTRIB_PAN, 0);
      BASS_ChannelSetAttribute(Channel, BASS_ATTRIB_VOL, 1);
      BASS_ChannelFlags(Channel, BASS_SAMPLE_LOOP, BASS_SAMPLE_LOOP);

      BASS_ChannelPlay(Channel, True);

      // Wait for it to start, then return the sub-buffer (frame) size

      Repeat
        Sleep(1);
      Until GetSoundPos(Obj) >= 0;

    End;

    Result := BuffSize;

  End;

  For Idx := 0 To Length(SoundObjects) -1 Do
    If SoundObjects[Idx] = Obj Then Exit;

  Idx := Length(SoundObjects);
  SetLength(SoundObjects, Idx +1);
  SoundObjects[Idx] := Obj;

End;

Function GetRMS(Var Buffer: Array of Byte): Double;
Var
  i, numSamples: Integer;
  lSmp, rSmp, RMS, Mean, Variance, StdDev: Double;
Begin

  // Get Peak buzzer levels. It's quite complex and requires calculation of
  // peak RMS and uses standard deviation to get buzzer activity rather than level.

  RMS := 0;
  Mean := 0;
  numSamples := Length(Buffer) Div 4;
  For i := 0 To numSamples -1 Do Begin
    lSmp := pSmallInt(@Buffer[i * 4])^ / 32768;
    rSmp := pSmallInt(@Buffer[i * 4 + 2])^ / 32768;
    RMS := RMS + (lSmp * lSmp + rSmp * rSmp);
    Mean := Mean + lSmp + rSmp;
  End;
  RMS := Max(0, Min(1, Sqrt(RMS / (2 * numSamples))));
  Mean := Mean / (2 * numSamples);
  Variance := 0;
  For i := 0 To numSamples -1 Do Begin
    lSmp := pSmallInt(@Buffer[i * 4])^ / 32768;
    rSmp := pSmallInt(@Buffer[i * 4 + 2])^ / 32768;
    Variance := Variance + Sqr(lSmp - Mean) + Sqr(rSmp - Mean);
  End;
  Variance := Variance / (2 * numSamples);
  StdDev := Sqrt(Variance);
  Result := Min(1, Power(RMS * StdDev * 2, 0.5));

End;

Procedure SetPeakRMS(Obj: pSoundObject; NewRMS: Double);
Begin

  With Obj^ Do Begin
    PeakRMS := PeakRMS * 0.7;
    If PeakRMS < NewRMS Then
      PeakRMS := NewRMS;
  End;

End;

Procedure InjectSound(Obj: pSoundObject; WaitForSync: Boolean);
Var
  RMS: Double;
  BuffNum, Pos, nPos, msRemaining: Integer;

  Function SampToMs(StartPos, EndPos: Integer): Integer;
  Begin
    Result := Trunc(((EndPos - StartPos) / 4) / (sHz / 1000));
  End;

  Procedure DoSleep;
  Begin
    If msRemaining > 2 Then
      If msRemaining <= 4 Then
        Sleep(1)
      Else If msRemaining <= 6 Then
        Sleep(2)
      Else begin
        Sleep(Trunc((msRemaining / 1.6)));
      end;
  End;

Begin

  // Get the currently playing buffer, add one and inject the sound data to it.
  // Then wait until the data starts playing.

  RMS := GetRMS(Obj.FrameBuffer);
  SetPeakRMS(Obj, RMS);

  With Obj^ Do
    If Enabled Then Begin

      Pos := GetSoundPos(Obj);
      BuffNum := Pos Div BuffSize;

      If BuffNum = BuffCount -1 Then Begin
        CopyMemory(@AudioBuffer[0], FrameBuffer, BuffSize);
        BASS_SampleSetData(Sample, @AudioBuffer[0]);
        If WaitForSync Then Begin
          Repeat
            nPos := GetSoundPos(Obj);
            If nPos < 0 Then Exit;
            msRemaining := SampToMs(nPos, AudioLen);
            if AudioLen - nPos < BuffSize Then
              DoSleep;
          Until nPos < BuffNum * BuffSize;
        End;
      End Else Begin
        nPos := (BuffNum + 1) * BuffSize;
        CopyMemory(@AudioBuffer[nPos], FrameBuffer, BuffSize);
        BASS_SampleSetData(Sample, @AudioBuffer[0]);
        If WaitForSync Then
          While Pos < nPos Do Begin
            Pos := GetSoundPos(Obj);
            If Pos < 0 Then Exit;
            msRemaining := SampToMs(Pos, nPos);
            DoSleep;
          End;
      End;
    End Else Begin
      If WaitForSync Then
        Sleep(FrameMs);
    End;

End;

Procedure PauseSound(Obj: pSoundObject);
Begin

  If Obj^.Enabled Then Begin
    BASS_ChannelPause(Obj^.Channel);
    FillMemory(@Obj^.AudioBuffer[0], Length(Obj^.AudioBuffer), 0);
  End;

End;

Procedure ResumeSound(Obj: pSoundObject);
Begin

  If Obj^.Enabled Then
    BASS_ChannelPlay(Obj^.Channel, False);

End;

Procedure DeClick(dcIn, dcOut: Boolean; Obj: pSoundObject);
Var
  oSample: SmallInt;
  idx, rLen: Integer;
  Scalar, ScaleInc: Double;
Begin

  With Obj^ Do
    If Enabled Then
      If dcIn or dcOut Then Begin
        Scalar := 0;
        rLen := sHz Div 1000;
        ScaleInc := 1 / rLen;
        For idx := 0 to rLen -1 Do Begin
          If dcIn Then Begin
            oSample := Round(pSmallInt(@FrameBuffer[idx * 2])^ * Scalar);
            pSmallInt(@FrameBuffer[idx * 2])^ := oSample;
          End;
          If dcOut Then Begin
            oSample := Round(pSmallInt(@FrameBuffer[BuffSize - ((idx + 1) * 2)])^ * Scalar);
            pSmallInt(@FrameBuffer[BuffSize - ((idx + 1) * 2)])^ := oSample;
          End;
          Scalar := Scalar + ScaleInc;
        End;
      End;

End;

Function  SemiTonesToHz(SemiTone: Double): Double;
Begin

  Result := (220 * Power(2, (1/4))) * (Power(2, SemiTone/12));

End;

end.
