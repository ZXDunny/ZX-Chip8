unit CustomCoreDlg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Core_Custom, Vcl.Mask;

type
  TCustomCoreDialog = class(TForm)
    OptionsBox: TGroupBox;
    MemoryBox: TComboBox;
    ShiftCheck: TCheckBox;
    ClipCheck: TCheckBox;
    JumpCheck: TCheckBox;
    DispWaitCheck: TCheckBox;
    VFResetCheck: TCheckBox;
    MemLabel: TLabel;
    HelpBox: TGroupBox;
    HelpLabel: TLabel;
    CancelBtn: TButton;
    OkayBtn: TButton;
    speedLabel: TLabel;
    SpeedEdit: TMaskEdit;
    CoreTypeBox: TComboBox;
    CoreTypeLabel: TLabel;
    procedure CoreTypeBoxChange(Sender: TObject);
    procedure CoreTypeBoxMouseEnter(Sender: TObject);
    procedure CancelBtnClick(Sender: TObject);
    procedure OkayBtnClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure MemoryBoxChange(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    CustomCPU: Integer;
    CustomQuirks: TQuirkSettings;
    CoreDefaultIPF: Integer;
    Procedure SetQuirks(Shifting, Clipping, Jumping, DispWait, VFReset: Boolean; Mem, IPF: Integer);
  end;

var
  CustomCoreDialog: TCustomCoreDialog;

Const

  // Quirk descriptions lifted almost wholesale from https://github.com/chip-8/chip-8-database/blob/master/database/quirks.json

  Hints: Array[1..8] of String = ('Base Core Type:'#13#13'Allows a choice of Chip8 interpreters to base this custom CPU upon.',
                                  'Shifting:'#13#13'On most systems the shift opcodes take "vY" as input and stores the shifted version of "vY" into "vX".'#13#13'The interpreters for the HP48 took `vX` as both the input and the output.',
                                  'Clipping:'#13#13'Most systems, when drawing sprites to the screen, will clip sprites at the edges of the screen.'#13#13'The Octo interpreter, which spawned the XO-CHIP variant of CHIP-8, instead wraps the sprite around to the other side of the screen.',
                                  'Jumping:'#13#13'The jump to "<address> + v0" opcode was wrongly implemented on all the HP48 interpreters as jump to "<address> + vX"',
                                  'Display wait:'#13#13'The original Cosmac VIP interpreter would wait for vertical blank before each sprite draw.'#13#13+'This was done to prevent sprite tearing on the display, but it would also act as an accidental limit on the execution speed of the program.'+' Some programs rely on this speed limit to be playable.'#13#13+'Vertical blank happens at 60Hz, and as such its logic be combined with the timers.',
                                  'VF Reset:'#13#13'On the original Cosmac VIP interpreter, "vF" would be reset after each opcode that would invoke the arithmetic routines. Later interpreters have not copied this behaviour.',
                                  'Memory:'#13#13'On most systems storing and retrieving data between registers and memory increments the "i" register with "X+1" (the number of registers read or written).'+' So for each register read or written, the index register would be incremented.'+#13#13'The CHIP-48 interpreter for the HP48 would only increment the "i" register by "X",'+' And the HP48 SuperChip interpreter would not affect "I" at all.',
                                  'Cycles/Speed:'#13#13'The various models of Chip8 Interpreter ran at speeds dictated by the hardware they were running on.'#13#13+'The Cosmac VIP Chip 8 achieved 3660 machine cycles, others were measured in approximate instructions per frame.'+' Some software required a faster interpreter, while others may fail if things run too fast.');
implementation

{$R *.dfm}

Uses Chip8Int;

procedure TCustomCoreDialog.CancelBtnClick(Sender: TObject);
begin

  ModalResult := mrCancel;

end;

procedure TCustomCoreDialog.CoreTypeBoxChange(Sender: TObject);
begin

  ActiveControl := nil;

  CustomCPU := CoreTypeBox.ItemIndex;
  If CustomCPU > 0 Then Inc(CustomCPU);

  Case CustomCPU Of
    Chip8_VIP:
      SetQuirks(False, True, False, True, True, MemIncX1, 3660);
    Chip8_Chip8x:
      SetQuirks(False, True, False, True, True, MemIncX1, 3660);
    Chip8_Chip48:
      SetQuirks(True, True, True, True, True, MemIncX, 20);
    Chip8_SChip_Legacy10:
      SetQuirks(True, True, True, True, False, MemIncX, 30);
    Chip8_SChip_Legacy11:
      SetQuirks(True, True, True, True, False, MemIncNone, 30);
    Chip8_SChip_Modern:
      SetQuirks(True, True, True, False, False, MemIncNone, 30);
    Chip8_XOChip:
      SetQuirks(False, False, False, False, False, MemIncX1, 1000);
    Chip8_MegaChip:
      SetQuirks(True, True, False, True, False, MemIncNone, 3000);
  End;

end;

procedure TCustomCoreDialog.CoreTypeBoxMouseEnter(Sender: TObject);
begin
  HelpLabel.Caption := Hints[(Sender As TControl).Tag];
end;

procedure TCustomCoreDialog.FormShow(Sender: TObject);
begin

  If CoreTypeBox.ItemIndex = -1 Then Begin
    CoreTypeBox.ItemIndex := 0;
    CoreTypeBoxChange(nil);
  End;

  OkayBtn.SetFocus;
  ActiveControl := nil;

end;

procedure TCustomCoreDialog.MemoryBoxChange(Sender: TObject);
begin
  ActiveControl := nil;
end;

procedure TCustomCoreDialog.OkayBtnClick(Sender: TObject);
begin

  With CustomQuirks Do Begin
    CPUType := CustomCPU;
    Shifting := ShiftCheck.Checked;
    Clipping := ClipCheck.Checked;
    Jumping := JumpCheck.Checked;
    DispWait := DispWaitCheck.Checked;
    VFReset := VFResetCheck.Checked;
    MemIncMethod := MemoryBox.ItemIndex;
    TargetIPF := StrToIntDef(SpeedEdit.Text, CoreDefaultIPF);
  End;

  ModalResult := mrOk;

end;

Procedure TCustomCoreDialog.SetQuirks(Shifting, Clipping, Jumping, DispWait, VFReset: Boolean; Mem, IPF: Integer);
Begin

  ShiftCheck.Checked := Shifting;
  ClipCheck.Checked := Clipping;
  JumpCheck.Checked := Jumping;
  DispWaitCheck.Checked := DispWait;
  VFResetCheck.Checked := VFReset;
  MemoryBox.ItemIndex := Mem;
  SpeedEdit.Text := IntToStr(IPF);
  CoreDefaultIPF := IPF;

End;

end.
