unit DBEditor;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls;

type
  TROMEditor = class(TForm)
    Edit1: TEdit;
    Label1: TLabel;
    Memo1: TMemo;
    Label2: TLabel;
    Label3: TLabel;
    Edit2: TEdit;
    Edit3: TEdit;
    TabControl1: TTabControl;
    RunBtn: TButton;
    Label4: TLabel;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ROMEditor: TROMEditor;

implementation

{
  TChip8Platform = Record
    HardwareID: Integer;
    QuirksEnabled: Boolean;
    Quirks: TQuirkSettings;
  End;

  pChip8ROM = ^TChip8ROM;

  TChip8ROM = Record
    IPF: Integer;
    Name, FileName, Path: String;
    Platforms: Array of TChip8Platform;
    colCount: Integer;
    Colours: Array[0..255] of LongWord;
    HasBuzzerColor, HasSilenceColor: Boolean;
    BuzzerColor, SilenceColor: LongWord;
    Keys: Array[0..15] of String;
    SmallFont, LargeFont: Integer;
    Description, Extra, Year, Author, dbFilename, subTitle: String;
  End;
}

{$R *.dfm}

end.
