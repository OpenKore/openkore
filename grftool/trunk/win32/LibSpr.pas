{***************************************************************************
* Purpose          : Provides functions to read Ragnarok Online sprite files
* Copyright        : (C) 2006 Abraxa <abraxa@dar-clan.de>
*
* This program is free software; you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by the
* Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
***************************************************************************}

unit LibSpr;

interface

uses
  Types, SysUtils, Windows, Classes, Graphics;

const
  SPRITEMAGIC: Word = $5053;
  BITMAPMAGIC: Word = $4D42;

type
  TSpriteContainerHeader = record
   Magic, Reserved1: Word;
   ImgCount, Reserved2: Word;
  end;

  TSpriteImageHeader = record
   Width, Height, DataLength: Word;
  end;

  TSpritePalette = array[0..255] of DWord;

  TSpriteList = class(TObject)
  private
   FBitmapList: Array[0..255] of TBitmap;
   FBitmaps, FCurrent: Byte;
   function GetBitmap(Index: Byte): TBitmap;
  public
   constructor Create;
   destructor Destroy; Override;
   procedure AddBitmapFromStream(Stream: TStream);
   procedure Clear;
   procedure Next;
   function GetCurrent: TBitmap;
   function IsEmpty: Boolean;
   function IsLast: Boolean;

   property Bitmap[Index: Byte]: TBitmap Read GetBitmap; Default;
   property Bitmaps: Byte Read FBitmaps;
  end;

var
  CurrentLoadedSprites: TSpriteList;

procedure LoadSpritesFromStream(Stream: TStream; Dest: TSpriteList);
procedure LoadSpritesFromFile(FileName: String; Dest: TSpriteList);
procedure LoadSpritesFromFileW(FileName: WideString; Dest: TSpriteList);

procedure CreateSpriteSheet(SpriteList: TSpriteList; Dest: TBitmap);

procedure ExtractSprites(FileName: String; DelFile: Boolean);
procedure ExtractSpritesW(FileName: WideString; DelFile: Boolean);

procedure ExtractSpritesAsSheet(FileName: String; DelFile: Boolean);
procedure ExtractSpritesAsSheetW(FileName: WideString; DelFile: Boolean);

implementation

/// -------------------
/// --- TSpriteList ---
/// -------------------

function TSpriteList.GetBitmap(Index: Byte): TBitmap;
begin
  Result := nil;
  if Index > FBitmaps-1 then Exit;
  Result := FBitmapList[Index];
end;

constructor TSpriteList.Create;
begin
  inherited Create;
  FBitmaps := 0;
  FCurrent := 0;
end;

destructor TSpriteList.Destroy;
var
  I: Byte;
begin
  if FBitmaps > 0 then
   for I := 0 to FBitmaps-1 do
    FBitmapList[I].Free;

  inherited Destroy;
end;

procedure TSpriteList.AddBitmapFromStream(Stream: TStream);
begin
  if FBitmaps = 255 then Exit;
  Inc(FBitmaps);
  FBitmapList[FBitmaps-1] := TBitmap.Create;
  FBitmapList[FBitmaps-1].LoadFromStream(Stream);
end;

procedure TSpriteList.Clear;
var
  I: Byte;
begin
  if FBitmaps > 0 then
   for I := 0 to FBitmaps-1 do
    FBitmapList[I].Free;

  FBitmaps := 0;
  FCurrent := 0;
end;

procedure TSpriteList.Next;
begin
 Inc(FCurrent);
 if FCurrent > FBitmaps-1 then
  FCurrent := 0;
end;

function TSpriteList.GetCurrent: TBitmap;
begin
 if (FBitmaps > 0) and (FCurrent <= FBitmaps-1) then
   Result := FBitmapList[FCurrent]
  else
   Result := nil; 
end;

function TSpriteList.IsEmpty: Boolean;
begin
 Result := FBitmaps = 0;
end;

function TSpriteList.IsLast: Boolean;
begin
 Result := FCurrent = FBitmaps-1;
end;

/// ------------------------
/// --- Sprite Functions ---
/// ------------------------

procedure LoadSpritesFromStream(Stream: TStream; Dest: TSpriteList);
const
  ZeroByte: Byte = 0;
var
  ContainerHeader: TSpriteContainerHeader;
  SpriteHeader: TSpriteImageHeader;
  Palette: TSpritePalette;
  PalBuf: DWord;
  BytesRead, I, J, K, PixCount: Integer;
  Padding, Buf: Byte;
  BitmapFileHeader: TBitmapFileHeader;
  BitmapInfoHeader: TBitmapInfoHeader;
  BmpDataStream, BmpFileStream: TMemoryStream;
begin
  // Read the sprite file header and verify the header magic
  BytesRead := Stream.Read(ContainerHeader, SizeOf(ContainerHeader));
  if BytesRead <> SizeOf(ContainerHeader) then
   raise EReadError.Create('Failed to read sprite file');
  if ContainerHeader.Magic <> SPRITEMAGIC then
   raise EReadError.Create('File is not a valid sprite resource');

  // Read the palette
  Stream.Seek(Stream.Size-SizeOf(Palette), SOFROMBEGINNING);
  BytesRead := Stream.Read(Palette, SizeOf(Palette));
  if BytesRead <> SizeOf(Palette) then
    raise EReadError.Create('Unable to read palette data');

  // The palette's R and B values are swapped so let's fix that
  for I := Low(Palette) to High(Palette) do
   begin
    PalBuf := Palette[I];
    Palette[I] :=
     ((PalBuf and $000000FF) shl 16) or
      (PalBuf and $0000FF00) or
     ((PalBuf and $00FF0000) shr 16);
   end;

  // Seek back to the beginning of the sprite images
  Stream.Seek(SizeOf(ContainerHeader), SOFROMBEGINNING);

  // Read and process all bitmaps inside the sprite file
  for I := 1 to ContainerHeader.ImgCount do
   begin
    // Read sprite image header
    BytesRead := Stream.Read(SpriteHeader, SizeOf(SpriteHeader));
    if BytesRead <> SizeOf(SpriteHeader) then
     raise EReadError.Create('Failed to read sprite header for #'+IntToStr(I));

    // Create the pixel data from the RLE-compressed image data.
    // Each scan line needs to be 32-bit aligned so we determine the padding
    // beforehand and add it every SpriteHeader.Width bytes.
    // The RLE itself is very simple: 0x00 indicates start of RLE,
    // followed by a byte that gives N. We then write N-1 bytes of 0x00
    // into the bitmap (only 0x00 gets compressed)

    BmpDataStream := TMemoryStream.Create;
    Padding := 4-SpriteHeader.Width mod 4;
    If Padding = 4 Then Padding := 0;

    BytesRead := 0;
    PixCount := 0;
    repeat
     Stream.Read(Buf, 1); Inc(BytesRead);
     if Buf = $00 then
      // RLE
      begin
       Stream.Read(Buf, 1); Inc(BytesRead);
       for J := 1 to Buf do
        begin
         BmpDataStream.Write(ZeroByte, 1);
         Inc(PixCount);
         if (PixCount mod SpriteHeader.Width) = 0 then
          for K := 1 to Padding do
           BmpDataStream.Write(ZeroByte, 1);
        end;
      end

     else
      // No RLE
      begin
       BmpDataStream.Write(Buf, 1);
       Inc(PixCount);
       if (PixCount mod SpriteHeader.Width) = 0 then
        for K := 1 to Padding do
         BmpDataStream.Write(ZeroByte, 1);
      end;

    until BytesRead >= SpriteHeader.DataLength;

    // Fill the bitmap headers with our data
    with BitmapFileHeader do
     begin
      BFType := BITMAPMAGIC;
      BFSize := SizeOf(BitmapFileHeader)+SizeOf(BitmapInfoheader)+SizeOf(Palette)+BmpDataStream.Size;
      BFReserved1 := 0;
      BFReserved2 := 0;
      BFOffBits := SizeOf(BitmapFileHeader)+SizeOf(BitmapInfoHeader)+SizeOf(Palette);
     end;
    with BitmapInfoHeader do
     begin
      BISize := SizeOf(BitmapInfoHeader);
      BIWidth := SpriteHeader.Width;
      BIHeight := SpriteHeader.Height;
      BIPlanes := 1;
      BIBitCount := 8;
      BICompression := BI_RGB;
      BISizeImage := BmpDataStream.Size;
      BIXPelsPerMeter := 0;
      BIYPelsPerMeter := 0;
      BIClrUsed := 256;
      BIClrImportant := 0;
     end;

    // Assemble the entire bitmap file
    BmpFileStream := TMemoryStream.Create;
    BmpFileStream.Write(BitmapFileHeader, SizeOf(BitmapFileHeader));
    BmpFileStream.Write(BitmapInfoHeader, SizeOf(BitmapInfoHeader));
    BmpFileStream.Write(Palette, SizeOf(Palette));

    // The bitmap data is upside down so we have to flip it during copying
    for J := 1 to SpriteHeader.Height do
     begin
      BmpDataStream.Seek((SpriteHeader.Height-J)*(SpriteHeader.Width+Padding), SOFROMBEGINNING);
      for K := 1 to SpriteHeader.Width+Padding do
       begin
        BmpDataStream.Read(Buf, 1);
        BmpFileStream.Write(Buf, 1);
       end;
     end;

    // Add the bitmap to the sprite list
    BmpFileStream.Seek(0, SOFROMBEGINNING);
    Dest.AddBitmapFromStream(BmpFileStream);

    // Clean up
    BmpFileStream.Free;
    BmpDataStream.Free;
   end;
end;



procedure LoadSpritesFromFile(FileName: String; Dest: TSpriteList);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, FMOPENREAD or FMSHAREDENYWRITE);
  LoadSpritesFromStream(Stream, Dest);
  Stream.Free;
end;



procedure LoadSpritesFromFileW(FileName: WideString; Dest: TSpriteList);
var
  Stream: TMemoryStream;
  FData: Pointer;
  FHandle: THandle;
  FSize, BytesRead: DWord;
begin
  FHandle := CreateFileW(PWideChar(FileName), GENERIC_READ,
   FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  FSize := GetFileSize(FHandle, nil);

  FData := VirtualAlloc(nil, FSize, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
  ReadFile(FHandle, FData^, FSize, BytesRead, nil);

  if BytesRead < FSize then
    begin
     VirtualFree(FData, 0, MEM_RELEASE);
     raise EReadError.Create('Couldn''t read '+FileName)
    end
   else
    begin
     Stream := TMemoryStream.Create;
     Stream.Write(FData^, FSize);
     Stream.Seek(0, SOFROMBEGINNING);

     LoadSpritesFromStream(Stream, Dest);

     Stream.Free;
    end;

  VirtualFree(FData, 0, MEM_RELEASE);
  CloseHandle(FHandle);
end;



procedure CreateSpriteSheet(SpriteList: TSpriteList; Dest: TBitmap);
var
  I, SpritesPerRow: Byte;
  MaxSpriteX, MaxSpriteY, XPos, YPos: Word;
begin
  if SpriteList.IsEmpty then Exit;

  // Find the greatest sprite dimensions
  MaxSpriteX := 0; MaxSpriteY := 0;
  for I := 0 to SpriteList.Bitmaps-1 do
   begin
    if SpriteList[I].Width > MaxSpriteX then MaxSpriteX := SpriteList[I].Width;
    if SpriteList[I].Height > MaxSpriteY then MaxSpriteY := SpriteList[I].Height;
   end;

  // We want a square sprite sheet so we put all sprites in a grid
  // where each cell has the size of the greatest sprite dimensions.
  // When we then take the square root of the grid's area we know
  // how many pixels one row should have at most.
  // Dividing that amount by the width of a cell yields the number of sprites
  SpritesPerRow := Round( Sqrt(MaxSpriteX*MaxSpriteY*SpriteList.Bitmaps) / MaxSpriteX );

  // Special case: there are a lot of sprite files where the same poses appear
  // from two different angles. We don't want those sheets to be square but to
  // be aligned in two rows.
  // We limit this rule to a maximum of 20 sprites so the sheets don't get too wide
  if (SpriteList.Bitmaps <= 20) and (SpriteList.Bitmaps mod 2 = 0) then
   SpritesPerRow := SpriteList.Bitmaps shr 1;

  with Dest do
   begin
    Width := MaxSpriteX*SpritesPerRow;
    Height := MaxSpriteY*((SpriteList.Bitmaps+SpritesPerRow-1) div SpritesPerRow);

    // We want things to look nice so let's fill the destination bitmap
    // with the background color to avoid white gaps between sprites
    Canvas.Brush.Style := BSSOLID;
    Canvas.Brush.Color := SpriteList[0].Canvas.Pixels[0, 0];
    Canvas.FillRect(Rect(0, 0, Width, Height));
   end;

  // Arrange the sprites on the destination bitmap
  for I := 0 to SpriteList.Bitmaps-1 do
   begin
    XPos := MaxSpriteX*(I mod SpritesPerRow);
    YPos := MaxSpriteY*(I div SpritesPerRow);
    if Assigned(SpriteList[I]) then
     Dest.Canvas.Draw(XPos, YPos, SpriteList[I]);
   end;
end;



procedure ExtractSprites(FileName: String; DelFile: Boolean);
var
  Sprites: TSpriteList;
  I: Byte;
begin
  // Load the sprites into memory
  Sprites := TSpriteList.Create;
  LoadSpritesFromFile(FileName, Sprites);

  // Iterate over all sprites and save every one of them
  for I := 0 to Sprites.Bitmaps-1 do
   if Assigned(Sprites[I]) then
    Sprites[I].SaveToFile(ChangeFileExt(FileName, Format('_%.2d.bmp', [I])));

  Sprites.Free;

  // Delete sprite archive if requested
  if DelFile then
   SysUtils.DeleteFile(FileName);
end;



procedure ExtractSpritesW(FileName: WideString; Delfile: Boolean);
var
  Sprites: TSpriteList;
  Stream: TMemoryStream;
  FN: WideString;
  FHandle: THandle;
  FData: Pointer;
  I: Byte;
  BytesWritten: DWord;
begin
  // Load the sprites into memory
  Sprites := TSpriteList.Create;
  LoadSpritesFromFileW(FileName, Sprites);

  if Sprites.Bitmaps > 0 then
   for I := 0 to Sprites.Bitmaps-1 do
    begin
     // Copy bitmap file into stream, then into buffer, then write it into file
     Stream := TMemoryStream.Create;
     if Assigned(Sprites[I]) then
      Sprites[I].SaveToStream(Stream);
     Stream.Seek(0, SOFROMBEGINNING);
     FData := VirtualAlloc(nil, Stream.Size, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
     Stream.Read(FData^, Stream.Size);

     FN := ChangeFileExt(FileName, Format('_%.2d.bmp', [I]));
     FHandle := CreateFileW(PWideChar(FN), GENERIC_WRITE, 0, nil,
      CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
     WriteFile(FHandle, FData^, Stream.Size, BytesWritten, nil);

     CloseHandle(FHandle);
     VirtualFree(FData, 0, MEM_RELEASE);
     Stream.Free;
    end;

  Sprites.Free;

  // Delete sprite archive if requested
  if DelFile then
   SysUtils.DeleteFile(FileName);
end;



procedure ExtractSpritesAsSheet(FileName: String; DelFile: Boolean);
var
  Sprites: TSpriteList;
  Bitmap: TBitmap;
begin
  // Load the sprites into memory
  Sprites := TSpriteList.Create;
  LoadSpritesFromFile(FileName, Sprites);

  // Create and save sprite sheet, then clean up
  try
   Bitmap := TBitmap.Create;
   CreateSpriteSheet(Sprites, Bitmap);
   Bitmap.SaveToFile(ChangeFileExt(FileName, '.bmp'));
  finally
   Bitmap.Free;
   Sprites.Free;
  end;

  // Delete sprite archive if requested
  if DelFile then
   SysUtils.DeleteFile(FileName);
end;



procedure ExtractSpritesAsSheetW(FileName: WideString; DelFile: Boolean);
var
  Sprites: TSpriteList;
  Sheet: TBitmap;
  Stream: TMemoryStream;
  FN: WideString;
  FHandle: THandle;
  FData: Pointer;
  I: Byte;
  BytesWritten: DWord;
begin
  // Load the sprites into memory
  Sprites := TSpriteList.Create;
  LoadSpritesFromFileW(FileName, Sprites);

  // Create the sprite sheet
  Sheet := TBitmap.Create;
  CreateSpriteSheet(Sprites, Sheet);

  // Copy bitmap file into stream, then into buffer, then write it into file
  Stream := TMemoryStream.Create;
  Sheet.SaveToStream(Stream);
  Stream.Seek(0, SOFROMBEGINNING);
  FData := VirtualAlloc(nil, Stream.Size, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
  Stream.Read(FData^, Stream.Size);

  FN := ChangeFileExt(FileName, Format('.bmp', [I]));
  FHandle := CreateFileW(PWideChar(FN), GENERIC_WRITE, 0, nil,
   CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  WriteFile(FHandle, FData^, Stream.Size, BytesWritten, nil);

  CloseHandle(FHandle);
  VirtualFree(FData, 0, MEM_RELEASE);
  Stream.Free;

  Sheet.Free;
  Sprites.Free;

  // Delete sprite archive if requested
  if DelFile then
   SysUtils.DeleteFile(FileName);
end;



initialization
  CurrentLoadedSprites := TSpriteList.Create;
finalization
  CurrentLoadedSprites.Free;
end.
