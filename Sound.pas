unit Sound;

interface

Uses Windows, Bass;

Procedure InitSound;
Procedure InjectSound(ReadBuffer: pByte; WaitForSync: Boolean);
Function  MakeSoundBuffers(Hz: Integer; NumBuffers: Integer): Integer;
Procedure StopSound;
Procedure CloseSound;
Procedure DeClick(dcIn, dcOut: Boolean);

Var

  Sample: LongWord;
  MAXRATE, MINRATE, BuffSize, BuffCount: Integer;
  AudioBuffer, FrameBuffer: Array of Byte;
  Channel: HChannel;

implementation

Procedure InitSound;
Var
  Info: BASS_INFO;
  BASS_Err: Integer;
Begin

  // Initialise BASS.

  BASS_SetConfig(BASS_CONFIG_DEV_DEFAULT, 1);
  BASS_Init(-1, 44100, 0, 0, nil);

  BASS_Err := BASS_ErrorGetCode;
  If BASS_Err = 0 Then Begin

    BASS_GetInfo(Info);
    MAXRATE := Info.maxrate;
    MINRATE := Info.minrate;

    If MAXRATE = 0 Then MAXRATE := 256000;
    If MINRATE = 0 Then MINRATE := 1024;
    If MAXRATE = MINRATE Then MINRATE := 1024;

  End;

End;

Procedure StopSound;
Begin

  BASS_ChannelStop(Channel);
  BASS_SampleStop(Sample);
  BASS_SampleFree(Sample);

End;

Function GetSoundPos: Integer;
Begin

  Result := BASS_ChannelGetPosition(Channel, BASS_POS_BYTE);

End;

Function MakeSoundBuffers(Hz: Integer; NumBuffers: Integer): Integer;
Var
  Len: LongWord;
Begin

  StopSound;

  // Allocate a buffer of (num) buffers, each of which are one frame in length at the specified framerate (Hz)
  // Not to be confused with video frame rates! Video can update independently of the emulation.

  BuffSize := Trunc((44100 / Hz) * 2 * 2);
  BuffCount := NumBuffers;
  Len := BuffSize * BuffCount;
  SetLength(AudioBuffer, Len);

  SetLength(FrameBuffer, BuffSize);

  // Start the buffer playing

  Sample := BASS_SampleCreate(Len, 44100, 2, 128, BASS_SAMPLE_OVER_POS or BASS_SAMPLE_LOOP);
  BASS_SampleSetData(Sample, @AudioBuffer[0]);

  Channel := BASS_SampleGetChannel(Sample, False);

  BASS_ChannelSetAttribute(Channel, BASS_ATTRIB_FREQ, 44100);
  BASS_ChannelSetAttribute(Channel, BASS_ATTRIB_PAN, 0);
  BASS_ChannelSetAttribute(Channel, BASS_ATTRIB_VOL, 1);
  BASS_ChannelFlags(Channel, BASS_SAMPLE_LOOP, BASS_SAMPLE_LOOP);

  BASS_ChannelPlay(Channel, True);

  // Wait for it to start, then return the sub-buffer (frame) size

  Repeat
    Sleep(1);
  Until GetSoundPos >= 0;

  Result := BuffSize;

End;

Procedure InjectSound(ReadBuffer: pByte; WaitForSync: Boolean);
Var
  BuffNum, Pos, nPos: Integer;
Begin

  // Get the currently playing buffer, add one and inject the sound data to it.
  // Then wait until the data starts playing.

  Pos := GetSoundPos;
  BuffNum := Pos Div BuffSize;
  If BuffNum = BuffCount -1 Then Begin
    CopyMemory(@AudioBuffer[0], ReadBuffer, BuffSize);
    BASS_SampleSetData(Sample, @AudioBuffer[0]);
    If WaitForSync Then
      While GetSoundPos >= Pos Do
        Sleep(1);
  End Else Begin
    nPos := (BuffNum + 1) * BuffSize;
    CopyMemory(@AudioBuffer[nPos], ReadBuffer, BuffSize);
    BASS_SampleSetData(Sample, @AudioBuffer[0]);
    If WaitForSync Then
      While GetSoundPos < nPos Do
        Sleep(1);
  End;

End;

Procedure CloseSound;
Begin

  StopSound;
  BASS_Free;

End;

Procedure DeClick(dcIn, dcOut: Boolean);
Var
  idx: Integer;
  oSample: SmallInt;
  Scalar, ScaleInc: Double;
Begin

  If dcIn or dcOut Then Begin
    Scalar := 0;
    ScaleInc := 1/44;
    For idx := 0 to 43 Do Begin
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

end.
