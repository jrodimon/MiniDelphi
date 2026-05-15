unit UProjectTab;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  UProjectTab.pas  —  Project IDE tab for MiniDelphi
//
//  Features
//  ────────
//  • New / Open / Save / Save As for .mdp source files
//  • Project files (.mdproj) group multiple .mdp files together
//  • Example project tree (single-file and multi-file)
//  • Full source editor with Ctrl+S, Ctrl+N, Ctrl+O, F5 shortcuts
//  • Recent files list (last 10)
//  • Run / Stop buttons (Stop interrupts a running program)
//  • Insert button + right-click menu for code snippets
//
//  File formats
//  ────────────
//  .mdp      Plain text MiniDelphi source  (UTF-8)
//  .mdproj   Simple text project file:
//              [Project]
//              Name=MyProject
//              Description=...
//              MainFile=Main.mdp
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
  UExampleProjects;

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

  // ---------------------------------------------------------------------------
  //  Snippet record — used by the Insert button and editor popup
  //
  //    Name         menu caption shown to the user
  //    Body         text inserted at the caret (use #13#10 for newlines)
  //    CaretFromEnd how many characters back from the end of the inserted
  //                 text the caret should land on (so the user can start
  //                 typing in a sensible place, e.g. inside the condition).
  //                 0 = caret at end of insertion.
  // ---------------------------------------------------------------------------
  TSnippet = record
    Name         : string;
    Body         : string;
    CaretFromEnd : Integer;
  end;

  // ---------------------------------------------------------------------------
  //  The Project tab panel — drop onto a TTabSheet
  // ---------------------------------------------------------------------------
  TProjectTab = class
  private
    FParent     : TWinControl;
    FExamples   : TExampleLibrary;
    FRecent     : TRecentFiles;

    // Current file state
    FCurrentFile    : string;    // full path to open .mdp file
    FProjectFile    : string;    // full path to open .mdproj file
    FProjectName    : string;
    FModified       : Boolean;

    // ── UI controls ──────────────────────────────────────────────────────────
    FOuterPanel     : TPanel;

    // Toolbar
    FToolBar        : TPanel;
    FBtnNew         : TButton;
    FBtnOpen        : TButton;
    FBtnSave        : TButton;
    FBtnSaveAs      : TButton;
    FBtnRun         : TButton;
    FBtnStop        : TButton;
    FBtnInsert      : TButton;
    FBtnNewProj     : TButton;
    FBtnOpenProj    : TButton;
    FBtnNewLib      : TButton;
    FLabelFile      : TLabel;

    // Left tree (examples + recent)
    FLeftPanel      : TPanel;
    FSplitter       : TSplitter;
    FTree           : TTreeView;
    FLabelTree      : TLabel;

    // Right editor + output
    FRightPanel     : TPanel;
    FEditorLabel    : TLabel;
    FEditor         : TMemo;
    FSplitVert      : TSplitter;
    FOutputLabel    : TLabel;
    FOutput         : TMemo;

    // Tree node roots
    FNodeRecent     : TTreeNode;
    FNodeExamples   : TTreeNode;

    // Snippet popup menu (shared by toolbar button and editor right-click)
    FSnippetMenu    : TPopupMenu;

    // nil when not running
    FInterp         : TInterpreter;

    // ── Helpers ──────────────────────────────────────────────────────────────
    procedure BuildUI;
    procedure BuildTree;
    procedure BuildSnippetMenu;
    procedure RefreshRecentNode;
    procedure UpdateTitleBar;
    procedure SetModified(Val: Boolean);

    function  ConfirmDiscard : Boolean;
    procedure LoadFile(const Path: string);
    procedure SaveFile(const Path: string);
    procedure RunCurrentSource;
    procedure InsertSnippet(const Body: string; CaretFromEnd: Integer);

    // Event handlers
    procedure OnNew         (Sender: TObject);
    procedure OnOpen        (Sender: TObject);
    procedure OnSave        (Sender: TObject);
    procedure OnSaveAs      (Sender: TObject);
    procedure OnRun         (Sender: TObject);
    procedure OnStop        (Sender: TObject);
    procedure OnInsertClick (Sender: TObject);
    procedure OnSnippetClick(Sender: TObject);
    procedure OnNewProject  (Sender: TObject);
    procedure OnOpenProject (Sender: TObject);
    procedure OnNewLibrary  (Sender: TObject);
    procedure OnTreeDblClick(Sender: TObject);
    procedure OnEditorChange(Sender: TObject);
    procedure OnEditorKey   (Sender: TObject; var Key: Word; Shift: TShiftState);

  public
    constructor Create(AParent: TWinControl);
    destructor  Destroy; override;

    property CurrentFile : string  read FCurrentFile;
    property Modified    : Boolean read FModified;
  end;

// =============================================================================
implementation
// =============================================================================

const
  MDP_FILTER   = 'MiniDelphi Source|*.mdp|All Files|*.*';
  MPROJ_FILTER = 'MiniDelphi Project|*.mdproj|All Files|*.*';
  MDP_EXT      = 'mdp';
  MPROJ_EXT    = 'mdproj';

  NEW_SOURCE =
    '// ============================================================' + #13#10 +
    '// NEW MINIDELPHI PROGRAM' + #13#10 +
    '// Replace this comment with your program''s name and purpose.' + #13#10 +
    '// ============================================================' + #13#10 +
    '' + #13#10 +
    'begin' + #13#10 +
    '  // Write your code here' + #13#10 +
    '  writeln(''Hello, MiniDelphi!'');' + #13#10 +
    'end.';

// ---------------------------------------------------------------------------
//  Snippet library — used by Insert button and editor right-click menu
//
//  CaretFromEnd counts back from the END of the inserted text.
//  Example: 'if  then'#13#10'  ;' has length 13. To land the caret right
//  after "if " (position 3), we want 13 - 3 = 10... but we typically want
//  a few chars earlier so the user is sitting inside the empty condition
//  space. Tune CaretFromEnd by counting back from the literal end of Body.
// ---------------------------------------------------------------------------
const
  SNIPPETS : array[0..14] of TSnippet = (

    // ── Control flow ────────────────────────────────────────────────────────
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

    // ── I/O ─────────────────────────────────────────────────────────────────
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

    // ── Routines ────────────────────────────────────────────────────────────
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

    // ── OOP ─────────────────────────────────────────────────────────────────
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
  // Remove if already in list (will re-add at top)
  I := FList.IndexOf(Path);
  if I >= 0 then FList.Delete(I);
  FList.Insert(0, Path);
  // Trim to max
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
//  PROJECT TAB
// ═══════════════════════════════════════════════════════════════════════════

constructor TProjectTab.Create(AParent: TWinControl);
begin
  inherited Create;
  FParent      := AParent;
  FExamples    := TExampleLibrary.Create;
  FRecent      := TRecentFiles.Create;
  FCurrentFile := '';
  FProjectFile := '';
  FProjectName := '';
  FModified    := False;
  FInterp      := nil;

  BuildUI;
  BuildSnippetMenu;
  BuildTree;
  UpdateTitleBar;

  // Pre-load the new file template
  FEditor.Lines.Text := NEW_SOURCE;
  FModified          := False;
end;

destructor TProjectTab.Destroy;
begin
  FExamples.Free;
  FRecent.Free;
  inherited;
end;

procedure TProjectTab.OnStop(Sender: TObject);
begin
  if Assigned(FInterp) then
    FInterp.RequestStop;
end;

// ---------------------------------------------------------------------------
//  Build the entire UI
// ---------------------------------------------------------------------------
procedure TProjectTab.BuildUI;
const
  BW  = 88;
  BH  = 28;
  PAD = 6;
  DARK    = $00252526;
  DARKER  = $001E1E1E;
  GREEN   = $0056D364;
  AMBER   = $0000AAFF;

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

  // Outer panel
  FOuterPanel            := TPanel.Create(FParent);
  FOuterPanel.Parent     := FParent;
  FOuterPanel.Align      := alClient;
  FOuterPanel.BevelOuter := bvNone;
  FOuterPanel.Color      := DARKER;

  // ── Toolbar ───────────────────────────────────────────────────────────────
  FToolBar               := TPanel.Create(FOuterPanel);
  FToolBar.Parent        := FOuterPanel;
  FToolBar.Align         := alTop;
  FToolBar.Height        := BH + PAD * 2;
  FToolBar.BevelOuter    := bvNone;
  FToolBar.Color         := $00303030;

  X := PAD;
  Btn(FBtnNew,      FToolBar, 'New',       X, OnNew,         'New file  (Ctrl+N)');
  Btn(FBtnOpen,     FToolBar, 'Open',      X, OnOpen,        'Open .mdp file  (Ctrl+O)');
  Btn(FBtnSave,     FToolBar, 'Save',      X, OnSave,        'Save  (Ctrl+S)');
  Btn(FBtnSaveAs,   FToolBar, 'Save As',   X, OnSaveAs,      'Save with new name');
  Btn(FBtnRun,      FToolBar, 'Run',       X, OnRun,         'Run this program  (F5)');
  Btn(FBtnStop,     FToolBar, 'Stop',      X, OnStop,        'Stop running program');
  Btn(FBtnInsert,   FToolBar, 'Insert',    X, OnInsertClick, 'Insert code snippet (or right-click in editor)');
  Inc(X, PAD * 2);
  Btn(FBtnNewProj,  FToolBar, 'New Proj',  X, OnNewProject,  'Create a new project');
  Btn(FBtnOpenProj, FToolBar, 'Open Proj', X, OnOpenProject, 'Open an existing project');

  // File label
  FLabelFile              := TLabel.Create(FToolBar);
  FLabelFile.Parent       := FToolBar;
  FLabelFile.Left         := X + PAD;
  FLabelFile.Top          := PAD + 6;
  FLabelFile.Width        := 400;
  FLabelFile.Font.Color   := clSilver;
  FLabelFile.Caption      := 'No file open';

  // ── Left panel (tree) ─────────────────────────────────────────────────────
  FLeftPanel              := TPanel.Create(FOuterPanel);
  FLeftPanel.Parent       := FOuterPanel;
  FLeftPanel.Align        := alLeft;
  FLeftPanel.Width        := 240;
  FLeftPanel.BevelOuter   := bvNone;
  FLeftPanel.Color        := DARK;

  FLabelTree              := TLabel.Create(FLeftPanel);
  FLabelTree.Parent       := FLeftPanel;
  FLabelTree.Align        := alTop;
  FLabelTree.Height       := 22;
  FLabelTree.Caption      := '  Projects & Examples';
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

  // ── Splitter ──────────────────────────────────────────────────────────────
  FSplitter               := TSplitter.Create(FOuterPanel);
  FSplitter.Parent        := FOuterPanel;
  FSplitter.Align         := alLeft;
  FSplitter.Width         := 4;

  // ── Right panel (editor + output) ─────────────────────────────────────────
  FRightPanel             := TPanel.Create(FOuterPanel);
  FRightPanel.Parent      := FOuterPanel;
  FRightPanel.Align       := alClient;
  FRightPanel.BevelOuter  := bvNone;
  FRightPanel.Color       := DARKER;

  FEditorLabel            := TLabel.Create(FRightPanel);
  FEditorLabel.Parent     := FRightPanel;
  FEditorLabel.Align      := alTop;
  FEditorLabel.Height     := 20;
  FEditorLabel.Caption    := '  Source Editor  —  Ctrl+S to save  |  F5 to run  |  right-click for snippets';
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
  FOutput.Font.Color      := GREEN;
end;

// ---------------------------------------------------------------------------
//  Build the popup menu used by both the Insert button and the editor
//  right-click. Items use Tag to hold the SNIPPETS array index.
// ---------------------------------------------------------------------------
procedure TProjectTab.BuildSnippetMenu;
var
  I        : Integer;
  Item     : TMenuItem;
  Sep      : TMenuItem;
  LastWasCtrl : Boolean;
begin
  FSnippetMenu := TPopupMenu.Create(FOuterPanel);

  // Hand-built grouping: rough separators between control flow / I/O /
  // routines / OOP. Positions matched to the SNIPPETS array layout above.
  for I := 0 to High(SNIPPETS) do
  begin
    // Insert separator before I/O group (index 8) and routines (index 12)
    // and OOP (index 14)
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

  // Wire the same menu up to the editor for right-click access
  FEditor.PopupMenu := FSnippetMenu;
end;

// ---------------------------------------------------------------------------
//  Insert a snippet at the current caret position, then reposition the
//  caret CaretFromEnd characters back from the end of the inserted text.
// ---------------------------------------------------------------------------
procedure TProjectTab.InsertSnippet(const Body: string; CaretFromEnd: Integer);
var
  StartPos : Integer;
begin
  StartPos := FEditor.SelStart;
  // SelText replaces any current selection, or inserts at caret if none
  FEditor.SelText  := Body;
  // Position caret inside the template where the user is likely to type next
  FEditor.SelStart := StartPos + Length(Body) - CaretFromEnd;
  FEditor.SelLength := 0;
  SetModified(True);
  FEditor.SetFocus;
end;

procedure TProjectTab.OnSnippetClick(Sender: TObject);
var
  Idx : Integer;
begin
  Idx := (Sender as TMenuItem).Tag;
  if (Idx >= 0) and (Idx <= High(SNIPPETS)) then
    InsertSnippet(SNIPPETS[Idx].Body, SNIPPETS[Idx].CaretFromEnd);
end;

procedure TProjectTab.OnInsertClick(Sender: TObject);
var
  P : TPoint;
begin
  // Drop the menu just below the Insert button
  P := FBtnInsert.ClientToScreen(Point(0, FBtnInsert.Height));
  FSnippetMenu.Popup(P.X, P.Y);
end;

// ---------------------------------------------------------------------------
//  Build the example / recent tree
// ---------------------------------------------------------------------------
procedure TProjectTab.BuildTree;
var
  Cats     : TStringList;
  Cat      : string;
  CatNode  : TTreeNode;
  I        : Integer;
  Ex       : TExampleProject;
  ExNode   : TTreeNode;
begin
  FTree.Items.Clear;

  // Recent files node
  FNodeRecent := FTree.Items.Add(nil, 'Recent Files');
  FNodeRecent.Data := Pointer(-1);
  RefreshRecentNode;

  // Examples by category
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
          ExNode.Data := Pointer(I);   // index into FExamples
        end;
      end;
      CatNode.Expand(False);
    end;
  finally
    Cats.Free;
  end;

  FNodeRecent.Expand(True);
  FNodeExamples.Expand(False);
end;

procedure TProjectTab.RefreshRecentNode;
var
  I    : Integer;
  Name : string;
  Node : TTreeNode;
begin
  // Remove old children of FNodeRecent
  while FNodeRecent.Count > 0 do
    FTree.Items.Delete(FNodeRecent.Item[0]);

  if FRecent.Files.Count = 0 then
  begin
    FTree.Items.AddChild(FNodeRecent, '  (none yet)').Data := Pointer(-99);
  end
  else
  begin
    for I := 0 to FRecent.Files.Count - 1 do
    begin
      Name := ExtractFileName(FRecent.Files[I]);
      Node := FTree.Items.AddChild(FNodeRecent, '  ' + Name);
      Node.Data := Pointer(-(100 + I));   // encoded as -(100+recentIndex)
    end;
  end;
end;

// ---------------------------------------------------------------------------
//  Title bar / file label helpers
// ---------------------------------------------------------------------------
procedure TProjectTab.UpdateTitleBar;
var
  Title : string;
begin
  if FCurrentFile <> '' then
    Title := ExtractFileName(FCurrentFile)
  else
    Title := 'Untitled.mdp';

  if FModified then Title := '* ' + Title;

  if FProjectName <> '' then
    Title := '[' + FProjectName + ']  ' + Title;

  FLabelFile.Caption := Title;
end;

procedure TProjectTab.SetModified(Val: Boolean);
begin
  FModified := Val;
  UpdateTitleBar;
end;

// ---------------------------------------------------------------------------
//  Confirm discard of unsaved changes
// ---------------------------------------------------------------------------
function TProjectTab.ConfirmDiscard: Boolean;
begin
  if not FModified then begin Result := True; Exit; end;
  Result := MessageDlg(
    'You have unsaved changes. Discard them?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

// ---------------------------------------------------------------------------
//  Load a .mdp file into the editor
// ---------------------------------------------------------------------------
procedure TProjectTab.LoadFile(const Path: string);
begin
  if not TFile.Exists(Path) then
  begin
    ShowMessage('File not found: ' + Path);
    Exit;
  end;
  FEditor.Lines.Text := TFile.ReadAllText(Path, TEncoding.UTF8);
  FCurrentFile       := Path;
  FModified          := False;
  FRecent.Add(Path);
  RefreshRecentNode;
  UpdateTitleBar;
  FOutput.Clear;
end;

// ---------------------------------------------------------------------------
//  Save current editor to a .mdp file
// ---------------------------------------------------------------------------
procedure TProjectTab.SaveFile(const Path: string);
begin
  TFile.WriteAllText(Path, FEditor.Lines.Text, TEncoding.UTF8);
  FCurrentFile := Path;
  FModified    := False;
  FRecent.Add(Path);
  RefreshRecentNode;
  UpdateTitleBar;
end;

// ---------------------------------------------------------------------------
//  Run the current source through the interpreter
// ---------------------------------------------------------------------------
procedure TProjectTab.RunCurrentSource;
var
  Lex   : TLexer;
  Par   : TParser;
  Prog  : TProgramNode;
  T0    : Cardinal;
begin
  if Assigned(FInterp) then Exit;  // already running

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
            FOutput.Lines.Add(Format('─── Done  (%d ms) ───', [GetTickCount - T0]));
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

// ---------------------------------------------------------------------------
//  EVENT HANDLERS
// ---------------------------------------------------------------------------

procedure TProjectTab.OnNew(Sender: TObject);
begin
  if not ConfirmDiscard then Exit;
  FEditor.Lines.Text := NEW_SOURCE;
  FCurrentFile       := '';
  FModified          := False;
  FOutput.Clear;
  UpdateTitleBar;
end;

procedure TProjectTab.OnOpen(Sender: TObject);
var
  Dlg : TOpenDialog;
begin
  if not ConfirmDiscard then Exit;
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Filter      := MDP_FILTER;
    Dlg.DefaultExt  := MDP_EXT;
    Dlg.Options     := [ofFileMustExist];
    if Dlg.Execute then
      LoadFile(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TProjectTab.OnSave(Sender: TObject);
begin
  if FCurrentFile = '' then
    OnSaveAs(Sender)
  else
    SaveFile(FCurrentFile);
end;

procedure TProjectTab.OnSaveAs(Sender: TObject);
var
  Dlg : TSaveDialog;
begin
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Filter     := MDP_FILTER;
    Dlg.DefaultExt := MDP_EXT;
    if FCurrentFile <> '' then
      Dlg.FileName := FCurrentFile;
    if Dlg.Execute then
      SaveFile(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TProjectTab.OnRun(Sender: TObject);
begin
  // Auto-save before running if we have a file
  if (FCurrentFile <> '') and FModified then
    SaveFile(FCurrentFile);
  RunCurrentSource;
end;

procedure TProjectTab.OnNewProject(Sender: TObject);
var
  ProjName    : string;
  ProjDir     : string;
  ProjFile    : string;
  MainProjPath: string;
  ProjSrc     : string;
  Dlg         : TSaveDialog;
  Ini         : TIniFile;
begin
  ProjName := InputBox('Project name:', 'New Project', 'MyProject');
  if ProjName = '' then Exit;

  // Ask where to save the project file
  Dlg            := TSaveDialog.Create(nil);
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

  ProjDir := ExtractFilePath(ProjFile);

  // Write the .mdproj file
  Ini := TIniFile.Create(ProjFile);
  try
    Ini.WriteString('Project', 'Name',        ProjName);
    Ini.WriteString('Project', 'Description', '');
    Ini.WriteString('Project', 'MainFile',    ProjName + '.mdp');
    Ini.WriteString('Project', 'Created',     DateTimeToStr(Now));
  finally
    Ini.Free;
  end;

  // Create the main source file
  MainProjPath := ProjDir + ProjName + '.mdp';
  ProjSrc :=
    '// ============================================================' + #13#10 +
    '// ' + UpperCase(ProjName) + #13#10 +
    '// Project: ' + ProjName + #13#10 +
    '// Created: ' + DateToStr(Now) + #13#10 +
    '// ============================================================' + #13#10 +
    'begin' + #13#10 +
    '  writeln(' + chr(39) + 'Hello from ' + ProjName + '!' + chr(39) + ');' + #13#10 +
    'end.';
  TFile.WriteAllText(MainProjPath, ProjSrc, TEncoding.UTF8);

  FProjectFile := ProjFile;
  FProjectName := ProjName;
  LoadFile(MainProjPath);
  MessageDlg('Project "' + ProjName + '" created!' + #13#10 +
             'Project file: ' + ProjFile, mtInformation, [mbOK], 0);
end;

procedure TProjectTab.OnOpenProject(Sender: TObject);
var
  Dlg         : TOpenDialog;
  Ini         : TIniFile;
  MainFile    : string;
  ProjDir     : string;
  FullProjPath: string;
begin
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Filter     := MPROJ_FILTER;
    Dlg.DefaultExt := MPROJ_EXT;
    Dlg.Options    := [ofFileMustExist];
    if not Dlg.Execute then Exit;

    Ini := TIniFile.Create(Dlg.FileName);
    try
      FProjectName := Ini.ReadString('Project', 'Name', '');
      MainFile     := Ini.ReadString('Project', 'MainFile', '');
    finally
      Ini.Free;
    end;

    FProjectFile := Dlg.FileName;
    ProjDir      := ExtractFilePath(Dlg.FileName);

    // Load the main source file
    if MainFile <> '' then
    begin
      FullProjPath := ProjDir + MainFile;
      if TFile.Exists(FullProjPath) then
        LoadFile(FullProjPath)
      else
        MessageDlg('Main file not found: ' + FullProjPath, mtWarning, [mbOK], 0);
    end;

    UpdateTitleBar;
  finally
    Dlg.Free;
  end;
end;

procedure TProjectTab.OnTreeDblClick(Sender: TObject);
var
  Node    : TTreeNode;
  Tag     : Integer;
  Ex      : TExampleProject;
  RecentI : Integer;
  TempDir : string;
  MainPath: string;
  MFI     : Integer;
  EF      : TExampleFile;
  FilePath: string;
begin
  Node := FTree.Selected;
  if not Assigned(Node) then Exit;

  Tag := Integer(Node.Data);

  if Tag >= 0 then
  begin
    // Example project
    if not ConfirmDiscard then Exit;
    Ex := FExamples.Items(Tag);
    FOutput.Clear;

    if Ex.IsMultiFile then
    begin
      // ---------------------------------------------------------------
      // Multi-file example: write all files to a temp folder, then
      // open the main file in the editor.
      // ---------------------------------------------------------------

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

      // If no file was marked IsMain, use the last one
      if MainPath = '' then
        MainPath := TPath.Combine(TempDir, Ex.Files[High(Ex.Files)].FileName);

      FEditor.Lines.Text := TFile.ReadAllText(MainPath, TEncoding.UTF8);
      FCurrentFile       := MainPath;
      FModified          := False;
      FLabelFile.Caption := 'Multi-file Example: ' + Ex.Name +
                            '  [' + IntToStr(Length(Ex.Files)) + ' files in ' + TempDir + ']';

      FOutput.Lines.Add('// Multi-file Example: ' + Ex.Name);
      FOutput.Lines.Add('// ' + Ex.Description);
      FOutput.Lines.Add('// Files written to: ' + TempDir);
      for MFI := 0 to High(Ex.Files) do
      begin
        if Ex.Files[MFI].IsMain then
          FOutput.Lines.Add('//   ' + Ex.Files[MFI].FileName + '  <-- main file')
        else
          FOutput.Lines.Add('//   ' + Ex.Files[MFI].FileName);
      end;
      FOutput.Lines.Add('//');
      FOutput.Lines.Add('// Click Run to execute. All library files are ready to import.');
      FOutput.Lines.Add('// Save As to save the main file to your own project folder.');
    end
    else
    begin
      // Single-file example
      FEditor.Lines.Text := Ex.Source;
      FCurrentFile       := '';
      FModified          := False;
      FLabelFile.Caption := 'Example: ' + Ex.Name + ' — Save As to keep your changes';
      FOutput.Lines.Add('// Example: ' + Ex.Name);
      FOutput.Lines.Add('// ' + Ex.Description);
      FOutput.Lines.Add('// Click Run to execute. Save As to keep your changes.');
    end;
  end
  else if Tag <= -100 then
  begin
    // Recent file
    RecentI := (-Tag) - 100;
    if (RecentI >= 0) and (RecentI < FRecent.Files.Count) then
    begin
      if not ConfirmDiscard then Exit;
      LoadFile(FRecent.Files[RecentI]);
    end;
  end;
end;

procedure TProjectTab.OnEditorChange(Sender: TObject);
begin
  SetModified(True);
end;

procedure TProjectTab.OnEditorKey(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  // Ctrl+S = Save
  if (Key = Ord('S')) and (ssCtrl in Shift) then
  begin
    OnSave(Sender);
    Key := 0;
  end
  // Ctrl+N = New
  else if (Key = Ord('N')) and (ssCtrl in Shift) then
  begin
    OnNew(Sender);
    Key := 0;
  end
  // Ctrl+O = Open
  else if (Key = Ord('O')) and (ssCtrl in Shift) then
  begin
    OnOpen(Sender);
    Key := 0;
  end
  // F5 = Run
  else if Key = VK_F5 then
  begin
    OnRun(Sender);
    Key := 0;
  end;
end;

procedure TProjectTab.OnNewLibrary(Sender: TObject);
var
  LibName  : string;
  Dlg      : TSaveDialog;
  Path     : string;
  FName    : string;
  Template : string;
begin
  LibName := InputBox('Library unit name:', 'New Library', 'MyUtils');
  if LibName = '' then Exit;

  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Title      := 'Save Library Unit';
    Dlg.Filter     := MDP_FILTER;
    Dlg.DefaultExt := MDP_EXT;
    Dlg.FileName   := LibName;
    if FCurrentFile <> '' then
      Dlg.InitialDir := ExtractFilePath(FCurrentFile);
    if not Dlg.Execute then Exit;
    Path  := Dlg.FileName;
    FName := ExtractFileName(Path);
  finally
    Dlg.Free;
  end;

  Template :=
    '// ============================================================' + #13#10 +
    '// ' + UpperCase(LibName) + ' - MiniDelphi Library Unit' + #13#10 +
    '// Created: ' + DateToStr(Now) + #13#10 +
    '//' + #13#10 +
    '// LIBRARY FILE: contains procedures/functions for other programs.' + #13#10 +
    '// Import in your main .mdp with:' + #13#10 +
    '//' + #13#10 +
    '//     uses' + #13#10 +
    '//       ' + chr(39) + FName + chr(39) + ';' + #13#10 +
    '//' + #13#10 +
    '// A library has NO begin..end block - only declarations.' + #13#10 +
    '// ============================================================' + #13#10 +
    '' + #13#10 +
    '// Example: rename and replace with your own routines' + #13#10 +
    'procedure SayHello(name: String);' + #13#10 +
    'begin' + #13#10 +
    '  writeln(' + chr(39) + 'Hello, ' + chr(39) + ', name, ' + chr(39) + '!' + chr(39) + ');' + #13#10 +
    'end;' + #13#10 +
    '' + #13#10 +
    'function Square(n: Integer): Integer;' + #13#10 +
    'begin' + #13#10 +
    '  Result := n * n;' + #13#10 +
    'end;';

  TFile.WriteAllText(Path, Template, TEncoding.UTF8);
  LoadFile(Path);
  MessageDlg('Library created: ' + FName + #13#10 +
             #13#10 +
             'Import in your program with:' + #13#10 +
             '  uses' + #13#10 +
             '    ' + chr(39) + FName + chr(39) + ';',
             mtInformation, [mbOK], 0);
end;


function IfThen(B: Boolean; const T, F: string): string;
begin
  if B then Result := T else Result := F;
end;

end.
