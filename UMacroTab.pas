unit UMacroTab;

// =============================================================================
// MiniDelphi Toy Compiler & Learning IDE
// Copyright (C) 2026 Nomidor Software, LLC.
// GPL v3 — see https://www.gnu.org/licenses/gpl-3.0.html
// =============================================================================

// =============================================================================
//  UMacroTab.pas  -  Macros tab UI.
//
//  Macros live in:   %USERPROFILE%\Documents\MiniDelphi\Macros\
//  Each macro is a .mdp file with header metadata:
//
//      // @name        My Macro Name
//      // @description One-line description
//      // @category    Group it lives in
//
//  Features
//  ────────
//   • Tree of macros grouped by @category, with @name and @description
//   • Source editor for the selected macro
//   • Run / Stop / Save / New buttons
//   • Per-macro "Trusted" toggle: silently allows Shell* calls. When off,
//     each Shell* call prompts the user for confirmation.
//   • First-run seeding from UMacroLibrary
// =============================================================================

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.IOUtils, System.IniFiles,
  System.Generics.Collections,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Graphics, Vcl.ComCtrls, Vcl.Dialogs, Vcl.Menus,
  System.UITypes,
  ULexer, UParser, UAST, UInterpreter, UMacroLibrary,System.Math,Winapi.ShellAPI;

type
  // ---------------------------------------------------------------------------
  //  Parsed macro metadata
  // ---------------------------------------------------------------------------
  TMacroInfo = class
  public
    FilePath    : string;     // full disk path
    DisplayName : string;     // from @name, or filename if absent
    Description : string;     // from @description
    Category    : string;     // from @category, default 'Uncategorised'
    Trusted     : Boolean;    // stored in trusted.ini
    constructor Create(const APath: string);
  end;

  TMacroList = TObjectList<TMacroInfo>;

  TMacroTab = class
  private
    FParent     : TWinControl;
    FMacroDir   : string;
    FTrustedIni : string;
    FMacros     : TMacroList;
    FCurrent    : TMacroInfo;
    FInterp     : TInterpreter;
    FModified   : Boolean;

    // UI
    FOuter      : TPanel;
    FToolBar    : TPanel;
    FBtnNew     : TButton;
    FBtnSave    : TButton;
    FBtnRun     : TButton;
    FBtnStop    : TButton;
    FBtnDelete  : TButton;
    FBtnOpenFolder : TButton;
    FBtnReseed  : TButton;
    FChkTrust   : TCheckBox;
    FLblStatus  : TLabel;

    FLeftPanel  : TPanel;
    FTree       : TTreeView;
    FSplitter   : TSplitter;

    FRightPanel : TPanel;
    FLblDesc    : TLabel;
    FEditor     : TMemo;
    FSplitVert  : TSplitter;
    FLblOut     : TLabel;
    FOutput     : TMemo;

    // ── Helpers ──────────────────────────────────────────────────────────
    procedure BuildUI;
    procedure EnsureMacroFolder;
    procedure LoadMacros;
    procedure BuildTree;
    procedure SaveTrustedFlags;
    procedure LoadTrustedFlags;
    procedure SelectMacro(M: TMacroInfo);
    function  ConfirmDiscard : Boolean;

    // Shell confirmation callback for the interpreter
    function  OnShellConfirm(const Cmd: string) : Boolean;

    // Event handlers
    procedure OnNew(Sender: TObject);
    procedure OnSave(Sender: TObject);
    procedure OnRun(Sender: TObject);
    procedure OnStop(Sender: TObject);
    procedure OnDelete(Sender: TObject);
    procedure OnOpenFolder(Sender: TObject);
    procedure OnReseed(Sender: TObject);
    procedure OnTrustChanged(Sender: TObject);
    procedure OnTreeDblClick(Sender: TObject);
    procedure OnTreeChange(Sender: TObject; Node: TTreeNode);
    procedure OnEditorChange(Sender: TObject);

  public
    constructor Create(AParent: TWinControl);
    destructor  Destroy; override;
  end;

// =============================================================================
implementation
// =============================================================================

const
  DARK    = $00252526;
  DARKER  = $001E1E1E;
  GREEN   = $0056D364;

  NEW_MACRO_TEMPLATE =
    '// @name        New Macro' + #13#10 +
    '// @description Describe what this macro does' + #13#10 +
    '// @category    My Macros' + #13#10 +
    '' + #13#10 +
    '// ============================================================' + #13#10 +
    '// NEW MACRO' + #13#10 +
    '// Replace this with what your macro does.' + #13#10 +
    '// ============================================================' + #13#10 +
    '' + #13#10 +
    'begin' + #13#10 +
    '  ShowMessage(''Hello from my new macro!'');' + #13#10 +
    'end.';

// ═══════════════════════════════════════════════════════════════════════════
//  TMacroInfo
// ═══════════════════════════════════════════════════════════════════════════

constructor TMacroInfo.Create(const APath: string);
var
  Lines : TStringList;
  S, V  : string;
  Lo    : string;
  I     : Integer;
  P     : Integer;

  function ExtractTag(const Line, Tag: string): string;
  var
    Idx : Integer;
  begin
    Idx := Pos(LowerCase(Tag), LowerCase(Line));
    if Idx > 0 then
      Result := Trim(Copy(Line, Idx + Length(Tag), MaxInt))
    else
      Result := '';
  end;

begin
  inherited Create;
  FilePath    := APath;
  DisplayName := ChangeFileExt(ExtractFileName(APath), '');
  Description := '';
  Category    := 'Uncategorised';
  Trusted     := False;

  if not TFile.Exists(APath) then Exit;

  Lines := TStringList.Create;
  try
    try
      Lines.LoadFromFile(APath, TEncoding.UTF8);
    except
      Exit;
    end;

    // Only scan the first 30 lines for header tags
    for I := 0 to Min(Lines.Count - 1, 29) do
    begin
      S  := Lines[I];
      Lo := LowerCase(S);
      // Stop scanning once we hit the first non-comment, non-blank line
      P := Pos('//', S);
      if (Trim(S) <> '') and (P = 0) then Break;

      V := ExtractTag(S, '@name');
      if V <> '' then DisplayName := V;
      V := ExtractTag(S, '@description');
      if V <> '' then Description := V;
      V := ExtractTag(S, '@category');
      if V <> '' then Category := V;
    end;
  finally
    Lines.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  TMacroTab
// ═══════════════════════════════════════════════════════════════════════════

constructor TMacroTab.Create(AParent: TWinControl);
begin
  inherited Create;
  FParent   := AParent;
  FMacros   := TMacroList.Create(True);
  FCurrent  := nil;
  FInterp   := nil;
  FModified := False;

  EnsureMacroFolder;
  BuildUI;
  LoadTrustedFlags;
  LoadMacros;
  BuildTree;

  FLblStatus.Caption := Format('  %d macros loaded from %s',
                                [FMacros.Count, FMacroDir]);
end;

destructor TMacroTab.Destroy;
begin
  SaveTrustedFlags;
  FMacros.Free;
  inherited;
end;

// ---------------------------------------------------------------------------
//  Make sure the macro folder exists; seed it on first run
// ---------------------------------------------------------------------------
procedure TMacroTab.EnsureMacroFolder;
var
  Docs    : string;
  Existing: TArray<string>;
  Count   : Integer;
begin
  Docs      := GetEnvironmentVariable('USERPROFILE') + '\Documents\MiniDelphi\Macros';
  FMacroDir := Docs;
  if not TDirectory.Exists(FMacroDir) then
    TDirectory.CreateDirectory(FMacroDir);

  FTrustedIni := TPath.Combine(FMacroDir, 'trusted.ini');

  // First run: seed if folder is empty
  Existing := TDirectory.GetFiles(FMacroDir, '*.mdp');
  if Length(Existing) = 0 then
  begin
    Count := SeedMacroFolder(FMacroDir);
    if Count > 0 then
      MessageDlg(Format(
        'Welcome! %d starter macros were copied to:' + sLineBreak + sLineBreak +
        '%s' + sLineBreak + sLineBreak +
        'You can edit them, delete them, or use them as templates.',
        [Count, FMacroDir]), mtInformation, [mbOK], 0);
  end;
end;

// ---------------------------------------------------------------------------
//  Load every *.mdp from the macro folder
// ---------------------------------------------------------------------------
procedure TMacroTab.LoadMacros;
var
  Files : TArray<string>;
  F     : string;
  M     : TMacroInfo;
  Ini   : TIniFile;
begin
  FMacros.Clear;
  Files := TDirectory.GetFiles(FMacroDir, '*.mdp');

  Ini := TIniFile.Create(FTrustedIni);
  try
    for F in Files do
    begin
      M := TMacroInfo.Create(F);
      M.Trusted := Ini.ReadBool('Trusted', ExtractFileName(F), False);
      FMacros.Add(M);
    end;
  finally
    Ini.Free;
  end;
end;

procedure TMacroTab.LoadTrustedFlags;
begin
  // Loading happens inside LoadMacros (per file); this is a stub for symmetry
end;

procedure TMacroTab.SaveTrustedFlags;
var
  Ini : TIniFile;
  M   : TMacroInfo;
begin
  Ini := TIniFile.Create(FTrustedIni);
  try
    Ini.EraseSection('Trusted');
    for M in FMacros do
      Ini.WriteBool('Trusted', ExtractFileName(M.FilePath), M.Trusted);
  finally
    Ini.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Build the category → macro tree
// ---------------------------------------------------------------------------
procedure TMacroTab.BuildTree;
var
  Cats     : TStringList;
  CatNode  : TTreeNode;
  C        : string;
  M        : TMacroInfo;
  MNode    : TTreeNode;
  I        : Integer;
begin
  FTree.Items.BeginUpdate;
  try
    FTree.Items.Clear;
    Cats := TStringList.Create;
    try
      Cats.Sorted    := True;
      Cats.Duplicates := dupIgnore;
      for M in FMacros do
        Cats.Add(M.Category);

      for I := 0 to Cats.Count - 1 do
      begin
        C := Cats[I];
        CatNode := FTree.Items.Add(nil, C);
        CatNode.Data := nil;

        for M in FMacros do
          if M.Category = C then
          begin
            MNode      := FTree.Items.AddChild(CatNode, M.DisplayName);
            MNode.Data := M;
          end;
        CatNode.Expand(False);
      end;
    finally
      Cats.Free;
    end;
  finally
    FTree.Items.EndUpdate;
  end;
end;

// ---------------------------------------------------------------------------
//  Build the entire UI
// ---------------------------------------------------------------------------
procedure TMacroTab.BuildUI;
const
  BW  = 86;
  BH  = 28;
  PAD = 6;

  procedure Btn(var B: TButton; Parent: TWinControl;
                const Cap: string; var X: Integer; H: TNotifyEvent;
                const Hint: string = '');
  begin
    B          := TButton.Create(Parent);
    B.Parent   := Parent;
    B.Caption  := Cap;
    B.Left     := X; B.Top := PAD;
    B.Width    := BW; B.Height := BH;
    B.OnClick  := H;
    B.Hint     := Hint;
    B.ShowHint := Hint <> '';
    Inc(X, BW + PAD);
  end;

var
  X : Integer;
begin
  if FParent = nil then
    raise Exception.Create('TMacroTab requires a non-nil parent');

  FOuter            := TPanel.Create(FParent);
  FOuter.Parent     := FParent;
  FOuter.Align      := alClient;
  FOuter.BevelOuter := bvNone;
  FOuter.Color      := DARKER;

  // Toolbar
  FToolBar            := TPanel.Create(FOuter);
  FToolBar.Parent     := FOuter;
  FToolBar.Align      := alTop;
  FToolBar.Height     := BH + PAD * 2;
  FToolBar.BevelOuter := bvNone;
  FToolBar.Color      := $00303030;

  X := PAD;
  Btn(FBtnNew,        FToolBar, 'New',      X, OnNew,        'Create a new macro');
  Btn(FBtnSave,       FToolBar, 'Save',     X, OnSave,       'Save current macro');
  Btn(FBtnRun,        FToolBar, 'Run',      X, OnRun,        'Run selected macro  (F5)');
  Btn(FBtnStop,       FToolBar, 'Stop',     X, OnStop,       'Stop running macro');
  Btn(FBtnDelete,     FToolBar, 'Delete',   X, OnDelete,     'Delete selected macro');
  Inc(X, PAD);
  Btn(FBtnOpenFolder, FToolBar, 'Folder',   X, OnOpenFolder, 'Open macro folder in Explorer');
  Btn(FBtnReseed,     FToolBar, 'Restore',  X, OnReseed,     'Restore missing starter macros');

  FChkTrust            := TCheckBox.Create(FToolBar);
  FChkTrust.Parent     := FToolBar;
  FChkTrust.Caption    := 'Trusted (silent shell)';
  FChkTrust.Left       := X + PAD;
  FChkTrust.Top        := PAD + 5;
  FChkTrust.Width      := 160;
  FChkTrust.Font.Color := clSilver;
  FChkTrust.OnClick    := OnTrustChanged;
  FChkTrust.Enabled    := False;
  FChkTrust.Hint       := 'When ticked, Shell calls run silently. When off, each Shell call asks for permission.';
  FChkTrust.ShowHint   := True;
  Inc(X, 170);

  FLblStatus            := TLabel.Create(FToolBar);
  FLblStatus.Parent     := FToolBar;
  FLblStatus.Left       := X + PAD;
  FLblStatus.Top        := PAD + 7;
  FLblStatus.Width      := 500;
  FLblStatus.Font.Color := clSilver;

  // Left panel: tree
  FLeftPanel              := TPanel.Create(FOuter);
  FLeftPanel.Parent       := FOuter;
  FLeftPanel.Align        := alLeft;
  FLeftPanel.Width        := 260;
  FLeftPanel.BevelOuter   := bvNone;
  FLeftPanel.Color        := DARK;

  FTree                   := TTreeView.Create(FLeftPanel);
  FTree.Parent            := FLeftPanel;
  FTree.Align             := alClient;
  FTree.ReadOnly          := True;
  FTree.Color             := DARK;
  FTree.Font.Color        := clSilver;
  FTree.HideSelection     := False;
  FTree.Indent            := 14;
  FTree.OnDblClick        := OnTreeDblClick;
  FTree.OnChange          := OnTreeChange;

  FSplitter        := TSplitter.Create(FOuter);
  FSplitter.Parent := FOuter;
  FSplitter.Align  := alLeft;
  FSplitter.Width  := 4;

  // Right side: editor + output
  FRightPanel            := TPanel.Create(FOuter);
  FRightPanel.Parent     := FOuter;
  FRightPanel.Align      := alClient;
  FRightPanel.BevelOuter := bvNone;
  FRightPanel.Color      := DARKER;

  FLblDesc               := TLabel.Create(FRightPanel);
  FLblDesc.Parent        := FRightPanel;
  FLblDesc.Align         := alTop;
  FLblDesc.Height        := 22;
  FLblDesc.Caption       := '  Select a macro from the list';
  FLblDesc.Font.Color    := GREEN;
  FLblDesc.Font.Style    := [fsBold];

  FEditor                := TMemo.Create(FRightPanel);
  FEditor.Parent         := FRightPanel;
  FEditor.Align          := alTop;
  FEditor.Height         := 360;
  FEditor.WordWrap       := False;
  FEditor.ScrollBars     := ssBoth;
  FEditor.Font.Name      := 'Consolas';
  FEditor.Font.Size      := 10;
  FEditor.Color          := DARKER;
  FEditor.Font.Color     := $00DCDCDC;
  FEditor.OnChange       := OnEditorChange;

  FSplitVert        := TSplitter.Create(FRightPanel);
  FSplitVert.Parent := FRightPanel;
  FSplitVert.Align  := alTop;
  FSplitVert.Height := 4;

  FLblOut            := TLabel.Create(FRightPanel);
  FLblOut.Parent     := FRightPanel;
  FLblOut.Align      := alTop;
  FLblOut.Height     := 20;
  FLblOut.Caption    := '  Output';
  FLblOut.Font.Color := GREEN;

  FOutput            := TMemo.Create(FRightPanel);
  FOutput.Parent     := FRightPanel;
  FOutput.Align      := alClient;
  FOutput.ReadOnly   := True;
  FOutput.WordWrap   := False;
  FOutput.ScrollBars := ssBoth;
  FOutput.Font.Name  := 'Consolas';
  FOutput.Font.Size  := 9;
  FOutput.Color      := $00121212;
  FOutput.Font.Color := GREEN;
end;

// ---------------------------------------------------------------------------
//  Macro selection
// ---------------------------------------------------------------------------
procedure TMacroTab.SelectMacro(M: TMacroInfo);
begin
  if not ConfirmDiscard then Exit;
  FCurrent := M;
  FModified := False;
  if Assigned(M) then
  begin
    FEditor.Lines.LoadFromFile(M.FilePath);
    FLblDesc.Caption := '  ' + M.DisplayName + '  —  ' + M.Description;
    FChkTrust.Enabled := True;
    FChkTrust.Checked := M.Trusted;
  end
  else
  begin
    FEditor.Clear;
    FLblDesc.Caption := '  Select a macro from the list';
    FChkTrust.Enabled := False;
    FChkTrust.Checked := False;
  end;
end;

function TMacroTab.ConfirmDiscard: Boolean;
begin
  if not FModified then begin Result := True; Exit; end;
  Result := MessageDlg('Discard unsaved changes to current macro?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

// ---------------------------------------------------------------------------
//  Shell confirmation callback (used by interpreter when macro is untrusted)
// ---------------------------------------------------------------------------
function TMacroTab.OnShellConfirm(const Cmd: string): Boolean;
var
  Res : Integer;
  Msg : string;
begin
  // If macro is marked trusted, allow without asking
  if Assigned(FCurrent) and FCurrent.Trusted then
  begin
    Result := True;
    Exit;
  end;

  Msg := 'This macro wants to run the following command:' + sLineBreak +
         sLineBreak +
         '    ' + Cmd + sLineBreak +
         sLineBreak +
         'Allow this and any further Shell calls from this macro?';

  Res := MessageDlg(Msg, mtConfirmation,
                    [mbYes, mbNo, mbYesToAll], 0);
  case Res of
    mrYes      : Result := True;
    mrYesToAll : begin
                   Result := True;
                   // Mark this macro trusted for future runs too
                   if Assigned(FCurrent) then
                   begin
                     FCurrent.Trusted := True;
                     FChkTrust.Checked := True;
                     SaveTrustedFlags;
                   end;
                 end;
  else
    Result := False;
  end;
end;

// ---------------------------------------------------------------------------
//  EVENT HANDLERS
// ---------------------------------------------------------------------------

procedure TMacroTab.OnNew(Sender: TObject);
var
  Name, Path : string;
  M          : TMacroInfo;
begin
  if not ConfirmDiscard then Exit;
  Name := InputBox('New macro', 'File name (without .mdp):', 'MyMacro');
  if Name = '' then Exit;

  Path := TPath.Combine(FMacroDir, Name + '.mdp');
  if TFile.Exists(Path) then
  begin
    ShowMessage('A macro with that name already exists.');
    Exit;
  end;

  TFile.WriteAllText(Path, NEW_MACRO_TEMPLATE, TEncoding.UTF8);

  // Refresh
  M := TMacroInfo.Create(Path);
  FMacros.Add(M);
  BuildTree;
  SelectMacro(M);
  FLblStatus.Caption := '  New macro created.';
end;

procedure TMacroTab.OnSave(Sender: TObject);
begin
  if FCurrent = nil then Exit;
  TFile.WriteAllText(FCurrent.FilePath, FEditor.Lines.Text, TEncoding.UTF8);
  // Reparse metadata in case the user edited @name etc
  FreeAndNil(FCurrent);
  // Note: FCurrent was owned by FMacros, so don't free it here — re-create instead
  FModified := False;
  // Reload everything to pick up metadata changes
  LoadMacros;
  BuildTree;
  FLblStatus.Caption := '  Saved.';
end;

procedure TMacroTab.OnRun(Sender: TObject);
var
  Lex  : TLexer;
  Par  : TParser;
  Prog : TProgramNode;
  T0   : Cardinal;
begin
  if FCurrent = nil then
  begin
    ShowMessage('Select a macro to run first.');
    Exit;
  end;
  if Assigned(FInterp) then Exit;  // already running

  FOutput.Clear;
  FOutput.Lines.Add('Running ' + FCurrent.DisplayName + '...');
  T0 := GetTickCount;

  try
    Lex := TLexer.Create(FEditor.Lines.Text);
    try
      Lex.Tokenise;
      Par := TParser.Create(Lex.Tokens);
      try
        Prog := Par.Parse;
        try
          FInterp := TInterpreter.Create(Prog, FOutput.Lines);
          try
            FOutput.Lines.Clear;
            FInterp.SourceText  := FEditor.Lines.Text;
            FInterp.SourcePath  := FMacroDir;
            FInterp.AllowShell  := True;
            FInterp.ShellConfirm := OnShellConfirm;
            FInterp.Run;
            FOutput.Lines.Add('');
            FOutput.Lines.Add(Format('─── Done  (%d ms) ───',
                                     [GetTickCount - T0]));
          finally
            FInterp.Free;
            FInterp := nil;
          end;
        finally
          Prog.Free;
        end;
      finally
        Par.Free;
      end;
    finally
      Lex.Free;
    end;
  except
    on E: Exception do
    begin
      FOutput.Lines.Add('');
      FOutput.Lines.Add('*** ' + E.Message);
    end;
  end;
end;

procedure TMacroTab.OnStop(Sender: TObject);
begin
  if Assigned(FInterp) then
    FInterp.RequestStop;
end;

procedure TMacroTab.OnDelete(Sender: TObject);
var
  M : TMacroInfo;
begin
  if FCurrent = nil then Exit;
  if MessageDlg('Delete "' + FCurrent.DisplayName + '" permanently?',
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  M := FCurrent;
  try
    TFile.Delete(M.FilePath);
  except
    on E: Exception do
    begin
      ShowMessage('Could not delete: ' + E.Message);
      Exit;
    end;
  end;

  FCurrent := nil;
  FMacros.Remove(M);     // OwnsObjects=True frees it
  BuildTree;
  FEditor.Clear;
  FLblDesc.Caption := '  Select a macro from the list';
  FChkTrust.Enabled := False;
  FLblStatus.Caption := '  Macro deleted.';
end;

procedure TMacroTab.OnOpenFolder(Sender: TObject);
begin
  ShellExecute(0, 'open', PChar(FMacroDir), nil, nil, SW_SHOWNORMAL);
end;

procedure TMacroTab.OnReseed(Sender: TObject);
var
  Count : Integer;
begin
  Count := SeedMacroFolder(FMacroDir);
  if Count > 0 then
  begin
    LoadMacros;
    BuildTree;
    ShowMessage(Format('Restored %d starter macros.', [Count]));
  end
  else
    ShowMessage('All starter macros are already present.');
end;

procedure TMacroTab.OnTrustChanged(Sender: TObject);
begin
  if FCurrent = nil then Exit;
  FCurrent.Trusted := FChkTrust.Checked;
  SaveTrustedFlags;
end;

procedure TMacroTab.OnTreeChange(Sender: TObject; Node: TTreeNode);
begin
  if Assigned(Node) and Assigned(Node.Data) then
    SelectMacro(TMacroInfo(Node.Data))
  else
    SelectMacro(nil);
end;

procedure TMacroTab.OnTreeDblClick(Sender: TObject);
begin
  if Assigned(FCurrent) then OnRun(Sender);
end;

procedure TMacroTab.OnEditorChange(Sender: TObject);
begin
  FModified := True;
end;

// Local helper used by EnsureMacroFolder
function Min(A, B: Integer): Integer;
begin
  if A < B then Result := A else Result := B;
end;

end.
