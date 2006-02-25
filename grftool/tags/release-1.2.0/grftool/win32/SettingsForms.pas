unit SettingsForms;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, Buttons;

type
  TSettings = record
    Unicode: Boolean;
  end;

  TSettingsForm = class(TForm)
    Label1: TLabel;
    RadioButton1: TRadioButton;
    Unicode: TRadioButton;
    Bevel1: TBevel;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    procedure BitBtn1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  SettingsForm: TSettingsForm;
  Settings: TSettings;

procedure InitSettings;

implementation

{$R *.dfm}

procedure TSettingsForm.BitBtn1Click(Sender: TObject);
begin
  Settings.Unicode := Unicode.Checked;
end;

procedure TSettingsForm.FormCreate(Sender: TObject);
begin
  Unicode.Checked := Settings.Unicode;
end;

procedure InitSettings;
begin
  Settings.Unicode := False;
end;

end.
