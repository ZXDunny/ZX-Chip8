unit mainform;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, dglOpenGL, display, Vcl.ExtCtrls, Chip8Int, Math,
  Vcl.Menus, Core_Custom;

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
    Browser1: TMenuItem;
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
    procedure Browser1Click(Sender: TObject);
  private
    { Private declarations }
    MaxIPF: Integer;
    MRUList: TStringlist;
    procedure FormMove(var Msg: TMessage); message WM_MOVING;
    procedure OnAppMessage(var Msg: TMsg; var Handled: Boolean);
    procedure CMDialogKey(var msg: TCMDialogKey);  message CM_DIALOGKEY;
    procedure WMDropFiles(var msg: TWMDropFiles); message WM_DROPFILES;
  protected
    procedure CreateWnd; Override;
    procedure DestroyWnd; Override;
  public
    { Public declarations }
    Function  GetModelName(Model: Integer): String;
    Procedure SetModel(Model: Integer; Quirks: pQuirkSettings);
    Procedure SetCustomModel(Quirks: TQuirkSettings);
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

Const

  MaxModels = 10;
  ModelNames:     Array[0..MaxModels -1] of String = ('VIP', 'Hybrid VIP', 'Chip8x', 'Chip-48', 'SChip1.0', 'SChip1.1', 'SChip Modern', 'XO-Chip', 'MegaChip', 'BytePusher');
  ModelLongNames: Array[0..MaxModels -1] of String = ('Cosmac VIP (Chip8)', 'Hybrid VIP', 'Chip8X', 'Chip-48', 'Legacy SChip 1.0', 'Legacy SChip 1.1', 'Modern SChip', 'XO-Chip', 'MegaChip', 'BytePusher');

implementation

{$R *.dfm}

Uses SyncObjs, ShellAPI, Sound, Browser, CustomCoreDlg, Core_Def;

Procedure TMainForm.CreateWnd;
Begin
  Inherited;
  DragAcceptFiles(Handle, True);
End;

Procedure TMainForm.DestroyWnd;
Begin
  DragAcceptFiles(Handle, false);
  Inherited;
End;

Procedure TMainForm.WMDROPFILES(var msg: TWMDropFiles);
Var
  i: integer;
  fileName: array[0..MAX_PATH] of char;
Begin
  For i := 0 To DragQueryFile(msg.Drop, $FFFFFFFF, fileName, MAX_PATH) - 1 Do Begin
    DragQueryFile(msg.Drop, i, fileName, MAX_PATH);
    LoadROM(Filename);
  End;
  DragFinish(msg.Drop);
End;

procedure TMainForm.FormMove(var Msg: TMessage);
Begin

  // Ensures the animation will display correctly during window move operations

  If Assigned(Interpreter) Then DisplayTimerTimer(nil);

End;

procedure TMainForm.OnAppMessage(var Msg: TMsg; var Handled: Boolean);
begin

  case Msg.message of
    WM_SYSCHAR:
      Handled := True;
    WM_KEYDOWN:
      begin // Remove key repeats
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

  Interpreter.Pause;

  With OpenDialog Do
    If Execute Then
      LoadROM(Filename);

  Interpreter.Restart;

end;

procedure TMainForm.menuResetClick(Sender: TObject);
begin

  Interpreter.Reset;

end;

procedure TMainForm.Browser1Click(Sender: TObject);
begin

  BrowserForm.Show;

end;

procedure TMainForm.CMDialogKey(var msg: TCMDialogKey);
begin

  if msg.Charcode <> VK_TAB then
    inherited;

end;

Procedure TMainForm.SetModel(Model: Integer; Quirks: pQuirkSettings);
Var
  i: Integer;
  RenderInfo: TDisplayInfo;
Begin

  Interpreter.Pause;
  CurrentModel := Model;
  If CurrentModel = -1 Then Begin
    Interpreter.SetCore(Chip8_Custom, Quirks);
  End Else
    Interpreter.SetCore(CurrentModel, nil);

  RenderInfo := Interpreter.Core.GetDisplayInfo;
  InitDisplay(60, RenderInfo.Width, RenderInfo.Height, True, DisplayPanel);
  For i := 0 To Chip8Model1.Count -1 Do
    If Chip8Model1.Items[i].Tag = CurrentModel Then
      Chip8Model1.Items[i].Checked := True;

  If Interpreter.ROMName <> '' Then
    Interpreter.LoadROM(Interpreter.ROMName);

  Interpreter.Restart;

End;

procedure TMainForm.CosmacVIPChip81Click(Sender: TObject);
Var
  t: Integer;
  p: tPoint;
begin

  t := (Sender As TMenuItem).Tag;
  If t = -1 Then Begin
    GetCursorPos(p);
    CustomCoreDialog.SetBounds(p.x - CustomCoreDialog.Width Div 3, p.y - CustomCoreDialog.Height Div 3, CustomCoreDialog.Width, CustomCoreDialog.Height);
    If CustomCoreDialog.ShowModal = mrOk Then SetModel(-1, @CustomCoreDialog.CustomQuirks);
  End Else
    SetModel((Sender as TMenuItem).Tag, nil);

end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
{$J+}
const
  rect: TRect = (Left:0; Top:0; Right:0; Bottom:0);
{$J-}
begin

  If (Key = VK_RETURN) and (ssAlt in Shift) Then Begin // Trap Alt+Enter for fullscreen flip
    Interpreter.Pause;
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
    Interpreter.Restart;
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
  Interpreter.SetCore(CurrentModel, nil);

end;

procedure TMainForm.DisplayPanelResize(Sender: TObject);
begin

  If DisplayReady Then Begin
    ResizeDisplay;
    DisplayUpdate := True;
  End;

end;

Function TMainForm.GetModelName(Model: Integer): String;
Begin

  If Model = -1 Then
    Result := ModelNames[TCustomCore(Interpreter.Core).CurCPUModel] + ' (Custom)'
  Else
    Result := ModelNames[Model];

End;


procedure TMainForm.DisplayTimerTimer(Sender: TObject);
Var
  ips: Single;
  s: String;
begin

  DisplayLock.Enter;

  If DisplayUpdate Then Begin
    Interpreter.Render;
    FrameLoop(False);
  End Else
    If FUllSpeed Then
      FrameLoop(False);

  DisplayLock.Leave;

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

  Caption := '[' + GetModelName(CurrentModel) + '] ' + s;

end;

procedure TMainForm.menuExitClick(Sender: TObject);
begin

  Interpreter.Terminate;
  Close;

end;

procedure TMainForm.FormCreate(Sender: TObject);
Var
  i: Integer;
  mi: TMenuItem;
begin

  CurrentModel := Chip8_VIP;
  InitDisplay(60, 64, 32, True, DisplayPanel);
  InitSound(44100);

  Application.OnMessage := OnAppMessage;

  For i := 0 To High(ModelNames) Do Begin
    mi := TMenuItem.Create(Chip8Model1);
    mi.Caption := ModelLongNames[i];
    mi.Tag := i;
    mi.RadioItem := True;
    mi.Checked := i = 0;
    mi.OnClick := CosmacVIPChip81Click;
    Chip8Model1.Add(mi);
  End;

  mi := TMenuItem.Create(Chip8Model1);
  mi.Caption := '-';
  Chip8Model1.Add(mi);


  mi := TMenuItem.Create(Chip8Model1);
  mi.Caption := 'Custom...';
  mi.Tag := -1;
  mi.RadioItem := True;
  mi.Checked := False;
  mi.OnClick := CosmacVIPChip81Click;
  Chip8Model1.Add(mi);

  LoadMRUList;

end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin

  SaveMRUList;
  Interpreter.Close;
  CloseGL;
  CloseSound;

end;

Procedure TMainForm.LoadROM(Filename: String);
Var
  CPUType: Integer;
  ext: String;
Begin

  CPUType := Interpreter.CoreType;
  If CPUType = Chip8_Custom Then
    CPUType := TCustomCore(Interpreter.Core).CurCPUModel;

  ext := LowerCase(ExtractFileExt(Filename));

  If (ext = '.xo8') And (CPUType <> Chip8_XOChip) Then
    SetModel(Chip8_XOChip, nil)
  Else
    If (ext = '.sc8') And (CPUType <> Chip8_SChip_Legacy11) Then
      SetModel(Chip8_SChip_Legacy11, nil)
    Else
      If (ext = '.mc8') And (CPUType <> Chip8_MegaChip) Then
        SetModel(Chip8_MegaChip, nil)
      Else
        If (ext = '.c8x') And (CPUType <> Chip8_Chip8X) Then
          SetModel(Chip8_Chip8x, nil)
        Else
          If (ext = '.bytepusher') And (CPUType <> Chip8_BytePusher) Then
            SetModel(Chip8_BytePusher, nil);

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
  i := 0;
  While i < MRUList.Count Do Begin
    if FileExists(MRUList[i]) Then Begin
      Item := TMenuItem.Create(nil);
      Item.Caption := ExtractFileName(MRUList[i]);
      Item.OnClick := MRUItemClick;
      Item.Tag := i;
      menuRecentFiles.Add(Item);
      Inc(i);
    End Else
      MRUList.Delete(i);
  End;

End;

procedure TMainForm.MRUItemClick(Sender: TObject);
begin

  LoadROM(MRUList[(Sender as TMenuItem).Tag]);

end;

Procedure TMainForm.SetCustomModel(Quirks: TQuirkSettings);
Begin
//
End;

end.
