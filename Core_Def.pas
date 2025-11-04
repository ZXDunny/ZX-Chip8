unit Core_Def;

interface

Uses Classes, Sound;

Type

  TOpcode = Procedure of Object;
  pOpcode = ^TOpcode;

  TDisplayInfo = Record
    Data: Pointer;
    Width, Height, Depth: Integer;
  End;

  TCore = Class
    Opcodes, Opcodes0, Opcodes5, Opcodes8, OpcodesE, OpcodesF, OpcodesM: Array[0..255] of TOpcode;
    Memory: Array of Byte;
    Regs: Array[0..15] of Byte;
    Stack: Array[0..1023] of LongWord;
    KeyStates: Array[0..15] of Boolean;

    t, x, y, n: Byte;
    PC, StackPtr: LongWord;
    ipf, maxipf, LastFx0A, Fx0ATime, Fx0ADelay, REPDEL, REPPER, FPS: Integer;
    ExitLoop, DoQuirks, DisplayWait, DxynWrap, FullSpeed, Press_fx0A, Musical_Tone: Boolean;
    ci, cil, Cycles, mCycles, LastFrameCount, Timer, sTimer, NextFrame, icnt, i, nnn, keyStage, LastS, iFrameCount: Integer;

    emuLastTicks, emuLastFrameTime, emuFrameLength: Double;

    DispWidth, DispHeight, DispDepth: Integer;
    DisplayMem, PresentDisplay: Array of Byte;
    sBuffPos, BuzzerTone, PeakRMS: Double;
    Audio: pSoundObject;

    Palette: Array[0..$FF] of LongWord;
    BuzzerColor, SilenceColor, SoundFlag: LongWord;

    Procedure Frame(AddCycles: Integer); Virtual;
    Procedure SetDisplay(Width, Height, Depth: Integer); Virtual;
    Function  GetDisplayInfo: TDisplayInfo; Virtual;
    Procedure Reset; Virtual;
    Procedure LoadROM(Filename: String; DoReset: Boolean); Virtual;
    Procedure InstructionLoop; Virtual;
    Procedure KeyDown(Key: Integer); Virtual;
    Procedure KeyUp(Key: Integer); Virtual;
    Procedure Present; Virtual;
    Function  GetMem(Address: Integer): Byte; Virtual;
    Procedure WriteMem(Address: Integer; Value: Byte); Virtual;
    Function  GetSTimer: Integer; Virtual;
    Function  GetBuzzerLevel: Double; Virtual;
    Function  GetBuzzerColor: LongWord; Virtual;
    Function  GetSilenceColor: LongWord; Virtual;
    Procedure SetBuzzerColor(Clr: LongWord); Virtual;
    Procedure SetSilenceColor(Clr: LongWord); Virtual;
    Function  FrameDone(Condition: Boolean): Boolean;
    Procedure GetTimings;
  End;

Const

  KeyCodes: Array[0..$F] of Char =
    ('X', '1', '2', '3',
     'Q', 'W', 'E', 'A',
     'S', 'D', 'Z', 'C',
     '4', 'R', 'F', 'V');

  {$IFDEF DEBUG}
  LogFilename = 'c:\temp\c8log.txt';
  Procedure Log(Str: String);
  {$ENDIF}

implementation

Uses SysUtils, SyncObjs, Math, Display;

Procedure TCore.Reset;
Begin
  STimer := 0;
  iFrameCount := 0;
  DoQuirks := False;
  DxynWrap := False;
  DisplayWait := True;
  Press_Fx0A := True;
  Musical_Tone := True;
  LastFx0A := -1;
  REPDEL := 20;
  REPPER := 4;
  emuLastTicks := GetTicks;
  emuLastFrameTime := 0;
  Fullspeed := False;
End;

Function TCore.FrameDone(Condition: Boolean): Boolean;
Begin
  If FullSpeed Then Begin
    Result := GetTicks - emuLastTicks >= Audio^.FrameMS_D
  End Else
    Result := Condition;
End;

Procedure TCore.GetTimings;
Var
  ticks: Double;
Begin
  Ticks := GetTicks;
  emuLastFrameTime := ticks - emuLastTicks;
  emuLastTicks := ticks;
End;

Procedure TCore.Frame(AddCycles: Integer);
Begin
  //
End;

Procedure TCore.LoadROM(Filename: String; DoReset: Boolean);
Begin
  //
End;

Procedure TCore.InstructionLoop;
Begin
  //
End;

Function  TCore.GetMem(Address: Integer): Byte;
Begin
  Result := 0;
End;

Procedure TCore.WriteMem(Address: Integer; Value: Byte);
Begin
  //
End;

Function TCore.GetSTimer: Integer;
Begin
  Result := SoundFlag;
  SoundFlag := 0;
End;

Function TCore.GetBuzzerLevel: Double;
Begin
  If SoundFlag > 0 Then Begin
    Result := Audio.PeakRMS;
    If Result < 1/32768 Then
      Result := 0;
  End Else
    Result := 0;
End;

Function  TCore.GetBuzzerColor: LongWord;
Begin
  Result := BuzzerColor;
End;

Function  TCore.GetSilenceColor: LongWord;
Begin
  Result := SilenceColor;
End;

Procedure TCore.SetBuzzerColor(Clr: LongWord);
Begin
  BuzzerColor := Clr;
End;

Procedure TCore.SetSilenceColor(Clr: LongWord);
Begin
  SilenceColor := Clr;
End;

Procedure TCore.SetDisplay(Width, Height, Depth: Integer);
Begin

  DisplayLock.Enter;

  SetLength(DisplayMem, Width * Height);
  SetLength(PresentDisplay, Length(DisplayMem) * (Depth Div 8));
  DispWidth := Width; DispHeight := Height;
  DispDepth := Depth;

  DisplayLock.Leave;

End;

Function  TCore.GetDisplayInfo: TDisplayInfo;
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

Procedure TCore.Present;
Begin
  //
End;

Procedure TCore.KeyDown(Key: Integer);
Var
  idx: Integer;
Begin

  For idx := 0 To 15 Do
    If Key = Ord(KeyCodes[idx]) Then Begin
      KeyStates[idx] := True;
      Fx0ATime := iFrameCount;
      Fx0ADelay := Ceil((REPDEL/50)*FPS);
      LastFx0A := -1;
    End;

End;

Procedure TCore.KeyUp(Key: Integer);
Var
  idx: Integer;
Begin

  For idx := 0 To 15 Do
    If Key = Ord(KeyCodes[idx]) Then Begin
      KeyStates[idx] := False;
      If idx = LastFx0A Then
        LastFx0A := -1;
    End;

End;

{$IFDEF DEBUG}
Procedure Log(Str: String);
var
  LogFile: TextFile;
Begin
  AssignFile(LogFile, LogFileName);
  Try
    If FileExists(LogFileName) Then
      Append(LogFile)
    Else
      Rewrite(LogFile);
    WriteLn(LogFile, Str);
  Finally
    CloseFile(LogFile);
  End;
End;
{$ENDIF}

end.
