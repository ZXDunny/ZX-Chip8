object BrowserForm: TBrowserForm
  Left = 0
  Top = 0
  Caption = 'ROM Browser'
  ClientHeight = 357
  ClientWidth = 849
  Color = clMedGray
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  DesignSize = (
    849
    357)
  PixelsPerInch = 96
  TextHeight = 13
  object ROMList: TTreeView
    Left = 8
    Top = 37
    Width = 232
    Height = 279
    Anchors = [akLeft, akTop, akBottom]
    BevelInner = bvNone
    BevelOuter = bvNone
    BevelKind = bkFlat
    Ctl3D = False
    Indent = 19
    ParentCtl3D = False
    TabOrder = 0
  end
  object NoDBPanel: TPanel
    Left = 248
    Top = 8
    Width = 593
    Height = 308
    Anchors = [akLeft, akTop, akRight, akBottom]
    BevelKind = bkFlat
    BevelOuter = bvNone
    Color = clWindow
    Ctl3D = False
    DoubleBuffered = True
    ParentBackground = False
    ParentCtl3D = False
    ParentDoubleBuffered = False
    TabOrder = 1
  end
  object FilterBox: TComboBox
    Left = 8
    Top = 8
    Width = 232
    Height = 22
    BevelInner = bvNone
    BevelOuter = bvNone
    Style = csOwnerDrawFixed
    Ctl3D = False
    ParentCtl3D = False
    TabOrder = 2
    OnChange = FilterBoxChange
    Items.Strings = (
      'List by folder'
      'List by extension'
      'List by platform')
  end
  object UpdateBtn: TButton
    Left = 707
    Top = 323
    Width = 135
    Height = 27
    Anchors = [akRight, akBottom]
    Caption = 'Update Database'
    TabOrder = 3
    TabStop = False
    OnClick = UpdateBtnClick
  end
  object ScanBtn: TButton
    Left = 7
    Top = 323
    Width = 82
    Height = 27
    Anchors = [akLeft, akBottom]
    Caption = 'Scan'
    TabOrder = 4
    TabStop = False
    OnClick = ScanBtnClick
  end
end
