object MainForm: TMainForm
  Left = 0
  Top = 0
  AlphaBlendValue = 0
  Caption = 'ZX-Chip8'
  ClientHeight = 208
  ClientWidth = 400
  Color = clMedGray
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnKeyUp = FormKeyUp
  OnShow = FormShow
  DesignSize = (
    400
    208)
  PixelsPerInch = 96
  TextHeight = 13
  object BuzzerShape: TShape
    Left = 0
    Top = 0
    Width = 401
    Height = 209
    Anchors = [akLeft, akTop, akRight, akBottom]
    Brush.Color = clMedGray
    Pen.Style = psClear
  end
  object DisplayPanel: TPanel
    Left = 8
    Top = 8
    Width = 384
    Height = 192
    Anchors = [akLeft, akTop, akRight, akBottom]
    BevelEdges = []
    BevelOuter = bvNone
    FullRepaint = False
    ParentBackground = False
    ParentColor = True
    ShowCaption = False
    TabOrder = 0
    OnResize = DisplayPanelResize
  end
  object OpenDialog: TOpenDialog
    Filter = 'All Files|*.*'
    Options = [ofEnableSizing, ofDontAddToRecent]
    Title = 'Open Chip 8 ROM image'
    Left = 136
    Top = 16
  end
  object MainMenu: TMainMenu
    Left = 80
    Top = 16
    object File1: TMenuItem
      Caption = 'File'
      object Chip8Model1: TMenuItem
        Caption = 'Chip8 Model'
      end
      object N2: TMenuItem
        Caption = '-'
      end
      object menuOpen: TMenuItem
        Caption = 'Open ROM image...'
        OnClick = menuOpenClick
      end
      object menuRecentfiles: TMenuItem
        Caption = 'Recent files'
      end
      object Browser1: TMenuItem
        Caption = 'Browser'
        OnClick = Browser1Click
      end
      object menuReset: TMenuItem
        Caption = 'Reset'
        OnClick = menuResetClick
      end
      object N1: TMenuItem
        Caption = '-'
      end
      object menuExit: TMenuItem
        Caption = 'Exit'
        OnClick = menuExitClick
      end
    end
  end
end
