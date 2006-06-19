unit SettingsForms;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, Buttons;

const
  // Sprite preview modes
  SPRPREV_CYCLING = 0;
  SPRPREV_SHEET   = 1;

  // Sprite file extraction modes
  SPRSAVE_ASIS     = 0;
  SPRSAVE_NUMBERED = 1;
  SPRSAVE_SHEET    = 2;

type
  TSettings = record
    Unicode: Boolean;
    SpritePrevMode: Byte;
    SpriteSaveMode: Byte;
  end;

  TSettingsForm = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    RB_Unicode: TRadioButton;
    RB_OriginalEnc: TRadioButton;
    RB_SprSave_AsIs: TRadioButton;
    RB_SprSave_Numbered: TRadioButton;
    RB_SprSave_Sheet: TRadioButton;
    RB_SprPrev_Cycling: TRadioButton;
    RB_SprPrev_Sheet: TRadioButton;
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
  with Settings do
   begin
    Unicode := RB_Unicode.Checked;

    if RB_SprPrev_Cycling.Checked then SpritePrevMode := SPRPREV_CYCLING;
    if RB_SprPrev_Sheet.Checked   then SpritePrevMode := SPRPREV_SHEET;

    if RB_SprSave_AsIs.Checked     then SpriteSaveMode := SPRSAVE_ASIS;
    if RB_SprSave_Numbered.Checked then SpriteSaveMode := SPRSAVE_NUMBERED;
    if RB_SprSave_Sheet.Checked    then SpriteSaveMode := SPRSAVE_SHEET;
   end;
end;

procedure TSettingsForm.FormCreate(Sender: TObject);
begin
  with Settings do
   begin
    RB_Unicode.Checked := Unicode;
    RB_OriginalEnc.Checked := not Unicode;

    RB_SprPrev_Cycling.Checked := SpritePrevMode = SPRPREV_CYCLING;
    RB_SprPrev_Sheet.Checked   := SpritePrevMode = SPRPREV_SHEET;

    RB_SprSave_AsIs.Checked     := SpriteSaveMode = SPRSAVE_ASIS;
    RB_SprSave_Numbered.Checked := SpriteSaveMode = SPRSAVE_NUMBERED;
    RB_SprSave_Sheet.Checked    := SpriteSaveMode = SPRSAVE_SHEET;
   end;
end;

procedure InitSettings;
begin
  Settings.Unicode := False;
  Settings.SpritePrevMode := SPRPREV_CYCLING;
  Settings.SpriteSaveMode := SPRSAVE_SHEET;
end;

end.
