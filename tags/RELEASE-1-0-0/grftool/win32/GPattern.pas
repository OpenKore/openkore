{  Direct translation from gpattern.c from glib.
   Copyright (C) 1995-1997, 1999  Peter Mattis, Red Hat, Inc.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the
   Free Software Foundation, Inc., 59 Temple Place - Suite 330,
   Boston, MA 02111-1307, USA.  }

unit GPattern;

interface

type
  { keep enum and structure of gpattern.c and patterntest.c in sync }
  GMatchType = (
    G_MATCH_ALL,       // "*A?A*"
    G_MATCH_ALL_TAIL,  // "*A?AA"
    G_MATCH_HEAD,      // "AAAA*"
    G_MATCH_TAIL,      // "*AAAA"
    G_MATCH_EXACT,     // "AAAAA"
    G_MATCH_LAST
  );

  GPatternSpec = Record
    match_type    : GMatchType;
    pattern_length: Cardinal;
    min_length    : Cardinal;
    pattern       : PChar;
  end;
  PGPatternSpec = ^GPatternSpec;

function g_pattern_spec_new(pattern: PChar): PGPatternSpec;
function g_pattern_match_string(pspec: PGPatternSpec; str: PChar): Boolean;
procedure g_pattern_spec_free(pspec: PGPatternSpec);

implementation

uses
  SysUtils;

function Reverse(Str: Pchar; Len: Integer): PChar;
var
  NewStr: PChar;
  i, j: Integer;
begin
  GetMem(NewStr, Len + 1);
  j := 0;
  for i := Len - 1 downto 0 do
  begin
      NewStr[i] := Str[j];
      Inc(j);
  end;
  NewStr[Len] := #0;
  Result := NewStr;
end;

function g_pattern_spec_new(pattern: PChar): PGPatternSpec;
var
  pspec: PGPatternSpec;
  seen_joker, seen_wildcard, more_wildcards: Boolean;
  hw_pos, tw_pos, hj_pos, tj_pos: Integer;
  follows_wildcard: Boolean;
  pending_jokers: Cardinal;
  s: PChar;
  d: PChar;
  i: Cardinal;
  tmp: PChar;
begin
  //seen_joker := False;
  //seen_wildcard := False;
  //more_wildcards := False;
  hw_pos := -1;
  tw_pos := -1;
  hj_pos := -1;
  tj_pos := -1;
  follows_wildcard := False;
  pending_jokers := 0;

  // canonicalize pattern and collect necessary stats
  GetMem(pspec, SizeOf(GPatternSpec));
  pspec^.pattern_length := StrLen(pattern);
  pspec^.min_length := 0;
  GetMem(pspec^.pattern, pspec^.pattern_length + 1);
  d := pspec^.pattern;

  s := pattern;
  i := 0;
  while s[0] <> #0 do
  begin
      if s[0] = '*' then
      begin
	  if follows_wildcard then    // compress multiple wildcards
          begin
	      Dec(pspec^.pattern_length);
	      Continue;
          end;
	  follows_wildcard := True;
	  if hw_pos < 0 then
              hw_pos := i;
	  tw_pos := i;
      end else if s[0] = '*' then
      begin
          Inc(pending_jokers);
          Inc(pspec^.min_length);
      end else
      begin
          while pending_jokers > 0 do
          begin
              d[0] := '?';
              Inc(d);
              if hj_pos < 0 then
                  hj_pos := i;
              tj_pos := i;

              Dec(pending_jokers);
              Inc(i);
	  end;
          follows_wildcard := FALSE;
          Inc(pspec^.min_length);
      end;
      d[0] := s[0];
      Inc(d);
      Inc(s);
      Inc(i);
  end;

  while pending_jokers > 0 do
  begin
      d[0] := '?';
      Inc(d);
      if hj_pos < 0 then;
          hj_pos := i;
      tj_pos := i;
      Dec(pending_jokers);
  end;
  d[0] := #0;
  //Inc(d);
  seen_joker := hj_pos >= 0;
  seen_wildcard := hw_pos >= 0;
  more_wildcards := ((seen_wildcard) and (hw_pos <> tw_pos));

  // special case sole head/tail wildcard or exact matches
  if (not seen_joker) and (not more_wildcards) then
  begin
      if pspec^.pattern[0] = '*' then
      begin
          pspec^.match_type := G_MATCH_TAIL;
          Dec(pspec^.pattern_length);
          tmp := pspec^.pattern + 1;
          StrMove(pspec^.pattern, tmp, pspec^.pattern_length);
          pspec^.pattern[pspec^.pattern_length] := #0;
          Result := pspec;
          Exit;
      end;
      if (pspec^.pattern_length > 0) and
         (pspec^.pattern[pspec^.pattern_length - 1] = '*') then
      begin
          pspec^.match_type := G_MATCH_HEAD;
          Dec(pspec^.pattern_length);
          pspec^.pattern[pspec^.pattern_length] := #0;
          Result := pspec;
          Exit;
      end;
      if not seen_wildcard then
      begin
          pspec^.match_type := G_MATCH_EXACT;
          Result := pspec;
          Exit;
      end;
  end;

  // now just need to distinguish between head or tail match start
  tw_pos := Integer(pspec^.pattern_length) - 1 - tw_pos;	// last pos to tail distance
  tj_pos := Integer(pspec^.pattern_length) - 1 - tj_pos;	// last pos to tail distance
  if seen_wildcard then
  begin
      if tw_pos > hw_pos then
          pspec^.match_type := G_MATCH_ALL_TAIL
      else
          pspec^.match_type := G_MATCH_ALL;
  end else // seen_joker
  begin
      if tj_pos > hj_pos then
          pspec^.match_type := G_MATCH_ALL_TAIL
      else
          pspec^.match_type := G_MATCH_ALL;
  end;
  if pspec^.match_type = G_MATCH_ALL_TAIL then
  begin
    tmp := pspec^.pattern;
    pspec^.pattern := Reverse(pspec^.pattern, pspec^.pattern_length);
    FreeMem(tmp);
  end;

  Result := pspec;
end;

procedure g_pattern_spec_free(pspec: PGPatternSpec);
begin
  if not Assigned(pspec) then Exit;
  FreeMem(pspec^.pattern);
  FreeMem(pspec);
end;

function g_pattern_ph_match (const match_pattern: PChar; const match_string: PChar): Boolean;
var
  pattern, str: PChar;
  ch: Char;
begin
  pattern := match_pattern;
  str := match_string;

  ch := pattern[0];
  Inc(pattern);
  while ch <> #0 do
  begin
      case ch of
        '?':
        begin
            if str[0] = #0 then
            begin
                Result := False;
                Exit;
            end;
            Inc(str);
        end;

        '*':
        begin
            repeat
            begin
                ch := pattern[0];
                Inc(pattern);
                if ch = '?' then
                begin
                    if str = #0 then
                    begin
                        Result := False;
                        Exit;
                    end;
                    Inc(str);
                end;
            end until (ch <> '*') and (ch <> '?');

            if ch = #0 then
            begin
                Result := True;
                Exit;
            end;

            repeat
            begin
                while ch <> str[0] do
                begin
                    if str[0] = #0 then
                    begin
                        Result := False;
                        Exit;
                    end;
                    Inc(str);
                end;

                Inc(str);
                if g_pattern_ph_match(pattern, str) then
                begin
                    Result := True;
                    Exit;
                end;
            end until str[0] = #0;
        end;

        else
        begin
            if ch = str[0] then
                Inc(str)
            else
            begin
                Result := False;
                Exit;
            end;
        end;
      end;

      ch := pattern[0];
      Inc(pattern);
  end;

  Result := str[0] = #0;
end;

function g_pattern_match(pspec: PGPatternSpec; string_length: Cardinal; str: PChar; string_reversed: PChar): Boolean;
var
  tmp: PChar;
begin
  Result := False;
  if not Assigned(pspec) then Exit;
  if not Assigned(str) then Exit;

  if (pspec^.min_length > string_length) then Exit;
  case pspec^.match_type of
    G_MATCH_ALL:
    begin
        Result := g_pattern_ph_match(pspec^.pattern, str);
        Exit;
    end;
    G_MATCH_ALL_TAIL:
    begin
        if Assigned(string_reversed) then
        begin
            Result := g_pattern_ph_match(pspec^.pattern, string_reversed);
            Exit;
        end else
        begin
            tmp := Reverse(str, string_length);
            Result := g_pattern_ph_match(pspec^.pattern, tmp);
            FreeMem(tmp);
            Exit;
        end;
    end;
    G_MATCH_HEAD:
    begin
        if pspec^.pattern_length = string_length then
            Result := String(pspec^.pattern) = String(str)
        else if pspec^.pattern_length > 0 then
            Result := StrLComp(pspec^.pattern, str, pspec^.pattern_length) = 0
        else
            Result := True;
        Exit;
    end;
    G_MATCH_TAIL:
    begin
        tmp := str + (string_length - pspec^.pattern_length);
        if pspec^.pattern_length > 0 then
            Result := String(pspec^.pattern) = String(tmp)
        else
            Result := True;
        Exit;
    end;
    G_MATCH_EXACT:
    begin
        if pspec^.pattern_length <> string_length then
	    Result := False
        else
            Result := String(pspec^.pattern) = String(str);
    end
    else
        Exit;
  end;
end;

function g_pattern_match_string(pspec: PGPatternSpec; str: PChar): Boolean;
begin
  Result := g_pattern_match(pspec, StrLen(Str), Str, nil);
end;

end.
