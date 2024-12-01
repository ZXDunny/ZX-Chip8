unit Chip8DB;

interface

Type

  pChip8ROM = ^TChip8ROM;

  TChip8ROM = Record
    Related: pChip8ROM;
    Name, FileName, Path: String;
    SHA1: String;
    Hardware: Integer;
    Palette: Array[0..255] of LongWord;
    ScreenGrab: Array of LongWord;
  End;

  TChip8DB = Class
    ROMS: Array of TChip8ROM;
    Function  AddROM(Filename: String): pChip8ROM;
    Function  Count: Integer;
    Function  SaveToFile(Filename: String): Boolean;
    Function  LoadFromFIle(Filename: String): Boolean;
  End;

  Procedure InitDB(DBFilename: String);

Var

  InternalDB: TChip8DB;

implementation

Uses Classes, SysUtils;

Procedure InitDB(DBFilename: String);
Begin

  // Create and load the internal ROM DB if it exists.

  InternalDB := TChip8DB.Create;

  If FileExists(DBFileName) Then
    InternalDB.LoadFromFile(DBFilename);

End;

Function TChip8DB.AddROM(Filename: String): pChip8ROM;
Begin

  // Checks to see if a ROM is already in the database.

  // First check to see if the filename (with path) is present. If it is, it checks the SHA-1 and updates the info if it's changed..
  // If not, check for filename without path. If still not present, calculate SHA-1 and examine other entries.
  // If STILL not present, make a new entry for it.

  // If present in the DB at a different path then check SHA-1 and if different, make a new entry.
  // If filename/path not found but SHA-1 does match then create a new entry and mark it as a sibling of the first instance of that SHA-1 entry.

  // Finally, now we have an entry we can scan the online DB for the SHA-1 and update the ROM's metadata with it.



End;

Function TChip8DB.Count: Integer;
Begin

  Result := Length(ROMS);

End;

Function  TChip8DB.SaveToFile(Filename: String): Boolean;
Begin

End;

Function  TChip8DB.LoadFromFIle(Filename: String): Boolean;
Begin

End;

end.
