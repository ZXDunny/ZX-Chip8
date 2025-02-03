object ROMEditor: TROMEditor
  Left = 0
  Top = 0
  Caption = 'ROMEditor'
  ClientHeight = 299
  ClientWidth = 635
  Color = clMedGray
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  DesignSize = (
    635
    299)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 24
    Top = 56
    Width = 31
    Height = 13
    Caption = 'Label1'
  end
  object Label2: TLabel
    Left = 24
    Top = 139
    Width = 31
    Height = 13
    Caption = 'Label1'
  end
  object Label3: TLabel
    Left = 24
    Top = 83
    Width = 31
    Height = 13
    Caption = 'Label1'
  end
  object Label4: TLabel
    Left = 24
    Top = 8
    Width = 603
    Height = 33
    AutoSize = False
    Caption = 'ROM Information for:'
  end
  object Edit1: TEdit
    Left = 72
    Top = 53
    Width = 257
    Height = 21
    TabOrder = 0
    Text = 'Edit1'
  end
  object Memo1: TMemo
    Left = 72
    Top = 136
    Width = 257
    Height = 81
    Lines.Strings = (
      'Memo1')
    TabOrder = 1
  end
  object Edit2: TEdit
    Left = 72
    Top = 80
    Width = 49
    Height = 21
    TabOrder = 2
    Text = 'Edit1'
  end
  object Edit3: TEdit
    Left = 127
    Top = 80
    Width = 202
    Height = 21
    TabOrder = 3
    Text = 'Edit1'
  end
  object TabControl1: TTabControl
    Left = 338
    Top = 53
    Width = 289
    Height = 204
    TabOrder = 4
    Tabs.Strings = (
      'Platforms'
      'Keys'
      'Palette')
    TabIndex = 0
  end
  object RunBtn: TButton
    Left = 492
    Top = 263
    Width = 135
    Height = 27
    Anchors = [akRight, akBottom]
    Caption = 'Launch ROM'
    TabOrder = 5
    TabStop = False
  end
end
