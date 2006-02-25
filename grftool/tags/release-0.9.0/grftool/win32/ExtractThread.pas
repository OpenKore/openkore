unit ExtractThread;

interface

uses
  Classes, SysUtils, Grf;

type
  TExtractor = class(TThread)
  private
    procedure StopExtractWatcher;
  protected
    procedure Execute; override;
  public
    Files: TStringList;
    Dir: String;
    Grf: TGrf;
    Stop: Boolean;

    Current, Max, Failed: Integer;
    CurrentFile: String;
  end;

implementation

uses
  main, Windows;

procedure MkDirs(Dir: String);
var
  S: String;
  i, j: Integer;
  DirNames: TStringList;
begin
  DirNames := TStringList.Create;
  S := Dir;

  repeat
      i := Pos('\', S);
      if i = 0 then
      begin
          DirNames.Add(S);
          Break;
      end;
      DirNames.Add(Copy(S, 1, i));
      S := Copy(S, i + 1, Length(S) - i);
  until S = '';

  for i := 0 to DirNames.Count - 1 do
  begin
      S := '';
      for j := 0 to i do
          S := S + DirNames[j];
      if not DirectoryExists(S) then
          MkDir(S);
  end;
  DirNames.Free;
end;

procedure TExtractor.StopExtractWatcher;
begin
  with Form1 do
  begin
      ExtractWatcher.Enabled := False;
      ExtractorPanel.Hide;
      if Failed > 0 then
          StatusBar1.SimpleText := IntToStr(Current - Failed) + ' files extracted (' +
              IntToStr(Failed) + ' failed)'
      else
          StatusBar1.SimpleText := IntToStr(Current - Failed) + ' files extracted';
      StopButton.Enabled := True;
      OpenBtn.Enabled := True;
      ExtractBtn.Enabled := True;
      Files.Free;
      Extractor := nil;
  end;
end;

procedure TExtractor.Execute;
var
  i: Integer;
  Index: Cardinal;
  CurrentDir, FileName: String;
  Error: TGrfError;
  F: PGrfFile;
begin
  Failed := 0;
  Max := Files.Count;
  Current := 1;

  for i := 0 to Files.Count - 1 do
  begin
      if Stop then Break;
      CurrentDir := Dir + '\' + ExtractFileDir(Files[i]);
      FileName := Dir + '\' + Files[i];

      if not DirectoryExists(CurrentDir) then
          MkDirs(CurrentDir);

      // Do not attempt to extract folders
      F := grf_find(Grf, PChar(Files[i]), Index);
      if Assigned(F) and (F.TheType <> 2) then
          if not grf_extract(Grf, PChar(Files[i]), PChar(FileName), Error) then
              Inc(Failed);
      Current := i + 1;
      CurrentFile := FileName;
  end;
  Synchronize(StopExtractWatcher);
end;

end.
