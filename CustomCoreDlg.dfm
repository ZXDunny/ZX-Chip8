object CustomCoreDialog: TCustomCoreDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Custom Chip8 Model'
  ClientHeight = 289
  ClientWidth = 545
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesigned
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object OptionsBox: TGroupBox
    Left = 8
    Top = 8
    Width = 249
    Height = 243
    Caption = ' Options '
    TabOrder = 0
    object MemLabel: TLabel
      Tag = 7
      Left = 16
      Top = 174
      Width = 38
      Height = 13
      Caption = 'Memory'
      OnMouseEnter = CoreTypeBoxMouseEnter
    end
    object speedLabel: TLabel
      Tag = 8
      Left = 16
      Top = 205
      Width = 51
      Height = 13
      Caption = 'Cycles/IPF'
      OnMouseEnter = CoreTypeBoxMouseEnter
    end
    object CoreTypeLabel: TLabel
      Tag = 1
      Left = 16
      Top = 27
      Width = 55
      Height = 13
      Caption = 'Core type: '
      OnMouseEnter = CoreTypeBoxMouseEnter
    end
    object MemoryBox: TComboBox
      Tag = 7
      Left = 87
      Top = 171
      Width = 145
      Height = 22
      Style = csOwnerDrawVariable
      ItemIndex = 0
      TabOrder = 0
      Text = 'Do not Increment I'
      OnChange = MemoryBoxChange
      OnMouseEnter = CoreTypeBoxMouseEnter
      Items.Strings = (
        'Do not Increment I'
        'Increment I by X'
        'Increment I by X+1')
    end
    object ShiftCheck: TCheckBox
      Tag = 2
      Left = 16
      Top = 50
      Width = 216
      Height = 17
      Caption = ' Shifting'
      TabOrder = 1
      OnMouseEnter = CoreTypeBoxMouseEnter
    end
    object ClipCheck: TCheckBox
      Tag = 3
      Left = 16
      Top = 73
      Width = 216
      Height = 17
      Caption = ' Clipping'
      TabOrder = 2
      OnMouseEnter = CoreTypeBoxMouseEnter
    end
    object JumpCheck: TCheckBox
      Tag = 4
      Left = 16
      Top = 96
      Width = 216
      Height = 17
      Caption = ' Jumping'
      TabOrder = 3
      OnMouseEnter = CoreTypeBoxMouseEnter
    end
    object DispWaitCheck: TCheckBox
      Tag = 5
      Left = 16
      Top = 119
      Width = 216
      Height = 17
      Caption = ' Display wait'
      TabOrder = 4
      OnMouseEnter = CoreTypeBoxMouseEnter
    end
    object VFResetCheck: TCheckBox
      Tag = 6
      Left = 16
      Top = 142
      Width = 216
      Height = 17
      Caption = ' VF Reset'
      TabOrder = 5
      OnMouseEnter = CoreTypeBoxMouseEnter
    end
    object SpeedEdit: TMaskEdit
      Tag = 8
      Left = 87
      Top = 202
      Width = 145
      Height = 21
      TabOrder = 6
      Text = '3668'
      OnMouseEnter = CoreTypeBoxMouseEnter
    end
    object CoreTypeBox: TComboBox
      Tag = 1
      Left = 87
      Top = 24
      Width = 145
      Height = 22
      Style = csOwnerDrawVariable
      TabOrder = 7
      OnChange = CoreTypeBoxChange
      OnMouseEnter = CoreTypeBoxMouseEnter
      Items.Strings = (
        'Cosmac VIP (Chip 8)'
        'Chip 8X'
        'Chip 48'
        'SuperChip 1.0'
        'SuperChip 1.1'
        'Modern SuperChip'
        'XO Chip'
        'MegaChip')
    end
  end
  object HelpBox: TGroupBox
    Left = 272
    Top = 14
    Width = 265
    Height = 236
    TabOrder = 1
    object HelpLabel: TLabel
      Left = 13
      Top = 8
      Width = 249
      Height = 193
      AutoSize = False
      WordWrap = True
    end
  end
  object CancelBtn: TButton
    Left = 462
    Top = 257
    Width = 75
    Height = 25
    Caption = 'Cancel'
    TabOrder = 2
    OnClick = CancelBtnClick
  end
  object OkayBtn: TButton
    Left = 381
    Top = 257
    Width = 75
    Height = 25
    Caption = 'Okay'
    Default = True
    TabOrder = 3
    OnClick = OkayBtnClick
  end
end
