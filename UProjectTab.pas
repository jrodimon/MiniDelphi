unit UProjectTab;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  UProjectTab.pas  —  Project IDE tab for MiniDelphi  (Delphi-style)
//
//  Project model
//  ─────────────
//  The .mdproj file IS the project. Its [Source] section holds the main
//  program source. There is NO separate "main .mdp" file — the project
//  source lives inside the .mdproj itself (like a Delphi .dpr).
//
//  The .mdproj also has a [Files] section listing library .mdp files
//  used by the project. Paths are stored relative to the .mdproj so
//  projects are portable.
//
//  Example .mdproj:
//
//      [Project]
//      Name=MyApp
//      Created=2026-05-15
//
//      [Files]
//      Count=2
//      File0=StringLib.mdp
//      File1=Helpers\Math.mdp
//
//      [Source]
//      uses
//        'StringLib.mdp';
//      begin
//        writeln('Hello!');
//      end.
//
//  Toolbar
//  ───────
//  Run / Stop / Insert only. All file operations are reached via the
//  main form's File menu, which calls into this tab's public Do*
//  methods. Right-click the tree for project-level operations.
//
//  Public API for menu integration
//  ───────────────────────────────
//    DoNewFile, DoOpenFile, DoSave, DoSaveAs
//    DoNewProject, DoOpenProject, DoCloseProject
//    DoRun
//    ViewProjectSource
//    HasProject      — read-only flag
// =============================================================================

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.IniFiles, System.IOUtils,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Graphics, Vcl.ComCtrls, Vcl.Buttons, Vcl.Menus, Vcl.Dialogs,
  System.UITypes,
  ULexer, UParser, UAST, UInterpreter,
  UExampleProjects, UTheme;

type
  // ---------------------------------------------------------------------------
  //  Recent files list (persisted in INI)
  // ---------------------------------------------------------------------------
  TRecentFiles = class
  private
    FList : TStringList;
    FPath : string;
    const MAX = 10;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   Add(const Path: string);
    procedure   Load;
    procedure   Save;
    property    Files : TStringList read FList;
  end;

  TSnippet = record
    Name         : string;
    Body         : string;
    CaretFromEnd : Integer;
  end;

  // ---------------------------------------------------------------------------
  //  What's currently in the editor
  // ---------------------------------------------------------------------------
  TEditMode = (emProjectSource, emProjectFile, emStandalone);

  // ---------------------------------------------------------------------------
  // Tree node Data encoding (NativeInt cast):
  //   -1                    = "Recent Files" root
  //   -2                    = "Example Projects" root
  //   -3                    = example category folder
  //   -4                    = "Project: X" root
  //   -5                    = the project source pseudo-node
  //   -99                   = placeholder
  //   -(100 + recentIdx)    = a recent file entry
  //   -(200 + projFileIdx)  = a project library file entry
  //    >= 0                 = index into FExamples.Items
  // ---------------------------------------------------------------------------

  TProjectTab = class
  private
    FParent       : TWinControl;
    FExamples     : TExampleLibrary;
    FRecent       : TRecentFiles;

    // State
    FCurrentFile  : string;
    FEditMode     : TEditMode;
    FProjectFile  : string;
    FProjectName  : string;
    FProjectFiles : TStringList;
    FModified     : Boolean;

    // UI
    FOuterPanel     : TPanel;

    // Trimmed toolbar — Run/Stop/Insert only
    FToolBar        : TPanel;
    FBtnRun         : TButton;
    FBtnStop        : TButton;
    FLabelFile      : TLabel;

    FLeftPanel      : TPanel;
    FSplitter       : TSplitter;
    FTree           : TTreeView;
    FLabelTree      : TLabel;

    FRightPanel     : TPanel;
    FEditorLabel    : TLabel;
    FEditor         : TMemo;
    FSplitVert      : TSplitter;
    FOutputLabel    : TLabel;
    FOutput         : TMemo;

    FNodeProject    : TTreeNode;
    FNodeProjSrc    : TTreeNode;
    FNodeRecent     : TTreeNode;
    FNodeExamples   : TTreeNode;

    FSnippetMenu    : TPopupMenu;
    FProjFileMenu   : TPopupMenu;
    FProjRootMenu   : TPopupMenu;
    FProjMenuTargetPath : string;

    FInterp         : TInterpreter;

    // Optional callback fired when a project is opened, created, or closed.
    // The main form uses this to push the project folder to the Forms tab.
    FOnProjectChanged : TNotifyEvent;

    // ── Helpers ──────────────────────────────────────────────────────────────
    procedure BuildUI;
    procedure BuildTree;
    procedure ApplyTheme;
    procedure BuildSnippetMenu;
    procedure BuildProjectFileMenu;
    procedure RefreshRecentNode;
    procedure RefreshProjectNode;

    procedure UpdateTitleBar;
    procedure UpdateEditorLabel;
    procedure SetModified(Val: Boolean);
    function  IsProjectOpen : Boolean;

    procedure LoadProjectFromIni(const ProjPath: string);
    procedure SaveProjectIni;
    procedure SaveProjectSourceToIni;
    function  ReadProjectSource : string;
    function  ProjectRelPath(const FullPath: string): string;
    function  ProjectAbsPath(const RelPath: string): string;
    function  IsInProjectFolder(const Path: string): Boolean;
    procedure AddFileToProject(const Path: string);
    procedure RemoveFileFromProject(const Path: string);

    function  ConfirmDiscard : Boolean;
    procedure LoadProjectFile(const Path: string);
    procedure LoadStandaloneFile(const Path: string);
    procedure LoadProjectSourceIntoEditor;
    procedure SaveCurrentBuffer;
    procedure RunProjectSource;
    procedure RunStandaloneEditor;
    procedure InsertSnippet(const Body: string; CaretFromEnd: Integer);

    // Internal event handlers
    procedure OnRunBtn      (Sender: TObject);
    procedure OnStopBtn     (Sender: TObject);
    procedure OnSnippetClick(Sender: TObject);
    procedure OnTreeDblClick(Sender: TObject);
    procedure OnTreeMouseDown(Sender: TObject; Button: TMouseButton;
                              Shift: TShiftState; X, Y: Integer);
    procedure OnEditorChange(Sender: TObject);
    procedure OnEditorKey   (Sender: TObject; var Key: Word; Shift: TShiftState);

    // Right-click menu actions
    procedure OnProjMenuNewFile     (Sender: TObject);
    procedure OnProjMenuAddExisting (Sender: TObject);
    procedure OnProjMenuOpen        (Sender: TObject);
    procedure OnProjMenuRename      (Sender: TObject);
    procedure OnProjMenuRemove      (Sender: TObject);
    procedure OnProjMenuDelete      (Sender: TObject);

  public
    constructor Create(AParent: TWinControl);
    destructor  Destroy; override;

    // ── Public API called by the main form's File menu ───────────────────────
    procedure DoNewFile;
    procedure DoOpenFile;
    procedure DoSave;
    procedure DoSaveAs;
    procedure DoNewProject;
    procedure DoOpenProject;
    procedure DoCloseProject;
    procedure DoAddExistingFile;
    procedure DoRun;
    procedure ViewProjectSource;

    property CurrentFile : string  read FCurrentFile;
    property Modified    : Boolean read FModified;
    property HasProject  : Boolean read IsProjectOpen;
    property ProjectFile : string  read FProjectFile;
    property ProjectName : string  read FProjectName;
    property OnProjectChanged : TNotifyEvent read FOnProjectChanged
                                             write FOnProjectChanged;
  end;

// =============================================================================
implementation
// =============================================================================

const
  MDP_FILTER   = 'MiniDelphi Source|*.mdp|All Files|*.*';
  MPROJ_FILTER = 'MiniDelphi Project|*.mdproj|All Files|*.*';
  MDP_EXT      = 'mdp';
  MPROJ_EXT    = 'mdproj';

  function NewProjectSource(const ProjName: string) : string;
  begin
    Result :=
      '// ============================================================' + #13#10 +
      '// ' + UpperCase(ProjName) + #13#10 +
      '// Project: ' + ProjName + #13#10 +
      '// Created: ' + DateToStr(Now) + #13#10 +
      '// ============================================================' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  writeln(''Hello from ' + ProjName + '!'');' + #13#10 +
      'end.';
  end;

const
  NEW_SOURCE =
    '// ============================================================' + #13#10 +
    '// NEW MINIDELPHI PROGRAM' + #13#10 +
    '// ============================================================' + #13#10 +
    '' + #13#10 +
    'begin' + #13#10 +
    '  writeln(''Hello, MiniDelphi!'');' + #13#10 +
    'end.';

  NEW_LIBRARY_SOURCE =
    '// ============================================================' + #13#10 +
    '// LIBRARY UNIT' + #13#10 +
    '// Declarations only — no main begin..end block.' + #13#10 +
    '// Import in a main program with:' + #13#10 +
    '//     uses' + #13#10 +
    '//       ''ThisFile.mdp'';' + #13#10 +
    '// ============================================================' + #13#10 +
    '' + #13#10 +
    'function MyFunc(n: Integer): Integer;' + #13#10 +
    'begin' + #13#10 +
    '  Result := n * n;' + #13#10 +
    'end;';

const
  SNIPPETS : array[0..14] of TSnippet = (

    (Name         : 'if ... then';
     Body         : '// Run inner statement only when condition is true' + #13#10 +
                    'if  then' + #13#10 +
                    '  ;';
     CaretFromEnd : 11),

    (Name         : 'if ... then ... else';
     Body         : '// Choose between two branches' + #13#10 +
                    'if  then' + #13#10 +
                    '  ' + #13#10 +
                    'else' + #13#10 +
                    '  ;';
     CaretFromEnd : 20),

    (Name         : 'while ... do';
     Body         : '// Repeat while condition is true (may run 0 times)' + #13#10 +
                    'while  do' + #13#10 +
                    'begin' + #13#10 +
                    '  ' + #13#10 +
                    'end;';
     CaretFromEnd : 19),

    (Name         : 'repeat ... until';
     Body         : '// Repeat until condition is true (always runs at least once)' + #13#10 +
                    'repeat' + #13#10 +
                    '  ' + #13#10 +
                    'until ;';
     CaretFromEnd : 1),

    (Name         : 'for ... to ... do';
     Body         : '// Loop counting up from start to end' + #13#10 +
                    'for i := 1 to 10 do' + #13#10 +
                    'begin' + #13#10 +
                    '  ' + #13#10 +
                    'end;';
     CaretFromEnd : 9),

    (Name         : 'for ... downto ... do';
     Body         : '// Loop counting down from start to end' + #13#10 +
                    'for i := 10 downto 1 do' + #13#10 +
                    'begin' + #13#10 +
                    '  ' + #13#10 +
                    'end;';
     CaretFromEnd : 9),

    (Name         : 'case ... of (integer)';
     Body         : '// Switch on an integer value' + #13#10 +
                    'case  of' + #13#10 +
                    '  1 : ;' + #13#10 +
                    '  2 : ;' + #13#10 +
                    'else' + #13#10 +
                    '  ;' + #13#10 +
                    'end;';
     CaretFromEnd : 39),

    (Name         : 'caseof ... of (string)';
     Body         : '// Switch on a string value (MiniDelphi extension)' + #13#10 +
                    'caseof  of' + #13#10 +
                    '  ''a'' : ;' + #13#10 +
                    '  ''b'' : ;' + #13#10 +
                    'else' + #13#10 +
                    '  ;' + #13#10 +
                    'end;';
     CaretFromEnd : 47),

    (Name         : 'writeln(...)';
     Body         : 'writeln('''');';
     CaretFromEnd : 3),

    (Name         : 'ShowMessage(...)';
     Body         : 'ShowMessage('''');';
     CaretFromEnd : 3),

    (Name         : 'InputBox(prompt, title, default)';
     Body         : ' := InputBox(''Prompt:'', ''Title'', '''');';
     CaretFromEnd : 36),

    (Name         : 'if Confirm(...) then ...';
     Body         : 'if Confirm(''Are you sure?'') then' + #13#10 +
                    '  ;';
     CaretFromEnd : 1),

    (Name         : 'procedure ... begin ... end;';
     Body         : 'procedure MyProc;' + #13#10 +
                    'begin' + #13#10 +
                    '  ' + #13#10 +
                    'end;';
     CaretFromEnd : 6),

    (Name         : 'function ... begin Result := ... end;';
     Body         : 'function MyFunc: Integer;' + #13#10 +
                    'begin' + #13#10 +
                    '  Result := 0;' + #13#10 +
                    'end;';
     CaretFromEnd : 7),

    (Name         : 'class skeleton (type + impl)';
     Body         : 'type' + #13#10 +
                    '  TMyClass = class' + #13#10 +
                    '    Name : String;' + #13#10 +
                    '    procedure SayHello;' + #13#10 +
                    '  end;' + #13#10 +
                    '' + #13#10 +
                    'procedure TMyClass.SayHello;' + #13#10 +
                    'begin' + #13#10 +
                    '  writeln(''Hello from '', Self.Name);' + #13#10 +
                    'end;';
     CaretFromEnd : 0)
  );

// ═══════════════════════════════════════════════════════════════════════════
//  RECENT FILES
// ═══════════════════════════════════════════════════════════════════════════

constructor TRecentFiles.Create;
begin
  inherited;
  FList := TStringList.Create;
  FPath := ChangeFileExt(ParamStr(0), '.recent.ini');
  Load;
end;

destructor TRecentFiles.Destroy;
begin
  Save;
  FList.Free;
  inherited;
end;

procedure TRecentFiles.Add(const Path: string);
var I: Integer;
begin
  I := FList.IndexOf(Path);
  if I >= 0 then FList.Delete(I);
  FList.Insert(0, Path);
  while FList.Count > MAX do
    FList.Delete(FList.Count - 1);
  Save;
end;

procedure TRecentFiles.Load;
var
  Ini : TIniFile;
  I   : Integer;
  S   : string;
begin
  FList.Clear;
  if not TFile.Exists(FPath) then Exit;
  Ini := TIniFile.Create(FPath);
  try
    for I := 0 to MAX - 1 do
    begin
      S := Ini.ReadString('Recent', 'File' + IntToStr(I), '');
      if (S <> '') and TFile.Exists(S) then
        FList.Add(S);
    end;
  finally
    Ini.Free;
  end;
end;

procedure TRecentFiles.Save;
var
  Ini : TIniFile;
  I   : Integer;
begin
  Ini := TIniFile.Create(FPath);
  try
    Ini.EraseSection('Recent');
    for I := 0 to FList.Count - 1 do
      Ini.WriteString('Recent', 'File' + IntToStr(I), FList[I]);
  finally
    Ini.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  TProjectTab
// ═══════════════════════════════════════════════════════════════════════════

constructor TProjectTab.Create(AParent: TWinControl);
begin
  inherited Create;
  FParent        := AParent;
  FExamples      := TExampleLibrary.Create;
  FRecent        := TRecentFiles.Create;
  FProjectFiles  := TStringList.Create;
  FProjectFiles.CaseSensitive := False;
  FProjectFiles.Duplicates    := dupIgnore;
  FCurrentFile   := '';
  FEditMode      := emStandalone;
  FProjectFile   := '';
  FProjectName   := '';
  FModified      := False;
  FInterp        := nil;

  BuildUI;
  BuildSnippetMenu;
  BuildProjectFileMenu;
  BuildTree;
  UpdateTitleBar;
  UpdateEditorLabel;

  FEditor.Lines.Text := NEW_SOURCE;
  FModified          := False;

  ApplyTheme;
  Theme.Subscribe(ApplyTheme);
end;

destructor TProjectTab.Destroy;
begin
  Theme.Unsubscribe(ApplyTheme);
  FProjectFiles.Free;
  FExamples.Free;
  FRecent.Free;
  inherited;
end;

procedure TProjectTab.OnStopBtn(Sender: TObject);
begin
  if Assigned(FInterp) then
    FInterp.RequestStop;
end;

function TProjectTab.IsProjectOpen: Boolean;
begin
  Result := FProjectFile <> '';
end;

// ═══════════════════════════════════════════════════════════════════════════
//  PROJECT PATH UTILITIES
// ═══════════════════════════════════════════════════════════════════════════

function TProjectTab.ProjectRelPath(const FullPath: string): string;
var ProjDir : string;
begin
  if FProjectFile = '' then Exit(FullPath);
  ProjDir := IncludeTrailingPathDelimiter(ExtractFilePath(FProjectFile));
  Result := ExtractRelativePath(ProjDir, FullPath);
end;

function TProjectTab.ProjectAbsPath(const RelPath: string): string;
var ProjDir : string;
begin
  if FProjectFile = '' then Exit(RelPath);
  if TPath.IsPathRooted(RelPath) then Exit(RelPath);
  ProjDir := IncludeTrailingPathDelimiter(ExtractFilePath(FProjectFile));
  Result  := TPath.GetFullPath(ProjDir + RelPath);
end;

function TProjectTab.IsInProjectFolder(const Path: string): Boolean;
begin
  Result := IsProjectOpen and
            SameText(IncludeTrailingPathDelimiter(ExtractFilePath(Path)),
                     IncludeTrailingPathDelimiter(ExtractFilePath(FProjectFile)));
end;

// ---------------------------------------------------------------------------
//  Load project from .mdproj  (with old-format migration)
// ---------------------------------------------------------------------------
procedure TProjectTab.LoadProjectFromIni(const ProjPath: string);
var
  Ini       : TIniFile;
  Count, I  : Integer;
  Rel, Abs  : string;
  MainRel   : string;
  MainAbs   : string;
  HasSource : Boolean;
  SrcLines  : TStringList;
begin
  FProjectFile := ProjPath;
  FProjectFiles.Clear;

  Ini := TIniFile.Create(ProjPath);
  try
    FProjectName := Ini.ReadString('Project', 'Name', ExtractFileName(ProjPath));
    MainRel      := Ini.ReadString('Project', 'MainFile', '');

    if Ini.ValueExists('Files', 'Count') then
    begin
      Count := Ini.ReadInteger('Files', 'Count', 0);
      for I := 0 to Count - 1 do
      begin
        Rel := Ini.ReadString('Files', 'File' + IntToStr(I), '');
        if Rel <> '' then
        begin
          Abs := ProjectAbsPath(Rel);
          if TFile.Exists(Abs) then
            FProjectFiles.Add(Abs);
        end;
      end;
    end;

    HasSource := Ini.SectionExists('Source');
  finally
    Ini.Free;
  end;

  // Migrate old-format projects that point at a separate main .mdp
  if (not HasSource) and (MainRel <> '') then
  begin
    MainAbs := ProjectAbsPath(MainRel);
    if TFile.Exists(MainAbs) then
    begin
      SrcLines := TStringList.Create;
      try
        SrcLines.LoadFromFile(MainAbs, TEncoding.UTF8);
        FEditor.Lines.Assign(SrcLines);
        SaveProjectSourceToIni;
      finally
        SrcLines.Free;
      end;
      Ini := TIniFile.Create(FProjectFile);
      try
        Ini.DeleteKey('Project', 'MainFile');
      finally
        Ini.Free;
      end;
    end
    else
    begin
      FEditor.Lines.Text := NEW_SOURCE;
      SaveProjectSourceToIni;
    end;
  end
  else if not HasSource then
  begin
    FEditor.Lines.Text := NEW_SOURCE;
    SaveProjectSourceToIni;
  end;

  SaveProjectIni;
end;

procedure TProjectTab.SaveProjectIni;
var
  Ini : TIniFile;
  I   : Integer;
begin
  if FProjectFile = '' then Exit;
  Ini := TIniFile.Create(FProjectFile);
  try
    Ini.WriteString('Project', 'Name', FProjectName);
    Ini.EraseSection('Files');
    Ini.WriteInteger('Files', 'Count', FProjectFiles.Count);
    for I := 0 to FProjectFiles.Count - 1 do
      Ini.WriteString('Files', 'File' + IntToStr(I),
                      ProjectRelPath(FProjectFiles[I]));
  finally
    Ini.Free;
  end;
end;

function TProjectTab.ReadProjectSource: string;
var
  Lines    : TStringList;
  I        : Integer;
  Trimmed  : string;
  InSource : Boolean;
  Result_  : TStringList;
begin
  Result := '';
  if (FProjectFile = '') or (not TFile.Exists(FProjectFile)) then Exit;

  Lines   := TStringList.Create;
  Result_ := TStringList.Create;
  try
    Lines.LoadFromFile(FProjectFile, TEncoding.UTF8);
    InSource := False;
    for I := 0 to Lines.Count - 1 do
    begin
      Trimmed := Trim(Lines[I]);
      if SameText(Trimmed, '[Source]') then
      begin
        InSource := True;
        Continue;
      end;
      if InSource and (Length(Trimmed) >= 2) and
         (Trimmed[1] = '[') and (Trimmed[Length(Trimmed)] = ']') then
        Break;
      if InSource then
        Result_.Add(Lines[I]);
    end;
    Result := Result_.Text;
    if (Length(Result) >= 2) and
       (Result[Length(Result) - 1] = #13) and (Result[Length(Result)] = #10) then
      SetLength(Result, Length(Result) - 2);
  finally
    Lines.Free;
    Result_.Free;
  end;
end;

procedure TProjectTab.SaveProjectSourceToIni;
var
  Existing : TStringList;
  Result_  : TStringList;
  I        : Integer;
  Trimmed  : string;
  InSource : Boolean;
begin
  if FProjectFile = '' then Exit;

  Existing := TStringList.Create;
  Result_  := TStringList.Create;
  try
    if TFile.Exists(FProjectFile) then
      Existing.LoadFromFile(FProjectFile, TEncoding.UTF8);

    InSource := False;
    for I := 0 to Existing.Count - 1 do
    begin
      Trimmed := Trim(Existing[I]);
      if SameText(Trimmed, '[Source]') then
      begin
        InSource := True;
        Continue;
      end;
      if InSource and (Length(Trimmed) >= 2) and
         (Trimmed[1] = '[') and (Trimmed[Length(Trimmed)] = ']') then
        InSource := False;
      if not InSource then
        Result_.Add(Existing[I]);
    end;

    if (Result_.Count > 0) and (Trim(Result_[Result_.Count - 1]) <> '') then
      Result_.Add('');

    Result_.Add('[Source]');
    Result_.Add(FEditor.Lines.Text);

    Result_.SaveToFile(FProjectFile, TEncoding.UTF8);
  finally
    Result_.Free;
    Existing.Free;
  end;
end;

procedure TProjectTab.AddFileToProject(const Path: string);
begin
  if not IsProjectOpen then Exit;
  if Path = '' then Exit;
  if FProjectFiles.IndexOf(Path) >= 0 then Exit;
  FProjectFiles.Add(Path);
  FProjectFiles.Sort;
  SaveProjectIni;
  RefreshProjectNode;
end;

procedure TProjectTab.RemoveFileFromProject(const Path: string);
var I : Integer;
begin
  if not IsProjectOpen then Exit;
  I := FProjectFiles.IndexOf(Path);
  if I < 0 then Exit;
  FProjectFiles.Delete(I);
  SaveProjectIni;
  RefreshProjectNode;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  THEME
// ═══════════════════════════════════════════════════════════════════════════

procedure TProjectTab.ApplyTheme;
begin
  if Assigned(FOuterPanel)  then Theme.ApplyPanelBg(FOuterPanel);
  if Assigned(FToolBar)     then Theme.ApplyPanelToolbar(FToolBar);
  if Assigned(FLabelFile)   then Theme.ApplyLabel(FLabelFile, 'normal');
  if Assigned(FLeftPanel)   then Theme.ApplyPanelAlt(FLeftPanel);
  if Assigned(FLabelTree)   then Theme.ApplyLabel(FLabelTree, 'header');
  if Assigned(FTree)        then Theme.ApplyTreeView(FTree);
  if Assigned(FRightPanel)  then Theme.ApplyPanelBg(FRightPanel);
  if Assigned(FEditorLabel) then Theme.ApplyLabel(FEditorLabel, 'accent');
  if Assigned(FEditor)      then Theme.ApplyMemoInput(FEditor);
  if Assigned(FOutputLabel) then Theme.ApplyLabel(FOutputLabel, 'accent');
  if Assigned(FOutput)      then Theme.ApplyMemoOutput(FOutput);
end;

// ═══════════════════════════════════════════════════════════════════════════
//  UI CONSTRUCTION
// ═══════════════════════════════════════════════════════════════════════════

procedure TProjectTab.BuildUI;
const
  BW  = 80;
  BH  = 28;
  PAD = 5;
  DARK    = $00252526;
  DARKER  = $001E1E1E;
  GREEN   = $0056D364;

  procedure Btn(var B: TButton; Parent: TWinControl;
                const Cap: string; var X: Integer;
                Handler: TNotifyEvent; Hint: string = '');
  begin
    B          := TButton.Create(Parent);
    B.Parent   := Parent;
    B.Caption  := Cap;
    B.Left     := X;  B.Top := PAD;
    B.Width    := BW; B.Height := BH;
    B.OnClick  := Handler;
    B.Hint     := Hint;
    B.ShowHint := Hint <> '';
    Inc(X, BW + PAD);
  end;

var X : Integer;
begin
  if FParent = nil then
    raise Exception.Create('TProjectTab requires a non-nil parent');

  FOuterPanel            := TPanel.Create(FParent);
  FOuterPanel.Parent     := FParent;
  FOuterPanel.Align      := alClient;
  FOuterPanel.BevelOuter := bvNone;
  FOuterPanel.Color      := DARKER;

  // ── Slim toolbar: Run / Stop / Insert ──────────────────────────────────
  FToolBar               := TPanel.Create(FOuterPanel);
  FToolBar.Parent        := FOuterPanel;
  FToolBar.Align         := alTop;
  FToolBar.Height        := BH + PAD * 2;
  FToolBar.BevelOuter    := bvNone;
  FToolBar.Color         := $00303030;

  X := PAD;
  Btn(FBtnRun,    FToolBar, 'Run',    X, OnRunBtn,  'Run project / file  (F5)');
  Btn(FBtnStop,   FToolBar, 'Stop',   X, OnStopBtn, 'Stop running program');

  FLabelFile              := TLabel.Create(FToolBar);
  FLabelFile.Parent       := FToolBar;
  FLabelFile.Left         := X + PAD;
  FLabelFile.Top          := PAD + 6;
  FLabelFile.Width        := 700;
  FLabelFile.Font.Color   := clSilver;
  FLabelFile.Caption      := 'No file open';

  // ── Left panel (tree) ──────────────────────────────────────────────────
  FLeftPanel              := TPanel.Create(FOuterPanel);
  FLeftPanel.Parent       := FOuterPanel;
  FLeftPanel.Align        := alLeft;
  FLeftPanel.Width        := 260;
  FLeftPanel.BevelOuter   := bvNone;
  FLeftPanel.Color        := DARK;

  FLabelTree              := TLabel.Create(FLeftPanel);
  FLabelTree.Parent       := FLeftPanel;
  FLabelTree.Align        := alTop;
  FLabelTree.Height       := 22;
  FLabelTree.Caption      := '  Project and Examples';
  FLabelTree.Font.Style   := [fsBold];
  FLabelTree.Font.Color   := clSilver;

  FTree                   := TTreeView.Create(FLeftPanel);
  FTree.Parent            := FLeftPanel;
  FTree.Align             := alClient;
  FTree.ReadOnly          := True;
  FTree.Color             := DARK;
  FTree.Font.Color        := clSilver;
  FTree.HideSelection     := False;
  FTree.Indent            := 14;
  FTree.OnDblClick        := OnTreeDblClick;
  FTree.OnMouseDown       := OnTreeMouseDown;

  FSplitter               := TSplitter.Create(FOuterPanel);
  FSplitter.Parent        := FOuterPanel;
  FSplitter.Align         := alLeft;
  FSplitter.Width         := 4;

  // ── Right panel ────────────────────────────────────────────────────────
  FRightPanel             := TPanel.Create(FOuterPanel);
  FRightPanel.Parent      := FOuterPanel;
  FRightPanel.Align       := alClient;
  FRightPanel.BevelOuter  := bvNone;
  FRightPanel.Color       := DARKER;

  FEditorLabel            := TLabel.Create(FRightPanel);
  FEditorLabel.Parent     := FRightPanel;
  FEditorLabel.Align      := alTop;
  FEditorLabel.Height     := 20;
  FEditorLabel.Caption    := '  Source Editor';
  FEditorLabel.Font.Color := $0056D364;
  FEditorLabel.Font.Style := [fsBold];

  FEditor                 := TMemo.Create(FRightPanel);
  FEditor.Parent          := FRightPanel;
  FEditor.Align           := alTop;
  FEditor.Height          := 380;
  FEditor.WordWrap        := False;
  FEditor.ScrollBars      := ssBoth;
  FEditor.Font.Name       := 'Consolas';
  FEditor.Font.Size       := 10;
  FEditor.Color           := $001E1E1E;
  FEditor.Font.Color      := $00DCDCDC;
  FEditor.OnChange        := OnEditorChange;
  FEditor.OnKeyDown       := OnEditorKey;

  FSplitVert              := TSplitter.Create(FRightPanel);
  FSplitVert.Parent       := FRightPanel;
  FSplitVert.Align        := alTop;
  FSplitVert.Height       := 4;

  FOutputLabel            := TLabel.Create(FRightPanel);
  FOutputLabel.Parent     := FRightPanel;
  FOutputLabel.Align      := alTop;
  FOutputLabel.Height     := 20;
  FOutputLabel.Caption    := '  Output';
  FOutputLabel.Font.Color := $0056D364;

  FOutput                 := TMemo.Create(FRightPanel);
  FOutput.Parent          := FRightPanel;
  FOutput.Align           := alClient;
  FOutput.ReadOnly        := True;
  FOutput.WordWrap        := False;
  FOutput.ScrollBars      := ssBoth;
  FOutput.Font.Name       := 'Consolas';
  FOutput.Font.Size       := 9;
  FOutput.Color           := $00121212;
  FOutput.Font.Color      := $0056D364;
end;

procedure TProjectTab.BuildSnippetMenu;
var
  I    : Integer;
  Item : TMenuItem;
  Sep  : TMenuItem;
begin
  FSnippetMenu := TPopupMenu.Create(FOuterPanel);

  for I := 0 to High(SNIPPETS) do
  begin
    if (I = 8) or (I = 12) or (I = 14) then
    begin
      Sep := TMenuItem.Create(FSnippetMenu);
      Sep.Caption := '-';
      FSnippetMenu.Items.Add(Sep);
    end;

    Item         := TMenuItem.Create(FSnippetMenu);
    Item.Caption := SNIPPETS[I].Name;
    Item.Tag     := I;
    Item.OnClick := OnSnippetClick;
    FSnippetMenu.Items.Add(Item);
  end;

  FEditor.PopupMenu := FSnippetMenu;
end;

procedure TProjectTab.BuildProjectFileMenu;

  procedure AddItem(Menu: TPopupMenu; const Cap: string; H: TNotifyEvent);
  var M: TMenuItem;
  begin
    M := TMenuItem.Create(Menu);
    M.Caption := Cap;
    M.OnClick := H;
    Menu.Items.Add(M);
  end;

  procedure AddSep(Menu: TPopupMenu);
  var M: TMenuItem;
  begin
    M := TMenuItem.Create(Menu);
    M.Caption := '-';
    Menu.Items.Add(M);
  end;

begin
  FProjFileMenu := TPopupMenu.Create(FOuterPanel);
  AddItem(FProjFileMenu, 'New File...',          OnProjMenuNewFile);
  AddItem(FProjFileMenu, 'Add Existing File...', OnProjMenuAddExisting);
  AddSep(FProjFileMenu);
  AddItem(FProjFileMenu, 'Open',                 OnProjMenuOpen);
  AddSep(FProjFileMenu);
  AddItem(FProjFileMenu, 'Rename...',            OnProjMenuRename);
  AddItem(FProjFileMenu, 'Remove from Project',  OnProjMenuRemove);
  AddItem(FProjFileMenu, 'Delete from Disk...',  OnProjMenuDelete);

  FProjRootMenu := TPopupMenu.Create(FOuterPanel);
  AddItem(FProjRootMenu, 'New File...',          OnProjMenuNewFile);
  AddItem(FProjRootMenu, 'Add Existing File...', OnProjMenuAddExisting);
end;

procedure TProjectTab.InsertSnippet(const Body: string; CaretFromEnd: Integer);
var StartPos : Integer;
begin
  StartPos := FEditor.SelStart;
  FEditor.SelText   := Body;
  FEditor.SelStart  := StartPos + Length(Body) - CaretFromEnd;
  FEditor.SelLength := 0;
  SetModified(True);
  FEditor.SetFocus;
end;

procedure TProjectTab.OnSnippetClick(Sender: TObject);
var Idx : Integer;
begin
  Idx := (Sender as TMenuItem).Tag;
  if (Idx >= 0) and (Idx <= High(SNIPPETS)) then
    InsertSnippet(SNIPPETS[Idx].Body, SNIPPETS[Idx].CaretFromEnd);
end;

// ═══════════════════════════════════════════════════════════════════════════
//  TREE
// ═══════════════════════════════════════════════════════════════════════════

procedure TProjectTab.BuildTree;
var
  Cats     : TStringList;
  Cat      : string;
  CatNode  : TTreeNode;
  I        : Integer;
  Ex       : TExampleProject;
  ExNode   : TTreeNode;
begin
  FTree.Items.BeginUpdate;
  try
    FTree.Items.Clear;
    FNodeProject  := nil;
    FNodeProjSrc  := nil;
    FNodeRecent   := nil;
    FNodeExamples := nil;

    if IsProjectOpen then
    begin
      FNodeProject := FTree.Items.Add(nil, 'Project: ' + FProjectName);
      FNodeProject.Data := Pointer(-4);
      RefreshProjectNode;
      FNodeProject.Expand(True);
    end;

    FNodeRecent := FTree.Items.Add(nil, 'Recent Files');
    FNodeRecent.Data := Pointer(-1);
    RefreshRecentNode;

    FNodeExamples := FTree.Items.Add(nil, 'Example Projects');
    FNodeExamples.Data := Pointer(-2);

    Cats := FExamples.Categories;
    try
      for Cat in Cats do
      begin
        CatNode      := FTree.Items.AddChild(FNodeExamples, '  ' + Cat);
        CatNode.Data := Pointer(-3);

        for I := 0 to FExamples.Count - 1 do
        begin
          Ex := FExamples.Items(I);
          if Ex.Category = Cat then
          begin
            ExNode      := FTree.Items.AddChild(CatNode, '    ' + Ex.Name);
            ExNode.Data := Pointer(I);
          end;
        end;
        CatNode.Expand(False);
      end;
    finally
      Cats.Free;
    end;

    FNodeRecent.Expand(True);
    FNodeExamples.Expand(False);
  finally
    FTree.Items.EndUpdate;
  end;
end;

procedure TProjectTab.RefreshRecentNode;
var
  I    : Integer;
  Name : string;
  Node : TTreeNode;
begin
  if FNodeRecent = nil then Exit;
  while FNodeRecent.Count > 0 do
    FTree.Items.Delete(FNodeRecent.Item[0]);

  if FRecent.Files.Count = 0 then
    FTree.Items.AddChild(FNodeRecent, '  (none yet)').Data := Pointer(-99)
  else
    for I := 0 to FRecent.Files.Count - 1 do
    begin
      Name := ExtractFileName(FRecent.Files[I]);
      Node := FTree.Items.AddChild(FNodeRecent, '  ' + Name);
      Node.Data := Pointer(-(100 + I));
    end;
end;

procedure TProjectTab.RefreshProjectNode;
var
  I    : Integer;
  Name : string;
  Node : TTreeNode;
begin
  if FNodeProject = nil then Exit;

  while FNodeProject.Count > 0 do
    FTree.Items.Delete(FNodeProject.Item[0]);

  FNodeProjSrc := FTree.Items.AddChild(FNodeProject,
                    '  ' + ExtractFileName(FProjectFile) + ' (project source)');
  FNodeProjSrc.Data := Pointer(-5);

  if FProjectFiles.Count = 0 then
  begin
    FTree.Items.AddChild(FNodeProject,
      '  (no library files — right-click to add)').Data := Pointer(-99);
    Exit;
  end;

  for I := 0 to FProjectFiles.Count - 1 do
  begin
    Name := ExtractFileName(FProjectFiles[I]);
    Node := FTree.Items.AddChild(FNodeProject, '    ' + Name);
    Node.Data := Pointer(-(200 + I));
  end;
end;

procedure TProjectTab.OnTreeMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Node : TTreeNode;
  Tag  : NativeInt;
  Idx  : Integer;
  P    : TPoint;
begin
  if Button <> mbRight then Exit;
  P    := FTree.ClientToScreen(Point(X, Y));
  Node := FTree.GetNodeAt(X, Y);

  if Node = nil then
  begin
    if IsProjectOpen then
    begin
      FProjMenuTargetPath := '';
      FProjRootMenu.Popup(P.X, P.Y);
    end;
    Exit;
  end;

  Tag := NativeInt(Node.Data);

  if (Tag <= -200) and (Tag > -300) then
  begin
    Idx := -(Tag + 200);
    if (Idx >= 0) and (Idx < FProjectFiles.Count) then
    begin
      FProjMenuTargetPath := FProjectFiles[Idx];
      FTree.Selected      := Node;
      FProjFileMenu.Popup(P.X, P.Y);
    end;
  end
  else if (Tag = -4) or (Tag = -5) then
  begin
    FProjMenuTargetPath := '';
    FTree.Selected      := Node;
    FProjRootMenu.Popup(P.X, P.Y);
  end
  else if IsProjectOpen then
  begin
    FProjMenuTargetPath := '';
    FProjRootMenu.Popup(P.X, P.Y);
  end;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  EDITOR / TITLE BAR
// ═══════════════════════════════════════════════════════════════════════════

procedure TProjectTab.UpdateTitleBar;
var Title : string;
begin
  case FEditMode of
    emProjectSource :
      Title := ExtractFileName(FProjectFile) + ' (project source)';
    emProjectFile :
      Title := ExtractFileName(FCurrentFile);
    emStandalone :
      if FCurrentFile <> '' then
        Title := ExtractFileName(FCurrentFile)
      else
        Title := 'Untitled.mdp';
  end;

  if FModified then Title := '* ' + Title;
  if FProjectName <> '' then
    Title := '[' + FProjectName + ']  ' + Title;

  FLabelFile.Caption := Title;
end;

procedure TProjectTab.UpdateEditorLabel;
begin
  case FEditMode of
    emProjectSource :
      FEditorLabel.Caption := '  Project Source  -  Ctrl+S to save  |  F5 to run';
    emProjectFile :
      FEditorLabel.Caption := '  Library File  -  Ctrl+S to save  |  F5 runs project';
    emStandalone :
      FEditorLabel.Caption := '  Source Editor  -  Ctrl+S to save  |  F5 to run';
  end;
end;

procedure TProjectTab.SetModified(Val: Boolean);
begin
  FModified := Val;
  UpdateTitleBar;
end;

function TProjectTab.ConfirmDiscard: Boolean;
begin
  if not FModified then begin Result := True; Exit; end;
  Result := MessageDlg(
    'You have unsaved changes. Discard them?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

procedure TProjectTab.LoadProjectFile(const Path: string);
begin
  if not TFile.Exists(Path) then
  begin
    ShowMessage('File not found: ' + Path);
    Exit;
  end;
  FEditor.Lines.Text := TFile.ReadAllText(Path, TEncoding.UTF8);
  FCurrentFile       := Path;
  FEditMode          := emProjectFile;
  FModified          := False;
  FRecent.Add(Path);
  RefreshRecentNode;
  UpdateTitleBar;
  UpdateEditorLabel;
  FOutput.Clear;
end;

procedure TProjectTab.LoadStandaloneFile(const Path: string);
begin
  if not TFile.Exists(Path) then
  begin
    ShowMessage('File not found: ' + Path);
    Exit;
  end;
  FEditor.Lines.Text := TFile.ReadAllText(Path, TEncoding.UTF8);
  FCurrentFile       := Path;
  FEditMode          := emStandalone;
  FModified          := False;
  FRecent.Add(Path);
  RefreshRecentNode;
  UpdateTitleBar;
  UpdateEditorLabel;
  FOutput.Clear;
end;

procedure TProjectTab.LoadProjectSourceIntoEditor;
begin
  FEditor.Lines.Text := ReadProjectSource;
  FCurrentFile       := '';
  FEditMode          := emProjectSource;
  FModified          := False;
  UpdateTitleBar;
  UpdateEditorLabel;
  FOutput.Clear;
end;

procedure TProjectTab.SaveCurrentBuffer;
begin
  case FEditMode of
    emProjectSource :
      begin
        SaveProjectSourceToIni;
        FModified := False;
        UpdateTitleBar;
      end;
    emProjectFile :
      begin
        if FCurrentFile = '' then Exit;
        TFile.WriteAllText(FCurrentFile, FEditor.Lines.Text, TEncoding.UTF8);
        FModified := False;
        UpdateTitleBar;
      end;
    emStandalone :
      begin
        if FCurrentFile = '' then
          DoSaveAs
        else
        begin
          TFile.WriteAllText(FCurrentFile, FEditor.Lines.Text, TEncoding.UTF8);
          FModified := False;
          UpdateTitleBar;
        end;
      end;
  end;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  RUN
// ═══════════════════════════════════════════════════════════════════════════

procedure TProjectTab.RunStandaloneEditor;
var
  Lex   : TLexer;
  Par   : TParser;
  Prog  : TProgramNode;
  T0    : Cardinal;
begin
  if Assigned(FInterp) then Exit;
  FOutput.Clear;
  FOutput.Lines.Add('Running...');
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
            FInterp.SourceText := FEditor.Lines.Text;
            if FCurrentFile <> '' then
              FInterp.SourcePath := ExtractFilePath(FCurrentFile)
            else
              FInterp.SourcePath := GetCurrentDir;
            FInterp.Run;
            FOutput.Lines.Add('');
            FOutput.Lines.Add(Format('--- Done  (%d ms) ---', [GetTickCount - T0]));
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

procedure TProjectTab.RunProjectSource;
var
  Lex     : TLexer;
  Par     : TParser;
  Prog    : TProgramNode;
  T0      : Cardinal;
  Src     : string;
begin
  if Assigned(FInterp) then Exit;

  // Save what's being edited first
  if (FEditMode = emProjectSource) and FModified then
    SaveCurrentBuffer
  else if (FEditMode = emProjectFile) and FModified then
    SaveCurrentBuffer;

  Src := ReadProjectSource;
  if Trim(Src) = '' then
  begin
    ShowMessage('Project source is empty. Use View → View Project Source to add code.');
    Exit;
  end;

  FOutput.Clear;
  FOutput.Lines.Add('Running project: ' + FProjectName);
  T0 := GetTickCount;
  try
    Lex := TLexer.Create(Src);
    try
      Lex.Tokenise;
      Par := TParser.Create(Lex.Tokens);
      try
        Prog := Par.Parse;
        try
          FInterp := TInterpreter.Create(Prog, FOutput.Lines);
          try
            FOutput.Lines.Clear;
            FInterp.SourceText := Src;
            FInterp.SourcePath := ExtractFilePath(FProjectFile);
            FInterp.Run;
            FOutput.Lines.Add('');
            FOutput.Lines.Add(Format('--- Done  (%d ms) ---', [GetTickCount - T0]));
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

procedure TProjectTab.OnRunBtn(Sender: TObject);
begin
  DoRun;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  PUBLIC API CALLED BY MAIN FORM'S FILE MENU
// ═══════════════════════════════════════════════════════════════════════════

procedure TProjectTab.ViewProjectSource;
begin
  if not IsProjectOpen then
  begin
    ShowMessage('Open a project first.');
    Exit;
  end;
  if not ConfirmDiscard then Exit;
  LoadProjectSourceIntoEditor;
  FEditor.SetFocus;
end;

procedure TProjectTab.DoNewFile;
var
  Path   : string;
  Name   : string;
  Choice : Integer;
begin
  if not ConfirmDiscard then Exit;

  if IsProjectOpen then
  begin
    Name := InputBox('New library file in project ' + FProjectName,
                     'File name (without .mdp):', 'NewLib');
    if Trim(Name) = '' then Exit;
    Path := IncludeTrailingPathDelimiter(ExtractFilePath(FProjectFile)) +
            Name + '.mdp';
    if TFile.Exists(Path) then
    begin
      ShowMessage('A file with that name already exists in the project folder.');
      Exit;
    end;

    Choice := MessageDlg(
      'Library file (declarations only, no begin..end), or runnable program?' +
      sLineBreak + sLineBreak +
      'Yes = library     (typical for project members)' + sLineBreak +
      'No  = runnable program',
      mtConfirmation, [mbYes, mbNo, mbCancel], 0);
    if Choice = mrCancel then Exit;

    if Choice = mrYes then
      TFile.WriteAllText(Path, NEW_LIBRARY_SOURCE, TEncoding.UTF8)
    else
      TFile.WriteAllText(Path, NEW_SOURCE, TEncoding.UTF8);

    AddFileToProject(Path);
    LoadProjectFile(Path);
    Exit;
  end;

  // No project — untitled scratch file
  FEditor.Lines.Text := NEW_SOURCE;
  FCurrentFile       := '';
  FEditMode          := emStandalone;
  FModified          := False;
  FOutput.Clear;
  UpdateTitleBar;
  UpdateEditorLabel;
  FEditor.SetFocus;
end;

procedure TProjectTab.DoOpenFile;
var Dlg : TOpenDialog;
begin
  if not ConfirmDiscard then Exit;
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Filter      := MDP_FILTER;
    Dlg.DefaultExt  := MDP_EXT;
    Dlg.Options     := [ofFileMustExist];
    if IsProjectOpen then
      Dlg.InitialDir := ExtractFilePath(FProjectFile);
    if Dlg.Execute then
    begin
      if IsProjectOpen and (FProjectFiles.IndexOf(Dlg.FileName) >= 0) then
        LoadProjectFile(Dlg.FileName)
      else
        LoadStandaloneFile(Dlg.FileName);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TProjectTab.DoSave;
begin
  SaveCurrentBuffer;
end;

procedure TProjectTab.DoSaveAs;
var Dlg : TSaveDialog;
begin
  if FEditMode = emProjectSource then
  begin
    ShowMessage('The project source is part of the .mdproj file ' +
                'and cannot be saved separately.');
    Exit;
  end;

  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Filter     := MDP_FILTER;
    Dlg.DefaultExt := MDP_EXT;
    if FCurrentFile <> '' then
      Dlg.FileName := FCurrentFile
    else if IsProjectOpen then
      Dlg.InitialDir := ExtractFilePath(FProjectFile);
    if Dlg.Execute then
    begin
      TFile.WriteAllText(Dlg.FileName, FEditor.Lines.Text, TEncoding.UTF8);
      FCurrentFile := Dlg.FileName;
      FRecent.Add(Dlg.FileName);
      RefreshRecentNode;
      if IsProjectOpen and IsInProjectFolder(Dlg.FileName) then
      begin
        AddFileToProject(Dlg.FileName);
        FEditMode := emProjectFile;
      end
      else
        FEditMode := emStandalone;
      FModified := False;
      UpdateTitleBar;
      UpdateEditorLabel;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TProjectTab.DoRun;
begin
  if IsProjectOpen then
    RunProjectSource
  else
  begin
    if (FCurrentFile <> '') and FModified then
      SaveCurrentBuffer;
    RunStandaloneEditor;
  end;
end;

procedure TProjectTab.DoNewProject;
var
  ProjName : string;
  ProjFile : string;
  Dlg      : TSaveDialog;
  Ini      : TIniFile;
begin
  ProjName := InputBox('Project name:', 'New Project', 'MyProject');
  if Trim(ProjName) = '' then Exit;

  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Title      := 'Save Project File';
    Dlg.Filter     := MPROJ_FILTER;
    Dlg.DefaultExt := MPROJ_EXT;
    Dlg.FileName   := ProjName;
    if not Dlg.Execute then Exit;
    ProjFile := Dlg.FileName;
  finally
    Dlg.Free;
  end;

  Ini := TIniFile.Create(ProjFile);
  try
    Ini.WriteString('Project', 'Name',    ProjName);
    Ini.WriteString('Project', 'Created', DateToStr(Now));
  finally
    Ini.Free;
  end;

  FProjectFile := ProjFile;
  FProjectName := ProjName;
  FProjectFiles.Clear;

  FEditor.Lines.Text := NewProjectSource(ProjName);
  FEditMode := emProjectSource;
  FCurrentFile := '';
  SaveProjectSourceToIni;
  SaveProjectIni;
  FModified := False;

  BuildTree;
  UpdateTitleBar;
  UpdateEditorLabel;

  if Assigned(FOnProjectChanged) then FOnProjectChanged(Self);

  MessageDlg('Project "' + ProjName + '" created.' + sLineBreak +
             sLineBreak +
             'Edit the project source on the right.' + sLineBreak +
             'Right-click the project tree to add library files.',
             mtInformation, [mbOK], 0);
end;

procedure TProjectTab.DoOpenProject;
var Dlg : TOpenDialog;
begin
  if not ConfirmDiscard then Exit;
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Filter     := MPROJ_FILTER;
    Dlg.DefaultExt := MPROJ_EXT;
    Dlg.Options    := [ofFileMustExist];
    if not Dlg.Execute then Exit;

    LoadProjectFromIni(Dlg.FileName);
    BuildTree;
    LoadProjectSourceIntoEditor;
    if Assigned(FOnProjectChanged) then FOnProjectChanged(Self);
  finally
    Dlg.Free;
  end;
end;

procedure TProjectTab.DoCloseProject;
begin
  if not IsProjectOpen then
  begin
    ShowMessage('No project is open.');
    Exit;
  end;
  if not ConfirmDiscard then Exit;
  FProjectFile := '';
  FProjectName := '';
  FProjectFiles.Clear;
  FEditor.Lines.Text := NEW_SOURCE;
  FCurrentFile := '';
  FEditMode    := emStandalone;
  FModified    := False;
  BuildTree;
  UpdateTitleBar;
  UpdateEditorLabel;
  FOutput.Clear;
  FOutput.Lines.Add('Project closed.');
  if Assigned(FOnProjectChanged) then FOnProjectChanged(Self);
end;

procedure TProjectTab.DoAddExistingFile;
var
  Dlg : TOpenDialog;
  I   : Integer;
begin
  if not IsProjectOpen then
  begin
    ShowMessage('Open or create a project first.');
    Exit;
  end;
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Filter     := MDP_FILTER;
    Dlg.DefaultExt := MDP_EXT;
    Dlg.Options    := [ofFileMustExist, ofAllowMultiSelect];
    Dlg.InitialDir := ExtractFilePath(FProjectFile);
    if not Dlg.Execute then Exit;
    for I := 0 to Dlg.Files.Count - 1 do
      AddFileToProject(Dlg.Files[I]);
  finally
    Dlg.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  TREE DOUBLE-CLICK
// ═══════════════════════════════════════════════════════════════════════════

procedure TProjectTab.OnTreeDblClick(Sender: TObject);
var
  Node    : TTreeNode;
  Tag     : NativeInt;
  Ex      : TExampleProject;
  RecentI : Integer;
  ProjI   : Integer;
  TempDir : string;
  MainPath: string;
  MFI     : Integer;
  EF      : TExampleFile;
  FilePath: string;
begin
  Node := FTree.Selected;
  if not Assigned(Node) then Exit;
  Tag := NativeInt(Node.Data);

  if Tag = -5 then
  begin
    if not ConfirmDiscard then Exit;
    LoadProjectSourceIntoEditor;
    Exit;
  end;

  if Tag >= 0 then
  begin
    if not ConfirmDiscard then Exit;
    Ex := FExamples.Items(Tag);
    FOutput.Clear;

    if Ex.IsMultiFile then
    begin
      TempDir := TPath.Combine(TPath.GetTempPath,
                   'MiniDelphi_' + StringReplace(Ex.Name, ' ', '_', [rfReplaceAll]));
      TDirectory.CreateDirectory(TempDir);
      MainPath := '';
      for MFI := 0 to High(Ex.Files) do
      begin
        EF := Ex.Files[MFI];
        FilePath := TPath.Combine(TempDir, EF.FileName);
        TFile.WriteAllText(FilePath, EF.Source, TEncoding.UTF8);
        if EF.IsMain then MainPath := FilePath;
      end;
      if MainPath = '' then
        MainPath := TPath.Combine(TempDir, Ex.Files[High(Ex.Files)].FileName);

      FEditor.Lines.Text := TFile.ReadAllText(MainPath, TEncoding.UTF8);
      FCurrentFile       := MainPath;
      FEditMode          := emStandalone;
      FModified          := False;
      UpdateTitleBar;
      UpdateEditorLabel;

      FOutput.Lines.Add('// Multi-file Example: ' + Ex.Name);
      FOutput.Lines.Add('// ' + Ex.Description);
    end
    else
    begin
      FEditor.Lines.Text := Ex.Source;
      FCurrentFile       := '';
      FEditMode          := emStandalone;
      FModified          := False;
      UpdateTitleBar;
      UpdateEditorLabel;
      FOutput.Lines.Add('// Example: ' + Ex.Name);
      FOutput.Lines.Add('// ' + Ex.Description);
    end;
  end
  else if (Tag <= -200) and (Tag > -300) then
  begin
    ProjI := -(Tag + 200);
    if (ProjI >= 0) and (ProjI < FProjectFiles.Count) then
    begin
      if not ConfirmDiscard then Exit;
      LoadProjectFile(FProjectFiles[ProjI]);
    end;
  end
  else if Tag <= -100 then
  begin
    RecentI := (-Tag) - 100;
    if (RecentI >= 0) and (RecentI < FRecent.Files.Count) then
    begin
      if not ConfirmDiscard then Exit;
      LoadStandaloneFile(FRecent.Files[RecentI]);
    end;
  end;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  RIGHT-CLICK MENU ACTIONS
// ═══════════════════════════════════════════════════════════════════════════

procedure TProjectTab.OnProjMenuNewFile(Sender: TObject);
begin
  DoNewFile;
end;

procedure TProjectTab.OnProjMenuAddExisting(Sender: TObject);
begin
  DoAddExistingFile;
end;

procedure TProjectTab.OnProjMenuOpen(Sender: TObject);
begin
  if FProjMenuTargetPath = '' then Exit;
  if not ConfirmDiscard then Exit;
  LoadProjectFile(FProjMenuTargetPath);
end;

procedure TProjectTab.OnProjMenuRename(Sender: TObject);
var
  OldPath, NewPath, NewName, OldName : string;
  WasCurrent : Boolean;
  Idx : Integer;
begin
  if FProjMenuTargetPath = '' then Exit;
  OldPath := FProjMenuTargetPath;
  OldName := ExtractFileName(OldPath);
  NewName := InputBox('Rename file', 'New name (with .mdp extension):', OldName);
  if Trim(NewName) = '' then Exit;
  if SameText(NewName, OldName) then Exit;

  NewPath := IncludeTrailingPathDelimiter(ExtractFilePath(OldPath)) + NewName;
  if TFile.Exists(NewPath) then
  begin
    ShowMessage('A file with that name already exists.');
    Exit;
  end;

  WasCurrent := SameText(OldPath, FCurrentFile);
  try
    TFile.Move(OldPath, NewPath);
  except
    on E: Exception do
    begin
      ShowMessage('Could not rename: ' + E.Message);
      Exit;
    end;
  end;

  Idx := FProjectFiles.IndexOf(OldPath);
  if Idx >= 0 then
  begin
    FProjectFiles.Delete(Idx);
    FProjectFiles.Add(NewPath);
    FProjectFiles.Sort;
  end;
  if WasCurrent then FCurrentFile := NewPath;

  SaveProjectIni;
  RefreshProjectNode;
  UpdateTitleBar;
end;

procedure TProjectTab.OnProjMenuRemove(Sender: TObject);
begin
  if FProjMenuTargetPath = '' then Exit;
  if MessageDlg('Remove "' + ExtractFileName(FProjMenuTargetPath) +
                '" from the project?' + sLineBreak +
                '(The file itself is NOT deleted from disk.)',
                mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  RemoveFileFromProject(FProjMenuTargetPath);
  FOutput.Lines.Add('Removed from project: ' +
                    ExtractFileName(FProjMenuTargetPath));
end;

procedure TProjectTab.OnProjMenuDelete(Sender: TObject);
var Path : string;
begin
  if FProjMenuTargetPath = '' then Exit;
  Path := FProjMenuTargetPath;
  if MessageDlg('Delete "' + ExtractFileName(Path) + '" PERMANENTLY from disk?',
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  try
    TFile.Delete(Path);
  except
    on E: Exception do
    begin
      ShowMessage('Could not delete: ' + E.Message);
      Exit;
    end;
  end;

  if SameText(Path, FCurrentFile) then
  begin
    FEditor.Clear;
    FCurrentFile := '';
    FEditMode    := emStandalone;
    FModified    := False;
  end;
  RemoveFileFromProject(Path);
  UpdateTitleBar;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  EDITOR HANDLERS
// ═══════════════════════════════════════════════════════════════════════════

procedure TProjectTab.OnEditorChange(Sender: TObject);
begin
  SetModified(True);
end;

procedure TProjectTab.OnEditorKey(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = Ord('S')) and (ssCtrl in Shift) then
  begin
    DoSave;
    Key := 0;
  end
  else if (Key = Ord('N')) and (ssCtrl in Shift) then
  begin
    DoNewFile;
    Key := 0;
  end
  else if (Key = Ord('O')) and (ssCtrl in Shift) then
  begin
    DoOpenFile;
    Key := 0;
  end
  else if Key = VK_F5 then
  begin
    DoRun;
    Key := 0;
  end;
end;

end.
