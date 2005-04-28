program grftool;

uses
  Forms,
  main in 'Main.pas' {Form1},
  grf in 'grf.pas',
  about in 'about.pas' {AboutBox},
  ExtractThread in 'ExtractThread.pas',
  GPattern in 'GPattern.pas',
  SettingsForms in 'SettingsForms.pas' {SettingsForm};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'GRF Tool';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
