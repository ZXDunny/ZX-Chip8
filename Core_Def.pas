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
    PC, StackPtr: LongWord;
    ci, cil, Cycles, mCycles, LastFrameCount,
    Timer, sTimer, NextFrame, icnt, i,
    nnn, keyStage, LastS: Integer;
    sBuffPos: Double;
    t, x, y, n: Byte;
    ExitLoop: Boolean;
    ipf, maxipf: Integer;
    DispWidth, DispHeight, DispDepth: Integer;
    KeyStates: Array[0..15] of Boolean;
    DisplayMem, PresentDisplay: Array of Byte;
    BuzzerTone: Double;
    Function  GetDisplayInfo: TDisplayInfo; Virtual;
    Procedure Reset; Virtual;
    Procedure LoadROM(Filename: String); Virtual;
    Procedure InstructionLoop; Virtual;
    Procedure KeyDown(Key: Integer); Virtual;
    Procedure KeyUp(Key: Integer); Virtual;
    Procedure Present; Virtual;
    {$IFDEF DEBUG}
    Procedure Log(Str: String);
    {$ENDIF}
  End;

{$IFDEF DEBUG}
Const

  LogFilename = 'c:\temp\c8log.txt';
{$ENDIF}

implementation

Uses SysUtils;

Procedure TCore.Reset;
Begin
  //
End;

Procedure TCore.LoadROM(Filename: String);
Begin
  //
End;

Procedure TCore.InstructionLoop;
Begin
  //
End;

Function  TCore.GetDisplayInfo: TDisplayInfo;
Begin
  //
End;

Procedure TCore.Present;
Begin
  //
End;

Procedure TCore.KeyDown(Key: Integer);
Begin
  //
End;

Procedure TCore.KeyUp(Key: Integer);
Begin
  //
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
