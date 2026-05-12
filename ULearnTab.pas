unit ULearnTab;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  ULearnTab.pas  -  "Learn Delphi" interactive teaching tab
//
//  Architecture
//  ────────────
//  TLearnCurriculum   — holds all levels and challenges (pure data)
//  TAnswerChecker     — runs student code and decides pass/fail
//  TProgressStore     — remembers which challenges are complete (INI file)
//  TLearnTab          — the VCL panel that drives everything
//  TCertificateForm   — pop-up HTML certificate when all challenges done
//
//  Checking strategies (TCheckKind)
//  ────────────────────────────────
//  ckExactOutput      — output must match expected string exactly
//  ckContainsAll      — output must contain every string in the check list
//  ckOutputIsNumber   — output (trimmed) must be a valid number equal to N
//  ckOutputInRange    — output number must be between Lo and Hi
//  ckLineCount        — output must have exactly N lines
//  ckAnyOutput        — anything non-empty passes (free-form exercises)
// =============================================================================

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.IniFiles, System.Math,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Graphics, Vcl.ComCtrls, Vcl.Buttons, Vcl.Menus, Vcl.Dialogs,
  System.UITypes,
  ULexer, UParser, UAST, UInterpreter;

// ---------------------------------------------------------------------------
//  Check strategy
// ---------------------------------------------------------------------------
type
  TCheckKind = (
    ckExactOutput,    // trimmed output = expected string
    ckContainsAll,    // output contains every string in MustContain
    ckOutputIsNumber, // trimmed first line is a number = ExpectedNumber
    ckOutputInRange,  // first line number is Lo..Hi
    ckLineCount,      // output has exactly N non-empty lines
    ckAnyOutput       // anything non-empty passes
  );

// ---------------------------------------------------------------------------
//  One programming challenge
// ---------------------------------------------------------------------------
  TChallenge = record
    ID           : Integer;
    Title        : string;
    Instruction  : string;      // what the student must write
    Hint         : string;      // shown on demand
    Starter      : string;      // pre-filled code skeleton (may be empty)
    Solution     : string;      // shown if student asks
    CheckKind    : TCheckKind;
    Expected     : string;      // for ckExactOutput / ckContainsAll (pipe-sep)
    ExpectedNum  : Double;      // for ckOutputIsNumber
    RangeLo      : Double;      // for ckOutputInRange
    RangeHi      : Double;
    LineCount    : Integer;     // for ckLineCount
    Points       : Integer;     // awarded on pass
  end;

// ---------------------------------------------------------------------------
//  One lesson (a named group of challenges)
// ---------------------------------------------------------------------------
  TLesson = record
    Number     : Integer;
    Title      : string;
    Intro      : string;        // teaching text shown before challenges
    Challenges : TArray<TChallenge>;
  end;

// ---------------------------------------------------------------------------
//  The full curriculum
// ---------------------------------------------------------------------------
  TLearnCurriculum = class
  private
    FLessons : TArray<TLesson>;
    procedure Build;
  public
    constructor Create;
    function  LessonCount    : Integer;
    function  GetLesson(I: Integer) : TLesson;
    function  TotalChallenges: Integer;
    function  TotalPoints    : Integer;
  end;

// ---------------------------------------------------------------------------
//  Answer checker — runs code, applies strategy
// ---------------------------------------------------------------------------
  TAnswerChecker = class
  private
    class function RunCode(const Source: string;
                           Output: TStrings) : Boolean;
    class function TrimOutput(Lines: TStrings) : string;
  public
    class function Check(const Ch: TChallenge;
                         const Source: string;
                         out Msg: string) : Boolean;
  end;

// ---------------------------------------------------------------------------
//  Progress store — persists completions between sessions
// ---------------------------------------------------------------------------
  TProgressStore = class
  private
    FPath    : string;
    FIni     : TIniFile;
    FName    : string;
  public
    constructor Create;
    destructor  Destroy; override;
    function  IsComplete(ChallengeID: Integer)  : Boolean;
    procedure MarkComplete(ChallengeID: Integer);
    procedure Reset;
    function  CompletedCount : Integer;
    function  EarnedPoints   : Integer;
    property  StudentName    : string read FName write FName;
    procedure SaveName;
    procedure LoadName;
    procedure AddPoints(N: Integer);
  end;

// ---------------------------------------------------------------------------
//  Certificate pop-up
// ---------------------------------------------------------------------------
  TCertificateForm = class(TForm)
  private
    FMemo : TMemo;
    FBtn  : TButton;
    procedure BuildUI(const StudentName: string;
                      Points, Total: Integer);
    procedure OnClose(Sender: TObject);
  public
    constructor Create(AOwner: TComponent;
                       const StudentName: string;
                       Points, Total: Integer); reintroduce;
  end;

// ---------------------------------------------------------------------------
//  The VCL Learn tab panel  (drop onto a TTabSheet)
// ---------------------------------------------------------------------------
  TLearnTab = class
  private
    FParent      : TWinControl;
    FCurriculum  : TLearnCurriculum;
    FProgress    : TProgressStore;

    // Current position
    FCurLesson   : Integer;   // 0-based
    FCurChallenge: Integer;   // 0-based within lesson

    // ---- UI controls -------------------------------------------------------
    FOuterPanel  : TPanel;

    // Left navigation panel
    FNavPanel    : TPanel;
    FNavTree     : TTreeView;
    FLabelScore  : TLabel;
    FLabelName   : TLabel;
    FEditName    : TEdit;
    FBtnSaveName : TButton;
    FBtnReset    : TButton;

    // Right content panel
    FContentPanel : TPanel;

    // Header strip
    FHeaderPanel  : TPanel;
    FLabelLesson  : TLabel;
    FLabelStars   : TLabel;

    // Intro / instruction area
    FIntroMemo    : TMemo;

    // Code editor area
    FCodeLabel    : TLabel;
    FCodeMemo     : TMemo;

    // Hint / result strip
    FHintPanel    : TPanel;
    FBtnHint      : TButton;
    FBtnCheck     : TButton;
    FBtnSolution  : TButton;
    FBtnPrev      : TButton;
    FBtnNext      : TButton;

    // Result label
    FResultPanel  : TPanel;
    FResultLabel  : TLabel;

    // Output area
    FOutputLabel  : TLabel;
    FOutputMemo   : TMemo;

    // ---- Helpers -----------------------------------------------------------
    procedure BuildUI;
    procedure BuildNavTree;
    procedure LoadChallenge;
    procedure UpdateScore;
    procedure UpdateStars;
    procedure SelectNavNode;

    function  CurrentLesson    : TLesson;
    function  CurrentChallenge : TChallenge;

    procedure OnNavSelect (Sender: TObject);
    procedure OnCheck     (Sender: TObject);
    procedure OnHint      (Sender: TObject);
    procedure OnSolution  (Sender: TObject);
    procedure OnPrev      (Sender: TObject);
    procedure OnNext      (Sender: TObject);
    procedure OnSaveName  (Sender: TObject);
    procedure OnReset     (Sender: TObject);

    procedure ShowResult(const Msg: string; Pass: Boolean);
    procedure ShowCertificate;

  public
    constructor Create(AParent: TWinControl);
    destructor  Destroy; override;
  end;

// =============================================================================
implementation
// =============================================================================

// ═══════════════════════════════════════════════════════════════════════════
//  CURRICULUM DATA
//  Each challenge has a unique ID (never reuse or renumber — used as keys
//  in the progress INI file).
// ═══════════════════════════════════════════════════════════════════════════

constructor TLearnCurriculum.Create;
begin
  inherited;
  Build;
end;

procedure TLearnCurriculum.Build;
// Helper to make a challenge record cleanly
  function Ch(ID: Integer; const Title, Instr, Hint, Starter, Solution: string;
              Kind: TCheckKind; const Exp: string;
              ExpNum, Lo, Hi: Double; Lines, Pts: Integer) : TChallenge;
  begin
    Result.ID           := ID;
    Result.Title        := Title;
    Result.Instruction  := Instr;
    Result.Hint         := Hint;
    Result.Starter      := Starter;
    Result.Solution     := Solution;
    Result.CheckKind    := Kind;
    Result.Expected     := Exp;
    Result.ExpectedNum  := ExpNum;
    Result.RangeLo      := Lo;
    Result.RangeHi      := Hi;
    Result.LineCount    := Lines;
    Result.Points       := Pts;
  end;

begin
  SetLength(FLessons, 13);

  // ── LESSON 1 ── Hello World & Output ─────────────────────────────────────
  FLessons[0].Number := 1;
  FLessons[0].Title  := 'Hello World & Output';
  FLessons[0].Intro  :=
    'Welcome to MiniDelphi!'                                               + #13#10 +
    ''                                                                     + #13#10 +
    'Every Delphi program has a main block wrapped in  begin  and  end.'   + #13#10 +
    'To print text on screen you use  writeln( )  which prints a line,'    + #13#10 +
    'or  write( )  which prints without moving to a new line.'             + #13#10 +
    ''                                                                     + #13#10 +
    'Text (called a string) must be wrapped in single quotes:'             + #13#10 +
    ''                                                                     + #13#10 +
    '    writeln(''Hello, World!'');'                                      + #13#10 +
    ''                                                                     + #13#10 +
    'If you need a single quote INSIDE a string, write two of them:'       + #13#10 +
    ''                                                                     + #13#10 +
    '    writeln(''It''s a great day!'');';

  FLessons[0].Challenges := [
    Ch(101, 'Say Hello',
       'Write a program that prints exactly:'                              + #13#10 +
       ''                                                                  + #13#10 +
       '    Hello, World!',
       'Use  writeln(''Hello, World!'');  inside  begin...end.',
       'begin'  + #13#10 + '  // write your code here' + #13#10 + 'end.',
       'begin'  + #13#10 + '  writeln(''Hello, World!'');' + #13#10 + 'end.',
       ckExactOutput, 'Hello, World!', 0,0,0, 0, 10),

    Ch(102, 'Two Lines',
       'Print your first name on the first line and your last name on the second line.',
       'Call writeln twice — once for each line.',
       'begin'  + #13#10 + '  // two writeln calls' + #13#10 + 'end.',
       'begin'  + #13#10 + '  writeln(''John'');' + #13#10 + '  writeln(''Smith'');' + #13#10 + 'end.',
       ckLineCount, '', 0,0,0, 2, 10),

    Ch(103, 'One Long Line',
       'Using only  write  (not writeln), print:   I love Delphi!   all on one line.',
       'write() does not add a newline. Use writeln('''') at the end to finish the line.',
       'begin'  + #13#10 + '  // use write( ) not writeln( )' + #13#10 + 'end.',
       'begin'  + #13#10 + '  write(''I love Delphi!'');' + #13#10 + '  writeln('''');' + #13#10 + 'end.',
       ckContainsAll, 'I love Delphi!', 0,0,0, 0, 15)
  ];

  // ── LESSON 2 ── Variables ─────────────────────────────────────────────────
  FLessons[1].Number := 2;
  FLessons[1].Title  := 'Variables & Assignment';
  FLessons[1].Intro  :=
    'A variable is a named box that holds a value.'                        + #13#10 +
    'You declare variables in a  var  block before  begin:'                + #13#10 +
    ''                                                                     + #13#10 +
    '    var'                                                              + #13#10 +
    '      age    : Integer;'                                              + #13#10 +
    '      name   : String;'                                               + #13#10 +
    '      score  : Real;'                                                 + #13#10 +
    '      passed : Boolean;'                                              + #13#10 +
    ''                                                                     + #13#10 +
    'Then assign values using  :=  (colon equals):'                        + #13#10 +
    ''                                                                     + #13#10 +
    '    age  := 25;'                                                      + #13#10 +
    '    name := ''Alice'';'                                               + #13#10 +
    ''                                                                     + #13#10 +
    'You can print variables directly:'                                    + #13#10 +
    ''                                                                     + #13#10 +
    '    writeln(name, '' is '', age, '' years old.'');';

  FLessons[1].Challenges := [
    Ch(201, 'Store Your Age',
       'Declare an Integer variable called  age, assign it your age, then print it.',
       'var age : Integer;  then  age := 25;  then  writeln(age);',
       'var'  + #13#10 + '  age : Integer;' + #13#10 + 'begin' + #13#10 + '  // assign and print age' + #13#10 + 'end.',
       'var'  + #13#10 + '  age : Integer;' + #13#10 + 'begin' + #13#10 + '  age := 25;' + #13#10 + '  writeln(age);' + #13#10 + 'end.',
       ckAnyOutput, '', 0,0,0, 0, 10),

    Ch(202, 'Full Greeting',
       'Declare  name (String) and  age (Integer). Assign values. Print:'  + #13#10 +
       ''                                                                   + #13#10 +
       '    My name is Alice and I am 30 years old.'                        + #13#10 +
       ''                                                                   + #13#10 +
       '(Use your own name and age — the checker just wants that pattern.)',
       'writeln(''My name is '', name, '' and I am '', age, '' years old.'');',
       'var'  + #13#10 + '  name : String;' + #13#10 + '  age  : Integer;' + #13#10 + 'begin' + #13#10 + #13#10 + 'end.',
       'var'  + #13#10 + '  name : String;' + #13#10 + '  age  : Integer;' + #13#10 + 'begin' + #13#10 + '  name := ''Alice'';' + #13#10 + '  age  := 30;' + #13#10 + '  writeln(''My name is '', name, '' and I am '', age, '' years old.'');' + #13#10 + 'end.',
       ckContainsAll, 'My name is|years old.', 0,0,0, 0, 15),

    Ch(203, 'Swap Two Values',
       'Declare  a and  b as integers. Set a := 10, b := 20.'              + #13#10 +
       'Swap their values using a temporary variable  temp.'               + #13#10 +
       'Print: a=20  b=10',
       'temp := a; a := b; b := temp;',
       'var'  + #13#10 + '  a, b, temp : Integer;' + #13#10 + 'begin' + #13#10 + '  a := 10;' + #13#10 + '  b := 20;' + #13#10 + '  // swap here' + #13#10 + 'end.',
       'var'  + #13#10 + '  a, b, temp : Integer;' + #13#10 + 'begin' + #13#10 + '  a := 10; b := 20;' + #13#10 + '  temp := a; a := b; b := temp;' + #13#10 + '  writeln(''a='', a, ''  b='', b);' + #13#10 + 'end.',
       ckContainsAll, 'a=20|b=10', 0,0,0, 0, 20)
  ];

  // ── LESSON 3 ── Arithmetic ────────────────────────────────────────────────
  FLessons[2].Number := 3;
  FLessons[2].Title  := 'Arithmetic & Maths';
  FLessons[2].Intro  :=
    'Delphi supports all the usual arithmetic operators:'                  + #13#10 +
    ''                                                                     + #13#10 +
    '    +   addition'                                                     + #13#10 +
    '    -   subtraction'                                                  + #13#10 +
    '    *   multiplication'                                               + #13#10 +
    '    /   division  (always gives a Real result)'                       + #13#10 +
    '    div integer division  (discards remainder)'                       + #13#10 +
    '    mod remainder  (17 mod 5 = 2)'                                    + #13#10 +
    ''                                                                     + #13#10 +
    'Useful built-in functions:'                                           + #13#10 +
    '    sqrt(x)    square root'                                           + #13#10 +
    '    abs(x)     absolute value'                                        + #13#10 +
    '    sqr(x)     x squared'                                             + #13#10 +
    '    round(x)   nearest integer'                                       + #13#10 +
    '    power(x,y) x to the power y';

  FLessons[2].Challenges := [
    Ch(301, 'Addition',
       'Calculate and print the result of  247 + 358.',
       'writeln(247 + 358);',
       'begin' + #13#10 + '  writeln(  );  // fill in the expression' + #13#10 + 'end.',
       'begin' + #13#10 + '  writeln(247 + 358);' + #13#10 + 'end.',
       ckOutputIsNumber, '', 605, 0,0, 0, 10),

    Ch(302, 'Remainder',
       'Print the remainder when 1234 is divided by 7.',
       '1234 mod 7',
       'begin' + #13#10 + 'end.',
       'begin' + #13#10 + '  writeln(1234 mod 7);' + #13#10 + 'end.',
       ckOutputIsNumber, '', 3, 0,0, 0, 10),

    Ch(303, 'Circle Area',
       'Calculate the area of a circle with radius 7.'                     + #13#10 +
       'Formula: area = pi * r * r'                                        + #13#10 +
       'Print the result. It should be approximately 153.94.',
       'writeln(pi * 7 * 7);   — pi is a built-in constant',
       'begin' + #13#10 + '  // area of a circle r=7' + #13#10 + 'end.',
       'begin' + #13#10 + '  writeln(pi * 7 * 7);' + #13#10 + 'end.',
       ckOutputInRange, '', 0, 153.9, 154.0, 0, 15),

    Ch(304, 'Celsius to Fahrenheit',
       'Convert 100 degrees Celsius to Fahrenheit.'                        + #13#10 +
       'Formula: F = (C * 9 / 5) + 32'                                    + #13#10 +
       'Print the result.',
       'F = (100 * 9 / 5) + 32',
       'begin' + #13#10 + 'end.',
       'begin' + #13#10 + '  writeln((100 * 9 / 5) + 32);' + #13#10 + 'end.',
       ckOutputIsNumber, '', 212, 0,0, 0, 15)
  ];

  // ── LESSON 4 ── if / then / else ─────────────────────────────────────────
  FLessons[3].Number := 4;
  FLessons[3].Title  := 'if / then / else';
  FLessons[3].Intro  :=
    'The  if  statement lets your program make decisions:'                 + #13#10 +
    ''                                                                     + #13#10 +
    '    if age >= 18 then'                                                + #13#10 +
    '      writeln(''Adult'')'                                             + #13#10 +
    '    else'                                                             + #13#10 +
    '      writeln(''Minor'');'                                            + #13#10 +
    ''                                                                     + #13#10 +
    'Comparison operators:'                                                + #13#10 +
    '    =   equal to'                                                     + #13#10 +
    '    <>  not equal to'                                                 + #13#10 +
    '    <   less than'                                                    + #13#10 +
    '    >   greater than'                                                 + #13#10 +
    '    <=  less than or equal'                                           + #13#10 +
    '    >=  greater than or equal'                                        + #13#10 +
    ''                                                                     + #13#10 +
    'Combine conditions with  and  /  or  /  not:'                         + #13#10 +
    '    if (x > 0) and (x < 100) then ...';

  FLessons[3].Challenges := [
    Ch(401, 'Positive or Negative',
       'Set  n := -5.  Print  Negative  if n < 0, otherwise print  Positive.',
       'if n < 0 then writeln(''Negative'') else writeln(''Positive'');',
       'var'  + #13#10 + '  n : Integer;' + #13#10 + 'begin' + #13#10 + '  n := -5;' + #13#10 + '  // your if statement here' + #13#10 + 'end.',
       'var n:Integer; begin n:=-5; if n<0 then writeln(''Negative'') else writeln(''Positive''); end.',
       ckExactOutput, 'Negative', 0,0,0, 0, 10),

    Ch(402, 'Even or Odd',
       'Set  n := 42.  Print  Even  if it is even, otherwise print  Odd.'  + #13#10 +
       'Hint: a number is even if  n mod 2 = 0.',
       'if n mod 2 = 0 then writeln(''Even'') else writeln(''Odd'');',
       'var'  + #13#10 + '  n : Integer;' + #13#10 + 'begin' + #13#10 + '  n := 42;' + #13#10 + 'end.',
       'var n:Integer; begin n:=42; if n mod 2=0 then writeln(''Even'') else writeln(''Odd''); end.',
       ckExactOutput, 'Even', 0,0,0, 0, 10),

    Ch(403, 'Grade Classifier',
       'Set  score := 73.  Using  if / else if / else,  print:'            + #13#10 +
       '    A  if score >= 90'                                             + #13#10 +
       '    B  if score >= 80'                                             + #13#10 +
       '    C  if score >= 70'                                             + #13#10 +
       '    F  otherwise',
       'Chain:  if ... then ... else if ... then ... else ...',
       'var'  + #13#10 + '  score : Integer;' + #13#10 + 'begin' + #13#10 + '  score := 73;' + #13#10 + 'end.',
       'var score:Integer; begin score:=73; if score>=90 then writeln(''A'') else if score>=80 then writeln(''B'') else if score>=70 then writeln(''C'') else writeln(''F''); end.',
       ckExactOutput, 'C', 0,0,0, 0, 20),

    Ch(404, 'Leap Year',
       'Set  year := 2024.  A year is a leap year if:'                    + #13#10 +
       '  • divisible by 4  AND'                                          + #13#10 +
       '  • NOT divisible by 100, OR divisible by 400'                    + #13#10 +
       'Print  Leap year  or  Not a leap year.',
       'if (year mod 4=0) and ((year mod 100<>0) or (year mod 400=0)) then ...',
       'var'  + #13#10 + '  year : Integer;' + #13#10 + 'begin' + #13#10 + '  year := 2024;' + #13#10 + 'end.',
       'var year:Integer; begin year:=2024; if (year mod 4=0) and ((year mod 100<>0) or (year mod 400=0)) then writeln(''Leap year'') else writeln(''Not a leap year''); end.',
       ckExactOutput, 'Leap year', 0,0,0, 0, 25)
  ];

  // ── LESSON 5 ── while / repeat ───────────────────────────────────────────
  FLessons[4].Number := 5;
  FLessons[4].Title  := 'while & repeat Loops';
  FLessons[4].Intro  :=
    'Loops repeat a block of code.'                                        + #13#10 +
    ''                                                                     + #13#10 +
    'while — checks condition BEFORE each iteration:'                      + #13#10 +
    ''                                                                     + #13#10 +
    '    while n > 0 do'                                                   + #13#10 +
    '    begin'                                                            + #13#10 +
    '      writeln(n);'                                                    + #13#10 +
    '      n := n - 1;'                                                    + #13#10 +
    '    end;'                                                             + #13#10 +
    ''                                                                     + #13#10 +
    'repeat — checks condition AFTER each iteration (always runs once):'   + #13#10 +
    ''                                                                     + #13#10 +
    '    repeat'                                                           + #13#10 +
    '      writeln(n);'                                                    + #13#10 +
    '      n := n + 1;'                                                    + #13#10 +
    '    until n > 10;'                                                    + #13#10 +
    ''                                                                     + #13#10 +
    'Use  break  to exit a loop early, and  continue  to skip to the next iteration.';

  FLessons[4].Challenges := [
    Ch(501, 'Count to 5',
       'Using a  while  loop, print the numbers 1 to 5, one per line.',
       'var n:Integer; n:=1; while n<=5 do begin writeln(n); n:=n+1; end;',
       'var'  + #13#10 + '  n : Integer;' + #13#10 + 'begin' + #13#10 + '  n := 1;' + #13#10 + '  // while loop here' + #13#10 + 'end.',
       'var n:Integer; begin n:=1; while n<=5 do begin writeln(n); n:=n+1; end; end.',
       ckExactOutput, '1' + #13#10 + '2' + #13#10 + '3' + #13#10 + '4' + #13#10 + '5', 0,0,0, 0, 15),

    Ch(502, 'Powers of 2',
       'Print all powers of 2 that are less than 1000: 1, 2, 4, 8, ...',
       'var n:Integer; n:=1; while n<1000 do begin writeln(n); n:=n*2; end;',
       'var'  + #13#10 + '  n : Integer;' + #13#10 + 'begin' + #13#10 + '  n := 1;' + #13#10 + 'end.',
       'var n:Integer; begin n:=1; while n<1000 do begin writeln(n); n:=n*2; end; end.',
       ckContainsAll, '1|2|4|8|16|32|64|128|256|512', 0,0,0, 0, 15),

    Ch(503, 'Sum with repeat',
       'Using  repeat/until, add up the numbers 1 to 10 and print the total.',
       'var sum,i:Integer; sum:=0; i:=1; repeat sum:=sum+i; i:=i+1; until i>10;',
       'var'  + #13#10 + '  sum, i : Integer;' + #13#10 + 'begin' + #13#10 + '  sum := 0;' + #13#10 + '  i   := 1;' + #13#10 + '  // repeat...until loop' + #13#10 + 'end.',
       'var sum,i:Integer; begin sum:=0; i:=1; repeat sum:=sum+i; i:=i+1; until i>10; writeln(sum); end.',
       ckOutputIsNumber, '', 55, 0,0, 0, 20)
  ];

  // ── LESSON 6 ── for loops ────────────────────────────────────────────────
  FLessons[5].Number := 6;
  FLessons[5].Title  := 'for Loops';
  FLessons[5].Intro  :=
    'The  for  loop counts through a range automatically:'                 + #13#10 +
    ''                                                                     + #13#10 +
    '    for i := 1 to 10 do'                                             + #13#10 +
    '      writeln(i);'                                                    + #13#10 +
    ''                                                                     + #13#10 +
    'Count backwards with  downto:'                                        + #13#10 +
    ''                                                                     + #13#10 +
    '    for i := 10 downto 1 do'                                         + #13#10 +
    '      writeln(i);'                                                    + #13#10 +
    ''                                                                     + #13#10 +
    'Use  begin...end  when the loop body has more than one statement:'    + #13#10 +
    ''                                                                     + #13#10 +
    '    for i := 1 to 5 do'                                              + #13#10 +
    '    begin'                                                            + #13#10 +
    '      writeln(i, '' squared = '', i*i);'                             + #13#10 +
    '    end;';

  FLessons[5].Challenges := [
    Ch(601, 'Multiplication Table',
       'Print the 7 times table from 7×1 to 7×10.'                        + #13#10 +
       'Each line should look like:   7 x 1 = 7',
       'for i:=1 to 10 do writeln(''7 x '', i, '' = '', 7*i);',
       'var'  + #13#10 + '  i : Integer;' + #13#10 + 'begin' + #13#10 + '  // for loop here' + #13#10 + 'end.',
       'var i:Integer; begin for i:=1 to 10 do writeln(''7 x '', i, '' = '', 7*i); end.',
       ckContainsAll, '7 x 1 = 7|7 x 5 = 35|7 x 10 = 70', 0,0,0, 0, 15),

    Ch(602, 'Countdown',
       'Count down from 10 to 1, printing each number. Then print  Blast off!',
       'for i := 10 downto 1 do writeln(i);  writeln(''Blast off!'');',
       'var'  + #13#10 + '  i : Integer;' + #13#10 + 'begin' + #13#10 + 'end.',
       'var i:Integer; begin for i:=10 downto 1 do writeln(i); writeln(''Blast off!''); end.',
       ckContainsAll, '10|Blast off!', 0,0,0, 0, 15),

    Ch(603, 'FizzBuzz',
       'The classic! For numbers 1 to 20:'                                + #13#10 +
       '  • Print  FizzBuzz  if divisible by both 3 and 5'               + #13#10 +
       '  • Print  Fizz  if divisible by 3'                               + #13#10 +
       '  • Print  Buzz  if divisible by 5'                               + #13#10 +
       '  • Otherwise print the number',
       'Check mod 15 first (both), then mod 3, then mod 5.',
       'var'  + #13#10 + '  i : Integer;' + #13#10 + 'begin' + #13#10 + '  for i := 1 to 20 do' + #13#10 + '  begin' + #13#10 + '    // your logic here' + #13#10 + '  end;' + #13#10 + 'end.',
       'var i:Integer; begin for i:=1 to 20 do begin if i mod 15=0 then writeln(''FizzBuzz'') else if i mod 3=0 then writeln(''Fizz'') else if i mod 5=0 then writeln(''Buzz'') else writeln(i); end; end.',
       ckContainsAll, 'Fizz|Buzz|FizzBuzz', 0,0,0, 0, 25)
  ];

  // ── LESSON 7 ── Procedures ────────────────────────────────────────────────
  FLessons[6].Number := 7;
  FLessons[6].Title  := 'Procedures';
  FLessons[6].Intro  :=
    'A procedure is a named block of code you can call multiple times.'    + #13#10 +
    'Declare it BEFORE the main  begin...end  block:'                      + #13#10 +
    ''                                                                     + #13#10 +
    '    procedure SayHello(name: String);'                                + #13#10 +
    '    begin'                                                            + #13#10 +
    '      writeln(''Hello, '', name, ''!'');'                             + #13#10 +
    '    end;'                                                             + #13#10 +
    ''                                                                     + #13#10 +
    '    begin'                                                            + #13#10 +
    '      SayHello(''Alice'');'                                           + #13#10 +
    '      SayHello(''Bob'');'                                             + #13#10 +
    '    end.'                                                             + #13#10 +
    ''                                                                     + #13#10 +
    'Parameters are values passed in. The procedure gets its own copy.'    + #13#10 +
    'Use  var  parameters to let the procedure modify the caller''s variable.';

  FLessons[6].Challenges := [
    Ch(701, 'Simple Procedure',
       'Write a procedure  PrintLine  that prints a row of 10 dashes: ----------'  + #13#10 +
       'Call it 3 times from your main block.',
       'procedure PrintLine; begin writeln(''----------''); end;',
       'procedure PrintLine;' + #13#10 + 'begin' + #13#10 + '  // print 10 dashes' + #13#10 + 'end;' + #13#10 + #13#10 + 'begin' + #13#10 + '  PrintLine;' + #13#10 + '  PrintLine;' + #13#10 + '  PrintLine;' + #13#10 + 'end.',
       'procedure PrintLine; begin writeln(''----------''); end; begin PrintLine; PrintLine; PrintLine; end.',
       ckLineCount, '', 0,0,0, 3, 15),

    Ch(702, 'Procedure with Parameter',
       'Write a procedure  Greet(name: String)  that prints:  Hello, [name]!'  + #13#10 +
       'Call it with three different names.',
       'procedure Greet(name: String); begin writeln(''Hello, '', name, ''!''); end;',
       'procedure Greet(name: String);' + #13#10 + 'begin' + #13#10 + '  // print the greeting' + #13#10 + 'end;' + #13#10 + #13#10 + 'begin' + #13#10 + '  Greet(''Alice'');' + #13#10 + '  Greet(''Bob'');' + #13#10 + '  Greet(''Carol'');' + #13#10 + 'end.',
       'procedure Greet(name:String); begin writeln(''Hello, '', name, ''!''); end; begin Greet(''Alice''); Greet(''Bob''); Greet(''Carol''); end.',
       ckContainsAll, 'Hello, Alice!|Hello, Bob!|Hello, Carol!', 0,0,0, 0, 20),

    Ch(703, 'Procedure with var param',
       'Write a procedure  Double(var n: Integer)  that doubles the value of n.'  + #13#10 +
       'Set  x := 7, call  Double(x), then print x. Should print 14.',
       'procedure Double(var n: Integer); begin n := n * 2; end;',
       'procedure Double(var n: Integer);' + #13#10 + 'begin' + #13#10 + '  n := n * 2;' + #13#10 + 'end;' + #13#10 + #13#10 + 'var' + #13#10 + '  x : Integer;' + #13#10 + 'begin' + #13#10 + '  x := 7;' + #13#10 + '  Double(x);' + #13#10 + '  writeln(x);' + #13#10 + 'end.',
       'procedure Double(var n:Integer); begin n:=n*2; end; var x:Integer; begin x:=7; Double(x); writeln(x); end.',
       ckOutputIsNumber, '', 14, 0,0, 0, 25)
  ];

  // ── LESSON 8 ── Functions ─────────────────────────────────────────────────
  FLessons[7].Number := 8;
  FLessons[7].Title  := 'Functions & Return Values';
  FLessons[7].Intro  :=
    'A function is like a procedure but it RETURNS a value.'               + #13#10 +
    'Use  Result  to set the return value:'                                + #13#10 +
    ''                                                                     + #13#10 +
    '    function Square(n: Integer): Integer;'                            + #13#10 +
    '    begin'                                                            + #13#10 +
    '      Result := n * n;'                                               + #13#10 +
    '    end;'                                                             + #13#10 +
    ''                                                                     + #13#10 +
    '    begin'                                                            + #13#10 +
    '      writeln(Square(5));   // prints 25'                             + #13#10 +
    '    end.'                                                             + #13#10 +
    ''                                                                     + #13#10 +
    'Functions can call themselves — that is called recursion:'            + #13#10 +
    ''                                                                     + #13#10 +
    '    function Factorial(n: Integer): Integer;'                         + #13#10 +
    '    begin'                                                            + #13#10 +
    '      if n <= 1 then Result := 1'                                     + #13#10 +
    '      else Result := n * Factorial(n - 1);'                          + #13#10 +
    '    end;';

  FLessons[7].Challenges := [
    Ch(801, 'Max of Two',
       'Write a function  MaxOf(a, b: Integer): Integer'                   + #13#10 +
       'that returns the larger of two numbers.'                           + #13#10 +
       'Test: print MaxOf(17, 42). Should print 42.',
       'if a > b then Result := a else Result := b;',
       'function MaxOf(a, b: Integer): Integer;' + #13#10 + 'begin' + #13#10 + '  // return the larger value' + #13#10 + 'end;' + #13#10 + #13#10 + 'begin' + #13#10 + '  writeln(MaxOf(17, 42));' + #13#10 + 'end.',
       'function MaxOf(a,b:Integer):Integer; begin if a>b then Result:=a else Result:=b; end; begin writeln(MaxOf(17,42)); end.',
       ckOutputIsNumber, '', 42, 0,0, 0, 15),

    Ch(802, 'Is Prime',
       'Write a function  IsPrime(n: Integer): Boolean'                    + #13#10 +
       'that returns true if n is prime.'                                  + #13#10 +
       'Print all prime numbers from 1 to 30.',
       'Try dividing n by every number from 2 to n-1. If any divides evenly, not prime.',
       'function IsPrime(n: Integer): Boolean;' + #13#10 + 'var' + #13#10 + '  i : Integer;' + #13#10 + 'begin' + #13#10 + '  // your logic here' + #13#10 + 'end;' + #13#10 + #13#10 + 'var' + #13#10 + '  n : Integer;' + #13#10 + 'begin' + #13#10 + '  for n := 2 to 30 do' + #13#10 + '    if IsPrime(n) then writeln(n);' + #13#10 + 'end.',
       'function IsPrime(n:Integer):Boolean; var i:Integer; begin if n<2 then begin Result:=false; exit; end; Result:=true; i:=2; while i*i<=n do begin if n mod i=0 then begin Result:=false; exit; end; inc(i); end; end; var n:Integer; begin for n:=2 to 30 do if IsPrime(n) then writeln(n); end.',
       ckContainsAll, '2|3|5|7|11|13|17|19|23|29', 0,0,0, 0, 25),

    Ch(803, 'Fibonacci Function',
       'Write a recursive function  Fib(n: Integer): Integer'              + #13#10 +
       'that returns the nth Fibonacci number.'                            + #13#10 +
       'Fib(0)=0, Fib(1)=1, Fib(n)=Fib(n-1)+Fib(n-2).'                  + #13#10 +
       'Print Fib(10). Should be 55.',
       'if n <= 1 then Result := n else Result := Fib(n-1) + Fib(n-2);',
       'function Fib(n: Integer): Integer;' + #13#10 + 'begin' + #13#10 + '  // base case and recursive case' + #13#10 + 'end;' + #13#10 + #13#10 + 'begin' + #13#10 + '  writeln(Fib(10));' + #13#10 + 'end.',
       'function Fib(n:Integer):Integer; begin if n<=1 then Result:=n else Result:=Fib(n-1)+Fib(n-2); end; begin writeln(Fib(10)); end.',
       ckOutputIsNumber, '', 55, 0,0, 0, 25)
  ];

  // ── LESSON 9 ── case & caseof ─────────────────────────────────────────────
  FLessons[8].Number := 9;
  FLessons[8].Title  := 'case & caseof';
  FLessons[8].Intro  :=
    'The  case  statement is a cleaner alternative to many if/else if chains.' + #13#10 +
    'It works on INTEGER (ordinal) values only — that is real Delphi:'    + #13#10 +
    ''                                                                     + #13#10 +
    '    case day of'                                                      + #13#10 +
    '      1 : writeln(''Monday'');'                                       + #13#10 +
    '      2 : writeln(''Tuesday'');'                                      + #13#10 +
    '      6, 7 : writeln(''Weekend!'');'                                  + #13#10 +
    '    else'                                                             + #13#10 +
    '      writeln(''Weekday'');'                                          + #13#10 +
    '    end;'                                                             + #13#10 +
    ''                                                                     + #13#10 +
    'MiniDelphi also has  caseof  — our own invention for strings:'        + #13#10 +
    ''                                                                     + #13#10 +
    '    caseof colour of'                                                  + #13#10 +
    '      ''red''         : writeln(''Stop'');'                           + #13#10 +
    '      ''green'',''go'' : writeln(''Go!'');'                           + #13#10 +
    '    else'                                                             + #13#10 +
    '      writeln(''Unknown'');'                                          + #13#10 +
    '    end;';

  FLessons[8].Challenges := [
    Ch(901, 'Day Name',
       'Set  day := 3.  Using  case, print the day name:'                  + #13#10 +
       '1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday,'                    + #13#10 +
       '5=Friday, 6=Saturday, 7=Sunday',
       'case day of  1: writeln(''Monday'');  2: ...  end;',
       'var'  + #13#10 + '  day : Integer;' + #13#10 + 'begin' + #13#10 + '  day := 3;' + #13#10 + '  case day of' + #13#10 + '    // fill in arms' + #13#10 + '  end;' + #13#10 + 'end.',
       'var day:Integer; begin day:=3; case day of 1:writeln(''Monday''); 2:writeln(''Tuesday''); 3:writeln(''Wednesday''); 4:writeln(''Thursday''); 5:writeln(''Friday''); 6:writeln(''Saturday''); 7:writeln(''Sunday''); end; end.',
       ckExactOutput, 'Wednesday', 0,0,0, 0, 15),

    Ch(902, 'Season Finder',
       'Set  month := 7.  Using  case, print the season:'                  + #13#10 +
       '12,1,2=Winter   3,4,5=Spring   6,7,8=Summer   9,10,11=Autumn',
       'You can list multiple values per arm: 12, 1, 2 : writeln(''Winter'');',
       'var'  + #13#10 + '  month : Integer;' + #13#10 + 'begin' + #13#10 + '  month := 7;' + #13#10 + 'end.',
       'var month:Integer; begin month:=7; case month of 12,1,2:writeln(''Winter''); 3,4,5:writeln(''Spring''); 6,7,8:writeln(''Summer''); 9,10,11:writeln(''Autumn''); end; end.',
       ckExactOutput, 'Summer', 0,0,0, 0, 15),

    Ch(903, 'Animal Sound',
       'Set  animal := ''dog''.  Using  caseof, print the sound it makes:'  + #13#10 +
       'cat=Meow   dog=Woof   cow=Moo   duck=Quack'                       + #13#10 +
       'Anything else: Silence...',
       'caseof animal of  ''cat'': writeln(''Meow'');  ... end;',
       'var'  + #13#10 + '  animal : String;' + #13#10 + 'begin' + #13#10 + '  animal := ''dog'';' + #13#10 + '  caseof animal of' + #13#10 + '    // fill in arms' + #13#10 + '  end;' + #13#10 + 'end.',
       'var animal:String; begin animal:=''dog''; caseof animal of ''cat'':writeln(''Meow''); ''dog'':writeln(''Woof''); ''cow'':writeln(''Moo''); ''duck'':writeln(''Quack''); else writeln(''Silence...''); end; end.',
       ckExactOutput, 'Woof', 0,0,0, 0, 20)
  ];

  // ── LESSON 10 ── Putting it all together ──────────────────────────────────
  FLessons[9].Number := 10;
  FLessons[9].Title  := 'Grand Finale';
  FLessons[9].Intro  :=
    'Congratulations — you have reached the final lesson!'                 + #13#10 +
    ''                                                                     + #13#10 +
    'These challenges combine everything you have learned:'                + #13#10 +
    '  • Variables and assignment'                                         + #13#10 +
    '  • Arithmetic'                                                       + #13#10 +
    '  • if/else decisions'                                                + #13#10 +
    '  • for, while, and repeat loops'                                     + #13#10 +
    '  • Procedures and functions'                                         + #13#10 +
    '  • case and caseof'                                                  + #13#10 +
    ''                                                                     + #13#10 +
    'Complete all three to earn your certificate!';

  FLessons[9].Challenges := [
    Ch(1001, 'Number Pyramid',
       'Print this pyramid pattern for rows 1 to 5:'                      + #13#10 +
       '    1'                                                             + #13#10 +
       '    1 2'                                                           + #13#10 +
       '    1 2 3'                                                         + #13#10 +
       '    1 2 3 4'                                                       + #13#10 +
       '    1 2 3 4 5'                                                     + #13#10 +
       'Use a nested for loop. Print numbers separated by spaces.',
       'Outer loop: rows 1..5. Inner loop: cols 1..row. Use write() inside inner loop.',
       'var'  + #13#10 + '  row, col : Integer;' + #13#10 + 'begin' + #13#10 + '  for row := 1 to 5 do' + #13#10 + '  begin' + #13#10 + '    for col := 1 to row do' + #13#10 + '    begin' + #13#10 + '      // print col with space' + #13#10 + '    end;' + #13#10 + '    writeln('''');' + #13#10 + '  end;' + #13#10 + 'end.',
       'var row,col:Integer; begin for row:=1 to 5 do begin for col:=1 to row do begin write(col); write('' ''); end; writeln(''''); end; end.',
       ckContainsAll, '1 |1 2 |1 2 3 |1 2 3 4 |1 2 3 4 5', 0,0,0, 0, 25),

    Ch(1002, 'GCD Calculator',
       'Write a function  GCD(a, b: Integer): Integer'                     + #13#10 +
       'that returns the Greatest Common Divisor using the Euclidean algorithm:'  + #13#10 +
       '  while b <> 0 do: temp=b, b=a mod b, a=temp'                    + #13#10 +
       'Print GCD(48, 18). Should be 6.',
       'The Euclidean algorithm: keep replacing a with b and b with a mod b until b=0.',
       'function GCD(a, b: Integer): Integer;' + #13#10 + 'var' + #13#10 + '  temp : Integer;' + #13#10 + 'begin' + #13#10 + '  while b <> 0 do' + #13#10 + '  begin' + #13#10 + '    temp := b;' + #13#10 + '    b := a mod b;' + #13#10 + '    a := temp;' + #13#10 + '  end;' + #13#10 + '  Result := a;' + #13#10 + 'end;' + #13#10 + #13#10 + 'begin' + #13#10 + '  writeln(GCD(48, 18));' + #13#10 + 'end.',
       'function GCD(a,b:Integer):Integer; var temp:Integer; begin while b<>0 do begin temp:=b; b:=a mod b; a:=temp; end; Result:=a; end; begin writeln(GCD(48,18)); end.',
       ckOutputIsNumber, '', 6, 0,0, 0, 30),

    Ch(1003, 'Number Classifier',
       'Write a complete program that:'                                    + #13#10 +
       '  • Loops through numbers 1 to 15'                                + #13#10 +
       '  • For each, prints: [n] is [type]'                              + #13#10 +
       '  • Type is: Prime, Perfect Square, FizzBuzz, Fizz, Buzz, or Plain'+ #13#10 +
       '  • Check in that order (prime takes priority)'                   + #13#10 +
       '  Example: 1 is Perfect Square   2 is Prime   3 is Prime'         + #13#10 +
       '           4 is Perfect Square   5 is Prime   ...'                 + #13#10 +
       '  (perfect squares: 1,4,9,16; primes take priority over fizzbuzz)',
       'Write IsPrime and IsSquare functions first, then a for loop with nested if/else if.',
       'function IsPrime(n: Integer): Boolean;' + #13#10 + 'var i : Integer;' + #13#10 + 'begin' + #13#10 + '  if n < 2 then begin Result := false; exit; end;' + #13#10 + '  Result := true; i := 2;' + #13#10 + '  while i*i <= n do begin' + #13#10 + '    if n mod i = 0 then begin Result := false; exit; end;' + #13#10 + '    inc(i);' + #13#10 + '  end;' + #13#10 + 'end;' + #13#10 + #13#10 + 'function IsSquare(n: Integer): Boolean;' + #13#10 + 'var r : Integer;' + #13#10 + 'begin' + #13#10 + '  r := round(sqrt(n));' + #13#10 + '  Result := (r * r = n);' + #13#10 + 'end;' + #13#10 + #13#10 + 'var i : Integer;' + #13#10 + 'begin' + #13#10 + '  for i := 1 to 15 do' + #13#10 + '  begin' + #13#10 + '    write(i, '' is '');' + #13#10 + '    if IsSquare(i) and not IsPrime(i) then writeln(''Perfect Square'')' + #13#10 + '    else if IsPrime(i) then writeln(''Prime'')' + #13#10 + '    else if i mod 15 = 0 then writeln(''FizzBuzz'')' + #13#10 + '    else if i mod 3 = 0 then writeln(''Fizz'')' + #13#10 + '    else if i mod 5 = 0 then writeln(''Buzz'')' + #13#10 + '    else writeln(''Plain'');' + #13#10 + '  end;' + #13#10 + 'end.',
       'function IsPrime(n:Integer):Boolean; var i:Integer; begin if n<2 then begin Result:=false; exit; end; Result:=true; i:=2; while i*i<=n do begin if n mod i=0 then begin Result:=false; exit; end; inc(i); end; end; function IsSquare(n:Integer):Boolean; var r:Integer; begin r:=round(sqrt(n)); Result:=(r*r=n); end; var i:Integer; begin for i:=1 to 15 do begin write(i,'' is ''); if IsSquare(i) and not IsPrime(i) then writeln(''Perfect Square'') else if IsPrime(i) then writeln(''Prime'') else if i mod 15=0 then writeln(''FizzBuzz'') else if i mod 3=0 then writeln(''Fizz'') else if i mod 5=0 then writeln(''Buzz'') else writeln(''Plain''); end; end.',
       ckContainsAll, 'is Prime|is Perfect Square|is Fizz|is Buzz', 0,0,0, 0, 40)
  ];

  // ── LESSON 11 ── Message Boxes ──────────────────────────────────────────
  FLessons[10].Number := 11;
  FLessons[10].Title  := 'Message Boxes';
  FLessons[10].Intro  :=
    'MiniDelphi can pop up real Windows dialog boxes!'                     + #13#10 +
    ''                                                                     + #13#10 +
    'ShowMessage — displays a message and waits for OK:'                   + #13#10 +
    ''                                                                     + #13#10 +
    '    ShowMessage(''Hello from MiniDelphi!'');'                         + #13#10 +
    ''                                                                     + #13#10 +
    'Confirm — asks a Yes/No question, returns Boolean:'                   + #13#10 +
    ''                                                                     + #13#10 +
    '    if Confirm(''Do you want to continue?'') then'                    + #13#10 +
    '      writeln(''You said Yes!'')'                                     + #13#10 +
    '    else'                                                             + #13#10 +
    '      writeln(''You said No.'');'                                     + #13#10 +
    ''                                                                     + #13#10 +
    'InputBox — asks the user to type something, returns the text:'        + #13#10 +
    ''                                                                     + #13#10 +
    '    var name : String;'                                               + #13#10 +
    '    name := InputBox(''Enter your name'', ''Name'', ''World'');'      + #13#10 +
    '    writeln(''Hello, '', name, ''!'');'                               + #13#10 +
    ''                                                                     + #13#10 +
    'ShowInfoBox, ShowWarningBox, ShowErrorBox — coloured dialogs:'        + #13#10 +
    ''                                                                     + #13#10 +
    '    ShowInfoBox(''Everything is fine!'');'                            + #13#10 +
    '    ShowWarningBox(''Be careful!'');'                                  + #13#10 +
    '    ShowErrorBox(''Something went wrong!'');';

  FLessons[10].Challenges := [
    Ch(1101, 'Say Hello in a Box',
       'Use  ShowMessage  to pop up a box saying:  Hello from MiniDelphi!'  + #13#10 +
       'Then print  Done  to the output window.',
       'ShowMessage(''Hello from MiniDelphi!'');  writeln(''Done'');',
       'begin' + #13#10 + '  ShowMessage(''Hello from MiniDelphi!'');' + #13#10 + '  writeln(''Done'');' + #13#10 + 'end.',
       'begin ShowMessage(''Hello from MiniDelphi!''); writeln(''Done''); end.',
       ckExactOutput, 'Done', 0,0,0, 0, 10),

    Ch(1102, 'Ask a Question',
       'Use  Confirm  to ask: "Do you like Delphi?"'                       + #13#10 +
       'If Yes, print  Great choice!   If No, print  You will learn to!',
       'if Confirm(''Do you like Delphi?'') then writeln(''Great choice!'') else ...',
       'begin' + #13#10 + '  if Confirm(''Do you like Delphi?'') then' + #13#10 + '    writeln(''Great choice!'')' + #13#10 + '  else' + #13#10 + '    writeln(''You will learn to!'');' + #13#10 + 'end.',
       'begin if Confirm(''Do you like Delphi?'') then writeln(''Great choice!'') else writeln(''You will learn to!''); end.',
       ckAnyOutput, '', 0,0,0, 0, 15),

    Ch(1103, 'Personal Greeter',
       'Use  InputBox  to ask the user their name.'                        + #13#10 +
       'Then use  ShowMessage  to greet them: "Hello, [name]! Welcome to Delphi!"'  + #13#10 +
       'Also print the same greeting to the output window.',
       'var name : String;' + #13#10 + 'name := InputBox(''What is your name?'', ''Name'', '''');',
       'var'  + #13#10 + '  name : String;' + #13#10 + 'begin' + #13#10 + '  name := InputBox(''What is your name?'', ''Name'', '''');' + #13#10 + '  ShowMessage(''Hello, '' + name + ''! Welcome to Delphi!'');' + #13#10 + '  writeln(''Hello, '', name, ''! Welcome to Delphi!'');' + #13#10 + 'end.',
       'var name:String; begin name:=InputBox(''What is your name?'',''Name'',''''); ShowMessage(''Hello, ''+name+''! Welcome to Delphi!''); writeln(''Hello, '',name,''! Welcome to Delphi!''); end.',
       ckAnyOutput, '', 0,0,0, 0, 20)
  ];

  // ── LESSON 12 ── File Dialogs ────────────────────────────────────────────
  FLessons[11].Number := 12;
  FLessons[11].Title  := 'File Dialogs';
  FLessons[11].Intro  :=
    'File dialogs let your program ask the user to pick a file.'           + #13#10 +
    ''                                                                     + #13#10 +
    'OpenFileDialog — shows the standard Windows Open dialog:'             + #13#10 +
    ''                                                                     + #13#10 +
    '    var fname : String;'                                              + #13#10 +
    '    fname := OpenFileDialog(''Text Files|*.txt|All Files|*.*'');'     + #13#10 +
    '    if fname <> '''' then'                                            + #13#10 +
    '      writeln(''You chose: '', fname)'                                + #13#10 +
    '    else'                                                             + #13#10 +
    '      writeln(''No file chosen.'');'                                  + #13#10 +
    ''                                                                     + #13#10 +
    'SaveFileDialog — shows the standard Windows Save dialog:'             + #13#10 +
    ''                                                                     + #13#10 +
    '    fname := SaveFileDialog(''Text Files|*.txt'', ''txt'');'          + #13#10 +
    '    if fname <> '''' then'                                            + #13#10 +
    '      writeln(''Will save to: '', fname);'                            + #13#10 +
    ''                                                                     + #13#10 +
    'SelectDirectoryDialog — lets user pick a folder:'                     + #13#10 +
    ''                                                                     + #13#10 +
    '    var folder : String;'                                             + #13#10 +
    '    folder := SelectDirectoryDialog;'                                 + #13#10 +
    '    writeln(''Folder: '', folder);'                                   + #13#10 +
    ''                                                                     + #13#10 +
    'The filter string uses the format:  Description|*.ext|Description|*.ext';

  FLessons[11].Challenges := [
    Ch(1201, 'Open a File',
       'Show an Open File dialog filtered to text files.'                  + #13#10 +
       'If the user picks a file, print:  Selected: [filename]'           + #13#10 +
       'If they cancel, print:  Cancelled.',
       'fname := OpenFileDialog(''Text Files|*.txt|All Files|*.*'');',
       'var'  + #13#10 + '  fname : String;' + #13#10 + 'begin' + #13#10 + '  fname := OpenFileDialog(''Text Files|*.txt|All Files|*.*'');' + #13#10 + '  if fname <> '''' then' + #13#10 + '    writeln(''Selected: '', fname)' + #13#10 + '  else' + #13#10 + '    writeln(''Cancelled.'');' + #13#10 + 'end.',
       'var fname:String; begin fname:=OpenFileDialog(''Text Files|*.txt|All Files|*.*''); if fname<>'' '' then writeln(''Selected: '',fname) else writeln(''Cancelled.''); end.',
       ckAnyOutput, '', 0,0,0, 0, 15),

    Ch(1202, 'Save Dialog',
       'Show a Save File dialog for text files.'                           + #13#10 +
       'If the user picks a location, print:  Will save to: [filename]'   + #13#10 +
       'If they cancel, print:  Save cancelled.',
       'fname := SaveFileDialog(''Text Files|*.txt'', ''txt'');',
       'var'  + #13#10 + '  fname : String;' + #13#10 + 'begin' + #13#10 + '  fname := SaveFileDialog(''Text Files|*.txt'', ''txt'');' + #13#10 + '  if fname <> '''' then' + #13#10 + '    writeln(''Will save to: '', fname)' + #13#10 + '  else' + #13#10 + '    writeln(''Save cancelled.'');' + #13#10 + 'end.',
       'var fname:String; begin fname:=SaveFileDialog(''Text Files|*.txt'',''txt''); if fname<>'' '' then writeln(''Will save to: '',fname) else writeln(''Save cancelled.''); end.',
       ckAnyOutput, '', 0,0,0, 0, 15),

    Ch(1203, 'File Picker with Confirmation',
       'Show an Open dialog. If a file is chosen, ask  Confirm  whether'  + #13#10 +
       'to process it. Print either  Processing: [name]  or  Skipped.'    + #13#10 +
       'If no file chosen, print  No file selected.',
       'Combine OpenFileDialog + Confirm together.',
       'var'  + #13#10 + '  fname : String;' + #13#10 + 'begin' + #13#10 + '  fname := OpenFileDialog(''All Files|*.*'');' + #13#10 + '  if fname <> '''' then' + #13#10 + '  begin' + #13#10 + '    if Confirm(''Process '' + fname + ''?'') then' + #13#10 + '      writeln(''Processing: '', fname)' + #13#10 + '    else' + #13#10 + '      writeln(''Skipped.'');' + #13#10 + '  end' + #13#10 + '  else' + #13#10 + '    writeln(''No file selected.'');' + #13#10 + 'end.',
       'var fname:String; begin fname:=OpenFileDialog(''All Files|*.*''); if fname<>'' '' then begin if Confirm(''Process?'') then writeln(''Processing: '',fname) else writeln(''Skipped.''); end else writeln(''No file selected.''); end.',
       ckAnyOutput, '', 0,0,0, 0, 20)
  ];

  // ── LESSON 13 ── File I/O ────────────────────────────────────────────────
  FLessons[12].Number := 13;
  FLessons[12].Title  := 'Reading & Writing Files';
  FLessons[12].Intro  :=
    'Your program can read and write real files on disk!'                  + #13#10 +
    ''                                                                     + #13#10 +
    'WriteFile — creates or overwrites a file:'                            + #13#10 +
    ''                                                                     + #13#10 +
    '    WriteFile(''notes.txt'', ''Hello, file!'');'                      + #13#10 +
    '    writeln(''File written.'');'                                      + #13#10 +
    ''                                                                     + #13#10 +
    'AppendFile — adds a line to an existing file (or creates it):'        + #13#10 +
    ''                                                                     + #13#10 +
    '    AppendFile(''log.txt'', ''Entry number 1'');'                     + #13#10 +
    '    AppendFile(''log.txt'', ''Entry number 2'');'                     + #13#10 +
    ''                                                                     + #13#10 +
    'ReadFile — reads the whole file into a string:'                       + #13#10 +
    ''                                                                     + #13#10 +
    '    var contents : String;'                                           + #13#10 +
    '    contents := ReadFile(''notes.txt'');'                             + #13#10 +
    '    writeln(contents);'                                               + #13#10 +
    ''                                                                     + #13#10 +
    'FileExists — checks if a file is there:'                              + #13#10 +
    ''                                                                     + #13#10 +
    '    if FileExists(''notes.txt'') then'                                + #13#10 +
    '      writeln(''Found it!'');'                                        + #13#10 +
    ''                                                                     + #13#10 +
    'GetAppPath — returns the folder your program lives in:'               + #13#10 +
    ''                                                                     + #13#10 +
    '    writeln(GetAppPath);';

  FLessons[12].Challenges := [
    Ch(1301, 'Write and Read Back',
       'Write the text  "MiniDelphi was here!"  to a file called  test.txt.'  + #13#10 +
       'Then read it back and print the contents.',
       'WriteFile(''test.txt'', ''MiniDelphi was here!'');  then ReadFile(''test.txt'')',
       'begin' + #13#10 + '  WriteFile(''test.txt'', ''MiniDelphi was here!'');' + #13#10 + '  writeln(ReadFile(''test.txt''));' + #13#10 + 'end.',
       'begin WriteFile(''test.txt'',''MiniDelphi was here!''); writeln(ReadFile(''test.txt'')); end.',
       ckContainsAll, 'MiniDelphi was here!', 0,0,0, 0, 20),

    Ch(1302, 'Build a Log File',
       'Using  AppendFile, write 5 numbered log entries to  log.txt:'      + #13#10 +
       '  Log entry 1, Log entry 2, ... Log entry 5'                      + #13#10 +
       'Then read the file back and print it. Use a for loop.',
       'for i := 1 to 5 do AppendFile(''log.txt'', ''Log entry '' + IntToStr(i));',
       'var'  + #13#10 + '  i : Integer;' + #13#10 + 'begin' + #13#10 + '  for i := 1 to 5 do' + #13#10 + '    AppendFile(''log.txt'', ''Log entry '' + IntToStr(i));' + #13#10 + '  writeln(ReadFile(''log.txt''));' + #13#10 + 'end.',
       'var i:Integer; begin for i:=1 to 5 do AppendFile(''log.txt'',''Log entry ''+IntToStr(i)); writeln(ReadFile(''log.txt'')); end.',
       ckContainsAll, 'Log entry 1|Log entry 5', 0,0,0, 0, 25),

    Ch(1303, 'File Exists Check',
       'Write something to  check.txt.'                                    + #13#10 +
       'Then use  FileExists  to verify it is there.'                      + #13#10 +
       'Print  File found!  if it exists, or  File missing!  if not.',
       'WriteFile then FileExists(''check.txt'')',
       'begin' + #13#10 + '  WriteFile(''check.txt'', ''test'');' + #13#10 + '  if FileExists(''check.txt'') then' + #13#10 + '    writeln(''File found!'')' + #13#10 + '  else' + #13#10 + '    writeln(''File missing!'');' + #13#10 + 'end.',
       'begin WriteFile(''check.txt'',''test''); if FileExists(''check.txt'') then writeln(''File found!'') else writeln(''File missing!''); end.',
       ckExactOutput, 'File found!', 0,0,0, 0, 20),

    Ch(1304, 'Save with Dialog',
       'Ask the user to choose a save location with  SaveFileDialog.'      + #13#10 +
       'If they choose a file, write  "Saved by MiniDelphi!"  to it,'     + #13#10 +
       'then print  Saved to: [filename]'                                  + #13#10 +
       'If they cancel, print  Save was cancelled.',
       'Combine SaveFileDialog + WriteFile + ShowMessage.',
       'var'  + #13#10 + '  fname : String;' + #13#10 + 'begin' + #13#10 + '  fname := SaveFileDialog(''Text Files|*.txt'', ''txt'');' + #13#10 + '  if fname <> '''' then' + #13#10 + '  begin' + #13#10 + '    WriteFile(fname, ''Saved by MiniDelphi!'');' + #13#10 + '    ShowMessage(''File saved!'');' + #13#10 + '    writeln(''Saved to: '', fname);' + #13#10 + '  end' + #13#10 + '  else' + #13#10 + '    writeln(''Save was cancelled.'');' + #13#10 + 'end.',
       'var fname:String; begin fname:=SaveFileDialog(''Text Files|*.txt'',''txt''); if fname<>'' '' then begin WriteFile(fname,''Saved by MiniDelphi!''); ShowMessage(''File saved!''); writeln(''Saved to: '',fname); end else writeln(''Save was cancelled.''); end.',
       ckAnyOutput, '', 0,0,0, 0, 25)
  ];

end;

function TLearnCurriculum.LessonCount: Integer;
begin
  Result := Length(FLessons);
end;

function TLearnCurriculum.GetLesson(I: Integer): TLesson;
begin
  Result := FLessons[I];
end;

function TLearnCurriculum.TotalChallenges: Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to High(FLessons) do
    Inc(Result, Length(FLessons[I].Challenges));
end;

function TLearnCurriculum.TotalPoints: Integer;
var I, J: Integer;
begin
  Result := 0;
  for I := 0 to High(FLessons) do
    for J := 0 to High(FLessons[I].Challenges) do
      Inc(Result, FLessons[I].Challenges[J].Points);
end;

// ═══════════════════════════════════════════════════════════════════════════
//  ANSWER CHECKER
// ═══════════════════════════════════════════════════════════════════════════

class function TAnswerChecker.RunCode(const Source: string;
  Output: TStrings): Boolean;
var
  Lex   : TLexer;
  Par   : TParser;
  Prog  : TProgramNode;
  Interp: TInterpreter;
begin
  Result := False;
  try
    Lex := TLexer.Create(Source);
    try
      Lex.Tokenise;
      Par := TParser.Create(Lex.Tokens);
      try
        Prog := Par.Parse;
        try
          Interp := TInterpreter.Create(Prog, Output);
          try
            Interp.MaxSteps := 500000;
            Interp.Run;
            Result := True;
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
  except
    // Result stays False; caller can inspect Output for messages
  end;
end;

class function TAnswerChecker.TrimOutput(Lines: TStrings): string;
var
  I: Integer;
  Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    for I := 0 to Lines.Count - 1 do
      if Trim(Lines[I]) <> '' then
        Parts.Add(Trim(Lines[I]));
    Result := Trim(Parts.Text);
  finally
    Parts.Free;
  end;
end;

class function TAnswerChecker.Check(const Ch: TChallenge;
  const Source: string; out Msg: string): Boolean;
var
  Output     : TStringList;
  OutText    : string;
  Parts      : TArray<string>;
  Part       : string;
  Num        : Double;
  NonEmpty   : Integer;
  I          : Integer;
  SplitStart : Integer;
  PI         : Integer;
  PipeStr    : string;
begin
  Result := False;
  Output := TStringList.Create;
  try
    if not RunCode(Source, Output) then
    begin
      Msg := '✗  Your program has an error. Check the code carefully.';
      Exit;
    end;

    OutText := TrimOutput(Output);

    case Ch.CheckKind of

      ckExactOutput:
      begin
        if Trim(OutText) = Trim(Ch.Expected) then
        begin
          Result := True;
          Msg    := '✓  Perfect! Output matches exactly.';
        end
        else
          Msg := Format('✗  Expected:  "%s"' + #13#10 +
                        '   Got:       "%s"',
                        [Trim(Ch.Expected), Trim(OutText)]);
      end;

      ckContainsAll:
      begin
        // Split Expected by pipe character
        PipeStr := Ch.Expected + '|';
        SplitStart := 1;
        Result := True;
        for PI := 1 to Length(PipeStr) do
        begin
          if PipeStr[PI] = '|' then
          begin
            Part := Trim(Copy(PipeStr, SplitStart, PI - SplitStart));
            SplitStart := PI + 1;
            if (Part <> '') and (Pos(Part, Output.Text) = 0) then
            begin
              Result := False;
              Msg    := Format('✗  Output should contain: "%s"', [Part]);
              Break;
            end;
          end;
        end;
        if Result then
          Msg := '✓  Great! Output contains all the required text.';
      end;

      ckOutputIsNumber:
      begin
        if TryStrToFloat(Trim(Output[0]), Num) then
        begin
          if Abs(Num - Ch.ExpectedNum) < 0.01 then
          begin
            Result := True;
            Msg    := Format('✓  Correct! Answer is %g.', [Num]);
          end
          else
            Msg := Format('✗  Expected %g but got %g.', [Ch.ExpectedNum, Num]);
        end
        else
          Msg := '✗  Your program should print a number.';
      end;

      ckOutputInRange:
      begin
        if TryStrToFloat(Trim(Output[0]), Num) then
        begin
          if (Num >= Ch.RangeLo) and (Num <= Ch.RangeHi) then
          begin
            Result := True;
            Msg    := Format('✓  Correct! %g is in range.', [Num]);
          end
          else
            Msg := Format('✗  Got %g, expected a value between %g and %g.',
                          [Num, Ch.RangeLo, Ch.RangeHi]);
        end
        else
          Msg := '✗  Your program should print a number.';
      end;

      ckLineCount:
      begin
        NonEmpty := 0;
        for I := 0 to Output.Count - 1 do
          if Trim(Output[I]) <> '' then Inc(NonEmpty);
        if NonEmpty = Ch.LineCount then
        begin
          Result := True;
          Msg    := Format('✓  Correct! Output has %d lines.', [NonEmpty]);
        end
        else
          Msg := Format('✗  Expected %d non-empty lines, got %d.',
                        [Ch.LineCount, NonEmpty]);
      end;

      ckAnyOutput:
      begin
        if OutText <> '' then
        begin
          Result := True;
          Msg    := '✓  Well done! Your program produced output.';
        end
        else
          Msg := '✗  Your program produced no output.';
      end;

    end;
  finally
    Output.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  PROGRESS STORE
// ═══════════════════════════════════════════════════════════════════════════

constructor TProgressStore.Create;
begin
  inherited;
  FPath := ChangeFileExt(ParamStr(0), '.progress.ini');
  FIni  := TIniFile.Create(FPath);
  LoadName;
end;

destructor TProgressStore.Destroy;
begin
  FIni.Free;
  inherited;
end;

function TProgressStore.IsComplete(ChallengeID: Integer): Boolean;
begin
  Result := FIni.ReadBool('Progress', 'C' + IntToStr(ChallengeID), False);
end;

procedure TProgressStore.MarkComplete(ChallengeID: Integer);
begin
  FIni.WriteBool('Progress', 'C' + IntToStr(ChallengeID), True);
end;

procedure TProgressStore.Reset;
begin
  FIni.EraseSection('Progress');
end;

function TProgressStore.CompletedCount: Integer;
var
  Keys : TStringList;
  K    : string;
begin
  Result := 0;
  Keys   := TStringList.Create;
  try
    FIni.ReadSection('Progress', Keys);
    for K in Keys do
      if FIni.ReadBool('Progress', K, False) then
        Inc(Result);
  finally
    Keys.Free;
  end;
end;

function TProgressStore.EarnedPoints: Integer;
begin
  // We store points separately for speed
  Result := FIni.ReadInteger('Score', 'TotalPoints', 0);
end;

procedure TProgressStore.AddPoints(N: Integer);
begin
  FIni.WriteInteger('Score', 'TotalPoints', EarnedPoints + N);
end;

procedure TProgressStore.SaveName;
begin
  FIni.WriteString('Student', 'Name', FName);
end;

procedure TProgressStore.LoadName;
begin
  FName := FIni.ReadString('Student', 'Name', '');
end;

// ═══════════════════════════════════════════════════════════════════════════
//  CERTIFICATE FORM
// ═══════════════════════════════════════════════════════════════════════════

constructor TCertificateForm.Create(AOwner: TComponent;
  const StudentName: string; Points, Total: Integer);
begin
  inherited CreateNew(AOwner);
  Caption    := 'MiniDelphi Certificate of Achievement';
  Width      := 700;
  Height     := 540;
  Position   := poScreenCenter;
  BorderStyle := bsDialog;
  BuildUI(StudentName, Points, Total);
end;

procedure TCertificateForm.BuildUI(const StudentName: string;
  Points, Total: Integer);
var
  Lines : TStringList;
  Pct   : Integer;
begin
  Pct := Round(Points / Max(Total, 1) * 100);

  FMemo            := TMemo.Create(Self);
  FMemo.Parent     := Self;
  FMemo.Align      := alClient;
  FMemo.ReadOnly   := True;
  FMemo.WordWrap   := True;
  FMemo.Font.Name  := 'Consolas';
  FMemo.Font.Size  := 11;
  FMemo.Color      := $00FFFFF0;   // ivory
  FMemo.Font.Color := $00000080;   // dark blue

  Lines := TStringList.Create;
  try
    Lines.Add('');
    Lines.Add('  ╔══════════════════════════════════════════════════════╗');
    Lines.Add('  ║         CERTIFICATE OF ACHIEVEMENT                  ║');
    Lines.Add('  ║              MiniDelphi Learning Course              ║');
    Lines.Add('  ╚══════════════════════════════════════════════════════╝');
    Lines.Add('');
    Lines.Add('  This certifies that');
    Lines.Add('');
    if StudentName <> '' then
      Lines.Add('        ' + UpperCase(StudentName))
    else
      Lines.Add('        A DEDICATED STUDENT');
    Lines.Add('');
    Lines.Add('  has successfully completed all 10 lessons and');
    Lines.Add('  ' + IntToStr(Total div 10) + '0 programming challenges in the');
    Lines.Add('  MiniDelphi Interactive Delphi Learning Course.');
    Lines.Add('');
    Lines.Add('  ─────────────────────────────────────────────────────');
    Lines.Add('');
    Lines.Add(Format('  Score:  %d / %d points  (%d%%)', [Points, Total, Pct]));
    Lines.Add('');
    Lines.Add('  Topics mastered:');
    Lines.Add('    ✓  Variables and data types');
    Lines.Add('    ✓  Arithmetic and built-in functions');
    Lines.Add('    ✓  if / then / else decisions');
    Lines.Add('    ✓  while, repeat, and for loops');
    Lines.Add('    ✓  Procedures with parameters');
    Lines.Add('    ✓  Functions and recursion');
    Lines.Add('    ✓  case and caseof statements');
    Lines.Add('');
    Lines.Add('  ─────────────────────────────────────────────────────');
    Lines.Add('');
    Lines.Add('  Awarded:  ' + DateToStr(Now));
    Lines.Add('');
    Lines.Add('  ★ ★ ★  Well done! You are ready for real Delphi!  ★ ★ ★');
    Lines.Add('');

    FMemo.Lines.Assign(Lines);
  finally
    Lines.Free;
  end;

  FBtn          := TButton.Create(Self);
  FBtn.Parent   := Self;
  FBtn.Caption  := 'Close';
  FBtn.Width    := 100;
  FBtn.Height   := 32;
  FBtn.Left     := (Width - FBtn.Width) div 2;
  FBtn.Top      := Height - 60;
  FBtn.Anchors  := [akBottom, akLeft];
  FBtn.OnClick  := OnClose;
end;

procedure TCertificateForm.OnClose(Sender: TObject);
begin
  Close;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  LEARN TAB
// ═══════════════════════════════════════════════════════════════════════════

constructor TLearnTab.Create(AParent: TWinControl);
begin
  inherited Create;
  FParent      := AParent;
  FCurriculum  := TLearnCurriculum.Create;
  FProgress    := TProgressStore.Create;
  FCurLesson   := 0;
  FCurChallenge := 0;
  BuildUI;
  BuildNavTree;
  LoadChallenge;
  UpdateScore;
end;

destructor TLearnTab.Destroy;
begin
  FCurriculum.Free;
  FProgress.Free;
  inherited;
end;

function TLearnTab.CurrentLesson: TLesson;
begin
  Result := FCurriculum.GetLesson(FCurLesson);
end;

function TLearnTab.CurrentChallenge: TChallenge;
begin
  Result := CurrentLesson.Challenges[FCurChallenge];
end;

// ---------------------------------------------------------------------------
//  Build the VCL layout
// ---------------------------------------------------------------------------
procedure TLearnTab.BuildUI;
const
  NAV_W   = 220;
  BTN_H   = 28;
  PAD     = 6;
  DARK    = $00252526;
  DARKER  = $001E1E1E;
  ACCENT  = $00C87533;   // copper/gold
  GREEN   = $0056D364;
begin
  // Outer fills the tab sheet
  FOuterPanel            := TPanel.Create(FParent);
  FOuterPanel.Parent     := FParent;
  FOuterPanel.Align      := alClient;
  FOuterPanel.BevelOuter := bvNone;
  FOuterPanel.Color      := DARKER;

  // ── Left navigation ──────────────────────────────────────────────────────
  FNavPanel              := TPanel.Create(FOuterPanel);
  FNavPanel.Parent       := FOuterPanel;
  FNavPanel.Align        := alLeft;
  FNavPanel.Width        := NAV_W;
  FNavPanel.BevelOuter   := bvNone;
  FNavPanel.Color        := DARK;

  FLabelName             := TLabel.Create(FNavPanel);
  FLabelName.Parent      := FNavPanel;
  FLabelName.Align       := alTop;
  FLabelName.Caption     := '  Your name:';
  FLabelName.Height      := 20;
  FLabelName.Font.Color  := clSilver;

  FEditName              := TEdit.Create(FNavPanel);
  FEditName.Parent       := FNavPanel;
  FEditName.Align        := alTop;
  FEditName.Height       := 26;
  FEditName.Font.Name    := 'Segoe UI';
  FEditName.Color        := $00303030;
  FEditName.Font.Color   := clWhite;
  FEditName.Text         := FProgress.StudentName;

  FBtnSaveName           := TButton.Create(FNavPanel);
  FBtnSaveName.Parent    := FNavPanel;
  FBtnSaveName.Align     := alTop;
  FBtnSaveName.Height    := BTN_H;
  FBtnSaveName.Caption   := 'Save Name';
  FBtnSaveName.OnClick   := OnSaveName;

  FLabelScore            := TLabel.Create(FNavPanel);
  FLabelScore.Parent     := FNavPanel;
  FLabelScore.Align      := alTop;
  FLabelScore.Height     := 32;
  FLabelScore.Font.Color := ACCENT;
  FLabelScore.Font.Style := [fsBold];
  FLabelScore.Caption    := '  Score: 0 pts';

  FNavTree               := TTreeView.Create(FNavPanel);
  FNavTree.Parent        := FNavPanel;
  FNavTree.Align         := alClient;
  FNavTree.ReadOnly      := True;
  FNavTree.Color         := DARK;
  FNavTree.Font.Color    := clSilver;
  FNavTree.OnClick       := OnNavSelect;
  FNavTree.HideSelection := False;
  FNavTree.Indent        := 16;

  FBtnReset              := TButton.Create(FNavPanel);
  FBtnReset.Parent       := FNavPanel;
  FBtnReset.Align        := alBottom;
  FBtnReset.Height       := BTN_H;
  FBtnReset.Caption      := '⚠ Reset All Progress';
  FBtnReset.Font.Color   := clRed;
  FBtnReset.OnClick      := OnReset;

  // ── Right content ─────────────────────────────────────────────────────────
  FContentPanel            := TPanel.Create(FOuterPanel);
  FContentPanel.Parent     := FOuterPanel;
  FContentPanel.Align      := alClient;
  FContentPanel.BevelOuter := bvNone;
  FContentPanel.Color      := DARKER;

  // Header strip
  FHeaderPanel             := TPanel.Create(FContentPanel);
  FHeaderPanel.Parent      := FContentPanel;
  FHeaderPanel.Align       := alTop;
  FHeaderPanel.Height      := 36;
  FHeaderPanel.BevelOuter  := bvNone;
  FHeaderPanel.Color       := $00003366;   // dark blue header

  FLabelLesson             := TLabel.Create(FHeaderPanel);
  FLabelLesson.Parent      := FHeaderPanel;
  FLabelLesson.Left        := 8;
  FLabelLesson.Top         := 8;
  FLabelLesson.Width       := 500;
  FLabelLesson.Font.Color  := clWhite;
  FLabelLesson.Font.Style  := [fsBold];
  FLabelLesson.Font.Size   := 11;
  FLabelLesson.Caption     := '';

  FLabelStars              := TLabel.Create(FHeaderPanel);
  FLabelStars.Parent       := FHeaderPanel;
  FLabelStars.Left         := 550;
  FLabelStars.Top          := 8;
  FLabelStars.Width        := 200;
  FLabelStars.Font.Color   := ACCENT;
  FLabelStars.Font.Size    := 12;
  FLabelStars.Caption      := '';

  // Intro/instruction memo
  FIntroMemo               := TMemo.Create(FContentPanel);
  FIntroMemo.Parent        := FContentPanel;
  FIntroMemo.Align         := alTop;
  FIntroMemo.Height        := 170;
  FIntroMemo.ReadOnly      := True;
  FIntroMemo.WordWrap      := True;
  FIntroMemo.ScrollBars    := ssVertical;
  FIntroMemo.Font.Name     := 'Consolas';
  FIntroMemo.Font.Size     := 9;
  FIntroMemo.Color         := $00002040;
  FIntroMemo.Font.Color    := $00E0E0E0;

  // Code label
  FCodeLabel               := TLabel.Create(FContentPanel);
  FCodeLabel.Parent        := FContentPanel;
  FCodeLabel.Align         := alTop;
  FCodeLabel.Height        := 20;
  FCodeLabel.Caption       := '  ✏  Your code:';
  FCodeLabel.Font.Color    := ACCENT;
  FCodeLabel.Font.Style    := [fsBold];

  // Code editor
  FCodeMemo                := TMemo.Create(FContentPanel);
  FCodeMemo.Parent         := FContentPanel;
  FCodeMemo.Align          := alTop;
  FCodeMemo.Height         := 180;
  FCodeMemo.WordWrap       := False;
  FCodeMemo.ScrollBars     := ssBoth;
  FCodeMemo.Font.Name      := 'Consolas';
  FCodeMemo.Font.Size      := 10;
  FCodeMemo.Color          := $001E1E1E;
  FCodeMemo.Font.Color     := $00DCDCDC;

  // Button strip
  FHintPanel               := TPanel.Create(FContentPanel);
  FHintPanel.Parent        := FContentPanel;
  FHintPanel.Align         := alTop;
  FHintPanel.Height        := BTN_H + PAD * 2;
  FHintPanel.BevelOuter    := bvNone;
  FHintPanel.Color         := DARK;

  FBtnHint                 := TButton.Create(FHintPanel);
  FBtnHint.Parent          := FHintPanel;
  FBtnHint.Caption         := '💡 Hint';
  FBtnHint.Left            := PAD;  FBtnHint.Top := PAD;
  FBtnHint.Width           := 90;   FBtnHint.Height := BTN_H;
  FBtnHint.OnClick         := OnHint;

  FBtnCheck                := TButton.Create(FHintPanel);
  FBtnCheck.Parent         := FHintPanel;
  FBtnCheck.Caption        := '▶ Run & Check';
  FBtnCheck.Left           := PAD + 96;  FBtnCheck.Top := PAD;
  FBtnCheck.Width          := 120;       FBtnCheck.Height := BTN_H;
  FBtnCheck.Font.Style     := [fsBold];
  FBtnCheck.OnClick        := OnCheck;

  FBtnSolution             := TButton.Create(FHintPanel);
  FBtnSolution.Parent      := FHintPanel;
  FBtnSolution.Caption     := '👁 Solution';
  FBtnSolution.Left        := PAD + 222; FBtnSolution.Top := PAD;
  FBtnSolution.Width       := 100;       FBtnSolution.Height := BTN_H;
  FBtnSolution.OnClick     := OnSolution;

  FBtnPrev                 := TButton.Create(FHintPanel);
  FBtnPrev.Parent          := FHintPanel;
  FBtnPrev.Caption         := '◀ Prev';
  FBtnPrev.Left            := PAD + 330; FBtnPrev.Top := PAD;
  FBtnPrev.Width           := 80;        FBtnPrev.Height := BTN_H;
  FBtnPrev.OnClick         := OnPrev;

  FBtnNext                 := TButton.Create(FHintPanel);
  FBtnNext.Parent          := FHintPanel;
  FBtnNext.Caption         := 'Next ▶';
  FBtnNext.Left            := PAD + 416; FBtnNext.Top := PAD;
  FBtnNext.Width           := 80;        FBtnNext.Height := BTN_H;
  FBtnNext.OnClick         := OnNext;

  // Result strip
  FResultPanel             := TPanel.Create(FContentPanel);
  FResultPanel.Parent      := FContentPanel;
  FResultPanel.Align       := alTop;
  FResultPanel.Height      := 40;
  FResultPanel.BevelOuter  := bvNone;
  FResultPanel.Color       := DARKER;

  FResultLabel             := TLabel.Create(FResultPanel);
  FResultLabel.Parent      := FResultPanel;
  FResultLabel.Left        := 8;
  FResultLabel.Top         := 10;
  FResultLabel.Width       := 700;
  FResultLabel.Font.Name   := 'Consolas';
  FResultLabel.Font.Size   := 10;
  FResultLabel.Font.Style  := [fsBold];
  FResultLabel.Caption     := '';

  // Output area
  FOutputLabel             := TLabel.Create(FContentPanel);
  FOutputLabel.Parent      := FContentPanel;
  FOutputLabel.Align       := alTop;
  FOutputLabel.Height      := 18;
  FOutputLabel.Caption     := '  Program output:';
  FOutputLabel.Font.Color  := clSilver;

  FOutputMemo              := TMemo.Create(FContentPanel);
  FOutputMemo.Parent       := FContentPanel;
  FOutputMemo.Align        := alClient;
  FOutputMemo.ReadOnly     := True;
  FOutputMemo.ScrollBars   := ssVertical;
  FOutputMemo.Font.Name    := 'Consolas';
  FOutputMemo.Font.Size    := 9;
  FOutputMemo.Color        := $00121212;
  FOutputMemo.Font.Color   := GREEN;
end;

// ---------------------------------------------------------------------------
//  Build the tree view: Lesson nodes with challenge children
// ---------------------------------------------------------------------------
procedure TLearnTab.BuildNavTree;
var
  I, J    : Integer;
  Lesson  : TLesson;
  Ch      : TChallenge;
  LNode   : TTreeNode;
  CNode   : TTreeNode;
  Done    : string;
begin
  FNavTree.Items.Clear;
  for I := 0 to FCurriculum.LessonCount - 1 do
  begin
    Lesson := FCurriculum.GetLesson(I);
    LNode  := FNavTree.Items.Add(nil,
      Format('%d. %s', [Lesson.Number, Lesson.Title]));
    LNode.Data := Pointer(I);   // lesson index
    for J := 0 to High(Lesson.Challenges) do
    begin
      Ch   := Lesson.Challenges[J];
      if FProgress.IsComplete(Ch.ID) then Done := '✓ '
      else Done := '○ ';
      CNode := FNavTree.Items.AddChild(LNode,
        Done + Ch.Title);
      CNode.Data := Pointer(I * 1000 + J);  // encoded lesson+challenge
    end;
    LNode.Expand(False);
  end;
end;

// ---------------------------------------------------------------------------
//  Load the current lesson+challenge into the UI
// ---------------------------------------------------------------------------
procedure TLearnTab.LoadChallenge;
var
  Lesson : TLesson;
  Ch     : TChallenge;
begin
  Lesson := CurrentLesson;
  Ch     := CurrentChallenge;

  // Header
  FLabelLesson.Caption := Format('Lesson %d  —  %s   |   Challenge %d of %d: %s',
    [Lesson.Number, Lesson.Title,
     FCurChallenge + 1, Length(Lesson.Challenges), Ch.Title]);
  UpdateStars;

  // Intro = lesson intro + blank line + this challenge's instruction
  FIntroMemo.Lines.Text :=
    Lesson.Intro + #13#10 + #13#10 +
    '──────────────────────────────────────────────────────' + #13#10 +
    '📝  CHALLENGE ' + IntToStr(FCurChallenge + 1) + ': ' + Ch.Title + #13#10 +
    '──────────────────────────────────────────────────────' + #13#10 +
    Ch.Instruction;

  // Code editor — only prefill if currently empty or switching challenges
  FCodeMemo.Lines.Text := Ch.Starter;

  // Clear result and output
  FResultLabel.Caption    := '';
  FResultPanel.Color      := $00252526;
  FOutputMemo.Lines.Clear;

  SelectNavNode;
end;

// ---------------------------------------------------------------------------
//  Sync the TreeView selection to the current lesson/challenge
// ---------------------------------------------------------------------------
procedure TLearnTab.SelectNavNode;
var
  Node    : TTreeNode;
  Encoded : Integer;
begin
  Encoded := FCurLesson * 1000 + FCurChallenge;
  Node    := FNavTree.Items.GetFirstNode;
  while Assigned(Node) do
  begin
    if Integer(Node.Data) = Encoded then
    begin
      FNavTree.Selected := Node;
      Break;
    end;
    Node := Node.GetNext;
  end;
end;

// ---------------------------------------------------------------------------
//  Update score label
// ---------------------------------------------------------------------------
procedure TLearnTab.UpdateScore;
var
  Done, Total, Pts : Integer;
begin
  Done  := FProgress.CompletedCount;
  Total := FCurriculum.TotalChallenges;
  Pts   := FProgress.EarnedPoints;
  FLabelScore.Caption :=
    Format('  Score: %d pts   (%d / %d done)', [Pts, Done, Total]);
end;

// ---------------------------------------------------------------------------
//  Update star display for current lesson
// ---------------------------------------------------------------------------
procedure TLearnTab.UpdateStars;
var
  Lesson  : TLesson;
  Done, I : Integer;
  Stars   : string;
begin
  Lesson := CurrentLesson;
  Done   := 0;
  for I := 0 to High(Lesson.Challenges) do
    if FProgress.IsComplete(Lesson.Challenges[I].ID) then
      Inc(Done);
  Stars := '';
  for I := 1 to Length(Lesson.Challenges) do
    if I <= Done then Stars := Stars + '★'
    else Stars := Stars + '☆';
  FLabelStars.Caption := Stars;
end;

// ---------------------------------------------------------------------------
//  Show a pass/fail result in the result strip
// ---------------------------------------------------------------------------
procedure TLearnTab.ShowResult(const Msg: string; Pass: Boolean);
begin
  FResultLabel.Caption := Msg;
  if Pass then
  begin
    FResultPanel.Color      := $00004400;
    FResultLabel.Font.Color := $0056D364;
  end
  else
  begin
    FResultPanel.Color      := $00330000;
    FResultLabel.Font.Color := clRed;
  end;
end;

// ---------------------------------------------------------------------------
//  Show the certificate when all done
// ---------------------------------------------------------------------------
procedure TLearnTab.ShowCertificate;
var
  Cert : TCertificateForm;
begin
  Cert := TCertificateForm.Create(nil,
    FProgress.StudentName,
    FProgress.EarnedPoints,
    FCurriculum.TotalPoints);
  try
    Cert.ShowModal;
  finally
    Cert.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  EVENT HANDLERS
// ---------------------------------------------------------------------------

procedure TLearnTab.OnNavSelect(Sender: TObject);
var
  Node    : TTreeNode;
  Encoded : Integer;
begin
  Node := FNavTree.Selected;
  if not Assigned(Node) then Exit;
  Encoded := Integer(Node.Data);
  if Encoded >= 1000 then
  begin
    // Challenge node
    FCurLesson    := Encoded div 1000;
    FCurChallenge := Encoded mod 1000;
    LoadChallenge;
  end
  else
  begin
    // Lesson header node — jump to its first challenge
    FCurLesson    := Encoded;
    FCurChallenge := 0;
    LoadChallenge;
  end;
end;

procedure TLearnTab.OnCheck(Sender: TObject);
var
  Ch     : TChallenge;
  Msg    : string;
  Pass   : Boolean;
  Output : TStringList;
  Lex    : TLexer;
  Par    : TParser;
  Prog   : TProgramNode;
  Interp : TInterpreter;
begin
  Ch := CurrentChallenge;

  // Run and show output
  FOutputMemo.Lines.Clear;
  Output := TStringList.Create;
  try
    try
      Lex := TLexer.Create(FCodeMemo.Lines.Text);
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
    except
      on E: Exception do
        Output.Add('ERROR: ' + E.Message);
    end;
    FOutputMemo.Lines.Assign(Output);
  finally
    Output.Free;
  end;

  // Check
  Pass := TAnswerChecker.Check(Ch, FCodeMemo.Lines.Text, Msg);
  ShowResult(Msg, Pass);

  if Pass and not FProgress.IsComplete(Ch.ID) then
  begin
    FProgress.MarkComplete(Ch.ID);
    // Accumulate points
    FProgress.AddPoints(Ch.Points);
    UpdateScore;
    BuildNavTree;     // refresh tick marks
    UpdateStars;

    // Check if all done
    if FProgress.CompletedCount = FCurriculum.TotalChallenges then
    begin
      ShowResult('🎉  ALL CHALLENGES COMPLETE!  Click to claim your certificate!', True);
      ShowCertificate;
    end;
  end;
end;

procedure TLearnTab.OnHint(Sender: TObject);
var
  Ch : TChallenge;
begin
  Ch := CurrentChallenge;
  ShowResult('💡 Hint: ' + Ch.Hint, True);
end;

procedure TLearnTab.OnSolution(Sender: TObject);
var
  Ch : TChallenge;
begin
  Ch := CurrentChallenge;
  if MessageDlg('Show the solution? This will replace your code.',
                mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    FCodeMemo.Lines.Text := Ch.Solution;
end;

procedure TLearnTab.OnPrev(Sender: TObject);
begin
  if FCurChallenge > 0 then
    Dec(FCurChallenge)
  else if FCurLesson > 0 then
  begin
    Dec(FCurLesson);
    FCurChallenge := High(CurrentLesson.Challenges);
  end;
  LoadChallenge;
end;

procedure TLearnTab.OnNext(Sender: TObject);
var
  Lesson : TLesson;
begin
  Lesson := CurrentLesson;
  if FCurChallenge < High(Lesson.Challenges) then
    Inc(FCurChallenge)
  else if FCurLesson < FCurriculum.LessonCount - 1 then
  begin
    Inc(FCurLesson);
    FCurChallenge := 0;
  end;
  LoadChallenge;
end;

procedure TLearnTab.OnSaveName(Sender: TObject);
begin
  FProgress.StudentName := Trim(FEditName.Text);
  FProgress.SaveName;
  ShowResult('Name saved: ' + FProgress.StudentName, True);
end;

procedure TLearnTab.OnReset(Sender: TObject);
begin
  if MessageDlg('Reset ALL progress? This cannot be undone.',
                mtWarning, [mbYes, mbNo], 0) = mrYes then
  begin
    FProgress.Reset;
    FProgress.AddPoints(-FProgress.EarnedPoints);
    BuildNavTree;
    UpdateScore;
    UpdateStars;
    ShowResult('Progress reset.', False);
  end;
end;

// Local helper
function IfThen(B: Boolean; const T, F: string): string;
begin
  if B then Result := T else Result := F;
end;

end.
