unit Fonts;

interface

Uses Core_Def;

Procedure LoadFont(Core: TCore; FontID: Integer);

Const

  Font_None            = -1;

  Font_Small_Octo      =  0;
  Font_Small_VIP       =  1;
  Font_Small_Chip48    =  2;
  Font_Small_Dream6800 =  3;
  Font_Small_eti660    =  4;
  Font_Small_fish      =  5;
  Font_Small_akouz1    =  6;

  Font_Large_fish      =  7;
  Font_Large_schip10   =  8;
  Font_Large_schip11   =  9;
  Font_Large_xo        = 10;
  Font_Large_akouz1    = 11;

  // Small (8x5) fonts

  OctoFont:          Array[0..79] of Byte = ($F0, $90, $90, $90, $F0, $20, $60, $20, $20, $70, $F0, $10, $F0, $80, $F0, $F0, $10, $F0, $10, $F0,
                                             $90, $90, $F0, $10, $10, $F0, $80, $F0, $10, $F0, $F0, $80, $F0, $90, $F0, $F0, $10, $20, $40, $40,
                                             $F0, $90, $F0, $90, $F0, $F0, $90, $F0, $10, $F0, $F0, $90, $F0, $90, $90, $E0, $90, $E0, $90, $E0,
                                             $F0, $80, $80, $80, $F0, $E0, $90, $90, $90, $E0, $F0, $80, $F0, $80, $F0, $F0, $80, $F0, $80, $80);

  VIPFont:           Array[0..79] of Byte = ($F0, $90, $90, $90, $F0, $60, $20, $20, $20, $70, $F0, $10, $F0, $80, $F0, $F0, $10, $F0, $10, $F0,
                                             $A0, $A0, $F0, $20, $20, $F0, $80, $F0, $10, $F0, $F0, $80, $F0, $90, $F0, $F0, $10, $10, $10, $10,
                                             $F0, $90, $F0, $90, $F0, $F0, $90, $F0, $10, $F0, $F0, $90, $F0, $90, $90, $F0, $50, $70, $50, $F0,
                                             $F0, $80, $80, $80, $F0, $F0, $50, $50, $50, $F0, $F0, $80, $F0, $80, $F0, $F0, $80, $F0, $80, $80);

  Chip48Font:        Array[0..79] of Byte = ($F0, $90, $90, $90, $F0, $20, $60, $20, $20, $70, $F0, $10, $F0, $80, $F0, $F0, $10, $F0, $10, $F0,
                                             $90, $90, $F0, $10, $10, $F0, $80, $F0, $10, $F0, $F0, $80, $F0, $90, $F0, $F0, $10, $20, $40, $40,
                                             $F0, $90, $F0, $90, $F0, $F0, $90, $F0, $10, $F0, $F0, $90, $F0, $90, $90, $E0, $90, $E0, $90, $E0,
                                             $F0, $80, $80, $80, $F0, $E0, $90, $90, $90, $E0, $F0, $80, $F0, $80, $F0, $F0, $80, $F0, $80, $80);

  Dream6800Font:     Array[0..79] of Byte = ($E0, $A0, $A0, $A0, $E0, $40, $40, $40, $40, $40, $E0, $20, $E0, $80, $E0, $E0, $20, $E0, $20, $E0,
                                             $80, $A0, $A0, $E0, $20, $E0, $80, $E0, $20, $E0, $E0, $80, $E0, $A0, $E0, $E0, $20, $20, $20, $20,
                                             $E0, $A0, $E0, $A0, $E0, $E0, $A0, $E0, $20, $E0, $E0, $A0, $E0, $A0, $A0, $C0, $A0, $E0, $A0, $C0,
                                             $E0, $80, $80, $80, $E0, $C0, $A0, $A0, $A0, $C0, $E0, $80, $E0, $80, $E0, $E0, $80, $C0, $80, $80);

  eti660Font:        Array[0..79] of Byte = ($E0, $A0, $A0, $A0, $E0, $20, $20, $20, $20, $20, $E0, $20, $E0, $80, $E0, $E0, $20, $E0, $20, $E0,
                                             $A0, $A0, $E0, $20, $20, $E0, $80, $E0, $20, $E0, $E0, $80, $E0, $A0, $E0, $E0, $20, $20, $20, $20,
                                             $E0, $A0, $E0, $A0, $E0, $E0, $A0, $E0, $20, $E0, $E0, $A0, $E0, $A0, $A0, $80, $80, $E0, $A0, $E0,
                                             $E0, $80, $80, $80, $E0, $20, $20, $E0, $A0, $E0, $E0, $80, $E0, $80, $E0, $E0, $80, $E0, $80, $80);

  fishFont:          Array[0..79] of Byte = ($60, $A0, $A0, $A0, $C0, $40, $C0, $40, $40, $E0, $C0, $20, $40, $80, $E0, $C0, $20, $40, $20, $C0,
                                             $20, $A0, $E0, $20, $20, $E0, $80, $C0, $20, $C0, $40, $80, $C0, $A0, $40, $E0, $20, $60, $40, $40,
                                             $40, $A0, $40, $A0, $40, $40, $A0, $60, $20, $40, $40, $A0, $E0, $A0, $A0, $C0, $A0, $C0, $A0, $C0,
                                             $60, $80, $80, $80, $60, $C0, $A0, $A0, $A0, $C0, $E0, $80, $C0, $80, $E0, $E0, $80, $C0, $80, $80);

  akouz1Font:        Array[0..79] of Byte = ($60, $90, $90, $90, $60, $20, $60, $20, $20, $70, $E0, $10, $60, $80, $F0, $E0, $10, $E0, $10, $E0,
                                             $30, $50, $90, $F0, $10, $F0, $80, $F0, $10, $E0, $70, $80, $F0, $90, $60, $F0, $10, $20, $40, $40,
                                             $60, $90, $60, $90, $60, $60, $90, $70, $10, $60, $60, $90, $F0, $90, $90, $E0, $90, $E0, $90, $E0,
                                             $70, $80, $80, $80, $70, $E0, $90, $90, $90, $E0, $F0, $80, $E0, $80, $F0, $F0, $80, $E0, $80, $80);

  // Large (8x10) fonts

  fishFontLarge:    Array[0..159] of Byte = ($7C, $C6, $CE, $DE, $D6, $F6, $E6, $C6, $7C, $00, $10, $30, $F0, $30, $30, $30, $30, $30, $FC, $00,
                                             $78, $CC, $CC, $0C, $18, $30, $60, $CC, $FC, $00, $78, $CC, $0C, $0C, $38, $0C, $0C, $CC, $78, $00,
                                             $0C, $1C, $3C, $6C, $CC, $FE, $0C, $0C, $1E, $00, $FC, $C0, $C0, $C0, $F8, $0C, $0C, $CC, $78, $00,
                                             $38, $60, $C0, $C0, $F8, $CC, $CC, $CC, $78, $00, $FE, $C6, $C6, $06, $0C, $18, $30, $30, $30, $00,
                                             $78, $CC, $CC, $EC, $78, $DC, $CC, $CC, $78, $00, $7C, $C6, $C6, $C6, $7C, $18, $18, $30, $70, $00,
                                             $30, $78, $CC, $CC, $CC, $FC, $CC, $CC, $CC, $00, $FC, $66, $66, $66, $7C, $66, $66, $66, $FC, $00,
                                             $3C, $66, $C6, $C0, $C0, $C0, $C6, $66, $3C, $00, $F8, $6C, $66, $66, $66, $66, $66, $6C, $F8, $00,
                                             $FE, $62, $60, $64, $7C, $64, $60, $62, $FE, $00, $FE, $66, $62, $64, $7C, $64, $60, $60, $F0, $00);

  sChip10FontLarge: Array[0..99] of Byte =  ($3C, $7E, $C3, $C3, $C3, $C3, $C3, $C3, $7E, $3C, $18, $38, $58, $18, $18, $18, $18, $18, $18, $3C,
                                             $3E, $7F, $C3, $06, $0C, $18, $30, $60, $FF, $FF, $3C, $7E, $C3, $03, $0E, $0E, $03, $C3, $7E, $3C,
                                             $06, $0E, $1E, $36, $66, $C6, $FF, $FF, $06, $06, $FF, $FF, $C0, $C0, $FC, $FE, $03, $C3, $7E, $3C,
                                             $3E, $7C, $C0, $C0, $FC, $FE, $C3, $C3, $7E, $3C, $FF, $FF, $03, $06, $0C, $18, $30, $60, $60, $60,
                                             $3C, $7E, $C3, $C3, $7E, $7E, $C3, $C3, $7E, $3C, $3C, $7E, $C3, $C3, $7F, $3F, $03, $03, $3E, $7C);

  sChip11FontLarge: Array[0..99] of Byte =  ($3C, $7E, $E7, $C3, $C3, $C3, $C3, $E7, $7E, $3C, $18, $38, $58, $18, $18, $18, $18, $18, $18, $3C,
                                             $3E, $7F, $C3, $06, $0C, $18, $30, $60, $FF, $FF, $3C, $7E, $C3, $03, $0E, $0E, $03, $C3, $7E, $3C,
                                             $06, $0E, $1E, $36, $66, $C6, $FF, $FF, $06, $06, $FF, $FF, $C0, $C0, $FC, $FE, $03, $C3, $7E, $3C,
                                             $3E, $7C, $C0, $C0, $FC, $FE, $C3, $C3, $7E, $3C, $FF, $FF, $03, $06, $0C, $18, $30, $60, $60, $60,
                                             $3C, $7E, $C3, $C3, $7E, $7E, $C3, $C3, $7E, $3C, $3C, $7E, $C3, $C3, $7F, $3F, $03, $03, $3E, $7C);

  xoChipFontLarge: Array[0..159] of Byte =  ($7C, $C6, $CE, $DE, $D6, $F6, $E6, $C6, $7C, $00, $10, $30, $F0, $30, $30, $30, $30, $30, $FC, $00,
                                             $78, $CC, $CC, $0C, $18, $30, $60, $CC, $FC, $00, $78, $CC, $0C, $0C, $38, $0C, $0C, $CC, $78, $00,
                                             $0C, $1C, $3C, $6C, $CC, $FE, $0C, $0C, $1E, $00, $FC, $C0, $C0, $C0, $F8, $0C, $0C, $CC, $78, $00,
                                             $38, $60, $C0, $C0, $F8, $CC, $CC, $CC, $78, $00, $FE, $C6, $C6, $06, $0C, $18, $30, $30, $30, $00,
                                             $78, $CC, $CC, $EC, $78, $DC, $CC, $CC, $78, $00, $7C, $C6, $C6, $C6, $7C, $18, $18, $30, $70, $00,
                                             $30, $78, $CC, $CC, $CC, $FC, $CC, $CC, $CC, $00, $FC, $66, $66, $66, $7C, $66, $66, $66, $FC, $00,
                                             $3C, $66, $C6, $C0, $C0, $C0, $C6, $66, $3C, $00, $F8, $6C, $66, $66, $66, $66, $66, $6C, $F8, $00,
                                             $FE, $62, $60, $64, $7C, $64, $60, $62, $FE, $00, $FE, $66, $62, $64, $7C, $64, $60, $60, $F0, $00);

  Akouz1FontLarge: Array[0..159] of Byte =  ($7E, $C7, $C7, $CB, $CB, $D3, $D3, $E3, $E3, $7E, $18, $38, $78, $18, $18, $18, $18, $18, $18, $7E,
                                             $7E, $C3, $03, $03, $0E, $18, $30, $60, $C0, $FF, $7E, $C3, $03, $03, $1E, $03, $03, $03, $C3, $7E,
                                             $06, $0E, $1E, $36, $66, $C6, $C6, $FF, $06, $06, $FF, $C0, $C0, $C0, $FE, $03, $03, $03, $C3, $7E,
                                             $7E, $C3, $C0, $C0, $FE, $C3, $C3, $C3, $C3, $7E, $FF, $03, $03, $03, $06, $0C, $18, $18, $18, $18,
                                             $7E, $C3, $C3, $C3, $7E, $C3, $C3, $C3, $C3, $7E, $7E, $C3, $C3, $C3, $7F, $03, $03, $03, $C3, $7E,
                                             $7E, $C3, $C3, $C3, $FF, $C3, $C3, $C3, $C3, $C3, $FE, $C3, $C3, $C3, $FE, $C3, $C3, $C3, $C3, $FE,
                                             $7E, $C3, $C0, $C0, $C0, $C0, $C0, $C0, $C3, $7E, $FC, $C6, $C3, $C3, $C3, $C3, $C3, $C3, $C6, $FC,
                                             $FF, $C0, $C0, $C0, $FE, $C0, $C0, $C0, $C0, $FF, $FF, $C0, $C0, $C0, $FE, $C0, $C0, $C0, $C0, $C0);

implementation

Uses Math;

Procedure LoadFont(Core: TCore; FontID: Integer);
Var
  i, Size, Offset: Integer;
  Font: pByte;
Begin

  Case FontID Of
    Font_Small_Octo:
      Begin
        Font := @OctoFont[0];
        Size := 80;
        Offset := 80;
      End;
    Font_Small_VIP:
      Begin
        Font := @VIPFont[0];
        Size := 80;
        Offset := 80;
      End;
    Font_Small_Chip48:
      Begin
        Font := @Chip48Font[0];
        Size := 80;
        Offset := 80;
      End;
    Font_Small_Dream6800:
      Begin
        Font := @Dream6800Font[0];
        Size := 80;
        Offset := 80;
      End;
    Font_Small_eti660:
      Begin
        Font := @eti660Font[0];
        Size := 80;
        Offset := 80;
      End;
    Font_Small_fish:
      Begin
        Font := @fishFont[0];
        Size := 80;
        Offset := 80;
      End;
    Font_Small_akouz1:
      Begin
        Font := @akouz1Font[0];
        Size := 80;
        Offset := 80;
      End;
    Font_Large_fish:
      Begin
        Font := @fishFontLarge[0];
        Size := 160;
        Offset := 160;
      End;
    Font_Large_schip10:
      Begin
        Font := @sChip10FontLarge[0];
        Size := 100;
        Offset := 160;
      End;
    Font_Large_schip11:
      Begin
        Font := @sChip11FontLarge[0];
        Size := 100;
        Offset := 160;
      End;
    Font_Large_xo:
      Begin
        Font := @xoChipFontLarge[0];
        Size := 160;
        Offset := 160;
      End;
    Font_Large_akouz1:
      Begin
        Font := @Akouz1FontLarge[0];
        Size := 160;
        Offset := 160;
      End;
  Else
    Exit;
  End;

  For i := 0 To Size -1 Do Begin
    Core.Memory[Min(Max(0, i + Offset), High(Core.Memory))] := Font^;
    Inc(Font);
  End;

End;

end.
