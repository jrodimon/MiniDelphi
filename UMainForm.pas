unit UMainForm;

// =============================================================================
// MiniDelphi Toy Compiler & Learning IDE
// Copyright (C) 2026 Nomidor Software, LLC.
// GPL v3 — see https://www.gnu.org/licenses/gpl-3.0.html
// =============================================================================

// =============================================================================
//  UMainForm.pas  -  VCL front-end for the MiniDelphi Toy Compiler
//
//  Skinned via VCL Styles (TStyleManager). See UTheme.pas for details.
// =============================================================================

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Math,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Menus, Vcl.ComCtrls, Vcl.Buttons, Vcl.Graphics,
  ULexer, UParser, UAST, UInterpreter, UValidator,
  ULearnTab, UProjectTab, UMacroTab, UFormBuilderTab,
  UExampleProjects, UAboutDialog, UTheme, UPreferencesDialog;

type
  TSnippet = record
    Name         : string;
    Body         : string;
    CaretFromEnd : Integer;
  end;

  TFormMain = class(TForm)
  private
    // Pages
    FPages          : TPageControl;
    FTabCompiler    : TTabSheet;
    FTabCalc        : TTabSheet;
    FTabLearn       : TTabSheet;
    FLearnTab       : TLearnTab;
    FTabProject     : TTabSheet;
    FProjectTab     : TProjectTab;
    FTabForms       : TTabSheet;
    FFormBuilderTab : TFormBuilderTab;
    FTabMacro       : TTabSheet;
    FMacroTab       : TMacroTab;

    // Compiler tab
    FToolPanel      : TPanel;
    FBtnRun         : TButton;
    FBtnClear       : TButton;
    FStatusLabel    : TLabel;

    FSplitterMain   : TSplitter;
    FLeftPanel      : TPanel;
    FRightPanel     : TPanel;

    FLabelSrc       : TLabel;
    FMemoSrc        : TMemo;

    FLabelOut       : TLabel;
    FMemoOut        : TMemo;
    FLabelInput     : TLabel;
    FEditInput      : TEdit;

    FSplitterBot    : TSplitter;
    FBottomPanel    : TPanel;
    FLabelTok       : TLabel;
    FMemoTok        : TMemo;

    FSnippetMenu    : TPopupMenu;

    // Calculator tab
    FCalcOuter      : TPanel;
    FCalcHistory    : TMemo;
    FCalcInputPanel : TPanel;
    FCalcLabel      : TLabel;
    FCalcEdit       : TEdit;
    FCalcBtn        : TButton;
    FCalcHintLabel  : TLabel;

    procedure BuildMainMenu;
    procedure BuildCompilerTab;
    procedure BuildCalcTab;
    procedure BuildSnippetMenu;
    procedure InsertSnippet(const Body: string; CaretFromEnd: Integer);
    procedure SetStatus(const Msg: string; IsError: Boolean = False);
    procedure HighlightErrorLine(Line: Integer);
    procedure ClearHighlight;
    procedure ShowValidationResults(V: TValidator; ParseErr: string;
                                    ParseLine, ParseCol: Integer);
    procedure ShowTokens(Tokens: TList<TToken>);
    procedure EvalExpression;
    procedure GoToProjectsTab;
    procedure GoToCompilerTab;
    procedure GoToFormsTab;

    procedure ApplyTheme;
    procedure WMSettingChange(var Msg: TMessage); message WM_SETTINGCHANGE;
    procedure OnProjectChangedHandler(Sender: TObject);

    // Compiler tab handlers
    procedure OnLex(Sender: TObject);
    procedure OnParse(Sender: TObject);
    procedure OnRun(Sender: TObject);
    procedure OnClear(Sender: TObject);
    procedure OnExampleClick(Sender: TObject);
    procedure OnSnippetClick(Sender: TObject);

    // File menu
    procedure OnMenuNewFile(Sender: TObject);
    procedure OnMenuOpenFile(Sender: TObject);
    procedure OnMenuSave(Sender: TObject);
    procedure OnMenuSaveAs(Sender: TObject);
    procedure OnMenuNewProject(Sender: TObject);
    procedure OnMenuOpenProject(Sender: TObject);
    procedure OnMenuCloseProject(Sender: TObject);
    procedure OnMenuNewForm(Sender: TObject);
    procedure OnMenuOpenForm(Sender: TObject);
    procedure OnFileExit(Sender: TObject);

    // View menu
    procedure OnViewProjectSource(Sender: TObject);
    procedure OnViewShowTokens(Sender: TObject);
    procedure OnViewShowAST(Sender: TObject);
    procedure OnViewPreferences(Sender: TObject);

    // Help menu
    procedure OnAbout(Sender: TObject);

    // Calculator handlers
    procedure OnCalcBtn(Sender: TObject);
    procedure OnCalcKey(Sender: TObject; var Key: Char);
    procedure OnCalcSpecialKey(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

const
  EXAMPLE_COUNT = 8;

  EXAMPLE_NAMES : array[0..EXAMPLE_COUNT-1] of string = (
    'Hello World',
    'FizzBuzz',
    'Fibonacci',
    'Factorial (recursive)',
    'Primes (trial division)',
    'String manipulation',
    'case (integer)',
    'caseof (string switch)'
  );

  EXAMPLE_CODE : array[0..EXAMPLE_COUNT-1] of string = (

    'program HelloWorld;'                                            + #13#10 +
    ''                                                               + #13#10 +
    'begin'                                                          + #13#10 +
    '  writeln(''Hello, World!'');'                                  + #13#10 +
    '  writeln(''Welcome to MiniDelphi!'');'                         + #13#10 +
    'end.',

    'program FizzBuzz;'                                              + #13#10 +
    ''                                                               + #13#10 +
    'var'                                                            + #13#10 +
    '  i : Integer;'                                                 + #13#10 +
    ''                                                               + #13#10 +
    'begin'                                                          + #13#10 +
    '  for i := 1 to 30 do'                                          + #13#10 +
    '  begin'                                                        + #13#10 +
    '    if (i mod 15 = 0) then'                                     + #13#10 +
    '      writeln(''FizzBuzz'')'                                    + #13#10 +
    '    else if (i mod 3 = 0) then'                                 + #13#10 +
    '      writeln(''Fizz'')'                                        + #13#10 +
    '    else if (i mod 5 = 0) then'                                 + #13#10 +
    '      writeln(''Buzz'')'                                        + #13#10 +
    '    else'                                                       + #13#10 +
    '      writeln(i);'                                              + #13#10 +
    '  end;'                                                         + #13#10 +
    'end.',

    'program Fibonacci;'                                             + #13#10 +
    ''                                                               + #13#10 +
    'var'                                                            + #13#10 +
    '  a, b, c, i : Integer;'                                        + #13#10 +
    ''                                                               + #13#10 +
    'begin'                                                          + #13#10 +
    '  writeln(''Fibonacci sequence:'');'                            + #13#10 +
    '  a := 0;  b := 1;'                                             + #13#10 +
    '  writeln(a);  writeln(b);'                                     + #13#10 +
    '  for i := 1 to 15 do'                                          + #13#10 +
    '  begin'                                                        + #13#10 +
    '    c := a + b;  writeln(c);  a := b;  b := c;'                 + #13#10 +
    '  end;'                                                         + #13#10 +
    'end.',

    'program Factorial;'                                             + #13#10 +
    ''                                                               + #13#10 +
    'function Fact(n: Integer): Integer;'                            + #13#10 +
    'begin'                                                          + #13#10 +
    '  if n <= 1 then Result := 1'                                   + #13#10 +
    '  else Result := n * Fact(n - 1);'                              + #13#10 +
    'end;'                                                           + #13#10 +
    ''                                                               + #13#10 +
    'var i : Integer;'                                               + #13#10 +
    'begin'                                                          + #13#10 +
    '  for i := 0 to 12 do writeln(i, ''! = '', Fact(i));'           + #13#10 +
    'end.',

    'program Primes;'                                                + #13#10 +
    ''                                                               + #13#10 +
    'function IsPrime(n: Integer): Boolean;'                         + #13#10 +
    'var i : Integer;'                                               + #13#10 +
    'begin'                                                          + #13#10 +
    '  if n < 2 then begin Result := false; exit; end;'              + #13#10 +
    '  i := 2;  Result := true;'                                     + #13#10 +
    '  while i * i <= n do'                                          + #13#10 +
    '  begin'                                                        + #13#10 +
    '    if n mod i = 0 then begin Result := false; exit; end;'      + #13#10 +
    '    inc(i);'                                                    + #13#10 +
    '  end;'                                                         + #13#10 +
    'end;'                                                           + #13#10 +
    ''                                                               + #13#10 +
    'var n, count : Integer;'                                        + #13#10 +
    'begin'                                                          + #13#10 +
    '  writeln(''Primes up to 100:'');'                              + #13#10 +
    '  count := 0;'                                                  + #13#10 +
    '  for n := 2 to 100 do'                                         + #13#10 +
    '    if IsPrime(n) then begin write(n); write('' ''); inc(count); end;' + #13#10 +
    '  writeln('''');'                                               + #13#10 +
    '  writeln(''Total: '', count, '' primes'');'                    + #13#10 +
    'end.',

    'program Strings;'                                               + #13#10 +
    ''                                                               + #13#10 +
    'var'                                                            + #13#10 +
    '  s, t : String;'                                               + #13#10 +
    ''                                                               + #13#10 +
    'begin'                                                          + #13#10 +
    '  s := ''Hello, MiniDelphi!'';'                                 + #13#10 +
    '  writeln(''Original  : '', s);'                                + #13#10 +
    '  writeln(''Length    : '', length(s));'                        + #13#10 +
    '  writeln(''Upper     : '', uppercase(s));'                     + #13#10 +
    '  writeln(''Lower     : '', lowercase(s));'                     + #13#10 +
    '  t := copy(s, 1, 5);'                                          + #13#10 +
    '  writeln(''First 5   : '', t);'                                + #13#10 +
    '  writeln(''Pos Mini  : '', pos(''Mini'', s));'                 + #13#10 +
    '  writeln(''Concat    : '', s + '' (and more!)'');'             + #13#10 +
    'end.',

    'program CaseDemo;'                                              + #13#10 +
    'var score : Integer;'                                           + #13#10 +
    'begin'                                                          + #13#10 +
    '  score := 85;'                                                 + #13#10 +
    '  writeln(''Score: '', score);'                                 + #13#10 +
    '  write(''Grade: '');'                                          + #13#10 +
    '  case score div 10 of'                                         + #13#10 +
    '    10, 9 : writeln(''A - Excellent'');'                        + #13#10 +
    '    8     : writeln(''B - Good'');'                             + #13#10 +
    '    7     : writeln(''C - Average'');'                          + #13#10 +
    '    6     : writeln(''D - Below average'');'                    + #13#10 +
    '  else'                                                         + #13#10 +
    '    writeln(''F - Fail'');'                                     + #13#10 +
    '  end;'                                                         + #13#10 +
    'end.',

    'program CaseOfDemo;'                                            + #13#10 +
    ''                                                               + #13#10 +
    'procedure Describe(animal: String);'                            + #13#10 +
    'begin'                                                          + #13#10 +
    '  write(animal, '' -> '');'                                     + #13#10 +
    '  caseof animal of'                                             + #13#10 +
    '    ''cat''            : writeln(''Meow!'');'                   + #13#10 +
    '    ''dog'', ''hound'' : writeln(''Woof!'');'                   + #13#10 +
    '    ''cow''            : writeln(''Moo!'');'                    + #13#10 +
    '  else'                                                         + #13#10 +
    '    writeln(''Unknown!'');'                                     + #13#10 +
    '  end;'                                                         + #13#10 +
    'end;'                                                           + #13#10 +
    ''                                                               + #13#10 +
    'begin'                                                          + #13#10 +
    '  Describe(''cat'');'                                           + #13#10 +
    '  Describe(''dog'');'                                           + #13#10 +
    '  Describe(''cow'');'                                           + #13#10 +
    '  Describe(''unicorn'');'                                       + #13#10 +
    'end.'
  );

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

constructor TFormMain.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  // VCL Styles needs to be set before any controls are created or it leaves
  // some unstyled. Theme.Load picks the right style and applies it.
  Theme.Load;

  Caption   := 'MiniDelphi Toy Compiler';
  Width     := 1180;
  Height    := 780;
  Position  := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 10;

  BuildMainMenu;

  FPages                   := TPageControl.Create(Self);
  FPages.Parent            := Self;
  FPages.Align             := alClient;

  FTabCompiler             := TTabSheet.Create(FPages);
  FTabCompiler.PageControl := FPages;
  FTabCompiler.Caption     := '  Compiler  ';

  FTabCalc                 := TTabSheet.Create(FPages);
  FTabCalc.PageControl     := FPages;
  FTabCalc.Caption         := '  Calculator  ';

  FTabLearn                := TTabSheet.Create(FPages);
  FTabLearn.PageControl    := FPages;
  FTabLearn.Caption        := '  Learn Delphi  ';

  FTabProject              := TTabSheet.Create(FPages);
  FTabProject.PageControl  := FPages;
  FTabProject.Caption      := '  Projects  ';

  FTabForms                := TTabSheet.Create(FPages);
  FTabForms.PageControl    := FPages;
  FTabForms.Caption        := '  Forms  ';

  FTabMacro                := TTabSheet.Create(FPages);
  FTabMacro.PageControl    := FPages;
  FTabMacro.Caption        := '  Macros  ';

  BuildCompilerTab;
  BuildCalcTab;
  BuildSnippetMenu;
  FLearnTab       := TLearnTab.Create(FTabLearn);
  FProjectTab     := TProjectTab.Create(FTabProject);
  FFormBuilderTab := TFormBuilderTab.Create(FTabForms);
  FMacroTab       := TMacroTab.Create(FTabMacro);

  FProjectTab.OnProjectChanged := OnProjectChangedHandler;

  Theme.Subscribe(ApplyTheme);

  FMemoSrc.Lines.Text := EXAMPLE_CODE[0];
  SetStatus('Ready -- right-click in the editor for snippets, or pick Help > Examples.');
end;

destructor TFormMain.Destroy;
begin
  Theme.Unsubscribe(ApplyTheme);
  inherited;
end;

procedure TFormMain.WMSettingChange(var Msg: TMessage);
var S : string;
begin
  inherited;
  if Msg.LParam <> 0 then
  begin
    S := PChar(Msg.LParam);
    if SameText(S, 'ImmersiveColorSet') then
      Theme.ReevaluateFromWindows;
  end;
end;

procedure TFormMain.ApplyTheme;
begin
  // VCL Styles repaints every control automatically.
  // Hook left here for future custom-paint needs.
  Invalidate;
end;

procedure TFormMain.OnProjectChangedHandler(Sender: TObject);
begin
  if not Assigned(FFormBuilderTab) then Exit;
  if FProjectTab.HasProject then
    FFormBuilderTab.SetProjectFolder(ExtractFilePath(FProjectTab.ProjectFile))
  else
    FFormBuilderTab.SetProjectFolder('');
end;

procedure TFormMain.BuildMainMenu;

  function MakeItem(Owner: TMenuItem; const Cap: string;
                    Handler: TNotifyEvent; SC: TShortCut = 0): TMenuItem;
  begin
    Result := TMenuItem.Create(Owner);
    Result.Caption := Cap;
    if Assigned(Handler) then Result.OnClick := Handler;
    if SC <> 0 then Result.ShortCut := SC;
    Owner.Add(Result);
  end;

  function MakeSep(Owner: TMenuItem): TMenuItem;
  begin
    Result := TMenuItem.Create(Owner);
    Result.Caption := '-';
    Owner.Add(Result);
  end;

var
  MM       : TMainMenu;
  MIFile   : TMenuItem;
  MIView   : TMenuItem;
  MIHelp   : TMenuItem;
  MIExSub  : TMenuItem;
  Ex       : TMenuItem;
  I        : Integer;
begin
  MM := TMainMenu.Create(Self);

  MIFile := TMenuItem.Create(MM);
  MIFile.Caption := '&File';
  MM.Items.Add(MIFile);

  MakeItem(MIFile, '&New File',         OnMenuNewFile,
           ShortCut(Ord('N'), [ssCtrl]));
  MakeItem(MIFile, '&Open File...',     OnMenuOpenFile,
           ShortCut(Ord('O'), [ssCtrl]));
  MakeItem(MIFile, '&Save',             OnMenuSave,
           ShortCut(Ord('S'), [ssCtrl]));
  MakeItem(MIFile, 'Save &As...',       OnMenuSaveAs);
  MakeSep (MIFile);
  MakeItem(MIFile, 'New &Project...',   OnMenuNewProject);
  MakeItem(MIFile, 'Open Pr&oject...',  OnMenuOpenProject);
  MakeItem(MIFile, '&Close Project',    OnMenuCloseProject);
  MakeSep (MIFile);
  MakeItem(MIFile, 'N&ew Form...',      OnMenuNewForm);
  MakeItem(MIFile, 'Op&en Form...',     OnMenuOpenForm);
  MakeSep (MIFile);
  MakeItem(MIFile, 'E&xit',             OnFileExit,
           ShortCut(VK_F4, [ssAlt]));

  MIView := TMenuItem.Create(MM);
  MIView.Caption := '&View';
  MM.Items.Add(MIView);

  MakeItem(MIView, 'View &Project Source', OnViewProjectSource,
           ShortCut(VK_F11, [ssCtrl]));
  MakeSep (MIView);
  MakeItem(MIView, 'Show &Tokens',         OnViewShowTokens);
  MakeItem(MIView, 'Show &AST',            OnViewShowAST);
  MakeSep (MIView);
  MakeItem(MIView, 'P&references...',      OnViewPreferences);

  MIHelp := TMenuItem.Create(MM);
  MIHelp.Caption := '&Help';
  MM.Items.Add(MIHelp);

  MIExSub := TMenuItem.Create(MIHelp);
  MIExSub.Caption := '&Examples';
  MIHelp.Add(MIExSub);

  for I := 0 to EXAMPLE_COUNT - 1 do
  begin
    Ex := TMenuItem.Create(MIExSub);
    Ex.Caption := EXAMPLE_NAMES[I];
    Ex.Tag     := I;
    Ex.OnClick := OnExampleClick;
    MIExSub.Add(Ex);
  end;

  MakeSep (MIHelp);
  MakeItem(MIHelp, '&About MiniDelphi...', OnAbout);

  Self.Menu := MM;
end;

procedure TFormMain.GoToProjectsTab;
begin
  if FPages.ActivePage <> FTabProject then FPages.ActivePage := FTabProject;
end;

procedure TFormMain.GoToCompilerTab;
begin
  if FPages.ActivePage <> FTabCompiler then FPages.ActivePage := FTabCompiler;
end;

procedure TFormMain.GoToFormsTab;
begin
  if FPages.ActivePage <> FTabForms then FPages.ActivePage := FTabForms;
end;

procedure TFormMain.OnMenuNewFile(Sender: TObject);
begin
  GoToProjectsTab;
  if Assigned(FProjectTab) then FProjectTab.DoNewFile;
end;

procedure TFormMain.OnMenuOpenFile(Sender: TObject);
begin
  GoToProjectsTab;
  if Assigned(FProjectTab) then FProjectTab.DoOpenFile;
end;

procedure TFormMain.OnMenuSave(Sender: TObject);
begin
  if FPages.ActivePage = FTabForms then
  begin
    if Assigned(FFormBuilderTab) then FFormBuilderTab.DoSave;
  end
  else
  begin
    GoToProjectsTab;
    if Assigned(FProjectTab) then FProjectTab.DoSave;
  end;
end;

procedure TFormMain.OnMenuSaveAs(Sender: TObject);
begin
  if FPages.ActivePage = FTabForms then
  begin
    if Assigned(FFormBuilderTab) then FFormBuilderTab.DoSaveAs;
  end
  else
  begin
    GoToProjectsTab;
    if Assigned(FProjectTab) then FProjectTab.DoSaveAs;
  end;
end;

procedure TFormMain.OnMenuNewProject(Sender: TObject);
begin
  GoToProjectsTab;
  if Assigned(FProjectTab) then FProjectTab.DoNewProject;
end;

procedure TFormMain.OnMenuOpenProject(Sender: TObject);
begin
  GoToProjectsTab;
  if Assigned(FProjectTab) then FProjectTab.DoOpenProject;
end;

procedure TFormMain.OnMenuCloseProject(Sender: TObject);
begin
  GoToProjectsTab;
  if Assigned(FProjectTab) then FProjectTab.DoCloseProject;
end;

procedure TFormMain.OnMenuNewForm(Sender: TObject);
begin
  GoToFormsTab;
  if Assigned(FFormBuilderTab) then FFormBuilderTab.DoNew;
end;

procedure TFormMain.OnMenuOpenForm(Sender: TObject);
begin
  GoToFormsTab;
  if Assigned(FFormBuilderTab) then FFormBuilderTab.DoOpen;
end;

procedure TFormMain.OnFileExit(Sender: TObject);
begin
  Close;
end;

procedure TFormMain.OnViewProjectSource(Sender: TObject);
begin
  GoToProjectsTab;
  if Assigned(FProjectTab) then FProjectTab.ViewProjectSource;
end;

procedure TFormMain.OnViewShowTokens(Sender: TObject);
begin
  GoToCompilerTab;
  OnLex(Sender);
end;

procedure TFormMain.OnViewShowAST(Sender: TObject);
begin
  GoToCompilerTab;
  OnParse(Sender);
end;

procedure TFormMain.OnViewPreferences(Sender: TObject);
begin
  ShowPreferencesDialog;
end;

procedure TFormMain.OnAbout(Sender: TObject);
begin
  ShowAboutDialog;
end;

// =============================================================================
//  COMPILER TAB
// =============================================================================

procedure TFormMain.BuildCompilerTab;
const
  BTN_W = 90;
  BTN_H = 30;
  PAD   = 8;
var
  X : Integer;
begin
  FToolPanel            := TPanel.Create(Self);
  FToolPanel.Parent     := FTabCompiler;
  FToolPanel.Align      := alTop;
  FToolPanel.Height     := BTN_H + PAD * 2;
  FToolPanel.BevelOuter := bvNone;

  X := PAD;

  FBtnRun          := TButton.Create(FToolPanel);
  FBtnRun.Parent   := FToolPanel;
  FBtnRun.Caption  := 'Run';
  FBtnRun.Left     := X;  FBtnRun.Top := PAD;
  FBtnRun.Width    := BTN_W;  FBtnRun.Height := BTN_H;
  FBtnRun.OnClick  := OnRun;
  FBtnRun.Hint     := 'Run the source above (F5)';
  FBtnRun.ShowHint := True;
  Inc(X, BTN_W + PAD);

  FBtnClear          := TButton.Create(FToolPanel);
  FBtnClear.Parent   := FToolPanel;
  FBtnClear.Caption  := 'Clear';
  FBtnClear.Left     := X;  FBtnClear.Top := PAD;
  FBtnClear.Width    := BTN_W;  FBtnClear.Height := BTN_H;
  FBtnClear.OnClick  := OnClear;
  FBtnClear.Hint     := 'Clear source, output, and tokens';
  FBtnClear.ShowHint := True;
  Inc(X, BTN_W + PAD * 3);

  FStatusLabel            := TLabel.Create(FToolPanel);
  FStatusLabel.Parent     := FToolPanel;
  FStatusLabel.Left       := X;
  FStatusLabel.Top        := PAD + 8;
  FStatusLabel.Width      := 700;
  FStatusLabel.Caption    := '';

  FBottomPanel              := TPanel.Create(Self);
  FBottomPanel.Parent       := FTabCompiler;
  FBottomPanel.Align        := alBottom;
  FBottomPanel.Height       := 170;
  FBottomPanel.BevelOuter   := bvNone;

  FSplitterBot              := TSplitter.Create(Self);
  FSplitterBot.Parent       := FTabCompiler;
  FSplitterBot.Align        := alBottom;
  FSplitterBot.Height       := 4;

  FLabelTok                 := TLabel.Create(FBottomPanel);
  FLabelTok.Parent          := FBottomPanel;
  FLabelTok.Align           := alTop;
  FLabelTok.Caption         := '   Token Stream';
  FLabelTok.Font.Style      := [fsBold];
  FLabelTok.Height          := 24;

  FMemoTok                  := TMemo.Create(FBottomPanel);
  FMemoTok.Parent           := FBottomPanel;
  FMemoTok.Align            := alClient;
  FMemoTok.ReadOnly         := True;
  FMemoTok.ScrollBars       := ssBoth;
  FMemoTok.WordWrap         := False;
  FMemoTok.Font.Name        := 'Consolas';
  FMemoTok.Font.Size        := 9;

  FLeftPanel                := TPanel.Create(Self);
  FLeftPanel.Parent         := FTabCompiler;
  FLeftPanel.Align          := alLeft;
  FLeftPanel.Width          := 540;
  FLeftPanel.BevelOuter     := bvNone;

  FLabelSrc                 := TLabel.Create(FLeftPanel);
  FLabelSrc.Parent          := FLeftPanel;
  FLabelSrc.Align           := alTop;
  FLabelSrc.Caption         := '   Source   (right-click for snippets,  F5 to run)';
  FLabelSrc.Font.Style      := [fsBold];
  FLabelSrc.Height          := 24;

  FMemoSrc                  := TMemo.Create(FLeftPanel);
  FMemoSrc.Parent           := FLeftPanel;
  FMemoSrc.Align            := alClient;
  FMemoSrc.ScrollBars       := ssBoth;
  FMemoSrc.WordWrap         := False;
  FMemoSrc.Font.Name        := 'Consolas';
  FMemoSrc.Font.Size        := 10;

  FSplitterMain             := TSplitter.Create(Self);
  FSplitterMain.Parent      := FTabCompiler;
  FSplitterMain.Align       := alLeft;
  FSplitterMain.Width       := 4;

  FRightPanel               := TPanel.Create(Self);
  FRightPanel.Parent        := FTabCompiler;
  FRightPanel.Align         := alClient;
  FRightPanel.BevelOuter    := bvNone;

  FLabelOut                 := TLabel.Create(FRightPanel);
  FLabelOut.Parent          := FRightPanel;
  FLabelOut.Align           := alTop;
  FLabelOut.Caption         := '   Output';
  FLabelOut.Font.Style      := [fsBold];
  FLabelOut.Height          := 24;

  FLabelInput               := TLabel.Create(FRightPanel);
  FLabelInput.Parent        := FRightPanel;
  FLabelInput.Align         := alBottom;
  FLabelInput.Caption       := '   readln input (used by your program):';
  FLabelInput.Height        := 22;

  FEditInput                := TEdit.Create(FRightPanel);
  FEditInput.Parent         := FRightPanel;
  FEditInput.Align          := alBottom;
  FEditInput.Height         := 26;
  FEditInput.Font.Name      := 'Consolas';

  FMemoOut                  := TMemo.Create(FRightPanel);
  FMemoOut.Parent           := FRightPanel;
  FMemoOut.Align            := alClient;
  FMemoOut.ReadOnly         := True;
  FMemoOut.ScrollBars       := ssBoth;
  FMemoOut.WordWrap         := False;
  FMemoOut.Font.Name        := 'Consolas';
  FMemoOut.Font.Size        := 10;
end;

procedure TFormMain.BuildSnippetMenu;
var
  I    : Integer;
  Item : TMenuItem;
  Sep  : TMenuItem;
begin
  FSnippetMenu := TPopupMenu.Create(Self);

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

  FMemoSrc.PopupMenu := FSnippetMenu;
end;

procedure TFormMain.InsertSnippet(const Body: string; CaretFromEnd: Integer);
var
  StartPos : Integer;
begin
  StartPos := FMemoSrc.SelStart;
  FMemoSrc.SelText   := Body;
  FMemoSrc.SelStart  := StartPos + Length(Body) - CaretFromEnd;
  FMemoSrc.SelLength := 0;
  FMemoSrc.SetFocus;
end;

procedure TFormMain.OnSnippetClick(Sender: TObject);
var
  Idx : Integer;
begin
  Idx := (Sender as TMenuItem).Tag;
  if (Idx >= 0) and (Idx <= High(SNIPPETS)) then
    InsertSnippet(SNIPPETS[Idx].Body, SNIPPETS[Idx].CaretFromEnd);
end;

// =============================================================================
//  CALCULATOR TAB
// =============================================================================

procedure TFormMain.BuildCalcTab;
const
  HINT =
    '   Operators: + - * / div mod     ' +
    'Functions: abs  sqr  sqrt  power(x,y)  round  trunc  ' +
    'sin  cos  ln  exp  pi  max(a,b)  min(a,b)';
begin
  FCalcOuter            := TPanel.Create(Self);
  FCalcOuter.Parent     := FTabCalc;
  FCalcOuter.Align      := alClient;
  FCalcOuter.BevelOuter := bvNone;

  FCalcHintLabel            := TLabel.Create(FCalcOuter);
  FCalcHintLabel.Parent     := FCalcOuter;
  FCalcHintLabel.Align      := alTop;
  FCalcHintLabel.Height     := 26;
  FCalcHintLabel.Caption    := HINT;

  FCalcInputPanel             := TPanel.Create(FCalcOuter);
  FCalcInputPanel.Parent      := FCalcOuter;
  FCalcInputPanel.Align       := alBottom;
  FCalcInputPanel.Height      := 50;
  FCalcInputPanel.BevelOuter  := bvNone;

  FCalcLabel                  := TLabel.Create(FCalcInputPanel);
  FCalcLabel.Parent           := FCalcInputPanel;
  FCalcLabel.Caption          := ' >';
  FCalcLabel.Font.Name        := 'Consolas';
  FCalcLabel.Font.Size        := 16;
  FCalcLabel.Left             := 8;
  FCalcLabel.Top              := 12;

  FCalcEdit                   := TEdit.Create(FCalcInputPanel);
  FCalcEdit.Parent            := FCalcInputPanel;
  FCalcEdit.Left              := 32;
  FCalcEdit.Top               := 10;
  FCalcEdit.Height            := 30;
  FCalcEdit.Width             := FCalcInputPanel.Width - 104;
  FCalcEdit.Anchors           := [akLeft, akTop, akRight];
  FCalcEdit.Font.Name         := 'Consolas';
  FCalcEdit.Font.Size         := 13;
  FCalcEdit.OnKeyPress        := OnCalcKey;
  FCalcEdit.OnKeyDown         := OnCalcSpecialKey;

  FCalcBtn                    := TButton.Create(FCalcInputPanel);
  FCalcBtn.Parent             := FCalcInputPanel;
  FCalcBtn.Caption            := '=';
  FCalcBtn.Font.Name          := 'Consolas';
  FCalcBtn.Font.Size          := 14;
  FCalcBtn.Width              := 56;
  FCalcBtn.Height             := 30;
  FCalcBtn.Top                := 10;
  FCalcBtn.Anchors            := [akTop, akRight];
  FCalcBtn.Left               := FCalcInputPanel.Width - 64;
  FCalcBtn.OnClick            := OnCalcBtn;

  FCalcHistory                := TMemo.Create(FCalcOuter);
  FCalcHistory.Parent         := FCalcOuter;
  FCalcHistory.Align          := alClient;
  FCalcHistory.ReadOnly       := True;
  FCalcHistory.ScrollBars     := ssVertical;
  FCalcHistory.WordWrap       := False;
  FCalcHistory.Font.Name      := 'Consolas';
  FCalcHistory.Font.Size      := 12;

  with FCalcHistory.Lines do
  begin
    Add('   MiniDelphi Calculator');
    Add('   -------------------------------------');
    Add('   Type any expression and press Enter.');
    Add('');
  end;
end;

procedure TFormMain.EvalExpression;
var
  Raw, Wrapped, Answer : string;
  Lex     : TLexer;
  Par     : TParser;
  Prog    : TProgramNode;
  Interp  : TInterpreter;
  Output  : TStringList;
begin
  Raw := Trim(FCalcEdit.Text);
  if Raw = '' then Exit;

  Wrapped := 'begin writeln(' + Raw + '); end.';

  Output := TStringList.Create;
  try
    try
      Lex := TLexer.Create(Wrapped);
      try
        Lex.Tokenise;
        Par := TParser.Create(Lex.Tokens);
        try
          Prog := Par.Parse;
          try
            Interp := TInterpreter.Create(Prog, Output);
            try
              Interp.Run;
            finally
              Interp.Free;
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

      if Output.Count > 0 then Answer := Output[0]
      else Answer := '(no result)';

      FCalcHistory.Lines.Add('   > ' + Raw);
      FCalcHistory.Lines.Add('     = ' + Answer);
      FCalcHistory.Lines.Add('');

    except
      on E: Exception do
      begin
        FCalcHistory.Lines.Add('   > ' + Raw);
        FCalcHistory.Lines.Add('     Error: ' + E.Message);
        FCalcHistory.Lines.Add('');
      end;
    end;
  finally
    Output.Free;
  end;

  FCalcHistory.Perform(WM_VSCROLL, SB_BOTTOM, 0);
  FCalcEdit.SelectAll;
end;

procedure TFormMain.OnCalcBtn(Sender: TObject);
begin
  EvalExpression;
end;

procedure TFormMain.OnCalcKey(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    EvalExpression;
  end;
end;

procedure TFormMain.OnCalcSpecialKey(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = Ord('A')) and (ssCtrl in Shift) then
    FCalcEdit.SelectAll;
end;

procedure TFormMain.SetStatus(const Msg: string; IsError: Boolean);
begin
  FStatusLabel.Caption := Msg;
  if IsError then FStatusLabel.Font.Color := clRed
  else FStatusLabel.Font.Color := clDefault;
end;

procedure TFormMain.ShowTokens(Tokens: TList<TToken>);
var
  Tok : TToken;
  TI  : Integer;
begin
  FMemoTok.Lines.BeginUpdate;
  try
    FMemoTok.Clear;
    for TI := 0 to Tokens.Count - 1 do
    begin
      Tok := Tokens[TI];
      if Tok.Kind = tkEOF then Break;
      FMemoTok.Lines.Add(Format('[%-14s]  %-20s  line %-3d  col %d',
        [TLexer.TokenKindName(Tok.Kind),
         QuotedStr(Tok.Value), Tok.Line, Tok.Col]));
    end;
  finally
    FMemoTok.Lines.EndUpdate;
  end;
end;

procedure TFormMain.OnLex(Sender: TObject);
var
  Lex : TLexer;
begin
  FMemoTok.Clear;  FMemoOut.Clear;
  try
    Lex := TLexer.Create(FMemoSrc.Lines.Text);
    try
      Lex.Tokenise;
      ShowTokens(Lex.Tokens);
      SetStatus(Format('Lex OK -- %d tokens', [Lex.Tokens.Count]));
    finally
      Lex.Free;
    end;
  except
    on E: Exception do
    begin
      FMemoOut.Lines.Add('LEX ERROR: ' + E.Message);
      SetStatus('Lex failed.', True);
    end;
  end;
end;

procedure TFormMain.OnParse(Sender: TObject);
var
  Lex    : TLexer;
  Par    : TParser;
  Prog   : TProgramNode;
  R      : TRoutineDecl;
  D      : TVarDecl;
  AstOut : TStringList;
  GI, RI : Integer;
begin
  FMemoOut.Clear;  FMemoTok.Clear;
  AstOut := TStringList.Create;
  try
    Lex := TLexer.Create(FMemoSrc.Lines.Text);
    try
      Lex.Tokenise;
      ShowTokens(Lex.Tokens);
      Par := TParser.Create(Lex.Tokens);
      try
        Prog := Par.Parse;
        try
          AstOut.Add('=== AST SUMMARY ===');
          if Prog.ProgramName <> '' then
            AstOut.Add('Program : ' + Prog.ProgramName)
          else
            AstOut.Add('Program : (unnamed)');
          AstOut.Add('');
          AstOut.Add(Format('Global vars (%d):', [Prog.Globals.Count]));
          for GI := 0 to Prog.Globals.Count - 1 do
          begin
            D := Prog.Globals[GI];
            AstOut.Add('  var ' + D.Name + ' : ' + D.TypeName);
          end;
          AstOut.Add('');
          AstOut.Add(Format('Routines (%d):', [Prog.Routines.Count]));
          for RI := 0 to Prog.Routines.Count - 1 do
          begin
            R := Prog.Routines[RI];
            if R.ReturnType <> '' then
              AstOut.Add(Format('  function  %s : %s  (%d params, %d locals)',
                [R.Name, R.ReturnType, R.Params.Count, R.Locals.Count]))
            else
              AstOut.Add(Format('  procedure %s  (%d params, %d locals)',
                [R.Name, R.Params.Count, R.Locals.Count]));
          end;
          AstOut.Add('');
          if Assigned(Prog.MainBlock) then
            AstOut.Add(Format('Main block: %d statement(s)',
              [Prog.MainBlock.Stmts.Count]))
          else
            AstOut.Add('(no main block)');
          AstOut.Add('');
          AstOut.Add('Parse completed successfully.');
          FMemoOut.Lines.Assign(AstOut);
          SetStatus(Format('Parse OK -- %d routines, %d globals',
            [Prog.Routines.Count, Prog.Globals.Count]));
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
      FMemoOut.Lines.Add('PARSE ERROR: ' + E.Message);
      SetStatus('Parse failed.', True);
    end;
  end;
  AstOut.Free;
end;

procedure TFormMain.HighlightErrorLine(Line: Integer);
var
  CharPos, LineLen, L : Integer;
begin
  if (Line < 1) or (Line > FMemoSrc.Lines.Count) then Exit;
  CharPos := 0;
  for L := 0 to Line - 2 do
    CharPos := CharPos + Length(FMemoSrc.Lines[L]) + 2;
  LineLen := Length(FMemoSrc.Lines[Line - 1]);
  FMemoSrc.SelStart  := CharPos;
  FMemoSrc.SelLength := LineLen;
  FMemoSrc.Perform(EM_SCROLLCARET, 0, 0);
  FMemoSrc.SetFocus;
end;

procedure TFormMain.ClearHighlight;
begin
  FMemoSrc.SelLength := 0;
end;

procedure TFormMain.ShowValidationResults(V: TValidator;
  ParseErr: string; ParseLine, ParseCol: Integer);
var
  Issue          : TValidationIssue;
  Prefix         : string;
  II             : Integer;
  ECount, WCount : Integer;
  FirstErrorLine : Integer;
begin
  FMemoOut.Clear;

  if ParseErr <> '' then
  begin
    FMemoOut.Lines.Add('+=== PARSE ERROR ==============================');
    FMemoOut.Lines.Add(Format('|  Line %d, Col %d: %s', [ParseLine, ParseCol, ParseErr]));
    FMemoOut.Lines.Add('+===============================================');
    FMemoOut.Lines.Add('');
    if ParseLine > 0 then
      HighlightErrorLine(ParseLine);
    SetStatus(Format('Parse error -- line %d', [ParseLine]), True);
    Exit;
  end;

  if V.Issues.Count = 0 then Exit;

  ECount := 0;
  WCount := 0;
  for Issue in V.Issues do
  begin
    if Issue.Severity = vsError   then Inc(ECount);
    if Issue.Severity = vsWarning then Inc(WCount);
  end;

  if ECount > 0 then
    FMemoOut.Lines.Add(Format('+=== VALIDATION -- %d ERROR(S), %d WARNING(S) ==',
      [ECount, WCount]))
  else
    FMemoOut.Lines.Add(Format('+=== VALIDATION -- %d WARNING(S) ==', [WCount]));

  FirstErrorLine := -1;
  for II := 0 to V.Issues.Count - 1 do
  begin
    Issue := V.Issues[II];
    case Issue.Severity of
      vsError   : Prefix := '|  X ERROR';
      vsWarning : Prefix := '|  ! WARNING';
      vsHint    : Prefix := '|  i HINT';
    end;

    if Issue.Line > 0 then
      FMemoOut.Lines.Add(Format('%s  (line %d): %s', [Prefix, Issue.Line, Issue.Message]))
    else
      FMemoOut.Lines.Add(Format('%s: %s', [Prefix, Issue.Message]));

    if Issue.Hint <> '' then
      FMemoOut.Lines.Add(Format('|     -> %s', [Issue.Hint]));

    if (Issue.Severity = vsError) and (Issue.Line > 0) and (FirstErrorLine < 0) then
      FirstErrorLine := Issue.Line;
  end;

  FMemoOut.Lines.Add('+===============================================');
  FMemoOut.Lines.Add('');

  if FirstErrorLine > 0 then
    HighlightErrorLine(FirstErrorLine)
  else
    ClearHighlight;
end;

procedure TFormMain.OnRun(Sender: TObject);
var
  Lex       : TLexer;
  Par       : TParser;
  Prog      : TProgramNode;
  Interp    : TInterpreter;
  Valid     : TValidator;
  T0        : Cardinal;
  ParseErr  : string;
  ParseLine : Integer;
  ParseCol  : Integer;
begin
  FMemoOut.Clear;  FMemoTok.Clear;
  ClearHighlight;
  T0        := GetTickCount;
  ParseErr  := '';
  ParseLine := 0;
  ParseCol  := 0;
  Prog      := nil;
  Par       := nil;
  Lex       := nil;

  try
    Lex := TLexer.Create(FMemoSrc.Lines.Text);
    Lex.Tokenise;
    ShowTokens(Lex.Tokens);
  except
    on E: Exception do
    begin
      ParseErr  := E.Message;
      ParseLine := 1;
      ShowValidationResults(nil, ParseErr, ParseLine, 1);
      Lex.Free;
      Exit;
    end;
  end;

  try
    Par  := TParser.Create(Lex.Tokens);
    Prog := Par.Parse;
  except
    on E: EParseError do
    begin
      ParseLine := E.Line;
      ParseCol  := E.Col;
      ParseErr  := E.Message;
      ShowValidationResults(nil, ParseErr, ParseLine, ParseCol);
      Par.Free;  Lex.Free;
      Exit;
    end;
    on E: Exception do
    begin
      ParseErr  := E.Message;
      ParseLine := 1;
      ShowValidationResults(nil, ParseErr, ParseLine, 1);
      Par.Free;  Lex.Free;
      Exit;
    end;
  end;

  Valid := TValidator.Create(Prog, FMemoSrc.Lines.Text);
  try
    Valid.Validate;
    ShowValidationResults(Valid, '', 0, 0);

    if Valid.HasErrors then
    begin
      SetStatus('Validation failed -- fix errors before running.', True);
      Prog.Free;  Par.Free;  Lex.Free;
      Exit;
    end;

    if Valid.HasWarnings then
      FMemoOut.Lines.Add('Warnings noted -- running anyway...');

  finally
    Valid.Free;
  end;

  try
    try
      Interp := TInterpreter.Create(Prog, FMemoOut.Lines);
      try
        Interp.InputLine  := FEditInput.Text;
        Interp.SourceText := FMemoSrc.Lines.Text;
        Interp.AllowShell := False;
        Interp.Run;
      finally
        Interp.Free;
      end;
      ClearHighlight;
      SetStatus(Format('--- Done  (%d ms) ---', [GetTickCount - T0]));
    except
      on E: Exception do
      begin
        FMemoOut.Lines.Add('');
        FMemoOut.Lines.Add('*** ERROR: ' + E.Message);
        SetStatus('Runtime error.', True);
      end;
    end;
  finally
    Prog.Free;
    Par.Free;
    Lex.Free;
  end;
end;

procedure TFormMain.OnExampleClick(Sender: TObject);
begin
  GoToCompilerTab;
  FMemoSrc.Lines.Text := EXAMPLE_CODE[(Sender as TMenuItem).Tag];
  FMemoOut.Clear;
  FMemoTok.Clear;
  SetStatus('Example loaded -- click Run to execute.');
end;

procedure TFormMain.OnClear(Sender: TObject);
begin
  FMemoSrc.Clear;  FMemoOut.Clear;  FMemoTok.Clear;
  SetStatus('Cleared.');
end;

end.
