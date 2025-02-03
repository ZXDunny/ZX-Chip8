program chip8;

uses
  Vcl.Forms,
  mainform in 'mainform.pas' {Main},
  Browser in 'Browser.pas' {BrowserForm},
  CustomCoreDlg in 'CustomCoreDlg.pas' {CustomCoreDialog},
  Chip8DB in 'Chip8DB.pas',
  Display in 'Display.pas',
  Sound in 'Sound.pas',
  Chip8Int in 'Chip8Int.pas',
  Core_Def in 'Core_Def.pas',
  Core_Chip8 in 'Core_Chip8.pas',
  Core_sChipLegacy11 in 'Core_sChipLegacy11.pas',
  Core_sChipLegacy10 in 'Core_sChipLegacy10.pas',
  Core_sChipModern in 'Core_sChipModern.pas',
  Core_xoChip in 'Core_xoChip.pas',
  Core_MegaChip in 'Core_MegaChip.pas',
  Core_Chip48 in 'Core_Chip48.pas',
  Core_Chip8x in 'Core_Chip8x.pas',
  Core_RCA1802 in 'Core_RCA1802.pas',
  Core_BytePusher in 'Core_BytePusher.pas',
  Core_Custom in 'Core_Custom.pas',
  TextureMap in 'TextureMap.pas',
  Fonts in 'Fonts.pas',
  DBEditor in 'DBEditor.pas' {ROMEditor};

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, Main);
  Application.CreateForm(TBrowserForm, BrowserForm);
  Application.CreateForm(TCustomCoreDialog, CustomCoreDialog);
  Application.CreateForm(TROMEditor, ROMEditor);
  Application.Run;
end.
