unit grf;

interface

uses
  Types;

type
  TGrfFile = Record
    Name: PChar;
    TheType: Integer;
    CompressedLen: Cardinal;
    CompressedLenAligned: Cardinal;
    RealLen: Cardinal;
    Pos: Cardinal;
    Cycle: LongInt;
  end;
  PGrfFile = ^TGrfFile;
  TGrfFiles = array of TGrfFile;

  RGrf = Record
    FileName: PChar;
    Version: Integer;
    nFiles: Cardinal;
    files: TGrfFiles;

    F: Pointer;
  end;
  TGrf = ^RGrf;

  TGrfError = Integer;

const
  GE_BADARGS = 0;
  GE_CANTOPEN = 1;
  GE_INVALID = 2;
  GE_CORRUPTED = 3;
  GE_NOMEM = 4;
  GE_NSUP = 5;
  GE_NOTFOUND = 6;
  GE_INDEX = 7;
  GE_WRITE = 8;

function grf_open(const FileName: PChar; var Error: TGrfError): TGrf; cdecl; external 'grf.dll';
function grf_find (Grf: TGrf; FileName: PChar; var Index: Cardinal): PGrfFile; cdecl; external 'grf.dll';
function grf_get(Grf: TGrf; FileName: PChar; var Size: Cardinal; var Error: TGrfError): Pointer; cdecl; external 'grf.dll';
function grf_extract(Grf: TGrf; FileName: PChar; WriteToFile: PChar; var Error: TGrfError): Boolean; cdecl; external 'grf.dll';
function grf_extract_wide(Grf: TGrf; FileName: PChar; WriteToFile: WideString; var Error: TGrfError): Boolean; cdecl;
procedure grf_free(Grf: TGrf); cdecl; external 'grf.dll';

function grf_strerror(Error: TGrfError): PChar; cdecl; external 'grf.dll';

implementation

uses
  Main, TntSysUtils, Windows, Dialogs, SysUtils;

function grf_extract_wide(Grf: TGrf; FileName: PChar; WriteToFile: WideString; var Error: TGrfError): Boolean;
var
  Size, Written: Cardinal;
  Data: Pointer;
  F: Integer;
begin
  Result := False;
  if not Assigned(Grf) then
  begin
      Error := GE_BADARGS;
      Exit;
  end;

  Data := grf_get(Grf, FileName, Size, Error);
  if not Assigned(Data) then Exit;

  F := WideFileCreate(WriteToFile);
  if F = -1 then
  begin
      Error := GE_WRITE;
      Exit;
  end;

  WriteFile(F, Data, Size, Written, nil);  // WHY DOES THIS NOT WORK!?!?!?!?
  ShowMessage(inttostr(Written));
  CloseHandle(F);
  CFree(Data);
  Result := True;
end;

end.
