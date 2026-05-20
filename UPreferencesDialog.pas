unit UPreferencesDialog;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// =============================================================================

// =============================================================================
//  UPreferencesDialog.pas  —  modal Preferences dialog
//
//  Phase 1: Appearance / Theme only.
//
//  Three options: Dark / Light / Follow Windows.
//  Live preview as you click each radio.  OK commits, Cancel reverts.
// =============================================================================

interface

procedure ShowPreferencesDialog;

implementation

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Vcl.Buttons, Vcl.Graphics, System.UITypes, Vcl.Dialogs,
  UTheme;

type
  TPrefsForm = class(TForm)
  private
    FPages    : TPageControl;
    FTabAppr  : TTabSheet;
    FGrp      : TGroupBox;
    FRBDark   : TRadioButton;
    FRBLight  : TRadioButton;
    FRBSys    : TRadioButton;
    FLblSys   : TLabel;
    FLblNote  : TLabel;
    FBtnOK    : TButton;
    FBtnCancel: TButton;
    FOrigMode : TThemeMode;
    procedure Build;
    procedure OnRadioChange(Sender: TObject);
    procedure OnOK(Sender: TObject);
    procedure OnCancel(Sender: TObject);
  public
    constructor CreatePrefs(AOwner: TComponent);
  end;

procedure ShowPreferencesDialog;
var Dlg : TPrefsForm;
begin
  Dlg := TPrefsForm.CreatePrefs(Application);
  try
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

constructor TPrefsForm.CreatePrefs(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption     := 'Preferences';
  Position    := poScreenCenter;
  Width       := 480;
  Height      := 400;
  BorderStyle := bsDialog;
  Font.Name   := 'Segoe UI';
  Font.Size   := 10;
  FOrigMode   := Theme.Mode;
  Build;
end;

procedure TPrefsForm.Build;
var
  SysLabel : string;
begin
  FPages              := TPageControl.Create(Self);
  FPages.Parent       := Self;
  FPages.Align        := alClient;

  FTabAppr             := TTabSheet.Create(FPages);
  FTabAppr.PageControl := FPages;
  FTabAppr.Caption     := '  Appearance  ';

  FGrp         := TGroupBox.Create(FTabAppr);
  FGrp.Parent  := FTabAppr;
  FGrp.Caption := ' Theme ';
  FGrp.Left    := 16;
  FGrp.Top     := 16;
  FGrp.Width   := 430;
  FGrp.Height  := 200;

  FRBDark         := TRadioButton.Create(FGrp);
  FRBDark.Parent  := FGrp;
  FRBDark.Caption := 'Dark  (Carbon)';
  FRBDark.Left    := 20;
  FRBDark.Top     := 32;
  FRBDark.Width   := 380;
  FRBDark.OnClick := OnRadioChange;

  FRBLight        := TRadioButton.Create(FGrp);
  FRBLight.Parent := FGrp;
  FRBLight.Caption := 'Light  (Iceberg Classico)';
  FRBLight.Left   := 20;
  FRBLight.Top    := 60;
  FRBLight.Width  := 380;
  FRBLight.OnClick := OnRadioChange;

  FRBSys          := TRadioButton.Create(FGrp);
  FRBSys.Parent   := FGrp;
  FRBSys.Caption  := 'Follow Windows setting';
  FRBSys.Left     := 20;
  FRBSys.Top      := 88;
  FRBSys.Width    := 380;
  FRBSys.OnClick  := OnRadioChange;

  if Theme.Current = tkLight then
    SysLabel := '(Windows is currently: Light)'
  else
    SysLabel := '(Windows is currently: Dark)';
  FLblSys             := TLabel.Create(FGrp);
  FLblSys.Parent      := FGrp;
  FLblSys.Caption     := SysLabel;
  FLblSys.Left        := 40;
  FLblSys.Top         := 112;
  FLblSys.Font.Color  := clGrayText;

  FLblNote             := TLabel.Create(FGrp);
  FLblNote.Parent      := FGrp;
  FLblNote.Caption     := 'Click an option to preview it. OK commits, Cancel reverts.';
  FLblNote.Left        := 20;
  FLblNote.Top         := 160;
  FLblNote.Font.Color  := clGrayText;
  FLblNote.Font.Style  := [];

  case Theme.Mode of
    tmDark          : FRBDark.Checked  := True;
    tmLight         : FRBLight.Checked := True;
    tmFollowWindows : FRBSys.Checked   := True;
  end;

  FBtnOK         := TButton.Create(Self);
  FBtnOK.Parent  := Self;
  FBtnOK.Caption := 'OK';
  FBtnOK.Width   := 96;
  FBtnOK.Height  := 30;
  FBtnOK.Anchors := [akRight, akBottom];
  FBtnOK.Left    := Self.ClientWidth - 210;
  FBtnOK.Top     := Self.ClientHeight - 42;
  FBtnOK.OnClick := OnOK;
  FBtnOK.Default := True;

  FBtnCancel         := TButton.Create(Self);
  FBtnCancel.Parent  := Self;
  FBtnCancel.Caption := 'Cancel';
  FBtnCancel.Width   := 96;
  FBtnCancel.Height  := 30;
  FBtnCancel.Anchors := [akRight, akBottom];
  FBtnCancel.Left    := Self.ClientWidth - 108;
  FBtnCancel.Top     := Self.ClientHeight - 42;
  FBtnCancel.OnClick := OnCancel;
  FBtnCancel.Cancel  := True;
end;

procedure TPrefsForm.OnRadioChange(Sender: TObject);
begin
  if FRBDark.Checked then
    Theme.SetMode(tmDark)
  else if FRBLight.Checked then
    Theme.SetMode(tmLight)
  else if FRBSys.Checked then
    Theme.SetMode(tmFollowWindows);
end;

procedure TPrefsForm.OnOK(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TPrefsForm.OnCancel(Sender: TObject);
begin
  if Theme.Mode <> FOrigMode then
    Theme.SetMode(FOrigMode);
  ModalResult := mrCancel;
end;

end.
