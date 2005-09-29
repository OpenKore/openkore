unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Grf, ComCtrls, ToolWin, ImgList, ExtCtrls, Buttons, Types,
  ShellAPI, ShlObj, ExtractThread, VirtualTrees, Menus;

type
  TForm1 = class(TForm)
    OpenDialog1: TOpenDialog;
    ImageList1: TImageList;
    ToolBar1: TToolBar;
    ToolBar2: TToolBar;
    StatusBar1: TStatusBar;
    OpenBtn: TToolButton;
    Search: TEdit;
    SearchBtn: TToolButton;
    ExtractBtn: TToolButton;
    ToolButton4: TToolButton;
    PreviewBtn: TToolButton;
    ToolButton6: TToolButton;
    AboutBtn: TToolButton;
    ImageList2: TImageList;
    Splitter1: TSplitter;
    PreviewPane: TPanel;
    Notebook1: TNotebook;
    RichEdit1: TRichEdit;
    Panel2: TPanel;
    SpeedButton1: TSpeedButton;
    Timer1: TTimer;
    ScrollBox1: TScrollBox;
    Image1: TImage;
    SaveDialog1: TSaveDialog;
    ExtractWatcher: TTimer;
    ExtractorPanel: TPanel;
    Panel3: TPanel;
    StopButton: TSpeedButton;
    ProgressBar1: TProgressBar;
    FileList: TVirtualStringTree;
    procedure FormResize(Sender: TObject);
    procedure OpenBtnClick(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure PreviewBtnClick(Sender: TObject);
    procedure SearchBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure PreviewPaneResize(Sender: TObject);
    procedure FileListClick(Sender: TObject);
    procedure SearchKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FileListKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Timer1Timer(Sender: TObject);
    procedure AboutBtnClick(Sender: TObject);
    procedure ExtractBtnClick(Sender: TObject);
    procedure ExtractWatcherTimer(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FileListColumnClick(Sender: TObject; Column: TListColumn);
    procedure FileListGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType;
      var CellText: WideString);
  private
    Grf: TGrf;
    function OpenGRF(FileName: String): Boolean;
    procedure FillFileList;
    procedure UpdateSelectionStatus;
  public
    Extractor: TExtractor;
  end;

  TGrfItem = Record
    i: Integer;
  end;

var
  Form1: TForm1;

implementation

uses
  About;

{$R *.dfm}

function TForm1.OpenGRF(FileName: String): Boolean;
var
  Error: TGrfError;
  NewGrf: TGrf;
begin
  NewGrf := grf_open (PChar(FileName), Error);
  if NewGrf = nil then
  begin
      MessageBox(Handle, PChar('Unable to open ' + ExtractFileName(FileName) + ':' + #13#10 +
                         grf_strerror(Error)), 'Error', MB_ICONERROR);
      Result := False;
      Exit;
  end;

  if Grf <> nil then
      grf_free (Grf);
  Grf := NewGrf;

  FillFileList;
  Caption := FileName + ' - GRF Tool';
  ExtractBtn.Enabled := True;
  Result := True;
end;

function GetTypeName(FileName: String): String;
begin
  Result := UpperCase(ExtractFileExt(FileName));
end;

function FriendlySizeName(Size: Cardinal): String;
begin
  if Size < 1024 then
      Result := IntToStr(Size) + ' bytes'
  else if (Size >= 1024) and (Size < 1024 * 1024) then
      Result := Format('%.1f', [Size / 1024]) + ' KB'
  else
      Result := Format('%.1f', [Size / 1024 / 1024]) + ' MB';
end;

procedure TForm1.FillFileList;
var
  i: Cardinal;
  SearchFor: String;
  SearchLen: Integer;
  Node: ^TGrfItem;
begin
  SearchFor := LowerCase(Search.Text);
  SearchLen := Length(SearchFor);
  Screen.Cursor := crHourGlass;

  FileList.BeginUpdate;
  FileList.Clear;
  FileList.EndUpdate;
  Application.ProcessMessages;

  FileList.BeginUpdate;
  for i := 0 to Grf.nfiles - 1 do
  begin
      if (SearchLen <> 0) and (Pos(SearchFor, LowerCase(Grf.files[i].Name)) <= 0) then
          Continue;

      Node := FileList.GetNodeData(FileList.AddChild(nil));
      Node.i := i;
  end;
  FileList.EndUpdate;
  Screen.Cursor := crDefault;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  Search.Width := Width - SearchBtn.Width - ToolBar2.Indent - 8;
end;

procedure TForm1.OpenBtnClick(Sender: TObject);
var
  PrevText: String;
begin
  if OpenDialog1.Execute then
  begin
      PrevText := StatusBar1.SimpleText;
      StatusBar1.SimpleText := 'Loading ' + ExtractFileName(OpenDialog1.FileName) + '...';
      Application.ProcessMessages;
      if OpenGRF(OpenDialog1.FileName) then
          UpdateSelectionStatus
      else
          StatusBar1.SimpleText := PrevText;
  end;
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin
  PreviewBtn.Down := not PreviewBtn.Down;
  PreviewBtnClick(Sender);
end;

procedure TForm1.PreviewBtnClick(Sender: TObject);
begin
  PreviewPane.Visible := PreviewBtn.Down;
  Splitter1.Visible := PreviewBtn.Down;
end;

procedure TForm1.SearchBtnClick(Sender: TObject);
begin
  if Grf = nil then Exit;
  StatusBar1.SimpleText := 'Searching...';
  FillFileList;
  StatusBar1.SimpleText := IntToStr(FileList.RootNode.ChildCount) + ' files found';
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Grf := nil;
  Extractor := nil;
  FileList.NodeDataSize := SizeOf(TGrfItem);
  Font.Name := 'Tahoma';
  Panel2.Font.Name := 'Tahoma';
end;

procedure TForm1.PreviewPaneResize(Sender: TObject);
begin
  SpeedButton1.Left := Panel2.Width - SpeedButton1.Width - 2;
end;

procedure TForm1.UpdateSelectionStatus;
var
  Size: Integer;
  Node: PVirtualNode;
  Data: ^TGrfItem;
begin
  if not Assigned(Grf) then Exit;

  if FileList.SelectedCount = 0 then
      StatusBar1.SimpleText := IntToStr(Grf.nFiles) + ' files in archive'
  else
  begin
      Size := 0;
      Node := FileList.RootNode;
      repeat
          Node := FileList.GetNextSelected(Node);
          if not Assigned(Node) then Break;

          Data := FileList.GetNodeData(Node);
          Inc(Size, Grf.files[Data.i].RealLen);
      until not Assigned(Node);

      StatusBar1.SimpleText := IntToStr(FileList.SelectedCount) + ' files selected (' +
              FriendlySizeName(Size) + ')';
  end;
end;

procedure TForm1.FileListClick(Sender: TObject);
var
  FType, FName: String;
  Item: ^TGrfItem;

  Data: Pointer;
  Size: Cardinal;
  Error: TGrfError;

  TempDir, TempFile: array[0..MAX_PATH] of Char;
begin
  UpdateSelectionStatus;
  if (Grf = nil) or (FileList.SelectedCount <> 1) or (not PreviewBtn.Down) then
      Exit;

  Item := FileList.GetNodeData(FileList.GetNextSelected(FileList.RootNode));
  FType := UpperCase(ExtractFileExt(Grf.files[Item.i].Name));

  if (FType = '.TXT') or (FType = '.XML') then
  begin
      Data := grf_get(Grf, PChar(Grf.files[Item.i].Name), Size, Error);
      if Data = nil then
      begin
          MessageBox(Handle, grf_strerror(Error), 'Error', MB_ICONERROR);
          Exit;
      end;
      RichEdit1.Text := String(Data);
      NoteBook1.PageIndex := 0;

  end else if (FType = '.BMP') then
  begin
      GetTempPath(SizeOf(TempDir) - 1, @TempDir);
      GetTempFileName(TempDir, 'grf', 1, @TempFile);
      FName := TempFile + FType;

      if not grf_extract(Grf, PChar(Grf.files[Item.i].Name), PChar(FName), Error) then
      begin
          MessageBox(Handle, grf_strerror (Error), 'Error', MB_ICONERROR);
          Exit;
      end;

      try
          Image1.Picture.LoadFromFile(FName);
      finally
          DeleteFile(FName);
      end;
      Notebook1.PageIndex := 1;

  end else
  begin
      RichEdit1.Clear;
      Notebook1.PageIndex := 0;
  end;
end;

procedure TForm1.SearchKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then
      SearchBtnClick(Sender);
end;

procedure TForm1.FileListKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  UpdateSelectionStatus;
  if (Key = VK_DOWN) or (Key = VK_UP) or (Key = VK_HOME) or (Key = VK_END)
    or (Key = VK_PRIOR) or (Key = VK_NEXT) then
      // We update the preview with a timer because right now,
      // the file list's item index hasn't changed yet
      Timer1.Enabled := True;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := False;
  FileListClick(Sender);
end;

procedure TForm1.AboutBtnClick(Sender: TObject);
begin
  AboutBox := TAboutBox.Create(nil);
  AboutBox.ShowModal;
  AboutBox.Free;
end;

procedure TForm1.ExtractBtnClick(Sender: TObject);
var
  Files: TStringList;
  Node: PVirtualNode;
  Data: ^TGrfItem;

  Error: TGrfError;
  Info: TBrowseInfo;
  ItemList: PItemIDList;
  Dir: array[0..MAX_PATH] of Char;
const
  BIF_NEWDIALOGSTYLE = 64;
begin
  Files := TStringList.Create;
  Files.BeginUpdate;

  if FileList.SelectedCount = 0 then
  begin
      Node := FileList.GetFirst;
      repeat
          Node := FileList.GetNextVisible(Node);
          if not Assigned(Node) then Break;

          Data := FileList.GetNodeData(Node);
          Files.Add(Grf.files[Data.i].Name);
      until not Assigned(Node);
      ShowMessage('TODO: extract all files when nothing''s selected');
      Files.EndUpdate;
      Files.Free;
      Exit;
  end else
  begin
      Node := FileList.RootNode;
      repeat
          Node := FileList.GetNextSelected(Node);
          if not Assigned(Node) then Break;

          Data := FileList.GetNodeData(Node);
          Files.Add(Grf.files[Data.i].Name);
      until not Assigned(Node);
  end;

  Files.EndUpdate;


  if Files.Count = 1 then
  begin
      SaveDialog1.FileName := ExtractFileName(Files[0]);
      if SaveDialog1.Execute then
      begin
          if not grf_extract(Grf, PChar(Files[0]), PChar(SaveDialog1.FileName), Error) then
              MessageBox(Handle,
                  PChar('Unable to extract ' + ExtractFileName(Files[0]) + ':' + #13#10 + grf_strerror(Error)),
                  'Error', MB_ICONERROR)
          else
              StatusBar1.SimpleText := 'Successfully extracted ' + ExtractFileName(Files[0]);
      end;
      Files.Free;

  end else
  begin
      ZeroMemory(@Info, sizeof(TBrowseInfo));
      Info.hwndOwner := Handle;
      Info.ulFlags := BIF_EDITBOX or BIF_NEWDIALOGSTYLE;
      Info.lpszTitle := 'Select a folder to extract the files to.';
      ItemList := SHBrowseForFolder(Info);
      if not Assigned(ItemList) then Exit;

      if not SHGetPathFromIDList(ItemList, Dir) then
      begin
          FreeMemory(ItemList);
          Files.Free;
          Exit;
      end;
      FreeMemory(ItemList);

      StatusBar1.SimpleText := 'Extracting ' + IntToStr(Files.Count) + ' files...';
      Extractor := TExtractor.Create(True);
      Extractor.Files := Files;
      Extractor.Dir := Dir;
      Extractor.Grf := Grf;
      Extractor.FreeOnTerminate := True;
      ExtractWatcher.Enabled := True;
      ProgressBar1.Max := Files.Count;
      ProgressBar1.Position := 0;
      ExtractorPanel.Show;
      OpenBtn.Enabled := False;
      ExtractBtn.Enabled := False;
      Extractor.Resume;
  end;
end;

procedure TForm1.ExtractWatcherTimer(Sender: TObject);
begin
  if not Assigned(Extractor) then Exit;
  ProgressBar1.Position := Extractor.Current;
  StatusBar1.SimpleText := Format('Extracting (%.1f%%): %s',
        [Extractor.Current / Extractor.Max * 100.0,
        ExtractFileName(Extractor.CurrentFile)]);
end;

procedure TForm1.StopButtonClick(Sender: TObject);
begin
  Extractor.Stop := True;
  StopButton.Enabled := False;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if Assigned(Extractor) then begin
      Extractor.FreeOnTerminate := False;
      Extractor.Stop := True;
      Extractor.WaitFor;
      Extractor.Free;
  end;

  FileList.BeginUpdate;
  FileList.Clear;
  FileList.EndUpdate;
  Application.ProcessMessages;
end;

procedure TForm1.FileListColumnClick(Sender: TObject; Column: TListColumn);
begin
//FileList.CustomSort();
end;

procedure TForm1.FileListGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: WideString);
var
  Data: ^TGrfItem;
begin
  Data := FileList.GetNodeData(Node);
  if Column = 0 then
      CellText := Grf.files[Data.i].Name
  else if Column = 1 then
      CellText := GetTypeName(Grf.files[Data.i].Name)
  else if Column = 2 then
      CellText := FriendlySizeName(Grf.files[Data.i].RealLen)
  else
      CellText := '';
end;

end.
