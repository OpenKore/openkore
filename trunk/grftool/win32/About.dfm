object AboutBox: TAboutBox
  Left = 647
  Top = 216
  BorderStyle = bsDialog
  Caption = 'About GRF Tool'
  ClientHeight = 96
  ClientWidth = 247
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 226
    Height = 24
    Caption = 'GRF Tool for Windows'
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -21
    Font.Name = 'Arial'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Label2: TLabel
    Left = 8
    Top = 32
    Width = 153
    Height = 13
    Caption = 'Version I'#39'm-Still-Working-On-This'
  end
  object BitBtn1: TBitBtn
    Left = 168
    Top = 64
    Width = 75
    Height = 25
    TabOrder = 0
    Kind = bkOK
  end
end
