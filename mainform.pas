unit mainform;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, dglOpenGL, display, Vcl.ExtCtrls, Chip8Int, Math,
  Vcl.Menus;

type
  TMainForm = class(TForm)
    DisplayPanel: TPanel;
    DisplayTimer: TTimer;
    OpenDialog: TOpenDialog;
    MainMenu: TMainMenu;
    File1: TMenuItem;
    menuOpen: TMenuItem;
    menuReset: TMenuItem;
    N1: TMenuItem;
    menuExit: TMenuItem;
    menuRecentfiles: TMenuItem;
    N2: TMenuItem;
    Chip8Model1: TMenuItem;
    CosmacVIPChip81: TMenuItem;
    SChip101: TMenuItem;
    SChip111: TMenuItem;
    XOChip1: TMenuItem;
    ModernSChip1: TMenuItem;
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
    procedure CosmacVIPChip81Click(Sender: TObject);
  private
    { Private declarations }
    MaxIPF: Integer;
    MRUList: TStringlist;
    procedure OnAppMessage(var Msg: TMsg; var Handled: Boolean);
    procedure CMDialogKey(var msg: TCMDialogKey);  message CM_DIALOGKEY;
  public
    { Public declarations }
    Procedure SetModel(Model: Integer);
    Procedure LoadROM(Filename: String);
    Procedure AddToMRUList(Name: String);
    Procedure LoadMRUList;
    Procedure SaveMRUList;
    Procedure MakeMRUMenu;
    procedure MRUItemClick(Sender: TObject);
  end;

var
  Main: TMainForm;
  CurrentModel: Integer;
  Interpreter: TChip8Interpreter;
  ModelItems: Array of ^TMenuItem;

Const

  ModelNames: Array[0..4] of String = ('VIP', 'SChip1.0', 'SChip1.1', 'SChip Modern', 'XO-Chip');

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
    If Execute Then
      LoadROM(Filename);

end;

procedure TMainForm.menuResetClick(Sender: TObject);
begin

  Interpreter.Reset;
  If Interpreter.ROMName <> '' Then
    Interpreter.LoadROM(Interpreter.ROMName);

end;

procedure TMainForm.CMDialogKey(var msg: TCMDialogKey);
begin

  if msg.Charcode <> VK_TAB then
    inherited;

end;

Procedure TMainForm.SetModel(Model: Integer);
Var
  i: Integer;
Begin
  PauseInterpreter(interpreter);
  CurrentModel := Model;
  Interpreter.SetCore(CurrentModel);
  InitDisplay(60, Interpreter.Core.DispWidth, Interpreter.Core.DispHeight, True, DisplayPanel);
  For i := 0 To Length(ModelItems) -1 Do
    If ModelItems[i]^.Tag = CurrentModel Then
      ModelItems[i]^.Checked := True;
  ResumeInterpreter(interpreter);
End;

procedure TMainForm.CosmacVIPChip81Click(Sender: TObject);
begin
  SetModel((Sender as TMenuItem).Tag);
  (Sender as TMenuItem).Checked := True;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
{$J+}
const
  rect: TRect = (Left:0; Top:0; Right:0; Bottom:0);
{$J-}
begin

  If (Key = VK_RETURN) and (ssAlt in Shift) Then Begin
    If FullScreen Then Begin
      DisplayPanel.Align := alNone;
      Self.Menu := MainMenu;
    End Else Begin
      Rect := DisplayPanel.BoundsRect;
      DisplayPanel.Align := alClient;
      Self.Menu := nil;
    End;
    SwitchFullScreen;
    If Not FullScreen Then Begin
      DisplayPanel.SetBounds(rect.Left, rect.Top, rect.Right - rect.Left, rect.Bottom - rect.Top);
      DisplayPanel.Anchors := [akLeft, akTop, akRight, akBottom];
    End;
    Exit;
  End;

  Interpreter.KeyDown(Key);

end;

procedure TMainForm.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin

  Interpreter.KeyUp(key);

end;

procedure TMainForm.FormShow(Sender: TObject);
begin

  Interpreter := TChip8Interpreter.Create(False);
  Interpreter.SetCore(CurrentModel);

end;

procedure TMainForm.DisplayPanelResize(Sender: TObject);
begin

  If DisplayReady Then Begin
    ResizeDisplay;
    DisplayUpdate := True;
  End;

end;

procedure TMainForm.DisplayTimerTimer(Sender: TObject);
Var
  ips: Single;
  s: String;
begin

  If DisplayUpdate Then Begin
    Interpreter.Render;
    FrameLoop;
  End Else
    If FUllSpeed Then
      FrameLoop;

  MaxIPF := Round((Interpreter.iPerFrame + 0.5 + MaxIPF) / 2);
  ips := (MaxIPF * 60) / 1e6;
  s := '';
  if Interpreter.ROMName <> '' Then
    s := ExtractFileName(Interpreter.ROMName) + ' - '
  Else
    s := 'Idle - ';
  s := s + Format('%.0n', [MaxIPF + 0.0]) + ' ipf';
  If ips > 0.1 Then
    s := s+ ' (' + Format('%.1f', [ips]) + 'M ips)';
  Caption := '[' + ModelNames[CurrentModel] + '] ' + s;

end;

procedure TMainForm.menuExitClick(Sender: TObject);
begin

  Interpreter.Terminate;
  Close;

end;

procedure TMainForm.FormCreate(Sender: TObject);
begin

  CurrentModel := Chip8_VIP;
  InitDisplay(60, 64, 32, True, DisplayPanel);
  Application.OnMessage := OnAppMessage;
  SetLength(ModelItems, 5);
  ModelItems[0] := @CosmacVIPChip81;
  ModelItems[1] := @SChip101;
  ModelItems[2] := @SChip111;
  ModelItems[3] := @ModernSChip1;
  ModelItems[4] := @XOChip1;
  LoadMRUList;

end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin

  SaveMRUList;
  CloseInterpreter(Interpreter);
  CloseGL;

end;

Procedure TMainForm.LoadROM(Filename: String);
Begin

  If ExtractFileExt(Filename) = '.xo8' Then
    SetModel(Chip8_XOChip);

  Interpreter.LoadROM(Filename);
  AddToMRUList(Filename);
  MaxIPF := 0;

End;

Procedure TMainForm.LoadMRUList;
Begin

  MRUList := TStringlist.Create;
  If FileExists('recentfiles') Then
    MRUList.LoadFromFile('recentfiles');

  MakeMRUMenu;

End;

Procedure TMainForm.SaveMRUList;
Begin

  MRUList.SaveToFile('recentfiles');

End;

Procedure TMainForm.AddToMRUList(Name: String);
Var
  i: Integer;
Begin

  i := 0;
  While i < MRUList.Count Do Begin
    if LowerCase(MRUList[i]) = LowerCase(Name) Then
      MRUList.Delete(i)
    Else
      Inc(i);
  End;

  MRUList.Insert(0, Name);
  While MRUList.Count > 10 Do
    MRUList.Delete(10);

  SaveMRUList;
  MakeMRUMenu;

End;

Procedure TMainForm.MakeMRUMenu;
Var
  i: Integer;
  Item: TMenuItem;
Begin

  menuRecentfiles.Clear;
  For i := 0 To MRUList.Count -1 Do Begin
    Item := TMenuItem.Create(nil);
    Item.Caption := ExtractFileName(MRUList[i]);
    Item.OnClick := MRUItemClick;
    Item.Tag := i;
    menuRecentFiles.Add(Item);
  End;

End;

procedure TMainForm.MRUItemClick(Sender: TObject);
begin

  LoadROM(MRUList[(Sender as TMenuItem).Tag]);

end;



end.
