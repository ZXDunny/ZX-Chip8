object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'ZX-Chip8'
  ClientHeight = 208
  ClientWidth = 400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu
  OldCreateOrder = False
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
  object DisplayPanel: TPanel
    Left = 8
    Top = 8
    Width = 384
    Height = 192
    Anchors = [akLeft, akTop, akRight, akBottom]
    BevelEdges = []
    BevelOuter = bvNone
    FullRepaint = False
    ShowCaption = False
    TabOrder = 0
    OnResize = DisplayPanelResize
  end
  object DisplayTimer: TTimer
    Interval = 1
    OnTimer = DisplayTimerTimer
    Left = 16
    Top = 16
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
      object menuOpen: TMenuItem
        Caption = 'Open ROM image...'
        OnClick = menuOpenClick
      end
      object menuRecentfiles: TMenuItem
        Caption = 'Recent files'
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
