program chip8;

uses
  Vcl.Forms,
  mainform in 'mainform.pas' {MainForm},
  Display in 'Display.pas',
  Chip8Int in 'Chip8Int.pas',
  Core_Chip8 in 'Core_Chip8.pas',
  Core_Def in 'Core_Def.pas',
  Core_sChipLegacy11 in 'Core_sChipLegacy11.pas',
  Core_sChipLegacy10 in 'Core_sChipLegacy10.pas',
  Core_sChipModern in 'Core_sChipModern.pas',
  Core_xoChip in 'Core_xoChip.pas',
  Sound in 'Sound.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, Main);
  Application.Run;
end.
