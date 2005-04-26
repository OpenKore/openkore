unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Grf, ComCtrls, ToolWin, ImgList, ExtCtrls, Buttons, Types,
  ShellAPI, ShlObj, ExtractThread, VirtualTrees, Menus, TntStdCtrls,
  TntComCtrls, mmsystem, TntDialogs, jpeg, ActiveX;

type
  TForm1 = class(TForm)
    OpenDialog1: TOpenDialog;
    ImageList1: TImageList;
    ToolBar1: TToolBar;
    ToolBar2: TToolBar;
    StatusBar1: TTntStatusBar;
    Search: TTntEdit;
    SearchBtn: TToolButton;
    ImageList2: TImageList;
    Splitter1: TSplitter;
    PreviewPane: TPanel;
    Notebook1: TNotebook;
    RichEdit1: TTntRichEdit;
    Panel2: TPanel;
    SpeedButton1: TSpeedButton;
    Timer1: TTimer;
    ScrollBox1: TScrollBox;
    Image1: TImage;
    ExtractWatcher: TTimer;
    ExtractorPanel: TPanel;
    Panel3: TPanel;
    StopButton: TSpeedButton;
    ProgressBar1: TProgressBar;
    FileList: TVirtualStringTree;
    Label1: TLabel;
    OpenBtn: TSpeedButton;
    ExtractBtn: TSpeedButton;
    PreviewBtn: TSpeedButton;
    AboutBtn: TSpeedButton;
    PaintBox1: TPaintBox;
    PaintBox2: TPaintBox;
    PopupMenu1: TPopupMenu;
    Copy1: TMenuItem;
    SaveDialog1: TTntSaveDialog;
    SettingsBtn: TSpeedButton;
    PaintBox3: TPaintBox;
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
    procedure FileListGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType;
      var CellText: WideString);
    procedure FileListDblClick(Sender: TObject);
    procedure FileListCompareNodes(Sender: TBaseVirtualTree; Node1,
      Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
    procedure FileListHeaderClick(Sender: TVTHeader; Column: TColumnIndex;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1Paint(Sender: TObject);
    procedure Copy1Click(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
    procedure SettingsBtnClick(Sender: TObject);
  private
    Grf: TGrf;
    FSortColumn: Integer;
    FSortDirection: TSortDirection;
    function OpenGRF(FileName: String): Boolean;
    procedure FillFileList;
    procedure UpdateSelectionStatus;
    procedure IterateList(Sender: TBaseVirtualTree; Node: PVirtualNode; Data: Pointer; var Abort: Boolean);
  public
    Extractor: TExtractor;
  end;

  TGrfItem = Record
    i: Integer;
  end;

var
  Form1: TForm1;

function UnicodeToKorean(Str: WideString): String;
function KoreanToUnicode(Str: AnsiString): WideString;

implementation

uses
  About, GPattern, TntSysUtils, SettingsForms;

{$R *.dfm}

function KoreanToUnicode(Str: AnsiString): WideString;
var
  Size: Integer;
begin
  // Attempt to convert from Korean
  Size := MultiByteToWideChar(51949, MB_PRECOMPOSED, PChar(Str), -1, nil, 0);
  if Size > 0 then
  begin
      // Don't include NULL character.
      Size := Size - 1;
      SetLength(Result, Size);
      MultiByteToWideChar(51949, MB_PRECOMPOSED, PChar(Str), -1, PWideChar(Result), Size);
  end else
  begin
      // Failed (maybe Korean support is not installed). Convert from ANSI.
      Size := MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, PChar(Str), -1, nil, 0);
      // Don't include NULL character.
      Size := Size - 1;
      SetLength(Result, Size);
      MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, PChar(Str), -1, PWideChar(Result), Size);
  end;
end;

function UnicodeToKorean(Str: WideString): String;
var
  Size: Integer;
begin
  Size := WideCharToMultiByte(51949, 0, PWideChar(Str), Length(Str), nil, 0, nil, nil);
  if Size > 0 then
  begin
      SetLength(Result, Size);
      WideCharToMultiByte(51949, 0, PWideChar(Str), Length(Str), PChar(Result), Size, nil, nil);
  end else
  begin
      Size := WideCharToMultiByte(CP_ACP, 0, PWideChar(Str), Length(Str), nil, 0, nil, nil);
      SetLength(Result, Size);
      WideCharToMultiByte(CP_ACP, 0, PWideChar(Str), Length(Str), PChar(Result), Size, nil, nil);
  end;
end;

function TForm1.OpenGRF(FileName: String): Boolean;
var
  Error: TGrfError;
  NewGrf: TGrf;
begin
  NewGrf := grf_callback_open (PChar(FileName), 'rb', Error, nil);
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

  FSortColumn := -1;
  FillFileList;
  Caption := FileName + ' - GRF Tool';
  ExtractBtn.Enabled := True;
  Result := True;
end;

function GetTypeName(FileName: String): WideString;
var
  Ext: String;
begin
  Ext := UpperCase(ExtractFileExt(FileName));
  if Ext = '.BMP' then
      Result := 'Bitmap Image'
  else if Ext = '.JPG' then
      Result := 'JPEG Image'
  else if Ext = '.GIF' then
      Result := 'GIF Image'
  else if Ext = '.PNG' then
      Result := 'PNG Image'
  else if Ext = '.TXT' then
      Result := 'Text File'
  else if Ext = '.WAV' then
      Result := 'Wave Sound'
  else if Ext = '.MP3' then
      Result := 'MP3 Music'
  else if Ext = '.SPR' then
      Result := 'Sprite Data'
  else if Ext = '.XML' then
      Result := 'XML Document'
  else
      Result := Ext;
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
  SearchFor: PChar;
  SearchLen: Integer;
  Pattern: PGPatternSpec;
  Node: ^TGrfItem;
begin
  // Do a substring search if the search text doesn't contain wildcards
  SearchLen := Length(Search.Text);
  if  (Pos('*', Search.Text) = 0) and (Pos('?', Search.Text) = 0) then
      SearchFor := PChar(UnicodeToKorean(WideLowerCase('*' + Search.Text + '*')))
  else
      SearchFor := PChar(UnicodeToKorean(WideLowerCase(Search.Text)));
  Screen.Cursor := crHourGlass;

  FileList.BeginUpdate;
  FileList.Clear;
  FileList.EndUpdate;
  Application.ProcessMessages;

  if SearchLen > 0 then
      Pattern := g_pattern_spec_new(SearchFor)
  else
      Pattern := nil;

  FileList.BeginUpdate;
  for i := 0 to Grf.nfiles - 1 do
  begin
      if (Assigned(Pattern)) and (not g_pattern_match_string(Pattern, PChar(LowerCase(Grf.files[i].Name)))) then
          Continue;
      if GRFFILE_IS_DIR(Grf.files[i]) then
          Continue;    // Do not list folders

      Node := FileList.GetNodeData(FileList.AddChild(nil));
      Node.i := i;
  end;
  FileList.EndUpdate;

  if Assigned(Pattern) then
      g_pattern_spec_free(Pattern);
  Screen.Cursor := crDefault;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  Search.Width := Width - SearchBtn.Width - Label1.Width - ToolBar2.Indent - 8;
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
  CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
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
      StatusBar1.SimpleText := IntToStr(FileList.RootNode.ChildCount) + ' files'
  else if FileList.SelectedCount = 1 then
  begin
      Data := FileList.GetNodeData(FileList.GetNextSelected(nil));
      StatusBar1.SimpleText := IntToStr(Grf.nFiles) + ' files - file #' +
          IntToStr(Data.i + 1) + ' selected';
  end else
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
      GetMem(Data, Grf.files[Item.i].RealLen);
      if grf_chunk_get(Grf, Grf.files[Item.i].Name, Data, 0, Size, Error) = nil then
      begin
          FreeMem(Data);
          MessageBox(Handle, grf_strerror(Error), 'Error', MB_ICONERROR);
          Exit;
      end;

      RichEdit1.Text := KoreanToUnicode(PChar(Data));
      NoteBook1.PageIndex := 0;
      FreeMem(Data);

  end else if (FType = '.BMP') or (FType = '.JPG') then
  begin
      GetTempPath(SizeOf(TempDir) - 1, @TempDir);
      GetTempFileName(TempDir, 'grf', 1, @TempFile);
      FName := TempFile + FType;

      if grf_extract(Grf, Grf.files[Item.i].Name, PChar(FName), Error) <= 0 then
      begin
          MessageBox(Handle, grf_strerror (Error), 'Error', MB_ICONERROR);
          Exit;
      end;

      try
          // Delphi has a bug which makes it unable to load RLE bitmaps. :(
          // Use the Win32 API as workaround.
          if FType = '.BMP' then
             Image1.Picture.Bitmap.Handle := LoadImage(Handle,
                PChar(FName), IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE)
          else
             Image1.Picture.LoadFromFile(FName);
      except
          // Do nothing
      end;
      DeleteFile(FName);
      Notebook1.PageIndex := 1;

  end else if (FType = '.WAV') then
  begin
      sndPlaySound(nil, SND_ASYNC);
      GetTempPath(SizeOf(TempDir) - 1, @TempDir);
      GetTempFileName(TempDir, 'grf', 1, @TempFile);
      FName := TempFile + FType;

      if grf_extract(Grf, Grf.files[Item.i].Name, PChar(FName), Error) <= 0 then
      begin
          MessageBox(Handle, grf_strerror (Error), 'Error', MB_ICONERROR);
          Exit;
      end;

      try
          sndPlaySound(PChar(FName), SND_ASYNC);
      except
          // Do nothing
      end;
      DeleteFile(FName);

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

procedure TForm1.IterateList(Sender: TBaseVirtualTree; Node: PVirtualNode; Data: Pointer; var Abort: Boolean);
var
  Files: TStringList;
  NData: ^TGrfItem;
begin
  Files := TStringList(Data);
  NData := FileList.GetNodeData(Node);
  if not GRFFILE_IS_DIR(Grf.files[NData.i]) then   // Do not extract folders
      Files.Add(Grf.files[NData.i].Name);
  Abort := False;
end;

procedure TForm1.ExtractBtnClick(Sender: TObject);
var
  Files: TStringList;
  Error: TGrfError;
  Info: TBrowseInfo;
  ItemList: PItemIDList;
  Dir: array[0..MAX_PATH] of Char;
  Result: Boolean;
const
  BIF_NEWDIALOGSTYLE = 64;
begin
  Files := TStringList.Create;
  Files.BeginUpdate;
  if FileList.SelectedCount = 0 then
      FileList.IterateSubtree(nil, IterateList, Files, [])
  else
      FileList.IterateSubtree(nil, IterateList, Files, [vsSelected]);
  Files.EndUpdate;


  if Files.Count = 1 then
  begin
      SaveDialog1.FileName := WideExtractFileName(KoreanToUnicode(Files[0]));
      if SaveDialog1.Execute then
      begin
          if Settings.Unicode then
              Result := grf_extractW(Grf, PChar(Files[0]), SaveDialog1.FileName, Error) <= 0
          else
              Result := grf_extract(Grf, PChar(Files[0]), PChar(UnicodeToKorean(SaveDialog1.FileName)), Error) <= 0;

          if Result then
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
      if not Assigned(ItemList) then
      begin
          Files.Free;
          Exit;
      end;

      if not SHGetPathFromIDList(ItemList, Dir) then
      begin
          CoTaskMemFree(ItemList);
          Files.Free;
          Exit;
      end;
      CoTaskMemFree(ItemList);

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
var
  FileName: WideString;
  Percentage: Single;
begin
  if not Assigned(Extractor) then
  begin
      ExtractWatcher.Enabled := False;
      Exit;
  end;

  ProgressBar1.Position := Extractor.Current;
  try
     Percentage := Extractor.Current * 100 / Extractor.Max;
     FileName := KoreanToUnicode(ExtractFileName(Extractor.CurrentFile));
     StatusBar1.SimpleText := WideFormat('Extracting (%f%%): %s',
        [Percentage, FileName]);
  except
  end;
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
  Application.ProcessMessages;
end;

procedure TForm1.FileListGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: WideString);
var
  Data: ^TGrfItem;
begin
  Data := FileList.GetNodeData(Node);
  if Column = 0 then
      CellText := KoreanToUnicode(Grf.files[Data.i].Name)
  else if Column = 1 then
      CellText := GetTypeName(Grf.files[Data.i].Name)
  else if Column = 2 then
      CellText := FriendlySizeName(Grf.files[Data.i].RealLen)
  else
      CellText := '';
end;

procedure TForm1.FileListDblClick(Sender: TObject);
begin
  if ExtractBtn.Enabled then
      ExtractBtnClick(Sender);
end;

procedure TForm1.FileListCompareNodes(Sender: TBaseVirtualTree; Node1,
  Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
var
  Data1, Data2: ^TGrfItem;
begin
  Data1 := FileList.GetNodeData(Node1);
  Data2 := FileList.GetNodeData(Node2);

  if Column = 0 then         // Name
      Result := WideCompareText(KoreanToUnicode(Grf.files[Data1.i].Name),
                            KoreanToUnicode(Grf.files[Data2.i].Name))
  else if Column = 1 then    // Type
      Result := WideCompareText(GetTypeName(Grf.files[Data1.i].Name),
                            GetTypeName(Grf.files[Data2.i].Name))
  else if Column = 2 then    // Size
      Result := Grf.files[Data2.i].RealLen - Grf.files[Data1.i].RealLen
  else
      Result := 0;
  StatusBar1.SimpleText := IntToStr(Column);
end;

procedure TForm1.FileListHeaderClick(Sender: TVTHeader;
  Column: TColumnIndex; Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
begin
  if Column = FSortColumn then
  begin
     if FSortDirection = sdAscending then
         FSortDirection := sdDescending
     else
         FSortDirection := sdAscending;
  end else
  begin
      FSortColumn := Column;
      FSortDirection := sdAscending;
  end;
  FileList.Sort(nil, Column, FSortDirection);
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
var
  P: TPaintBox;
begin
  P := TPaintBox(Sender);
  P.Canvas.Pen.Color := clBtnHighlight;
  P.Canvas.MoveTo(4, 3);
  P.Canvas.LineTo(4, P.Height - 3);
  P.Canvas.Pen.Color := clBtnShadow;
  P.Canvas.MoveTo(3, 3);
  P.Canvas.LineTo(3, P.Height - 3);
end;

procedure TForm1.Copy1Click(Sender: TObject);
begin
  RichEdit1.CopyToClipboard;
end;

procedure TForm1.PopupMenu1Popup(Sender: TObject);
begin
  Copy1.Enabled := RichEdit1.SelLength > 0;
end;

procedure TForm1.SettingsBtnClick(Sender: TObject);
begin
  SettingsForm := TSettingsForm.Create(Self);
  with SettingsForm do
  try
     ShowModal;
  finally
     Free;
  end;
end;

end.
