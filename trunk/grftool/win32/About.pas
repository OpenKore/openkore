unit About;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ExtCtrls;

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
    procedure FormCreate(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  AboutBox: TAboutBox;

implementation

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

end.
