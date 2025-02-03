unit Chip8Int;

interface

Uses SysUtils, Types, Classes, Windows, Math, SyncObjs, Sound, Core_Def, Core_Custom;

Const

  Chip8_None           = -1;
  Chip8_VIP            =  0;
  Chip8_Hybrid         =  1;
  Chip8_Chip8x         =  2;
  Chip8_Chip48         =  3;
  Chip8_SChip_Legacy10 =  4;
  Chip8_SChip_Legacy11 =  5;
  Chip8_SChip_Modern   =  6;
  Chip8_XOChip         =  7;
  Chip8_MegaChip       =  8;
  Chip8_BytePusher     =  9;
  Chip8_Custom         = 10;

  MaxModels            = 10;
  ModelNames:         Array[0..MaxModels -1] of String = ('VIP', 'Hybrid VIP', 'Chip8x', 'Chip-48', 'SChip1.0', 'SChip1.1', 'SChip Modern', 'XO-Chip', 'MegaChip', 'BytePusher');
  ModelLongNames:     Array[0..MaxModels -1] of String = ('Cosmac VIP (Chip8)', 'Hybrid VIP', 'Chip8X', 'Chip-48', 'Legacy SChip 1.0', 'Legacy SChip 1.1', 'Modern SChip', 'XO-Chip', 'MegaChip', 'BytePusher');

  IntMsg_Pause         =  0;
  IntMsg_Resume        =  1;
  IntMsg_SwitchCore    =  2;
  IntMsg_Close         =  3;
  IntMsg_LoadROM       =  4;
  IntMsg_Reset         =  5;
  IntMsg_KeyDown       =  6;
  IntMsg_KeyUp         =  7;
  IntMsg_Palette       =  8;
  IntMsg_BuzzerColor   =  9;
  IntMsg_SilenceColor  = 10;
  IntMsg_LoadFont      = 11;

Type

  TMsgRec = Record
    ID, PayLoadi: Integer;
    PayLoadS: String;
  End;

  TChip8CoreType = Integer;

  TChip8Interpreter = Class(TThread)
  Var
    Core: TCore;
    ROMName: String;
    CoreType: Integer;
    Width, Height, iPerFrame: Integer;
    MsgQueue: Array[0..1024] of TMsgRec;
    MsgPtr: Integer;
    MsgLock: TCriticalSection;
    Paused, Finished, DemoMode: Boolean;
    intQuirks: TQuirkSettings;
    SoundObject: TSoundObject;
    intPalette: Array[0..255] of LongWord;
    Constructor Create(CreateSuspended: Boolean = False);
    Destructor Destroy; Override;
    Procedure SetCore(NewCoreType: TChip8CoreType; Quirks: pQuirkSettings);
    Procedure SetPalette(Colours: Array of LongWord);
    Procedure SetBuzzerColor(Color: LongWord);
    Procedure SetSilenceColor(Color: LongWord);
    Procedure LoadFont(FontID: Integer);
    Procedure Execute; Override;
    Procedure Reset;
    Procedure LoadROM(Filename: String);
    Procedure KeyDown(Key: integer);
    Procedure KeyUp(Key: Integer);
    Procedure Render;
    Procedure Pause;
    Procedure Restart;
    Procedure Close;

    Procedure QueueAction(MsgID: Integer; Int: Integer = 0; Str: String = '');
    Procedure ProcessActions;
  End;

  TOpcodeProc = Procedure(Interpreter: TChip8Interpreter);

Var
  DisplayFlag: Boolean;

Const

  DefPalette: Array[0..15] of LongWord = ($0C1218, $E4DCD4, $8C8884, $403C38, $D82010, $40D020, $1040D0, $E0C818,
                                          $501010, $105010, $50B0C0, $F08010, $E06090, $E0F090, $B050F0, $704020);

  BootROM: Array[0..50] of Byte =     ($00, $e0, $a2, $1a, $64, $05, $61, $01, $62, $12, $63, $0c, $d2, $35, $72, $05, $f4, $1e, $71, $01,
                                       $31, $06, $12, $0c, $12, $18, $e0, $90, $e0, $90, $90, $f0, $80, $f0, $80, $f0, $f0, $90, $f0, $90,
                                       $90, $e0, $90, $90, $90, $e0, $90, $90, $60, $20, $20);

implementation

Uses Display, Fonts, Chip8DB, Core_Chip8, Core_RCA1802, Core_Chip8x, Core_Chip48, Core_sChipLegacy10, Core_sChipLegacy11, Core_sChipModern, Core_xoChip, Core_MegaChip, Core_BytePusher;

// Message queue handling

Procedure TChip8Interpreter.QueueAction(MsgID, Int: Integer; Str: String);
Begin

  // Never called by the interpreter. Always called by the VCL thread.

  MsgLock.Enter;

  Inc(MsgPtr);
  With MsgQueue[MsgPtr] Do Begin
    ID := MsgID;
    PayLoadi := Int;
    PayLoadS := Str;
  End;

  MsgLock.Leave;

End;

Procedure TChip8Interpreter.ProcessActions;
Var
  i, ID, PayLoadI, OldCoreType: Integer;
  PayLoadS: String;
Begin

  // Always called by the interpreter, never by any other thread.

  MsgLock.Enter;

  While MsgPtr >= 0 Do Begin

    ID := MsgQueue[0].ID;
    PayLoadI := MsgQueue[0].PayLoadI;
    PayLoadS := MsgQueue[0].PayLoadS;

    For i := 0 To MsgPtr -1 Do Begin
      MsgQueue[i].ID := MsgQueue[i +1].ID;
      MsgQueue[i].PayloadI := MsgQueue[i +1].PayloadI;
      MsgQueue[i].PayLoadS := MsgQueue[i +1].PayLoadS;
    End;
    Dec(MsgPtr);

    Case ID of
      IntMsg_Pause:
        Begin
          If Assigned(Core) And Core.Audio^.Enabled Then
            PauseSound(Core.Audio);
          Paused := True;
        End;
      IntMsg_Resume:
        Begin
          Paused := False;
          If Assigned(Core) And Core.Audio^.Enabled Then
            ResumeSound(Core.Audio);
        End;
      IntMsg_SwitchCore:
        Begin
          OldCoreType := CoreType;
          Core.Free;
          Case PayLoadI Of
            Chip8_VIP:
              Core := TChip8Core.Create;
            Chip8_Hybrid:
              Core := TRCA1802Core.Create;
            Chip8_Chip8x:
              Core := TChip8xCore.Create;
            Chip8_Chip48:
              Core := TChip48Core.Create;
            Chip8_SChip_Legacy10:
              Core := TSChipLegacy10Core.Create;
            Chip8_SChip_Legacy11:
              Core := TSChipLegacy11Core.Create;
            Chip8_SChip_Modern:
              Core := TSChipModernCore.Create;
            Chip8_XOChip:
              Core := TXOChipCore.Create;
            Chip8_MegaChip:
              Core := TMegaChipCore.Create;
            Chip8_BytePusher:
              Core := TBytePusherCore.Create;
            Chip8_Custom:
              Begin
                Core := TCustomCore.Create;
                TCustomCore(Core).SetCustomSettings(intQuirks);
              End;
          End;
          If ((OldCoreType = Chip8_BytePusher) or (PayLoadI = Chip8_BytePusher)) And (OldCoreType <> PayLoadI) Then
            ROMName := '';
          Core.Audio := @SoundObject;
          For i := 0 To High(DefPalette) Do
            Core.Palette[i] := DefPalette[i];
          SoundObject.Enabled := Not DemoMode;
          Core.Reset;
          CoreType := PayLoadI;
        End;
      IntMsg_Close:
        Begin
          If Core.Audio.Enabled Then
            StopSound(Core.Audio);
          Terminate;
        End;
      IntMsg_LoadROM:
        Begin
          Core.LoadROM(PayLoadS, True);
        End;
      IntMsg_Reset:
        Begin
          Core.Reset;
        End;
      IntMsg_KeyDown:
        Begin
          Core.KeyDown(PayLoadI);
        End;
      IntMsg_KeyUp:
        Begin
          Core.KeyUp(PayLoadI);
        End;
      IntMsg_Palette:
        Begin
          For i := 0 To PayLoadI Do
            Core.Palette[i] := intPalette[i];
        End;
      IntMsg_BuzzerColor:
        Begin
          Core.SetBuzzerColor(LongWord(PayLoadI));
        End;
      IntMsg_SilenceColor:
        Begin
          Core.SetSilenceColor(LongWord(PayLoadI));
        End;
      IntMsg_LoadFont:
        Begin
          Fonts.LoadFont(Core, PayLoadI);
        End;
    End;

  End;

  MsgLock.Leave;

End;

Constructor TChip8Interpreter.Create(CreateSuspended: Boolean = False);
Begin
  Core := nil;
  MsgPtr := -1;
  MsgLock := TCriticalSection.Create;
  Paused := True;
  Inherited;
End;

Destructor TChip8Interpreter.Destroy;
Begin

  Inherited;

End;

Procedure TChip8Interpreter.SetCore(NewCoreType: TChip8CoreType; Quirks: pQuirkSettings);
Begin

  CoreType := Chip8_None;
  If Assigned(Quirks) Then
    CopyMemory(@intQuirks.CPUType, @Quirks^.CPUType, SizeOf(TQuirkSettings))
  Else
    SetDefaultQuirks(NewCoreType, intQuirks);
  QueueAction(IntMsg_SwitchCore, NewCoreType);
  While CoreType <> NewCoreType Do Sleep(1);

End;

Procedure TChip8Interpreter.SetPalette(Colours: Array of LongWord);
Var
  i: Integer;
Begin

  For i := 0 To High(Colours) Do
    intPalette[i] := Colours[i];

  QueueAction(IntMsg_Palette, High(Colours));

End;

Procedure TChip8Interpreter.SetBuzzerColor(Color: LongWord);
Begin
  QueueAction(IntMsg_BuzzerColor, Integer(Color));
End;

Procedure TChip8Interpreter.SetSilenceColor(Color: LongWord);
Begin
  QueueAction(IntMsg_SilenceColor, Integer(Color));
End;

Procedure TChip8Interpreter.Pause;
Begin

  DisplayUpdate := False;
  QueueAction(IntMsg_Pause);
  While Not Paused Do Sleep(1);

End;

Procedure TChip8Interpreter.Restart;
Begin

  DisplayUpdate := False;
  QueueAction(IntMsg_Resume);
  While Paused Do Sleep(1);

End;

Procedure TChip8Interpreter.Reset;
Begin

  QueueAction(IntMsg_Reset);

End;

Procedure TChip8Interpreter.Execute;
Begin

  NameThreadForDebugging('Interpreter');
  Finished := False;
  FreeOnTerminate := True;
  Priority := tpNormal;

  Repeat

    ProcessActions;

    If Not Paused Then
      Core.InstructionLoop
    Else
      Sleep(1);

  Until Terminated;

  If Assigned(Core) Then Core.Free;

  MsgLock.Free;
  Finished := True;

End;

Procedure TChip8Interpreter.Close;
Begin

  QueueAction(IntMsg_Close);
  Repeat
    Sleep(1);
    DisplayUpdate := False;
  Until Finished;

End;

Procedure TChip8Interpreter.LoadROM(Filename: String);
Begin

  ROMName := Filename;
  QueueAction(IntMsg_LoadROM, 0, Filename);

End;

Procedure TChip8Interpreter.KeyDown(Key: Integer);
Begin

  If not DemoMode Then
    QueueAction(IntMsg_KeyDown, Key);

End;

Procedure TChip8Interpreter.KeyUp(Key: Integer);
Begin

  If Not DemoMode Then
    QueueAction(IntMsg_KeyUp, Key);

End;

Procedure TChip8Interpreter.LoadFont(FontID: Integer);
Begin

  QueueAction(IntMsg_LoadFont, FontID);

End;

Procedure TChip8Interpreter.Render;
Var
  Idx: Integer;
  RenderInfo: TDisplayInfo;
  Src: pByte;
Begin

  RenderInfo := Core.GetDisplayInfo;

  iPerFrame := Core.ipf;
  If Core.FullSpeed Then Core.ipf := 0;

  Case RenderInfo.Depth of
    8: // Chip8, Chip48, sChip and XO-Chip
      Begin
        Src := RenderInfo.Data;
        For Idx := 0 To Length(DisplayArray) -1 Do Begin
          DisplayArray[Idx] := Core.Palette[Src^ And $F];
          Inc(Src);
        End;
      End;
    32: // Chip8x, Mega-Chip, BytePusher
      Begin
        CopyMemory(@DisplayArray[0], RenderInfo.Data, RenderInfo.Width * RenderInfo.Height * SizeOf(LongWord));
      End;
  End;

End;

end.
