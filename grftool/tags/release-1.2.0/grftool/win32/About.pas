unit About;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ExtCtrls, Menus;

type
  TAboutBox = class(TForm)
    Panel1: TPanel;
    Panel2: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    SpeedButton1: TSpeedButton;
    Label4: TLabel;
    Bevel1: TBevel;
    Image1: TImage;
    Label5: TLabel;
    PopupMenu1: TPopupMenu;
    CopyURL1: TMenuItem;
    Label6: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure Label3Click(Sender: TObject);
    procedure CopyURL1Click(Sender: TObject);
    procedure Label6Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  AboutBox: TAboutBox;

implementation

uses
  ShellAPI, Clipbrd;

{$R *.dfm}

procedure TAboutBox.FormCreate(Sender: TObject);
begin
  Font.Name := 'Tahoma';
  Label2.Font.Name := 'Tahoma';
end;

procedure TAboutBox.SpeedButton1Click(Sender: TObject);
begin
  Close;
end;

procedure TAboutBox.Label3Click(Sender: TObject);
begin
  ShellExecute(Handle, nil, 'http://openkore.sourceforge.net/grftool/',
      nil, nil, SW_NORMAL);
end;

procedure TAboutBox.CopyURL1Click(Sender: TObject);
begin
  Clipboard.AsText := Label3.Caption;
end;

procedure TAboutBox.Label6Click(Sender: TObject);
begin
  MessageBox(Handle,
      'VCL - Main program.' + #13#10 +
      'floAt - Help with various components.' + #13#10 +
      'mrdiablo - Sound preview support.' + #13#10 +
      'jojobail & Rasqual - many improvements in libgrf.' + #13#10 +
      'AdamN - bugfix for extraction of multiple files.'
      , 'Credits', MB_ICONINFORMATION);
end;

end.
