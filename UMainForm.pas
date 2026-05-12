unit UMainForm;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  UMainForm.pas  -  VCL front-end for the MiniDelphi Toy Compiler
//
//  Two tabs:
//    [Compiler]   — source editor, lexer, parser, runner
//    [Calculator] — type any expression, press Enter or =, see the answer
// =============================================================================

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Math,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Menus, Vcl.ComCtrls, Vcl.Buttons, Vcl.Graphics,
  ULexer, UParser, UAST, UInterpreter, ULearnTab,
  UProjectTab, UExampleProjects;

type
  TFormMain = class(TForm)
  private
    // ------------------------------------------------------------------
    //  Top-level page control  (two tabs)
    // ------------------------------------------------------------------
    FPages          : TPageControl;
    FTabCompiler    : TTabSheet;
    FTabCalc        : TTabSheet;
    FTabLearn       : TTabSheet;
    FLearnTab       : TLearnTab;
    FTabProject     : TTabSheet;
    FProjectTab     : TProjectTab;

    // ------------------------------------------------------------------
    //  COMPILER TAB
    // ------------------------------------------------------------------
    FToolPanel      : TPanel;
    FBtnLex         : TButton;
    FBtnParse       : TButton;
    FBtnRun         : TButton;
    FBtnClear       : TButton;
    FBtnExample     : TButton;
    FBtnAbout       : TButton;
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

    FExampleMenu    : TPopupMenu;

    // ------------------------------------------------------------------
    //  CALCULATOR TAB
    // ------------------------------------------------------------------
    FCalcOuter      : TPanel;
    FCalcHistory    : TMemo;
    FCalcInputPanel : TPanel;
    FCalcLabel      : TLabel;
    FCalcEdit       : TEdit;
    FCalcBtn        : TButton;
    FCalcHintLabel  : TLabel;

    // ------------------------------------------------------------------
    //  Internal helpers
    // ------------------------------------------------------------------
    procedure BuildCompilerTab;
    procedure BuildCalcTab;
    procedure BuildExamples;
    procedure SetStatus(const Msg: string; IsError: Boolean = False);
    procedure ShowTokens(Tokens: TList<TToken>);
    procedure EvalExpression;

    procedure OnLex            (Sender: TObject);
    procedure OnParse          (Sender: TObject);
    procedure OnRun            (Sender: TObject);
    procedure OnClear          (Sender: TObject);
    procedure OnExample        (Sender: TObject);
    procedure OnAbout          (Sender: TObject);
    procedure OnCalcBtn        (Sender: TObject);
    procedure OnCalcKey        (Sender: TObject; var Key: Char);
    procedure OnCalcSpecialKey (Sender: TObject; var Key: Word;
                                Shift: TShiftState);
    procedure ExampleItemOnClick (Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  FormMain: TFormMain;

// =============================================================================
implementation
// =============================================================================

{$R *.dfm}

// ---------------------------------------------------------------------------
//  Built-in example programs
// ---------------------------------------------------------------------------
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
    '  for i := 1 to 30 do'                                         + #13#10 +
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
    '  a := 0;'                                                      + #13#10 +
    '  b := 1;'                                                      + #13#10 +
    '  writeln(a);'                                                  + #13#10 +
    '  writeln(b);'                                                  + #13#10 +
    '  for i := 1 to 15 do'                                         + #13#10 +
    '  begin'                                                        + #13#10 +
    '    c := a + b;'                                                + #13#10 +
    '    writeln(c);'                                                + #13#10 +
    '    a := b;'                                                    + #13#10 +
    '    b := c;'                                                    + #13#10 +
    '  end;'                                                         + #13#10 +
    'end.',

    'program Factorial;'                                             + #13#10 +
    ''                                                               + #13#10 +
    'function Fact(n: Integer): Integer;'                            + #13#10 +
    'begin'                                                          + #13#10 +
    '  if n <= 1 then'                                               + #13#10 +
    '    Result := 1'                                                + #13#10 +
    '  else'                                                         + #13#10 +
    '    Result := n * Fact(n - 1);'                                 + #13#10 +
    'end;'                                                           + #13#10 +
    ''                                                               + #13#10 +
    'var'                                                            + #13#10 +
    '  i : Integer;'                                                 + #13#10 +
    ''                                                               + #13#10 +
    'begin'                                                          + #13#10 +
    '  for i := 0 to 12 do'                                         + #13#10 +
    '    writeln(i, ''! = '', Fact(i));'                             + #13#10 +
    'end.',

    'program Primes;'                                                + #13#10 +
    ''                                                               + #13#10 +
    'function IsPrime(n: Integer): Boolean;'                         + #13#10 +
    'var'                                                            + #13#10 +
    '  i : Integer;'                                                 + #13#10 +
    'begin'                                                          + #13#10 +
    '  if n < 2 then begin Result := false; exit; end;'             + #13#10 +
    '  i := 2;'                                                      + #13#10 +
    '  Result := true;'                                              + #13#10 +
    '  while i * i <= n do'                                          + #13#10 +
    '  begin'                                                        + #13#10 +
    '    if n mod i = 0 then'                                        + #13#10 +
    '    begin'                                                      + #13#10 +
    '      Result := false;'                                         + #13#10 +
    '      exit;'                                                    + #13#10 +
    '    end;'                                                       + #13#10 +
    '    inc(i);'                                                    + #13#10 +
    '  end;'                                                         + #13#10 +
    'end;'                                                           + #13#10 +
    ''                                                               + #13#10 +
    'var'                                                            + #13#10 +
    '  n, count : Integer;'                                          + #13#10 +
    ''                                                               + #13#10 +
    'begin'                                                          + #13#10 +
    '  writeln(''Primes up to 100:'');'                              + #13#10 +
    '  count := 0;'                                                  + #13#10 +
    '  for n := 2 to 100 do'                                        + #13#10 +
    '    if IsPrime(n) then'                                         + #13#10 +
    '    begin'                                                      + #13#10 +
    '      write(n);'                                                + #13#10 +
    '      write('' '');'                                            + #13#10 +
    '      inc(count);'                                              + #13#10 +
    '    end;'                                                       + #13#10 +
    '  writeln('''');'                                               + #13#10 +
    '  writeln(''Total: '', count, '' primes'');'                    + #13#10 +
    'end.',

    'program Strings;'                                               + #13#10 +
    ''                                                               + #13#10 +
    'var'                                                            + #13#10 +
    '  s, t : String;'                                               + #13#10 +
    '  i    : Integer;'                                              + #13#10 +
    ''                                                               + #13#10 +
    'begin'                                                          + #13#10 +
    '  s := ''Hello, MiniDelphi!'';'                                 + #13#10 +
    '  writeln(''Original  : '', s);'                                + #13#10 +
    '  writeln(''Length    : '', length(s));'                        + #13#10 +
    '  writeln(''Upper     : '', uppercase(s));'                     + #13#10 +
    '  writeln(''Lower     : '', lowercase(s));'                     + #13#10 +
    '  t := copy(s, 1, 5);'                                         + #13#10 +
    '  writeln(''First 5   : '', t);'                                + #13#10 +
    '  writeln(''Pos Mini  : '', pos(''Mini'', s));'                 + #13#10 +
    '  writeln(''Concat    : '', s + '' (and more!)'');'             + #13#10 +
    'end.',

    // 6 — case (integer)
    'program CaseDemo;'                                              + #13#10 +
    ''                                                               + #13#10 +
    'var'                                                            + #13#10 +
    '  score : Integer;'                                             + #13#10 +
    ''                                                               + #13#10 +
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
    ''                                                               + #13#10 +
    '  writeln(''--- Days of week ---'');'                           + #13#10 +
    '  var day : Integer;'                                           + #13#10 +
    '  for day := 1 to 7 do'                                        + #13#10 +
    '  begin'                                                        + #13#10 +
    '    write(day, '' = '');'                                       + #13#10 +
    '    case day of'                                                 + #13#10 +
    '      1 : writeln(''Monday'');'                                  + #13#10 +
    '      2 : writeln(''Tuesday'');'                                 + #13#10 +
    '      3 : writeln(''Wednesday'');'                               + #13#10 +
    '      4 : writeln(''Thursday'');'                                + #13#10 +
    '      5 : writeln(''Friday'');'                                  + #13#10 +
    '      6, 7 : writeln(''Weekend!'');'                             + #13#10 +
    '    end;'                                                        + #13#10 +
    '  end;'                                                          + #13#10 +
    'end.',

    // 7 — caseof (string switch — our MiniDelphi invention)
    'program CaseOfDemo;'                                            + #13#10 +
    ''                                                               + #13#10 +
    'procedure Describe(animal: String);'                            + #13#10 +
    'begin'                                                          + #13#10 +
    '  write(animal, '' -> '');'                                     + #13#10 +
    '  caseof animal of'                                             + #13#10 +
    '    ''cat''            : writeln(''Meow! Cats are independent.'');'        + #13#10 +
    '    ''dog'', ''hound'' : writeln(''Woof! Dogs are loyal.'');'             + #13#10 +
    '    ''cow''            : writeln(''Moo! Cows give milk.'');'               + #13#10 +
    '    ''parrot''         : writeln(''Squawk! Parrots can talk.'');'          + #13#10 +
    '    ''goldfish''       : writeln(''...(blows bubbles)'');'                 + #13#10 +
    '  else'                                                         + #13#10 +
    '    writeln(''Unknown animal!'');'                               + #13#10 +
    '  end;'                                                         + #13#10 +
    'end;'                                                           + #13#10 +
    ''                                                               + #13#10 +
    'begin'                                                          + #13#10 +
    '  Describe(''cat'');'                                           + #13#10 +
    '  Describe(''dog'');'                                           + #13#10 +
    '  Describe(''cow'');'                                           + #13#10 +
    '  Describe(''parrot'');'                                        + #13#10 +
    '  Describe(''goldfish'');'                                      + #13#10 +
    '  Describe(''unicorn'');'                                       + #13#10 +
    'end.'
  );

// =============================================================================
//  Constructor
// =============================================================================

constructor TFormMain.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption   := 'MiniDelphi Toy Compiler';
  Width     := 1100;
  Height    := 750;
  Position  := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 10;

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
  FTabLearn.Caption        := '  Learn  ';

  FTabProject              := TTabSheet.Create(FPages);
  FTabProject.PageControl  := FPages;
  FTabProject.Caption      := '  Project  ';

  BuildCompilerTab;
  BuildCalcTab;
  FLearnTab    := TLearnTab.Create(FTabLearn);
  FProjectTab  := TProjectTab.Create(FTabProject);
  BuildExamples;

  FMemoSrc.Lines.Text := EXAMPLE_CODE[0];
  SetStatus('Ready — try the Calculator tab for quick maths, or Run the example above.');
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
  // Toolbar
  FToolPanel            := TPanel.Create(Self);
  FToolPanel.Parent     := FTabCompiler;
  FToolPanel.Align      := alTop;
  FToolPanel.Height     := BTN_H + PAD * 2;
  FToolPanel.BevelOuter := bvNone;
  FToolPanel.Color      := $00303030;

  X := PAD;

  FBtnLex := TButton.Create(FToolPanel); FBtnLex.Parent := FToolPanel;
  FBtnLex.Caption := 'Lex'; FBtnLex.Left := X; FBtnLex.Top := PAD;
  FBtnLex.Width := BTN_W; FBtnLex.Height := BTN_H; FBtnLex.OnClick := OnLex;
  Inc(X, BTN_W + PAD);

  FBtnParse := TButton.Create(FToolPanel); FBtnParse.Parent := FToolPanel;
  FBtnParse.Caption := 'Parse'; FBtnParse.Left := X; FBtnParse.Top := PAD;
  FBtnParse.Width := BTN_W; FBtnParse.Height := BTN_H; FBtnParse.OnClick := OnParse;
  Inc(X, BTN_W + PAD);

  FBtnRun := TButton.Create(FToolPanel); FBtnRun.Parent := FToolPanel;
  FBtnRun.Caption := 'Run'; FBtnRun.Left := X; FBtnRun.Top := PAD;
  FBtnRun.Width := BTN_W; FBtnRun.Height := BTN_H; FBtnRun.OnClick := OnRun;
  Inc(X, BTN_W + PAD);

  FBtnClear := TButton.Create(FToolPanel); FBtnClear.Parent := FToolPanel;
  FBtnClear.Caption := 'Clear'; FBtnClear.Left := X; FBtnClear.Top := PAD;
  FBtnClear.Width := BTN_W; FBtnClear.Height := BTN_H; FBtnClear.OnClick := OnClear;
  Inc(X, BTN_W + PAD);

  FBtnExample         := TButton.Create(FToolPanel);
  FBtnExample.Parent  := FToolPanel;
  FBtnExample.Caption := '📖 Examples ▾';
  FBtnExample.Left    := X;  FBtnExample.Top := PAD;
  FBtnExample.Width   := BTN_W + 30;  FBtnExample.Height := BTN_H;
  FBtnExample.OnClick := OnExample;
  Inc(X, BTN_W + 30 + PAD * 4);

  FStatusLabel            := TLabel.Create(FToolPanel);
  FStatusLabel.Parent     := FToolPanel;
  FStatusLabel.Left       := X;
  FStatusLabel.Top        := PAD + 7;
  FStatusLabel.Width      := 500;
  FStatusLabel.Font.Color := clSilver;
  FStatusLabel.Caption    := '';

  // Bottom token pane
  FBottomPanel              := TPanel.Create(Self);
  FBottomPanel.Parent       := FTabCompiler;
  FBottomPanel.Align        := alBottom;
  FBottomPanel.Height       := 160;
  FBottomPanel.BevelOuter   := bvNone;

  FSplitterBot              := TSplitter.Create(Self);
  FSplitterBot.Parent       := FTabCompiler;
  FSplitterBot.Align        := alBottom;
  FSplitterBot.Height       := 4;

  FLabelTok                 := TLabel.Create(FBottomPanel);
  FLabelTok.Parent          := FBottomPanel;
  FLabelTok.Align           := alTop;
  FLabelTok.Caption         := ' TOKEN STREAM';
  FLabelTok.Font.Style      := [fsBold];
  FLabelTok.Height          := 20;

  FMemoTok                  := TMemo.Create(FBottomPanel);
  FMemoTok.Parent           := FBottomPanel;
  FMemoTok.Align            := alClient;
  FMemoTok.ReadOnly         := True;
  FMemoTok.ScrollBars       := ssBoth;
  FMemoTok.WordWrap         := False;
  FMemoTok.Font.Name        := 'Consolas';
  FMemoTok.Font.Size        := 9;
  FMemoTok.Color            := $001E1E1E;
  FMemoTok.Font.Color       := $0056D364;

  // Left source panel
  FLeftPanel                := TPanel.Create(Self);
  FLeftPanel.Parent         := FTabCompiler;
  FLeftPanel.Align          := alLeft;
  FLeftPanel.Width          := 520;
  FLeftPanel.BevelOuter     := bvNone;

  FLabelSrc                 := TLabel.Create(FLeftPanel);
  FLabelSrc.Parent          := FLeftPanel;
  FLabelSrc.Align           := alTop;
  FLabelSrc.Caption         := ' SOURCE CODE';
  FLabelSrc.Font.Style      := [fsBold];
  FLabelSrc.Height          := 20;

  FMemoSrc                  := TMemo.Create(FLeftPanel);
  FMemoSrc.Parent           := FLeftPanel;
  FMemoSrc.Align            := alClient;
  FMemoSrc.ScrollBars       := ssBoth;
  FMemoSrc.WordWrap         := False;
  FMemoSrc.Font.Name        := 'Consolas';
  FMemoSrc.Font.Size        := 10;
  FMemoSrc.Color            := $001E1E1E;
  FMemoSrc.Font.Color       := $00DCDCDC;

  FSplitterMain             := TSplitter.Create(Self);
  FSplitterMain.Parent      := FTabCompiler;
  FSplitterMain.Align       := alLeft;
  FSplitterMain.Width       := 4;

  // Right output panel
  FRightPanel               := TPanel.Create(Self);
  FRightPanel.Parent        := FTabCompiler;
  FRightPanel.Align         := alClient;
  FRightPanel.BevelOuter    := bvNone;

  FLabelOut                 := TLabel.Create(FRightPanel);
  FLabelOut.Parent          := FRightPanel;
  FLabelOut.Align           := alTop;
  FLabelOut.Caption         := ' OUTPUT';
  FLabelOut.Font.Style      := [fsBold];
  FLabelOut.Height          := 20;

  FLabelInput               := TLabel.Create(FRightPanel);
  FLabelInput.Parent        := FRightPanel;
  FLabelInput.Align         := alBottom;
  FLabelInput.Caption       := '  readln input (used by your program):';
  FLabelInput.Height        := 22;

  FEditInput                := TEdit.Create(FRightPanel);
  FEditInput.Parent         := FRightPanel;
  FEditInput.Align          := alBottom;
  FEditInput.Height         := 26;
  FEditInput.Font.Name      := 'Consolas';
  FEditInput.Color          := $00252526;
  FEditInput.Font.Color     := clWhite;

  FMemoOut                  := TMemo.Create(FRightPanel);
  FMemoOut.Parent           := FRightPanel;
  FMemoOut.Align            := alClient;
  FMemoOut.ReadOnly         := True;
  FMemoOut.ScrollBars       := ssBoth;
  FMemoOut.WordWrap         := False;
  FMemoOut.Font.Name        := 'Consolas';
  FMemoOut.Font.Size        := 10;
  FMemoOut.Color            := $00121212;
  FMemoOut.Font.Color       := $00F8F8F2;
end;

// =============================================================================
//  CALCULATOR TAB
// =============================================================================

procedure TFormMain.BuildCalcTab;
const
  HINT =
    '  Operators: + - * / div mod     ' +
    'Functions: abs  sqr  sqrt  power(x,y)  round  trunc  ' +
    'sin  cos  ln  exp  pi  max(a,b)  min(a,b)     ' +
    'Press Enter or click  =  to evaluate';
begin
  FCalcOuter            := TPanel.Create(Self);
  FCalcOuter.Parent     := FTabCalc;
  FCalcOuter.Align      := alClient;
  FCalcOuter.BevelOuter := bvNone;
  FCalcOuter.Color      := $00121212;

  // Hint bar at top
  FCalcHintLabel            := TLabel.Create(FCalcOuter);
  FCalcHintLabel.Parent     := FCalcOuter;
  FCalcHintLabel.Align      := alTop;
  FCalcHintLabel.Height     := 22;
  FCalcHintLabel.Caption    := HINT;
  FCalcHintLabel.Font.Color := $00888888;
  FCalcHintLabel.Font.Size  := 8;

  // Input strip at bottom
  FCalcInputPanel             := TPanel.Create(FCalcOuter);
  FCalcInputPanel.Parent      := FCalcOuter;
  FCalcInputPanel.Align       := alBottom;
  FCalcInputPanel.Height      := 46;
  FCalcInputPanel.BevelOuter  := bvNone;
  FCalcInputPanel.Color       := $00252526;

  FCalcLabel                  := TLabel.Create(FCalcInputPanel);
  FCalcLabel.Parent           := FCalcInputPanel;
  FCalcLabel.Caption          := ' ›';
  FCalcLabel.Font.Name        := 'Consolas';
  FCalcLabel.Font.Size        := 16;
  FCalcLabel.Font.Color       := $0056D364;
  FCalcLabel.Left             := 6;
  FCalcLabel.Top              := 10;

  FCalcEdit                   := TEdit.Create(FCalcInputPanel);
  FCalcEdit.Parent            := FCalcInputPanel;
  FCalcEdit.Left              := 28;
  FCalcEdit.Top               := 8;
  FCalcEdit.Height            := 30;
  FCalcEdit.Width             := FCalcInputPanel.Width - 96;
  FCalcEdit.Anchors           := [akLeft, akTop, akRight];
  FCalcEdit.Font.Name         := 'Consolas';
  FCalcEdit.Font.Size         := 13;
  FCalcEdit.Color             := $00252526;
  FCalcEdit.Font.Color        := clWhite;
  FCalcEdit.BorderStyle       := bsNone;
  FCalcEdit.OnKeyPress        := OnCalcKey;
  FCalcEdit.OnKeyDown         := OnCalcSpecialKey;

  FCalcBtn                    := TButton.Create(FCalcInputPanel);
  FCalcBtn.Parent             := FCalcInputPanel;
  FCalcBtn.Caption            := '=';
  FCalcBtn.Font.Name          := 'Consolas';
  FCalcBtn.Font.Size          := 14;
  FCalcBtn.Width              := 50;
  FCalcBtn.Height             := 30;
  FCalcBtn.Top                := 8;
  FCalcBtn.Anchors            := [akTop, akRight];
  FCalcBtn.Left               := FCalcInputPanel.Width - 56;
  FCalcBtn.OnClick            := OnCalcBtn;

  // History area
  FCalcHistory                := TMemo.Create(FCalcOuter);
  FCalcHistory.Parent         := FCalcOuter;
  FCalcHistory.Align          := alClient;
  FCalcHistory.ReadOnly       := True;
  FCalcHistory.ScrollBars     := ssVertical;
  FCalcHistory.WordWrap       := False;
  FCalcHistory.Font.Name      := 'Consolas';
  FCalcHistory.Font.Size      := 12;
  FCalcHistory.Color          := $00121212;
  FCalcHistory.Font.Color     := $00F8F8F2;

  with FCalcHistory.Lines do
  begin
    Add('  MiniDelphi Calculator');
    Add('  ─────────────────────────────────────');
    Add('  Type any expression and press Enter.');
    Add('');
    Add('  Examples to try:');
    Add('    2 + 3 * 4');
    Add('    (2 + 3) * 4');
    Add('    sqrt(2) * power(3, 4) / (7 - 2)');
    Add('    sin(pi / 6)');
    Add('    (100 - 32) * 5 / 9');
    Add('    round(3.14159 * 100) / 100');
    Add('    ln(exp(1))');
    Add('    max(17, 42) + min(8, 3)');
    Add('    abs(-999) mod 7');
    Add('');
  end;
end;

// =============================================================================
//  Calculator — evaluate expression via the existing pipeline
// =============================================================================

procedure TFormMain.EvalExpression;
var
  Raw     : string;
  Wrapped : string;
  Lex     : TLexer;
  Par     : TParser;
  Prog    : TProgramNode;
  Interp  : TInterpreter;
  Output  : TStringList;
  Answer  : string;
begin
  Raw := Trim(FCalcEdit.Text);
  if Raw = '' then Exit;

  // Wrap the bare expression so the existing lexer/parser/interpreter
  // can process it without any changes to those units.
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

      FCalcHistory.Lines.Add('  › ' + Raw);
      FCalcHistory.Lines.Add('    = ' + Answer);
      FCalcHistory.Lines.Add('');

    except
      on E: Exception do
      begin
        FCalcHistory.Lines.Add('  › ' + Raw);
        FCalcHistory.Lines.Add('    Error: ' + E.Message);
        FCalcHistory.Lines.Add('');
      end;
    end;
  finally
    Output.Free;
  end;

  // Scroll history to bottom, then select all text in input for easy replacement
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

procedure TFormMain.ExampleItemOnClick(Sender: TObject);
    begin
      FMemoSrc.Lines.Text := EXAMPLE_CODE[(Sender as TMenuItem).Tag];
      FMemoOut.Clear;
      FMemoTok.Clear;
      SetStatus('Example loaded — click Run to execute.');
   end;

// =============================================================================
//  COMPILER TAB — example menu
// =============================================================================

procedure TFormMain.BuildExamples;
var
  I    : Integer;
  Item : TMenuItem;
begin
  FExampleMenu := TPopupMenu.Create(Self);
  for I := 0 to EXAMPLE_COUNT - 1 do
  begin
    Item         := TMenuItem.Create(FExampleMenu);
    Item.Caption := EXAMPLE_NAMES[I];
    Item.Tag     := I;
    Item.OnClick := ExampleItemOnClick;
    FExampleMenu.Items.Add(Item);
  end;
end;

// =============================================================================
//  COMPILER TAB — button handlers
// =============================================================================

procedure TFormMain.SetStatus(const Msg: string; IsError: Boolean);
begin
  FStatusLabel.Caption    := Msg;
  if IsError then FStatusLabel.Font.Color := clRed
  else FStatusLabel.Font.Color := clSilver;
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
      SetStatus(Format('Lex OK — %d tokens', [Lex.Tokens.Count]));
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
          SetStatus(Format('Parse OK — %d routines, %d globals',
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

procedure TFormMain.OnRun(Sender: TObject);
var
  Lex   : TLexer;
  Par   : TParser;
  Prog  : TProgramNode;
  Interp: TInterpreter;
  T0    : Cardinal;
begin
  FMemoOut.Clear;  FMemoTok.Clear;
  T0 := GetTickCount;
  try
    Lex := TLexer.Create(FMemoSrc.Lines.Text);
    try
      Lex.Tokenise;
      ShowTokens(Lex.Tokens);
      Par := TParser.Create(Lex.Tokens);
      try
        Prog := Par.Parse;
        try
          Interp := TInterpreter.Create(Prog, FMemoOut.Lines);
          try
            Interp.InputLine  := FEditInput.Text;
            Interp.SourceText := FMemoSrc.Lines.Text;
            Interp.Run;
          finally
            Interp.Free;
          end;
          SetStatus(Format('Run OK  (%d ms)', [GetTickCount - T0]));
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
      FMemoOut.Lines.Add('');
      FMemoOut.Lines.Add('*** ERROR: ' + E.Message);
      SetStatus('Runtime error.', True);
    end;
  end;
end;

procedure TFormMain.OnClear(Sender: TObject);
begin
  FMemoSrc.Clear;  FMemoOut.Clear;  FMemoTok.Clear;
  SetStatus('Cleared.');
end;

procedure TFormMain.OnExample(Sender: TObject);
var
  P : TPoint;
begin
  P := FBtnExample.ClientToScreen(Point(0, FBtnExample.Height));
  FExampleMenu.Popup(P.X, P.Y);
end;

// Local helper to avoid ambiguity with System.Math.IfThen
function IfThen(B: Boolean; const T, F: string): string; overload;
begin
  if B then Result := T else Result := F;
end;

function IfThen(B: Boolean; T, F: TColor): TColor; overload;
begin
  if B then Result := T else Result := F;
end;

procedure TFormMain.OnAbout(Sender: TObject);
var
  Msg : string;
begin
  Msg :=
    'MiniDelphi Toy Compiler & Learning IDE' + #13#10 +
    '─────────────────────────────────────────' + #13#10 +
    '' + #13#10 +
    'Version 1.0  |  May 2026' + #13#10 +
    '' + #13#10 +
    'Copyright © 2026 Nomidor Software, LLC.' + #13#10 +
    'All rights reserved.' + #13#10 +
    '' + #13#10 +
    'A complete Delphi learning environment featuring:' + #13#10 +
    '  • Full lexer, parser and interpreter pipeline' + #13#10 +
    '  • 4 tabs: Compiler, Calculator, Learn Delphi, Projects' + #13#10 +
    '  • 13 lessons, 45 challenges and a completion certificate' + #13#10 +
    '  • 40 single-file and 10 multi-file example programs' + #13#10 +
    '  • OOP: classes, inheritance, interfaces, polymorphism' + #13#10 +
    '  • SQLite database support (requires sqlite3.dll)' + #13#10 +
    '  • Unit import system (.mdp library files)' + #13#10 +
    '  • File dialogs, message boxes, file I/O builtins' + #13#10 +
    '  • Project save/load with .mdp and .mdproj formats' + #13#10 +
    '' + #13#10 +
    'Built with Embarcadero Delphi 13.' + #13#10 +
    '' + #13#10 +
    'www.nomidor.com';

  MessageDlg(Msg, mtInformation, [mbOK], 0);
end;


end.
