unit Browser;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Crypt.SHA1, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.StdCtrls, Generics.Collections,
  System.ImageList, Vcl.ImgList, Chip8Int, Chip8DB;

type
  TBrowserForm = class(TForm)
    ImageList1: TImageList;
    Splitter: TSplitter;
    ROMListPanel: TPanel;
    ROMInfoPanel: TPanel;
    ButtonPanel: TPanel;
    ScanBtn: TButton;
    RunBtn: TButton;
    FilterBox: TComboBox;
    ROMList: TTreeView;
    NoDBPanel: TPanel;
    Image: TImage;
    AnimTimer: TTimer;
    TitleLbl: TLabel;
    FilenameLbl: TLabel;
    AuthorLbl: TLabel;
    DescriptionLbl: TLabel;
    PlatformCmb: TComboBox;
    Platformlbl: TLabel;
    KeyImage: TImage;
    LLbl: TLabel;
    Rlbl: TLabel;
    Ulbl: TLabel;
    Dlbl: TLabel;
    Albl: TLabel;
    Blbl: TLabel;
    EditBtn: TButton;
    ImageList2: TImageList;
    procedure ScanBtnClick(Sender: TObject);
    procedure RunBtnClick(Sender: TObject);
    procedure FilterBoxChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ROMListGetImageIndex(Sender: TObject; Node: TTreeNode);
    procedure FormResize(Sender: TObject);
    procedure AnimTimerTimer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ROMListClick(Sender: TObject);
    procedure PlatformCmbChange(Sender: TObject);
    procedure ROMListExpanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
  private
    { Private declarations }
    IgnoreClick: Boolean;
  public
    { Public declarations }
    BrInt: TChip8Interpreter;
    ImageDIB: Array of LongWord;
    Procedure LaunchDemoInterpreter;
    Procedure SetInfoControls;
    Procedure FillTreeView;
    Procedure ResizeImage;
    Procedure MakeImage;
  end;

var
  BrowserForm: TBrowserForm;
  CurEntry: TChip8ROM;

implementation

{$R *.dfm}

Uses Math, Core_Def, Display, TextureMap, Fonts;

procedure TBrowserForm.FilterBoxChange(Sender: TObject);
begin
  ActiveControl := nil;
  FillTreeView;
end;

procedure TBrowserForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin

  AnimTimer.Enabled := False;
  If Assigned(brInt) Then
    brInt.Close;
  brInt := Nil;

end;

procedure TBrowserForm.FormResize(Sender: TObject);
begin

  ResizeImage;
  MakeImage;

end;

procedure TBrowserForm.FormShow(Sender: TObject);
begin

  FillTreeView;
  AnimTimer.Enabled := True;

end;

Procedure TBrowserForm.LaunchDemoInterpreter;
Var
  pIdx: Integer;
Begin

  If Not Assigned(brInt) Then
    BrInt := TChip8Interpreter.Create;

  BrInt.Pause;
  BrInt.DemoMode := True;
  pIdx := PlatformCMB.ItemIndex;
  If Length(CurEntry.Platforms) > 0 Then Begin
    if (pIdx < 0) or (pIdx > High(CurEntry.Platforms)) Then
      pIdx := 0;
    BrInt.SetCore(CurEntry.Platforms[pIdx].HardwareID, @CurEntry.Platforms[pIdx].Quirks);
    If CurEntry.ColCount > 0 Then
      BrInt.SetPalette(CurEntry.Colours)
    Else
      BrInt.SetPalette(DefPalette);
  End Else
    BrInt.SetCore(Chip8_VIP, Nil);
  If CurEntry.HasBuzzerColor then
    BrInt.SetBuzzerColor(CurEntry.BuzzerColor)
  Else
    BrInt.SetBuzzerColor($FF0000);
  If CurEntry.HasSilenceColor then
    BrInt.SetBuzzerColor(CurEntry.SilenceColor)
  Else
    BrInt.SetSilenceColor(0);
  If CurEntry.SmallFont <> Font_None Then
    BrInt.LoadFont(CurEntry.SmallFont);
  If CurEntry.LargeFont <> Font_None Then
    BrInt.LoadFont(CurEntry.LargeFont);
  BrInt.LoadROM(CurEntry.Path + CurEntry.Filename);
  BrInt.Restart;

End;

procedure TBrowserForm.ROMListClick(Sender: TObject);
Var
  Node: TTreeNode;
Begin

  If IgnoreClick Then
    IgnoreClick := False
  Else Begin
    Node := ROMList.Selected;
    If Assigned(Node.Data) Then Begin

      CurEntry := pChip8ROM(Node.Data)^;
      SetInfoControls;
      LaunchDemoInterpreter;

    End Else

      CurEntry.Name := '';

    EditBtn.Enabled := CurEntry.Name <> '';
    If EditBtn.Enabled Then
      EditBtn.ImageIndex := 0
    Else
      EditBtn.ImageIndex := 1;
  End;

end;

procedure TBrowserForm.ROMListExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
begin
  IgnoreClick := True;
end;

procedure TBrowserForm.ROMListGetImageIndex(Sender: TObject; Node: TTreeNode);
begin
  with Node do begin
    if ImageIndex <> 3 Then
      if Count > 0 Then Begin
        if Expanded then
          ImageIndex := 1
        else
          ImageIndex := 0;
      End Else
        ImageIndex := 2;
    SelectedIndex := ImageIndex;
  end;
end;

procedure TBrowserForm.ScanBtnClick(Sender: TObject);
begin
  ActiveControl := nil;
end;

procedure TBrowserForm.RunBtnClick(Sender: TObject);
begin
  ActiveControl := nil;
end;

procedure TBrowserForm.AnimTimerTimer(Sender: TObject);
begin

  MakeImage;

end;

Procedure TBrowserForm.FillTreeView;
Var
  idx, idx2: Integer;
  Files: TStringlist;

  Procedure AddFilesToTreeViewByPlatform(TreeView: TTreeView; FileList: TStringlist);
  Var
    i, ps: Integer;
    Node: TTreeNode;
    nPlatform, Name: String;
    NodeMap: TDictionary<String, TTreeNode>; // Tracks created nodes by their platform name
  Begin
    TreeView.Items.BeginUpdate;
    try
      NodeMap := TDictionary<String, TTreeNode>.Create;
      try
        For i := 0 To FileList.Count -1 Do Begin
          ps := Pos(#255, FileList[i]);
          Name := Copy(FileList[i], ps +1);
          nPlatform := Copy(FileList[i], 1, ps -1);
          If Not NodeMap.TryGetValue(nPlatForm, Node) Then Begin
            Node := TreeView.Items.GetFirstNode;
            While Assigned(Node) And (Node.Text < nPlatform) Do
              Node := Node.getNextSibling;
            If Assigned(Node) Then
              Node := TreeView.Items.Insert(Node, nPLatform)
            Else
              Node := TreeView.Items.Add(nil, nPlatform);
            Node.ImageIndex := 3;
            Node.SelectedIndex := 3;
            Node.ExpandedImageIndex := 3;
            Node.Data := nil;
            NodeMap.Add(nPlatform, Node);
          End;
          Node := TreeView.Items.AddChild(Node, Name);
          Node.Data := FileList.Objects[i];
        End;
      finally
        NodeMap.Free;
      end;
    finally
      TreeView.Items.EndUpdate;
    end;
  End;

  procedure AddFilesToTreeViewByFolder(TreeView: TTreeView; FileList: TStringList; BasePaths: TArray<String>);
  var
    i, j, ps: Integer;
    FilePath, RelativePath, CurrentPath, PartialPath, MatchedBasePath, Name, NewPath: String;
    Node, ParentNode: TTreeNode;
    NodeMap: TDictionary<String, TTreeNode>; // Tracks created nodes by their paths
    BasePathFound: Boolean;
  begin
    TreeView.Items.BeginUpdate;
    try
      NodeMap := TDictionary<String, TTreeNode>.Create;
      try
        for i := 0 to FileList.Count - 1 do begin
          ps := Pos(#255, FileList[i]);
          Name := Copy(FileList[i], ps +1);
          FilePath := Copy(FileList[i], 1, ps -1);
          BasePathFound := False;

          // Match file with one of the base paths
          for j := Low(BasePaths) +1 to High(BasePaths) do begin
            if FilePath.StartsWith(BasePaths[j], True) then begin
              MatchedBasePath := BasePaths[j];
              BasePathFound := True;
              Break;
            end;
          end;

          // Skip files that do not belong to any base path
          if not BasePathFound then
            Continue;

          // Get relative path
          NewPath := ExtractFileDir(MatchedBasePath);
          RelativePath := FilePath.Substring(Length(NewPath));
          CurrentPath := ExtractFileDir(RelativePath); // Get directory part
          ParentNode := nil;

          // Handle relative directory structure
          while (CurrentPath <> '\') and not NodeMap.ContainsKey(CurrentPath) do begin
            // Determine parent for this directory
            PartialPath := ExtractFileDir(CurrentPath);
            if PartialPath = CurrentPath then
              PartialPath := '';

            if PartialPath <> '' then
              NodeMap.TryGetValue(PartialPath, ParentNode);

            // Add current directory node to tree and dictionary
            NewPath := ExtractFileName(CurrentPath);
            If Assigned(ParentNode) Then Begin
              j := 0;
              While j < ParentNode.Count Do Begin
                If (ParentNode.Item[j].Count <> 0) And (ParentNode.Item[j].Text < NewPath) Then
                  Inc(j)
                Else
                  Break;
              End;
              If j = ParentNode.Count Then
                Node := TreeView.Items.AddChild(ParentNode, NewPath)
              Else
                Node := TreeView.Items.Insert(ParentNode.Item[j], NewPath);
            End Else Begin
              Node := TreeView.Items.AddChild(ParentNode, MatchedBasePath);
              Node.ImageIndex := 3;
              Node.SelectedIndex := 3;
              Node.ExpandedImageIndex := 3;
            End;
            Node.Data := nil;
            NodeMap.Add(CurrentPath, Node);

            // Move up the hierarchy to the parent
            CurrentPath := PartialPath;
          end;

          // Add file as a child of its directory
          NodeMap.TryGetValue(ExtractFileDir(RelativePath), ParentNode);
          Node := TreeView.Items.AddChild(ParentNode, Name);
          Node.ImageIndex := 2;
          Node.SelectedIndex := 2;
          Node.Data := FileList.Objects[i];
        end;
      finally
        NodeMap.Free;
      end;
    finally
      TreeView.Items.EndUpdate;
    end;
  end;

Begin

  // Use the database to fill this with ROMs!

  ROMList.Items.BeginUpdate;
  ROMList.Items.Clear;

  With InternalDB Do Begin

    Files := TStringlist.Create;

    Case FilterBox.ItemIndex Of

      0: // Folder view
        Begin
          For idx := 0 To High(ROMs) Do Begin
            Files.Add(ROMS[idx].Path + ROMS[idx].Filename + #255 + ROMs[idx].Name);
            Files.Objects[Files.Count -1] := @ROMs[Idx];
          End;
          AddFilesToTreeViewByFolder(ROMList, Files, Paths);
          ROMList.Items.GetFirstNode.Expand(False);
        End;

      1: // Platform view
        Begin
          For idx := 0 To High(ROMs) Do
            If Length(ROMs[Idx].Platforms) > 0 Then Begin
              For Idx2 := 0 To High(ROMs[Idx].Platforms) Do Begin
                Files.Add(ModelLongNames[ROMs[Idx].Platforms[Idx2].HardwareID] + #255 + ROMs[idx].Name);
                Files.Objects[Files.Count -1] := @ROMs[Idx];
              End;
            End Else
              Files.Add('Unknown' + #255 + ROMs[Idx].Name);
          AddFilesToTreeViewByPlatform(ROMList, Files);
        End;

    End;

    Files.Free;

  End;

  ROMList.Items.EndUpdate;
  IgnoreClick := False;

End;

Procedure TBrowserForm.ResizeImage;
Begin

  With Image.Picture.Bitmap Do Begin
    SetSize(Image.Width, Image.Height);
    SetLength(ImageDIB, Image.Width * Image.Height);
    PixelFormat := pf32bit;
  End;

End;

Procedure TBrowserForm.MakeImage;
Var
  ratio, Scale, bz: Double;
  RenderInfo: TDisplayInfo;
  x, y, iw, w, ih, pw, ph,tw, th, idx, px, py, iScale: Integer;
  Quad: Array[0..3] of p3D;
  Src, Ptr: pByte;
  c, t: LongWord;
  preScale, ThumbNail: Array Of LongWord;
  sDIB, sTex: TSurface;
  Rct: TRect;
  ActiveKeys: Array[0..5] of Integer;
  lbl: ^TLabel;

  Function Clamp(v, a, b: Integer): Integer;
  Begin
    Result := Max(Min(v, b), a);
  End;

  function BlendRGB(RGBBack, RGBFore: LongWord): LongWord;
  var
    A, R, G, B: LongWord;
  begin
    A := RGBBack and $FF000000;
    R := (((RGBBack and $FF0000) shr 16) + ((RGBFore and $FF0000) shr 16)) div 3;
    G := (((RGBBack and $00FF00) shr 8) + ((RGBFore and $00FF00) shr 8)) div 3;
    B := ((RGBBack and $0000FF) + (RGBFore and $0000FF)) div 3;
    Result := A or (R shl 16) or (G shl 8) or B;
  end;

  function DoubleRGBFast(ARGB: LongWord): LongWord;
  var
    A, R, G, B: LongWord;
  begin
    A := ARGB and $FF000000;
    R := Clamp((ARGB and $00FF0000) shr 16 + 16, 96, 255);
    G := Clamp((ARGB and $0000FF00) shr 8 + 16, 96, 255);
    B := Clamp((ARGB and $000000FF) + 16, 96, 255);
    Result := A or (R shl 16) or (G shl 8) or B;
  End;

  Function Lerp(A, B: Byte; Amt: Double): Byte;
  Begin
    Result := Trunc(A + ((B - A) * Amt));
  End;

Begin

  // BUild background

  iw := Image.Width;
  ih := Image.Height;
  iScale := 3;

  For y := 0 To ih Div 2 -1 Do Begin
    c := $80 + Round($60 * y / ih);
    c := c + c shl 8 + c shl 16 + c shl 24;
    For x := 0 To iw -1 Do Begin
      ImageDIB[x + y * iw] := c;
      ImageDIB[x + (y + ih Div 2) * iw] := Not c;
    End;
  End;

  // Grab preview image if the interpreter is running, or a "snow" image if not

  If Assigned(brInt) And (CurEntry.Name <> '') Then Begin

    RenderInfo := brInt.Core.GetDisplayInfo;
    px := Max((4 * RenderInfo.Width Div 64), (4 * RenderInfo.Height Div 32));
    pw := RenderInfo.Width + px;
    ph := RenderInfo.Height + px;
    SetLength(preScale, pw * ph);
    px := px Div 2;

    bz := brInt.Core.GetBuzzerLevel;
    c := brInt.Core.GetBuzzerColor;
    t := brInt.Core.GetSilenceColor;
    c := (Lerp((t Shr 16) and $FF, (c Shr 16) And $FF, bz) Shl 16) or (Lerp((t Shr 8) and $FF, (c Shr 8) And $FF, bz) Shl 8) or Lerp(t and $FF, c And $FF, bz);

    For Idx := 0 To Length(preScale) -1 Do
      preScale[Idx] := c;

    Src := RenderInfo.Data;
    Case RenderInfo.Depth Of
      8: // 8 Bpp image
        Begin
          For y := 0 To RenderInfo.Height -1 Do
            For x := 0 To RenderInfo.Width -1 Do Begin
              preScale[x + px + (y + px) * pw] := BrInt.Core.Palette[Src^ And $F];
              Inc(Src);
            End;
        End;

      32: // 32Bpp image
        Begin
          For y := 0 To RenderInfo.Height -1 Do
            For x := 0 To RenderInfo.Width -1 Do Begin
              preScale[x + px + (y + px) * pw] := pLongWord(Src)^;
              Inc(Src, SizeOf(LongWord));
            End;
        End;

    End;

  End Else Begin

    pw := 256;
    ph := 128;

    SetLength(preScale, pw * ph);
    Fillmemory(@preScale[0], pw * ph * SizeOf(LongWord), 0);
    For x := 4 to pw -5 Do
      For y := 4 to ph -5 Do Begin
        c := random(255);
        preScale[x + y * pw] := c or c shl 8 or c shl 16;
      End;

  End;

  // Dump thumbnail

  SetLength(ThumbNail, pw * ph * iScale * iScale);
  ScaleBuffers(@preScale[0], @Thumbnail[0], pw, iScale, 0, pw -1, 0, ph -1);

  pw := pw * iScale;
  ph := ph * iScale;

  ratio := ph / pw;
  tw := 10;
  th := Round(tw * ratio);

  if CurEntry.Name <> '' Then Begin
    if th > 8 Then Begin
      th := 8;
      tw := Round(th / Ratio);
    End;
  End;

  if CurEntry.Name = '' Then
    Scale := Min(iw / 192, ih / 192) * 0.8
  Else
    Scale := Min(iw / 256, ih / 256) * 0.8;

  sDIB.Bits := @ImageDIB[0];
  sDIB.Width := iw;
  sDIB.Height := ih;

  sTex.Bits := @Thumbnail[0];
  sTex.Width := pW;
  sTex.Height := pH;

  Quad[0].X := -tw; Quad[0].Y := -th; Quad[0].Z := 0; Quad[0].U := 0;  Quad[0].V := pH - 0.01;
  Quad[1].X := -tw; Quad[1].Y := th;  Quad[1].Z := 0; Quad[1].U := 0;  Quad[1].V := 0;
  Quad[2].X := tw;  Quad[2].Y := th;  Quad[2].Z := 0; Quad[2].U := pW - 0.01; Quad[2].V := 0;
  Quad[3].X := tw;  Quad[3].Y := -th; Quad[3].Z := 0; Quad[3].U := pW - 0.01; Quad[3].V := pH - 0.01;

  Rotate3D(Quad, 0, 0.628/2, 0);
  Translate3D(Quad, 0, 0, -275);

  If CurEntry.Name = '' Then
    Rct := DrawQuad(sDIB, Quad, sTex, Scale, iw Div 2, ih Div 2)
  Else Begin
    Rct := DrawQuad(sDIB, Quad, sTex, Scale, Round(140 * Scale), (ih Div 2) + 32);

    // Now draw info panel and arrange info text fields

    Ptr := @ImageDIB[Rct.Right + Rct.Left + iw * 8];

    For y := 0 To ih - 16 Do Begin
      For Idx := 0 To iw - 8 - (Rct.Right + Rct.Left) Do Begin
        pLongWord(Ptr)^ := DoubleRGBFast(pLongWord(Ptr)^);
        Inc(Ptr, 4);
      End;
      Inc(Ptr, ((7 + Rct.Right + Rct.Left) * 4));
    End;

  End;

  // Keys

  With CurEntry Do
    If Name <> '' Then Begin
      x := 8;
      For idx := 0 To 5 Do
        ActiveKeys[Idx] := -1;
      For idx := 0 To 15 Do Begin
        If Keys[idx] = 'left' Then
          ActiveKeys[0] := idx
        Else
          If Keys[Idx] = 'down' Then
            ActiveKeys[1] := idx
          Else
            If Keys[idx] = 'up' then
              ActiveKeys[2] := idx
            Else
              If Keys[Idx] = 'right' Then
                ActiveKeys[3] := idx
              Else
                If keys[idx] = 'a' Then
                  ActiveKeys[4] := idx
                Else
                  if Keys[idx] = 'b' Then
                    ActiveKeys[5] := idx;
      End;

      For idx := 0 To 5 Do Begin
        Case idx of
          0: lbl := @lLbl;
          1: lbl := @dLbl;
          2: lbl := @uLbl;
          3: lbl := @rLbl;
          4: lbl := @aLbl;
        Else
          lbl := @bLbl;
        End;
        If idx = 2 Then Begin
          Dec(x, 32);
          y := ih - 71
        end else
          y := ih -  40;
        If activeKeys[idx] = -1 Then Begin // Unused key
          lbl^.Visible := False;
          For py := 0 To 31 Do
            For px := 0 To 31 Do
              ImageDIB[px + x + (py + y) * iw] := BlendRGB(ImageDIB[px + x + (py + y) * iw], pLongWord(NativeUInt(KeyImage.Picture.Bitmap.Scanline[py]) + px * 3)^);
        End Else Begin
          Lbl^.SetBounds(x + 8, y + 4, 16, 17);
          Lbl^.Caption := KeyCodes[ActiveKeys[idx]];
          lbl^.Visible := True;
          For py := 0 To 31 Do
            For px := 0 To 31 Do
              ImageDIB[px + x + (py + y) * iw] := pLongWord(NativeUInt(KeyImage.Picture.Bitmap.Scanline[py]) + px * 3)^;
        End;
        Inc(x, 32);
        if idx = 3 Then inc(x, 8);
      End;
    End Else Begin
      lLbl.Visible := False;
      rLbl.Visible := False;
      uLbl.Visible := False;
      dLbl.Visible := False;
      aLbl.Visible := False;
      bLbl.Visible := False;
    End;

  // FINAL STAGE - Copy to DIB.

  w := Image.Width * SizeOf(LongWord);
  for y := 0 to Image.Height - 1 do
    CopyMemory(Image.Picture.Bitmap.ScanLine[y], @ImageDIB[y * iW], w);

  // Set the ROM info controls positions

  If CurEntry.Name <> '' Then Begin

    TitleLbl.SetBounds(Rct.Right + Rct.Left + 8, TitleLbl.Top, Iw - 20 - (Rct.Left + Rct.Right), TitleLbl.Height);
    FileNameLbl.SetBounds(TitleLbl.Left, TitleLbl.Top + 20, TitleLbl.Width, FilenameLbl.Height);
    AuthorLbl.SetBounds(TitleLbl.Left, FilenameLbl.Top + 24, TitleLbl.Width, AuthorLbl.Height);
    DescriptionLbl.SetBounds(TitleLbl.Left, AuthorLbl.Top + 24, TitleLbl.Width, DescriptionLbl.Height);
    TitleLbl.Visible := True;
    FilenameLbl.Visible := True;
    AuthorLbl.Visible := True;
    DescriptionLbl.Visible := True;
    PlatformCMB.Visible := True;
    PlatformLbl.Visible := True;

  End Else Begin

    TitleLbl.Visible := False;
    FilenameLbl.Visible := False;
    AuthorLbl.Visible := False;
    DescriptionLbl.Visible := False;
    PlatformCMB.Visible := False;
    PlatformLbl.Visible := False;

  End;

  Image.Invalidate;

End;

procedure TBrowserForm.PlatformCmbChange(Sender: TObject);
begin
  ActiveControl := nil;
  LaunchDemoInterpreter;
end;

Procedure TBrowserForm.SetInfoControls;
Var
  s: String;
  Idx: Integer;
Begin

  TitleLbl.Caption := CurEntry.Name;
  FileNameLbl.Caption := CurEntry.Filename;

  s := '';
  If CurEntry.Year <> '' Then s := CurEntry.Year + ', ';
  s := s + CurEntry.Author;
  AuthorLbl.Caption := s;

  DescriptionLbl.Caption := CurEntry.Description + #$A#$A + CurEntry.Extra;

  PlatformCmb.Items.Clear;
  For Idx := 0 To High(CurEntry.Platforms) Do Begin
    s := ModelLongNames[CurEntry.Platforms[Idx].HardwareID];
    If CurEntry.Platforms[Idx].QuirksEnabled Then
      s := s + ' *';
    PlatformCmb.Items.Add(s);
  End;

  PlatFormCMB.ItemIndex := 0;

End;

end.
