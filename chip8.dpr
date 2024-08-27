program chip8;

uses
  Vcl.Forms,
  mainform in 'mainform.pas' {Main},
  Display in 'Display.pas',
  Chip8Int in 'Chip8Int.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, Main);
  Application.Run;
end.
