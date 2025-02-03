unit mainform;

// TO DO:
//
// Browser
  // Database editor
  // DB load/save
//
// optional keypress
// Octo assembler
// on-screen keyboard
// debugger

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, dglOpenGL, display, Vcl.ExtCtrls, Chip8Int, Math,
  Vcl.Menus, Core_Custom;

Const
  WM_RENDER = WM_USER +1;

type
  TMainForm = class(TForm)
    DisplayPanel: TPanel;
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
    BuzzerShape: TShape;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure DisplayPanelResize(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure menuOpenClick(Sender: TObject);
    procedure menuExitClick(Sender: TObject);
    procedure menuResetClick(Sender: TObject);
    procedure CosmacVIPChip81Click(Sender: TObject);
    procedure Browser1Click(Sender: TObject);
  private
    { Private declarations }
    MaxIPF, TimingCount: Integer;
    MRUList: TStringlist;
    Timings, iTimings: Array[0..3] of Double;
    procedure FormMove(var Msg: TMessage); message WM_MOVING;
    procedure OnAppMessage(var Msg: TMsg; var Handled: Boolean);
    procedure CMDialogKey(var msg: TCMDialogKey);  message CM_DIALOGKEY;
    procedure WMDropFiles(var msg: TWMDropFiles); message WM_DROPFILES;
    procedure WMRender(var msg: TMessage); message WM_RENDER;
  protected
    procedure CreateWnd; Override;
    procedure DestroyWnd; Override;
  public
    { Public declarations }
    CurrentModel: Integer;
    Interpreter: TChip8Interpreter;
    LastSTimer, CurBuzzerColor: Integer;
    Function  GetModelName(Model: Integer): String;
    Procedure SetModel(Model: Integer; Quirks: pQuirkSettings);
    Procedure SetCustomModel(Quirks: TQuirkSettings);
    Procedure LoadROM(Filename: String);
    Procedure AddToMRUList(Name: String);
    Procedure LoadMRUList;
    Procedure SaveMRUList;
    Procedure MakeMRUMenu;
    procedure MRUItemClick(Sender: TObject);
    Procedure SetBackground(Clr: LongWord);
  end;

var
  Main: TMainForm;

implementation

{$R *.dfm}

Uses SyncObjs, ShellAPI, Sound, Browser, CustomCoreDlg, Core_Def, Chip8DB;

Procedure TMainForm.WMRender(var msg: TMessage);
Var
  c, t: LongWord;
  ips: Single;
  bz: Double;
  s: String;

  Function Lerp(A, B: Byte; Amt: Double): Byte;
  Begin
    Result := Trunc(A + ((B - A) * Amt));
  End;

  Procedure MakeTimings;
  Var
    MaxTimings: Integer;
  Begin
    Inc(TimingCount);
    MaxTimings := Interpreter.Core.FPS Div 8;
    iTimings[0] := (iTimings[0] + LastFrameDuration);
    iTimings[1] := (iTimings[1] + LastFrameTime);
    iTimings[2] := (iTimings[2] + Interpreter.Core.emuFrameLength);
    iTimings[3] := (iTimings[3] + Interpreter.Core.emuLastFrameTime);

    If TimingCount >= MaxTimings Then Begin
      Timings[0] := iTimings[0] / TimingCount;
      Timings[1] := iTimings[1] / TimingCount;
      Timings[2] := iTimings[2] / TimingCount;
      Timings[3] := iTimings[3] / TimingCount;
      iTimings[0] := 0;
      iTimings[1] := 0;
      iTimings[2] := 0;
      iTimings[3] := 0;
      Dec(TimingCount, MaxTimings);
    End;

  End;

begin

  DisplayLock.Enter;

    bz := Interpreter.Core.GetBuzzerLevel;
    c := Interpreter.Core.GetBuzzerColor;
    If Not FullScreen Then
      t := Interpreter.Core.GetSilenceColor
    Else
      t := 0;
    CurBuzzerColor := (Lerp((t Shr 16) and $FF, (c Shr 16) And $FF, bz) Shl 16) or (Lerp((t Shr 8) and $FF, (c Shr 8) And $FF, bz) Shl 8) or Lerp(t and $FF, c And $FF, bz);
    SetBackground(CurBuzzerColor);
    DisplayUpdate := DisplayUpdate Or (bz > 0);

    If DisplayUpdate Then Begin
      Interpreter.Render;
      FrameLoop;
    End;

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

  MakeTimings;
  Caption := '[' + GetModelName(CurrentModel) + '] ' + s + Format(' (Frame time: %5.2f, Time since: %5.2f, emuTime: %5.2f, emuSince: %5.2f)', [Timings[0], Timings[1], Timings[2], Timings[3]]);

  BuzzerShape.Brush.Color := CurBuzzerColor;

end;

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

  If Assigned(Interpreter) Then Begin
    DisplayUpdate := True;
    WMRender(Msg);
  End;

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
  If Interpreter.ROMName <> '' Then
    Interpreter.LoadROM(Interpreter.ROMName);

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

  LastSTimer := 0;
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

  Interpreter.SetBuzzerColor(ColorToRGB(clRed));
  Interpreter.SetSilenceColor(ColorToRGB(clMedGray));
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
    DisplayUpdate := True;
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
  Interpreter.DemoMode := False;
  Interpreter.SetCore(CurrentModel, nil);
  Interpreter.SetBuzzerColor(ColorToRGB(clRed));
  Interpreter.SetSilenceColor(ColorToRGB(clMedGray));
  Interpreter.Restart;

  InitDB(ExtractFileDir(ParamStr(0)) + '\ROMDB.c8db');

end;

procedure TMainForm.DisplayPanelResize(Sender: TObject);
var
  Msg: TMessage;
begin

  If DisplayReady Then Begin
    ResizeDisplay;
    DisplayUpdate := True;
    WMRender(msg);
  End;

end;

Function TMainForm.GetModelName(Model: Integer): String;
Begin

  If Model = -1 Then
    Result := ModelNames[TCustomCore(Interpreter.Core).CurCPUModel] + ' (Custom)'
  Else
    Result := ModelNames[Model];

End;

Procedure TMainForm.SetBackground(Clr: LongWord);
Begin

  BackRed := (Clr And $FF) / 255;
  BackGreen := ((Clr And $FF00) Shr 8) / 255;
  BackBlue := ((Clr And $FF0000) Shr 16)/ 255;

End;

procedure TMainForm.menuExitClick(Sender: TObject);
begin

  Close;

end;

procedure TMainForm.FormCreate(Sender: TObject);
Var
  i: Integer;
  mi: TMenuItem;
begin

  CurrentModel := Chip8_VIP;
  InitDisplay(60, 64, 32, True, DisplayPanel);
  InitSound(48000);

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

  DoubleBuffered := True;

end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin

  SaveMRUList;
  MRUList.Free;
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
