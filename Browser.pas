unit Browser;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Crypt.SHA1, Vcl.ExtCtrls,
  Vcl.ComCtrls, Vcl.StdCtrls;

type
  TBrowserForm = class(TForm)
    ROMList: TTreeView;
    NoDBPanel: TPanel;
    FilterBox: TComboBox;
    UpdateBtn: TButton;
    ScanBtn: TButton;
    procedure ScanBtnClick(Sender: TObject);
    procedure UpdateBtnClick(Sender: TObject);
    procedure FilterBoxChange(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  BrowserForm: TBrowserForm;

implementation

{$R *.dfm}

procedure TBrowserForm.FilterBoxChange(Sender: TObject);
begin
  ActiveControl := nil;
end;

procedure TBrowserForm.ScanBtnClick(Sender: TObject);
begin
  ActiveControl := nil;
end;

procedure TBrowserForm.UpdateBtnClick(Sender: TObject);
begin
  ActiveControl := nil;
end;

end.
