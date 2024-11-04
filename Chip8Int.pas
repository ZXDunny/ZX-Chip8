unit Chip8Int;

interface

Uses SysUtils, Types, Classes, Windows, Math, SyncObjs, Sound, Core_Def;

Const

  Chip8_VIP            = 0;
  Chip8_SChip_Legacy10 = 1;
  Chip8_SChip_Legacy11 = 2;
  Chip8_SChip_Modern   = 3;
  Chip8_XOChip         = 4;
  Chip8_MegaChip       = 5;

  IntMsg_Pause         = 0;
  IntMsg_Resume        = 1;
  IntMsg_SwitchCore    = 2;
  IntMsg_Close         = 3;
  IntMsg_LoadROM       = 4;
  IntMsg_Reset         = 5;

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
    Paused, Finished: Boolean;
  Const
    KeyCodes: Array[0..$F] of Char =
      ('X', '1', '2', '3',
       'Q', 'W', 'E', 'A',
       'S', 'D', 'Z', 'C',
       '4', 'R', 'F', 'V');
    Constructor Create(CreateSuspended: Boolean = False);
    Procedure SetCore(NewCoreType: TChip8CoreType);
    Procedure Execute; Override;
    Procedure Reset;
    Procedure LoadROM(Filename: String);
    Procedure KeyDown(Key: integer);
    Procedure KeyUp(Key: Integer);
    Procedure Render;
    Procedure Wait;

    Procedure QueueAction(MsgID: Integer; Int: Integer = 0; Str: String = '');
    Procedure ProcessActions;
  End;

  TOpcodeProc = Procedure(Interpreter: TChip8Interpreter);

  Procedure PauseInterpreter(Interpreter: TChip8Interpreter);
  Procedure ResumeInterpreter(Interpreter: TChip8Interpreter);
  Procedure CloseInterpreter(Interpreter: TChip8Interpreter);

Var
  DisplayFlag: Boolean;
  FullSpeed: Boolean;
  ROMName: String;

Const

  Font: Array [0..79] of Byte =       ($F0, $90, $90, $90, $F0, $20, $60, $20, $20, $70, $F0, $10, $F0, $80, $F0, $F0, $10, $F0, $10, $F0,
                                       $90, $90, $F0, $10, $10, $F0, $80, $F0, $10, $F0, $F0, $80, $F0, $90, $F0, $F0, $10, $20, $40, $40,
                                       $F0, $90, $F0, $90, $F0, $F0, $90, $F0, $10, $F0, $F0, $90, $F0, $90, $90, $E0, $90, $E0, $90, $E0,
                                       $F0, $80, $80, $80, $F0, $E0, $90, $90, $90, $E0, $F0, $80, $F0, $80, $F0, $F0, $80, $F0, $80, $80);

  HiresFont10: Array[0..99] of Byte = ($3C, $7E, $C3, $C3, $C3, $C3, $C3, $C3, $7E, $3C, $18, $38, $58, $18, $18, $18, $18, $18, $18, $3C,
                                       $3E, $7F, $C3, $06, $0C, $18, $30, $60, $FF, $FF, $3C, $7E, $C3, $03, $0E, $0E, $03, $C3, $7E, $3C,
                                       $06, $0E, $1E, $36, $66, $C6, $FF, $FF, $06, $06, $FF, $FF, $C0, $C0, $FC, $FE, $03, $C3, $7E, $3C,
                                       $3E, $7C, $C0, $C0, $FC, $FE, $C3, $C3, $7E, $3C, $FF, $FF, $03, $06, $0C, $18, $30, $60, $60, $60,
                                       $3C, $7E, $C3, $C3, $7E, $7E, $C3, $C3, $7E, $3C, $3C, $7E, $C3, $C3, $7F, $3F, $03, $03, $3E, $7C);

  HiresFont11: Array[0..99] of Byte = ($3C, $7E, $E7, $C3, $C3, $C3, $C3, $E7, $7E, $3C, $18, $38, $58, $18, $18, $18, $18, $18, $18, $3C,
                                       $3E, $7F, $C3, $06, $0C, $18, $30, $60, $FF, $FF, $3C, $7E, $C3, $03, $0E, $0E, $03, $C3, $7E, $3C,
                                       $06, $0E, $1E, $36, $66, $C6, $FF, $FF, $06, $06, $FF, $FF, $C0, $C0, $FC, $FE, $03, $C3, $7E, $3C,
                                       $3E, $7C, $C0, $C0, $FC, $FE, $C3, $C3, $7E, $3C, $FF, $FF, $03, $06, $0C, $18, $30, $60, $60, $60,
                                       $3C, $7E, $C3, $C3, $7E, $7E, $C3, $C3, $7E, $3C, $3C, $7E, $C3, $C3, $7F, $3F, $03, $03, $3E, $7C);

  xoChipFont: Array[0..159] of Byte = ($7C, $C6, $CE, $DE, $D6, $F6, $E6, $C6, $7C, $00, $10, $30, $F0, $30, $30, $30, $30, $30, $FC, $00,
                                       $78, $CC, $CC, $0C, $18, $30, $60, $CC, $FC, $00, $78, $CC, $0C, $0C, $38, $0C, $0C, $CC, $78, $00,
                                       $0C, $1C, $3C, $6C, $CC, $FE, $0C, $0C, $1E, $00, $FC, $C0, $C0, $C0, $F8, $0C, $0C, $CC, $78, $00,
                                       $38, $60, $C0, $C0, $F8, $CC, $CC, $CC, $78, $00, $FE, $C6, $C6, $06, $0C, $18, $30, $30, $30, $00,
                                       $78, $CC, $CC, $EC, $78, $DC, $CC, $CC, $78, $00, $7C, $C6, $C6, $C6, $7C, $18, $18, $30, $70, $00,
                                       $30, $78, $CC, $CC, $CC, $FC, $CC, $CC, $CC, $00, $FC, $66, $66, $66, $7C, $66, $66, $66, $FC, $00,
                                       $3C, $66, $C6, $C0, $C0, $C0, $C6, $66, $3C, $00, $F8, $6C, $66, $66, $66, $66, $66, $6C, $F8, $00,
                                       $FE, $62, $60, $64, $7C, $64, $60, $62, $FE, $00, $FE, $66, $62, $64, $7C, $64, $60, $60, $F0, $00);

  Palette: Array[0..15] of LongWord = ($0C1218, $E4DCD4, $8C8884, $403C38, $D82010, $40D020, $1040D0, $E0C818,
                                       $501010, $105010, $50B0C0, $F08010, $E06090, $E0F090, $B050F0, $704020);


implementation

Uses Display, Core_Chip8, Core_sChipLegacy10, Core_sChipLegacy11, Core_sChipModern, Core_xoChip, Core_MegaChip;

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
  i: Integer;
Begin

  // Always called by the interpreter, never by any other thread.

  MsgLock.Enter;

  If MsgPtr >= 0 Then Begin

    Case MsgQueue[0].ID of
      IntMsg_Pause:
        Begin
          Paused := True;
        End;
      IntMsg_Resume:
        Begin
          Paused := False;
        End;
      IntMsg_SwitchCore:
        Begin
          Core.Free;
          Case MsgQueue[0].PayLoadI Of
            Chip8_VIP:
              Core := TChip8Core.Create;
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
          End;
          CoreType := MsgQueue[0].PayLoadI;
          Core.Reset;
        End;
      IntMsg_Close:
        Begin
          Terminate;
        End;
      IntMsg_LoadROM:
        Begin
          Core.LoadROM(MsgQueue[0].PayLoadS);
        End;
      IntMsg_Reset:
        Begin
          Core.Reset;
        End;
    End;

    For i := 0 To MsgPtr -2 Do Begin
      MsgQueue[i].ID := MsgQueue[i +1].ID;
      MsgQueue[i].PayloadI := MsgQueue[i +1].PayloadI;
      MsgQueue[i].PayLoadS := MsgQueue[i +1].PayLoadS;
    End;
    Dec(MsgPtr);

  End;

  MsgLock.Leave;

End;

Constructor TChip8Interpreter.Create(CreateSuspended: Boolean = False);
Begin
  Core := nil;
  MsgPtr := -1;
  MsgLock := TCriticalSection.Create;
  FullSpeed := False;
  Inherited;
End;

Procedure TChip8Interpreter.Wait;
Begin
  Sleep(1);
  FrameLoop;
End;

Procedure TChip8Interpreter.SetCore(NewCoreType: TChip8CoreType);
Begin

  QueueAction(IntMsg_SwitchCore, NewCoreType);
  Repeat
    Wait;
  Until CoreType = NewCoreType;

End;

Procedure PauseInterpreter(Interpreter: TChip8Interpreter);
Begin

  Interpreter.QueueAction(IntMsg_Pause);
  While Not Interpreter.Paused Do Interpreter.Wait;

End;

Procedure ResumeInterpreter(Interpreter: TChip8Interpreter);
Begin

  Interpreter.QueueAction(IntMsg_Resume);
  While Interpreter.Paused Do Interpreter.Wait;

End;

Procedure TChip8Interpreter.Reset;
Begin

  Core.Reset;

End;

Procedure TChip8Interpreter.Execute;
Begin

  NameThreadForDebugging('Interpreter');
  Finished := False;

  Repeat

    ProcessActions;

    If Not Paused Then
      Core.InstructionLoop
    Else
      WaitForSync;

  Until Terminated;

  Finished := True;

End;

Procedure CloseInterpreter(Interpreter: TChip8Interpreter);
Begin

  Interpreter.QueueAction(IntMsg_Close);
  Repeat
    Sleep(1);
    DisplayUpdate := False;
  Until Interpreter.Finished;

End;

Procedure TChip8Interpreter.LoadROM(Filename: String);
Begin

  ROMName := Filename;
  QueueAction(IntMsg_LoadROM, 0, Filename);

End;

Procedure TChip8Interpreter.KeyDown(Key: Integer);
Var
  i: Integer;
Begin

  For i := 0 To 15 Do
    If Key = Ord(KeyCodes[i]) Then
      Core.KeyStates[i] := True;

End;

Procedure TChip8Interpreter.KeyUp(Key: Integer);
Var
  i: Integer;
Begin

  For i := 0 To 15 Do
    If Key = Ord(KeyCodes[i]) Then
      Core.KeyStates[i] := False;

End;

Procedure TChip8Interpreter.Render;
Var
  Idx: Integer;
  RenderInfo: TDisplayInfo;
  Src: pByte;
Begin

  iPerFrame := Core.ipf;
  If FullSpeed Then Core.ipf := 0;

  DisplayLock.Enter;

  RenderInfo := Core.GetDisplayInfo;

  Case RenderInfo.Depth of
    8: // Chip8, sChip and XO-Chip
      Begin
        Src := RenderInfo.Data;
        For Idx := 0 To Length(DisplayArray) -1 Do Begin
          DisplayArray[Idx] := Palette[Src^ And $F];
          Inc(Src);
        End;
      End;
    32: // Mega-Chip
      Begin
        CopyMemory(@DisplayArray[0], RenderInfo.Data, RenderInfo.Width * RenderInfo.Height * SizeOf(LongWord));
      End;
  End;

  DisplayLock.Leave;

End;

end.
