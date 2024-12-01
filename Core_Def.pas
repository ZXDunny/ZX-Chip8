unit Core_Def;

interface

Uses Classes;

Type

  TOpcode = Procedure of Object;
  pOpcode = ^TOpcode;

  TOpRec = Record
    Idx: Integer;
    Opcode: pOpcode;
  End;

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
    ipf, maxipf: Integer;
    PC, StackPtr: LongWord;
    ExitLoop, DoQuirks, DisplayWait, DxynWrap: Boolean;
    ci, cil, Cycles, mCycles, LastFrameCount, Timer, sTimer, NextFrame, icnt, i, nnn, keyStage, LastS: Integer;

    DispWidth, DispHeight, DispDepth: Integer;
    DisplayMem, PresentDisplay: Array of Byte;
    sBuffPos, BuzzerTone: Double;

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
    {$IFDEF DEBUG}
    Procedure Log(Str: String);
    {$ENDIF}
  End;


Const

  KeyCodes: Array[0..$F] of Char =
    ('X', '1', '2', '3',
     'Q', 'W', 'E', 'A',
     'S', 'D', 'Z', 'C',
     '4', 'R', 'F', 'V');

  {$IFDEF DEBUG}
  LogFilename = 'c:\temp\c8log.txt';
  {$ENDIF}

implementation

Uses SysUtils, SyncObjs, Display;

Procedure TCore.Reset;
Begin
  DoQuirks := False;
  DxynWrap := False;
  DisplayWait := True;
End;

Procedure TCore.Frame(AddCycles: Integer);
Begin

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
    If Key = Ord(KeyCodes[idx]) Then
      KeyStates[idx] := True;

End;

Procedure TCore.KeyUp(Key: Integer);
Var
  idx: Integer;
Begin

  For idx := 0 To 15 Do
    If Key = Ord(KeyCodes[idx]) Then
      KeyStates[idx] := False;

End;

{$IFDEF DEBUG}
Procedure TCore.Log(Str: String);
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
