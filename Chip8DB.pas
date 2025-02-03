unit Chip8DB;

interface

Uses Classes, SysUtils, Core_Custom;

Type

  TChip8Platform = Record
    HardwareID: Integer;
    QuirksEnabled: Boolean;
    Quirks: TQuirkSettings;
  End;

  pChip8ROM = ^TChip8ROM;

  TChip8ROM = Record
    SHA1: String;
    IPF: Integer;
    Name, FileName, Path: String;
    Platforms: Array of TChip8Platform;
    colCount: Integer;
    Colours: Array[0..255] of LongWord;
    HasBuzzerColor, HasSilenceColor: Boolean;
    BuzzerColor, SilenceColor: LongWord;
    Keys: Array[0..15] of String;
    ScreenGrab: Array of LongWord;
    SmallFont, LargeFont: Integer;
    Description, Extra, Year, Author, dbFilename, subTitle: String;
  End;

  TChip8DB = Class
    Paths: TArray<String>;
    ROMS:  Array of TChip8ROM;
    Procedure ScanROMs;
    Function  GetFileList: TStringlist;
    Procedure AddROM(inFilename: String);
    Function  Count: Integer;
    Function  SaveToFile(Filename: String): Boolean;
    Function  LoadFromFile(Filename: String): Boolean;
  End;

  Procedure InitDB(DBFilename: String);
  Procedure SetDefaultQuirks(Model: Integer; Var Quirks: TQuirkSettings);
  Function  StringToModel(Str: String): Integer;
  Procedure DownloadDBFiles;
  Procedure LoadDBFiles;
  Procedure CloseDB;

Var

  InternalDB: TChip8DB;
  Dups: TStringlist;

Const
  DBFilenames: Array[0..1] of String =  ('https://raw.githubusercontent.com/chip-8/chip-8-database/refs/heads/master/database/programs.json',
                                         'https://raw.githubusercontent.com/chip-8/chip-8-database/refs/heads/master/database/sha1-hashes.json');

  DBSavedNames: Array[0..1] of String = ('programs.json', 'hashes.json');

implementation

Uses System.JSON, System.IOUtils, URLMon, Crypt.SHA1, Chip8Int, Fonts;

Var

  Hashes, Programs: TJSONValue;

Procedure InitDB(DBFilename: String);
Begin

  // Create and load the internal ROM DB if it exists.

  Dups := TStringlist.Create;
  InternalDB := TChip8DB.Create;

  With InternalDB Do Begin

    SetLength(Paths, 2);
    Paths[0] := ExtractFileDir(DBFilename);
    Paths[1] := ExtractFileDir(DBFilename) + '\' + 'ROMS';

    If FileExists(DBFileName) Then
      LoadFromFile(DBFilename);

    DownloadDBFiles; // Temp REMOVE
    ScanROMs; // Temp REMOVE

  End;

End;

Procedure DownloadDBFiles;
Var
  idx: Integer;
  Filename, Savename: String;
Begin

  For idx := 0 To High(DBFilenames) Do Begin
    Filename := DBFilenames[idx];
    SaveName := DBSavedNames[idx];
    If FileExists(Savename) Then DeleteFile(Savename);
    URLDownloadToFile(nil, pWideChar(DBFilenames[idx]), PWideChar(Savename), 0, nil);
  End;

  LoadDBFiles;

End;

Procedure LoadDBFiles;
Begin

  Programs := TJSONObject.ParseJSONValue(TFile.ReadAllText(InternalDB.Paths[0] + '\' + DBSavedNames[0]));
  Hashes := TJSONObject.ParseJSONValue(TFile.ReadAllText(InternalDB.Paths[0] + '\' + DBSavedNames[1]));

End;

Procedure CloseDB;
Begin

  InternalDB.Free;
  Dups.Free;
  Programs.Free;
  Hashes.Free;

End;

Procedure AddFiles(Path: String; Var List: TStringlist);
Var
  idx: Integer;
  Done: Boolean;
  Res: TSearchRec;
  Dirs, Files: TStringlist;
Begin

  Dirs := TStringlist.Create;
  Files := TStringlist.Create;
  Files.Sorted := True;
  Dirs.Sorted := True;

  Done := False;
  If FindFirst(Path + '\*.*', faAnyFile, Res) >= 0 Then
    While Not Done Do Begin
      If Copy(Res.Name, 1, 1) <> '.' Then
        If Res.Attr And faDirectory > 0 Then
          Dirs.Add(Path + '\' + Res.Name)
        Else
          Files.Add(Path + '\' + Res.Name);
      Done := SysUtils.FindNext(Res) <> 0;
    End;

  FindClose(Res);

  If Files.Count > 0 Then
    List.AddStrings(Files);

  If Dirs.Count > 0 Then
    For idx := 0 To Dirs.Count -1 Do
      AddFiles(Dirs[idx], List);

  Files.Free;
  Dirs.Free;

End;

Function TChip8DB.GetFileList: TStringlist;
Var
  Idx: Integer;
Begin

  Result := TStringlist.Create;

  For Idx := 1 To High(Paths) Do
    AddFiles(Paths[Idx], Result);

End;

Function SplitBetter(Const Str: String): String;
Var
  Idx: Integer;
Begin

  Result := Str;
  if Result <> '' Then Begin
    idx := 0;
    Repeat
      Inc(idx);
      if (idx > 1) And (Result[idx] = #$A) And (Not CharInSet(Result[idx -1], ['.', '-', ')', ' ', #$A])) Then
        Result := Copy(Result, 1, idx -1) + ' ' + Copy(Result, idx +1);
    Until idx >= Length(Result);
  End;

End;

Procedure TChip8DB.ScanROMS;
Var
  Idx: Integer;
  Files: TStringlist;
Begin

  Files := GetFileList;

  For idx := 0 To Files.Count -1 Do
    AddROM(Files[Idx]);

  Files.Free;

End;

Function StringToModel(Str: String): Integer;
Begin

  Result := Chip8_None;

  str := LowerCase(str);
  If Str = 'originalchip8' Then
    Result := Chip8_VIP
  Else
    If Str = 'hybridvip' Then
      Result := Chip8_Hybrid
    Else
      If Str = 'modernchip8' Then
        Result := Chip8_SChip_Modern
      Else
        If Str = 'chip8x' Then
          Result := Chip8_Chip8x
        Else
          If Str = 'chip48' Then
            Result := Chip8_Chip48
          Else
            If Str = 'superchip1' Then
              Result := Chip8_SChip_Legacy10
            Else
              If Str = 'superchip' Then
                Result := Chip8_SChip_Legacy11
              Else
                If Str = 'megachip8' Then
                  Result := Chip8_MegaChip
                Else
                  If Str = 'xochip' Then
                    Result := Chip8_XOChip;

End;

Procedure SetDefaultQuirks(Model: Integer; Var Quirks: TQuirkSettings);

  Procedure SetQuirks(Shifting, Clipping, Jumping, DispWait, VFReset: Boolean; Mem, IPF: Integer);
  Begin
    With Quirks Do Begin
      CPUType := Model;
      Shifting := Shifting;
      Clipping := Clipping;
      Jumping := Jumping;
      DispWait := DispWait;
      VFReset := VFReset;
      MemIncMethod := Mem;
      TargetIPF := IPF;
    End;
  End;

Begin

  Case Model of
    Chip8_VIP:
      SetQuirks(False, True, False, True, True, MemIncX1, 3660);
    Chip8_Chip8x:
      SetQuirks(False, True, False, True, True, MemIncX1, 3660);
    Chip8_Chip48:
      SetQuirks(True, True, True, True, True, MemIncX, 20);
    Chip8_SChip_Legacy10:
      SetQuirks(True, True, True, True, False, MemIncX, 30);
    Chip8_SChip_Legacy11:
      SetQuirks(True, True, True, True, False, MemIncNone, 30);
    Chip8_SChip_Modern:
      SetQuirks(True, True, True, False, False, MemIncNone, 30);
    Chip8_XOChip:
      SetQuirks(False, False, False, False, False, MemIncX1, 1000);
    Chip8_MegaChip:
      SetQuirks(True, True, False, True, False, MemIncNone, 3000);
  End;

End;

Procedure SetQuirkFromName(Var Quirks: TQuirkSettings; QuirkName: String; Enabled: Boolean);
Begin

  QuirkName := Lowercase(QuirkName);

  If QuirkName = 'shift' Then
    Quirks.Shifting := Enabled
  Else
    If QuirkName = 'memoryincrementbyx' Then
      Quirks.MemIncMethod := MemIncX
    Else
      If QuirkName = 'memoryleaveiunchanged' Then
        Quirks.MemIncMethod := MemIncNone
      Else
        If QuirkName = 'wrap' Then
          Quirks.Clipping := Not Enabled
        Else
          If QuirkName = 'jump' Then
            Quirks.Jumping := Enabled
          Else
            If QuirkName = 'vblank' Then
              Quirks.DispWait := Enabled
            Else
              If QuirkName = 'logic' Then
                Quirks.VFReset := Enabled;

End;

Procedure SetPlatformByExtension(inFilename: String; Var ROM: TChip8ROM);
Var
  l: integer;
  ext: String;
Begin
  With ROM Do Begin
    l := Length(Platforms);
    SetLength(Platforms, l +1);
    With Platforms[l] Do Begin
      HardWareID := Chip8_None;
      ext := LowerCase(ExtractFileExt(inFilename));
      If (ext = '.ch8') or (Ext = '.c8b') Then
        HardwareID := Chip8_VIP
      Else
        If Ext = '.hc8' Then
          HardwareID := Chip8_Hybrid
        Else
          If Ext = '.c8x' Then
            HardwareID := Chip8_Chip8X
          Else
            If Ext = '.sc8' Then
              HardwareID := Chip8_sChip_Legacy11
            Else
              If Ext = '.mc8' Then
                HardwareID := Chip8_MegaChip
              Else
                If Ext = '.xo8' Then
                  HardwareID := Chip8_XOChip
                Else
                  If Ext = '.bytepusher' Then
                    HardwareID := Chip8_BytePusher;

      If HardwareID <> Chip8_None Then Begin
        QuirksEnabled := False;
        SetDefaultQuirks(HardwareID, Quirks);
      End;
    End;

    If Platforms[0].HardwareID = Chip8_None Then Begin
      SetLength(Platforms, 9);
      For l := 0 To High(Platforms) Do
        With Platforms[l] Do Begin
          HardwareID := l;
          QuirksEnabled := False;
          SetDefaultQuirks(HardwareID, Quirks);
        End;
    End;

  End;
End;

Procedure GetAuthors(Var Entry: TJSONValue; Var ROM: TChip8ROM);
Var
  jArray: TJSONArray;
  idx: Integer;
Begin

  With Entry, ROM Do Begin

    Author := '';

    jArray := GetValue<TJSONArray>('authors', nil);
    If Assigned(jArray) Then Begin
      For idx := 0 To jArray.Count -1 Do Begin
        Author := Author + TJSONString(jArray.Items[idx]).Value;
        If idx < jArray.Count -1 Then
          Author := Author + ', ';
      End;
    End Else
      Author := '<Unknown>';

  End;

End;

Procedure GetColours(Var Entry: TJSONValue; Var ROM: TChip8ROM);
Var
  s: String;
  idx: Integer;
  tArray: TJSONArray;
  ColourEntry: TJSONValue;
Begin

  With Entry, ROM Do Begin

    For idx := 0 To 15 Do
      Colours[idx] := DefPalette[idx];

    colCount := 0;
    colourEntry := GetValue<TJSONValue>('colors', nil);
    if Assigned(colourEntry) Then Begin
      tArray := colourEntry.GetValue<TJSONArray>('pixels', nil);
      if Assigned(tArray) Then Begin
        for idx := 0 To tArray.Count -1 Do
          Colours[idx] := LongWord(StrToInt('$' + Copy(TJSONString(tArray.Items[idx]).Value, 2)));
        colCount := tArray.Count;
      End;
      s := GetValue<String>('buzzer', '');
      If s <> '' Then Begin
        HasBuzzerColor := True;
        BuzzerColor := LongWord(StrToIntDef('$' + Copy(s, 2), -1));
      End;
      s := GetValue<String>('silence', '');
      If s <> '' Then Begin
        HasSilenceColor := True;
        SilenceColor := LongWord(StrToIntDef('$' + Copy(s, 2), -1));
      End;
    end;

  End;

End;

Procedure GetKeys(Var Entry: TJSONValue; Var ROM: TChip8ROM);
Var
  KeysEntry: TJSONValue;
  idx, KeyNum: Integer;
Begin

  With Entry, ROM Do Begin

    For idx := 0 To 15 Do
      Keys[idx] := '';

    KeysEntry := GetValue<TJSONValue>('keys', nil);
    If Assigned(keysEntry) Then Begin
      For idx := 0 To TJSONArray(keysEntry).Count -1 Do Begin
        keyNum := StrToint(TJSONPair(TJSONArray(keysEntry).items[idx]).JSONValue.value);
        Keys[keyNum] := TJSONPair(TJSONArray(keysEntry).items[idx]).JSONString.value;
      End;
    end;

  End;

End;

Procedure GetPlatforms(Var Entry: TJSONValue; Var ROM: TChip8ROM);
Var
  tArray: TJSONArray;
  Quirky, qPlatform: TJSONObject;
  idx, idx2, l, iPlatform, pIdx: Integer;
  PlatformName, Quirk: String;
  Found, qEnabled: Boolean;
Begin

  With Entry, ROM Do Begin

    SetLength(Platforms, 0);

    tArray := GetValue<TJSONArray>('platforms', nil);
    if Assigned(tArray) Then Begin
      For idx := 0 To tArray.Count -1 Do Begin
        l := Length(Platforms);
        SetLength(Platforms, l +1);
        With Platforms[l] Do Begin
          HardwareID := StringToModel(TJSONString(tArray.Items[idx]).Value);
          QuirksEnabled := False;
          SetDefaultQuirks(HardwareID, Quirks);
        End;
      End;
    End;

    Quirky := GetValue<TJSONObject>('quirkyPlatforms', nil);
    If Assigned(Quirky) Then Begin
      For idx := 0 To Quirky.Count -1 Do Begin
        platformName := TJSONPair(TJSONArray(Quirky).items[idx]).JSONString.value;
        iPlatform := StringToModel(platformName);

        pIdx := 0;
        Found := False;
        For idx2 := 0 To High(Platforms) Do
          If Platforms[idx2].HardwareID = iPlatform Then Begin
            pIdx := idx2;
            Found := True;
            Break;
          End;

        if Not Found Then Begin
          pIdx := Length(Platforms);
          SetLength(Platforms, pIdx +1);
        End;

        With Platforms[pIdx] Do Begin
          HardwareID := iPlatform;
          QuirksEnabled := True;
          SetDefaultQuirks(HardwareID, Quirks);
        End;

        qPlatform := Quirky.GetValue<TJSONObject>(platformName, nil);
        If Assigned(qPlatform) Then Begin
          For idx2 := 0 To qPlatform.Count -1 Do Begin
            Quirk := TJSONPair(TJSONArray(qPlatform).items[idx2]).JSONString.value;
            QEnabled := TJSONPair(TJSONArray(qPlatform).items[idx2]).JSONValue.ToString = 'true';
            SetQuirkFromName(Platforms[pIdx].Quirks, Quirk, QEnabled);
          End;
        End;
      End;

    End;

  End;

End;

Procedure SplitFontFromStyle(FontStyle: String; Var ROM: TChip8ROM);
Begin

  With ROM Do Begin

    SmallFont := Font_Small_VIP;
    LargeFont := Font_None;

    If FontStyle = 'octo' Then Begin
      SmallFont := Font_Small_Octo;
      LargeFont := Font_Large_xo;
    End Else
      If FontStyle = 'vip' Then Begin
        SmallFont := Font_Small_VIP;
        LargeFont := Font_None;
      End Else
        If FontStyle = 'schip' Then Begin
          SmallFont := Font_Small_VIP;
          LargeFont := Font_Large_schip11;
        End Else
          If FontStyle = 'schip10' Then Begin
            SmallFont := Font_Small_VIP;
            LargeFont := Font_Large_schip10;
          End Else
            If FontStyle = 'dream6800' Then Begin
              SmallFont := Font_Small_Dream6800;
              LargeFont := Font_None;
            End Else
              If FontStyle = 'eti660' Then Begin
                SmallFont := Font_Small_eti660;
                LargeFont := Font_None;
              End Else
                If FontStyle = 'fish' Then Begin
                  SmallFont := Font_Small_fish;
                  LargeFont := Font_Large_fish;
                End Else
                  If FontStyle = 'akouz1' Then Begin
                    SmallFont := Font_Small_Akouz1;
                    LargeFont := Font_Large_Akouz1;
                  End;
  End;

End;

Procedure GetSpecificROMInfo(Entry: TJSONValue; Var ROM: TChip8ROM);
Var
  ROMlist, ROMEntry: TJSONValue;
Begin

  With Entry, ROM Do Begin

    romlist := GetValue<TJSONValue>('roms', nil);
    If Assigned(romlist) Then Begin
      romEntry := romlist.GetValue<TJSONValue>(SHA1, nil);
      If Assigned(RomEntry) Then Begin
        with romEntry Do Begin

          dbFilename := GetValue<String>('file', '');
          Extra := GetValue<String>('description', '');
          subTitle := GetValue<String>('embeddedTitle', '');
          IPF := GetValue<Integer>('tickrate', 11);
          SplitFontFromStyle(GetValue<String>('fontStyle', ''), ROM);
          GetColours(ROMEntry, ROM);
          GetKeys(ROMEntry, ROM);
          GetPlatforms(ROMEntry, ROM);

          Extra := SplitBetter(Extra);

        End;
      End;
    End;

  End;

End;

Procedure GetEntryInfo(Index: Integer; Var ROM: TChip8ROM);
Var
  entry: TJSONValue;
Begin

  entry := (Programs As TJSONArray).Items[Index];
  With entry, ROM Do Begin

    Name := GetValue<String>('title', '');
    Description := GetValue<String>('description', '');
    Year := GetValue<String>('release', '');
    Description := SplitBetter(Description);

    GetAuthors(Entry, ROM);
    GetSpecificROMInfo(Entry, ROM);

  End;

End;

Procedure TChip8DB.AddROM(inFilename: String);
Var
  cSHA1: String;
  Fs: TFileStream;
  Buffer: AnsiString;
  Idx, l: Integer;
Begin

  If FileExists(inFileName) Then Begin

    Fs := TFileStream.Create(inFilename, fmOpenRead or fmShareDenyNone);
    SetLength(Buffer, Fs.Size);
    Fs.Read(Buffer[1], Fs.Size);
    Fs.Free;

    cSHA1 := SHA1(Buffer);

    For idx := 0 To Length(ROMs) -1 Do
      If ROMS[idx].SHA1 = cSHA1 Then Begin
        Dups.Add(inFilename);
        Exit;
      End;

    l := length(ROMs);
    SetLength(ROMs, l +1);
    With ROMs[l] Do Begin
      FileName := ExtractFileName(inFilename);
      Path := ExtractFilePath(inFilename);
      Name := Copy(FileName, 1, Length(Filename) - Length(ExtractFileExt(Filename)));
      SHA1 := cSHA1;
      If Assigned(Programs) And Assigned(Hashes) Then Begin
        l := Hashes.GetValue<Integer>(cSHA1, -1);
        if l > -1 Then
          GetEntryInfo(l, ROMs[Length(ROMs) -1])
        Else
          If ExtractFileExt(inFilename) <> '' Then
            SetPlatformByExtension(inFilename, ROMs[Length(ROMs) -1]);
      End;
    End;

  End;

End;

Function TChip8DB.Count: Integer;
Begin
  Result := Length(ROMS);
End;

Function TChip8DB.SaveToFile(Filename: String): Boolean;
Begin

End;

Function TChip8DB.LoadFromFIle(Filename: String): Boolean;
Begin

End;

Initialization

Finalization

  CloseDB;

end.

