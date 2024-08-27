unit mainform;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, dglOpenGL, display, Vcl.ExtCtrls, Chip8Int,
  Vcl.Menus;

type
  TMainForm = class(TForm)
    DisplayPanel: TPanel;
    DisplayTimer: TTimer;
    MainMenu: TMainMenu;
    File1: TMenuItem;
    menuOpen: TMenuItem;
    menuReset: TMenuItem;
    N1: TMenuItem;
    menuExit: TMenuItem;
    OpenDialog: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure DisplayPanelResize(Sender: TObject);
    procedure DisplayTimerTimer(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure menuOpenClick(Sender: TObject);
    procedure menuExitClick(Sender: TObject);
    procedure menuResetClick(Sender: TObject);
  private
    { Private declarations }
    procedure OnAppMessage(var Msg: TMsg; var Handled: Boolean);
    procedure CMDialogKey(var msg: TCMDialogKey);  message CM_DIALOGKEY;
  public
    { Public declarations }
  end;

var
  Main: TMainForm;
  Interpreter: TChip8Interpreter;

Const
  KeyCodes: Array[0..$F] of Char =
    ('X', '1', '2', '3',
     'Q', 'W', 'E', 'A',
     'S', 'D', 'Z', 'C',
     '4', 'R', 'F', 'V');

implementation

{$R *.dfm}

procedure TMainForm.OnAppMessage(var Msg: TMsg; var Handled: Boolean);
begin

  case Msg.message of
    WM_SYSCHAR:
      Handled := True;
    WM_KEYDOWN:
      begin
        if (Msg.lParam shr 30) = 1 then begin
          Handled := True;
        end else
          Handled := False;
      end;
  else
     // Not handled
     Handled := False;
  end;

End;

procedure TMainForm.menuOpenClick(Sender: TObject);
begin

  With OpenDialog Do
    If Execute Then Begin
      PauseInterpreter(interpreter);
      Interpreter.ROMName := Filename;
      Interpreter.Reset;
      ResumeInterpreter(Interpreter);
    End;

end;

procedure TMainForm.menuResetClick(Sender: TObject);
begin

  PauseInterpreter(interpreter);
  Interpreter.Reset;
  ResumeInterpreter(interpreter);

end;

procedure TMainForm.CMDialogKey(var msg: TCMDialogKey);
begin

  if msg.Charcode <> VK_TAB then
    inherited;

end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
Var
  i: Integer;
{$J+}
const
  rect: TRect = (Left:0; Top:0; Right:0; Bottom:0);
{$J-}
begin

  If (Key = VK_RETURN) and (ssAlt in Shift) Then Begin
    If FullScreen Then Begin
      DisplayPanel.Align := alNone;
    End Else Begin
      Rect := DisplayPanel.BoundsRect;
      DisplayPanel.Align := alClient;
    End;
    SwitchFullScreen;
    If Not FullScreen Then Begin
      DisplayPanel.SetBounds(rect.Left, rect.Top, rect.Right - rect.Left, rect.Bottom - rect.Top);
      DisplayPanel.Anchors := [akLeft, akTop, akRight, akBottom];
    End;
    Exit;
  End;

  For i := 0 To 15 Do
    If Key = Ord(KeyCodes[i]) Then
      Interpreter.KeyStates[i] := True;

end;

procedure TMainForm.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
Var
  i: integer;
begin

  For i := 0 To 15 Do
    If Key = Ord(KeyCodes[i]) Then
      Interpreter.KeyStates[i] := False;

end;

procedure TMainForm.FormShow(Sender: TObject);
begin

  Interpreter := TChip8Interpreter.Create(False);

end;

procedure TMainForm.DisplayPanelResize(Sender: TObject);
begin

  If DisplayReady Then
    ResizeDisplay(DisplayPanel.ClientWidth, DisplayPanel.ClientHeight);

end;

procedure TMainForm.DisplayTimerTimer(Sender: TObject);
Var
  Idx: Integer;
begin

  If DisplayUpdate Then Begin
    For Idx := 0 To Length(Interpreter.Display) -1 Do
      DisplayArray[Idx] := $FFFFFF * Interpreter.Display[Idx];
    FrameLoop;
  End;

end;

procedure TMainForm.menuExitClick(Sender: TObject);
begin

  Interpreter.Terminate;
  Close;

end;

procedure TMainForm.FormCreate(Sender: TObject);
begin

  InitDisplay(60, 64, 32, DisplayPanel.ClientWidth, DisplayPanel.ClientHeight, True, DisplayPanel.Handle);
  Application.OnMessage := OnAppMessage;

end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin

  Interpreter.Terminate;
  Repeat
    Sleep(1);
  Until Not Interpreter.Finished;

  CloseGL;

end;

end.
