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
procedure grf_free(Grf: TGrf); cdecl; external 'grf.dll';

function grf_strerror(Error: TGrfError): PChar; cdecl; external 'grf.dll';

implementation

end.
