unit UTheme;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// =============================================================================

// =============================================================================
//  UTheme.pas  —  Thin wrapper around VCL Styles (TStyleManager).
//
//  We previously implemented a hand-rolled theme palette. That worked but
//  needed every tab to call ApplyXxx() helpers, and the result still looked
//  amateur compared to a properly-designed styled application.
//
//  VCL Styles (built into Delphi) re-paints every control automatically
//  from a single named style. No per-control work, professional finish.
//
//  Modes
//  ─────
//     tmDark           — sets a dark style (Carbon, fallback Windows10 SlateGray)
//     tmLight          — sets a light style (Iceberg Classico, fallback Glossy)
//     tmFollowWindows  — reads AppsUseLightTheme registry; chooses dark/light
//
//  Style names tried (in order)
//  ────────────────────────────
//  Dark : 'Carbon', 'Windows10 SlateGray', 'Dark'
//  Light: 'Iceberg Classico', 'Glossy', 'Windows', ''
//
//  Empty string ('') resets to default Windows style.
//
//  Public API preserved
//  ────────────────────
//  Code that calls Theme.Mode, Theme.Subscribe, Theme.ApplyForm etc.
//  still compiles. The Apply* helpers are no-ops now — VCL Styles handles
//  every paint. We keep them so we don't have to delete calls everywhere.
//
//  Persistence
//  ───────────
//  Stored in <exe>.settings.ini as before.
// =============================================================================

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.IniFiles, System.IOUtils,
  System.Generics.Collections,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Graphics, Vcl.ComCtrls, Vcl.Grids, Vcl.Buttons,
  Vcl.Themes, Vcl.Styles;

type
  TThemeMode = (tmDark, tmLight, tmFollowWindows);
  TThemeKind = (tkDark, tkLight);

  TThemeListenerProc = procedure of object;

  TThemeManager = class
  private
    FMode         : TThemeMode;
    FCurrent      : TThemeKind;
    FAppliedStyle : string;
    FListeners    : TList<TThemeListenerProc>;
    FSettingsPath : string;
    FBlocked      : Boolean;

    procedure ApplyChosenStyle;
    function  DetectWindowsTheme : TThemeKind;
    procedure NotifyAll;
    function  StyleExists(const Name: string): Boolean;
    function  PickFirstAvailable(const Names: array of string): string;
  public
    constructor Create;
    destructor  Destroy; override;

    property Mode         : TThemeMode read FMode;
    property Current      : TThemeKind read FCurrent;
    property AppliedStyle : string     read FAppliedStyle;

    procedure SetMode(M: TThemeMode);
    procedure ReevaluateFromWindows;

    procedure Subscribe  (Proc: TThemeListenerProc);
    procedure Unsubscribe(Proc: TThemeListenerProc);

    procedure Load;
    procedure Save;

    // ── Apply helpers — kept as no-ops for compatibility.
    //    VCL Styles paints every control automatically.
    procedure ApplyForm        (F: TForm);
    procedure ApplyPanelBg     (P: TPanel);
    procedure ApplyPanelToolbar(P: TPanel);
    procedure ApplyPanelAlt    (P: TPanel);
    procedure ApplyPanelOutput (P: TPanel);
    procedure ApplyLabel       (L: TLabel; const Role: string = 'body');
    procedure ApplyMemoInput   (M: TMemo);
    procedure ApplyMemoOutput  (M: TMemo);
    procedure ApplyEditInput   (E: TEdit);
    procedure ApplyListBox     (LB: TListBox);
    procedure ApplyTreeView    (TV: TTreeView);
    procedure ApplyStringGrid  (G: TStringGrid);
    procedure ApplySplitter    (S: TSplitter);
    procedure ApplyButton      (B: TButton);
  end;

function Theme : TThemeManager;

const
  DARK_STYLE_CANDIDATES  : array[0..2] of string = (
    'Carbon', 'Windows10 SlateGray', 'Dark');
  LIGHT_STYLE_CANDIDATES : array[0..3] of string = (
    'Iceberg Classico', 'Glossy', 'Windows', '');

implementation

uses
  System.Win.Registry;

var
  GTheme : TThemeManager = nil;

function Theme : TThemeManager;
begin
  if GTheme = nil then
    GTheme := TThemeManager.Create;
  Result := GTheme;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  TThemeManager
// ═══════════════════════════════════════════════════════════════════════════

constructor TThemeManager.Create;
begin
  inherited Create;
  FListeners    := TList<TThemeListenerProc>.Create;
  FSettingsPath := ChangeFileExt(ParamStr(0), '.settings.ini');
  FBlocked      := False;
  FMode         := tmDark;
  FCurrent      := tkDark;
  FAppliedStyle := '';
end;

destructor TThemeManager.Destroy;
begin
  FListeners.Free;
  inherited;
end;

// ---------------------------------------------------------------------------
//  Windows-theme detection (registry)
// ---------------------------------------------------------------------------
function TThemeManager.DetectWindowsTheme: TThemeKind;
var
  Reg     : TRegistry;
  AppsLgt : Integer;
begin
  Result := tkDark;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(
         'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize') then
    begin
      try
        if Reg.ValueExists('AppsUseLightTheme') then
        begin
          AppsLgt := Reg.ReadInteger('AppsUseLightTheme');
          if AppsLgt <> 0 then Result := tkLight else Result := tkDark;
        end;
      finally
        Reg.CloseKey;
      end;
    end;
  finally
    Reg.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Style lookup
// ---------------------------------------------------------------------------
function TThemeManager.StyleExists(const Name: string): Boolean;
var SN : TArray<string>;
    S  : string;
begin
  if Name = '' then Exit(True);    // empty = default Windows, always works

  try
    SN := TStyleManager.StyleNames;
  except
    Exit(False);
  end;

  if Length(SN) = 0 then Exit(False);

  for S in SN do
    if SameText(S, Name) then Exit(True);
  Result := False;
end;

function TThemeManager.PickFirstAvailable(
  const Names: array of string): string;
var I : Integer;
begin
  for I := 0 to High(Names) do
    if StyleExists(Names[I]) then
      Exit(Names[I]);
  Result := '';
end;

// ---------------------------------------------------------------------------
//  Apply chosen style. Resolves dark/light, picks the first available
//  name, and tells VCL Styles to switch.
// ---------------------------------------------------------------------------
procedure TThemeManager.ApplyChosenStyle;
var
  Wanted : string;
begin
  // Resolve dark/light
  if FMode = tmFollowWindows then FCurrent := DetectWindowsTheme
  else if FMode = tmLight    then FCurrent := tkLight
  else                            FCurrent := tkDark;

  // Pick a style name that's actually installed
  case FCurrent of
    tkDark  : Wanted := PickFirstAvailable(DARK_STYLE_CANDIDATES);
    tkLight : Wanted := PickFirstAvailable(LIGHT_STYLE_CANDIDATES);
  end;

  if SameText(Wanted, FAppliedStyle) then Exit;   // already there

  try
    if Wanted = '' then
      TStyleManager.SetStyle(TStyleManager.SystemStyle)
    else
      TStyleManager.SetStyle(Wanted);
    FAppliedStyle := Wanted;
  except
    // If style application fails (e.g. TStyleManager not ready, or the
    // style isn't actually compiled in), fall back silently.  Better to
    // launch with system defaults than crash on startup.
    try
      TStyleManager.SetStyle(TStyleManager.SystemStyle);
      FAppliedStyle := '';
    except
      FAppliedStyle := '';
    end;
  end;
end;

procedure TThemeManager.SetMode(M: TThemeMode);
begin
  if M = FMode then Exit;
  FMode := M;
  ApplyChosenStyle;
  Save;
  NotifyAll;
end;

procedure TThemeManager.ReevaluateFromWindows;
var Prev : TThemeKind;
begin
  if FMode <> tmFollowWindows then Exit;
  Prev := FCurrent;
  ApplyChosenStyle;
  if FCurrent <> Prev then NotifyAll;
end;

procedure TThemeManager.NotifyAll;
var L : TThemeListenerProc;
begin
  if FBlocked then Exit;
  FBlocked := True;
  try
    for L in FListeners do
      try L; except end;
  finally
    FBlocked := False;
  end;
end;

procedure TThemeManager.Subscribe(Proc: TThemeListenerProc);
begin
  if FListeners.IndexOf(Proc) < 0 then FListeners.Add(Proc);
end;

procedure TThemeManager.Unsubscribe(Proc: TThemeListenerProc);
var Idx : Integer;
begin
  Idx := FListeners.IndexOf(Proc);
  if Idx >= 0 then FListeners.Delete(Idx);
end;

procedure TThemeManager.Load;
var
  Ini : TIniFile;
  S   : string;
begin
  if not TFile.Exists(FSettingsPath) then
  begin
    FMode := tmFollowWindows;
    ApplyChosenStyle;
    Exit;
  end;
  Ini := TIniFile.Create(FSettingsPath);
  try
    S := Ini.ReadString('Theme', 'Mode', 'FollowWindows');
    if      SameText(S, 'Light') then FMode := tmLight
    else if SameText(S, 'Dark')  then FMode := tmDark
    else                              FMode := tmFollowWindows;
  finally
    Ini.Free;
  end;
  ApplyChosenStyle;
end;

procedure TThemeManager.Save;
var
  Ini : TIniFile;
  S   : string;
begin
  case FMode of
    tmDark          : S := 'Dark';
    tmLight         : S := 'Light';
    tmFollowWindows : S := 'FollowWindows';
  end;
  Ini := TIniFile.Create(FSettingsPath);
  try
    Ini.WriteString('Theme', 'Mode', S);
  finally
    Ini.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  Apply helpers — no-ops.  VCL Styles repaints automatically.
// ═══════════════════════════════════════════════════════════════════════════
procedure TThemeManager.ApplyForm        (F: TForm);            begin end;
procedure TThemeManager.ApplyPanelBg     (P: TPanel);           begin end;
procedure TThemeManager.ApplyPanelToolbar(P: TPanel);           begin end;
procedure TThemeManager.ApplyPanelAlt    (P: TPanel);           begin end;
procedure TThemeManager.ApplyPanelOutput (P: TPanel);           begin end;
procedure TThemeManager.ApplyLabel(L: TLabel; const Role: string); begin end;
procedure TThemeManager.ApplyMemoInput   (M: TMemo);            begin end;
procedure TThemeManager.ApplyMemoOutput  (M: TMemo);            begin end;
procedure TThemeManager.ApplyEditInput   (E: TEdit);            begin end;
procedure TThemeManager.ApplyListBox     (LB: TListBox);        begin end;
procedure TThemeManager.ApplyTreeView    (TV: TTreeView);       begin end;
procedure TThemeManager.ApplyStringGrid  (G: TStringGrid);      begin end;
procedure TThemeManager.ApplySplitter    (S: TSplitter);        begin end;
procedure TThemeManager.ApplyButton      (B: TButton);          begin end;

initialization

finalization
  GTheme.Free;

end.
