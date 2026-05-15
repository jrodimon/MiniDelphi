unit UExampleProjects;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  UExampleProjects.pas  —  30 fully-documented MiniDelphi example projects
//
//  Every example is a self-contained .mdp source string with:
//    • A header block explaining what the program does and what it teaches
//    • Comments on every non-trivial line
//    • Deliberate teaching moments called out with  // *** NOTE: ...
//
//  Used by UProjectTab to populate the Examples panel.
// =============================================================================

interface

uses System.SysUtils, System.Classes, System.Generics.Collections;

type
  // One file within a multi-file example project
  TExampleFile = record
    FileName : string;   // e.g. 'Main.mdp' or 'MathLib.mdp'
    Source   : string;   // file contents
    IsMain   : Boolean;  // True = open this in the editor on load
  end;

  TExampleProject = record
    Name        : string;             // display name
    Category    : string;             // grouping label
    Description : string;             // one-line summary shown in the tree
    Source      : string;             // main source (single-file projects)
    Files       : TArray<TExampleFile>; // all files (multi-file projects)
    IsMultiFile : Boolean;            // True = use Files[], False = use Source
  end;

  TExampleLibrary = class
  private
    FList : TList<TExampleProject>;
    procedure Build;
  public
    constructor Create;
    destructor  Destroy; override;
    function Count : Integer;
    function Items(I: Integer) : TExampleProject;
    function Categories : TStringList;   // caller frees
  end;

// =============================================================================
implementation
// =============================================================================

constructor TExampleLibrary.Create;
begin
  inherited;
  FList := TList<TExampleProject>.Create;
  Build;
end;

destructor TExampleLibrary.Destroy;
begin
  FList.Free;
  inherited;
end;

function TExampleLibrary.Count: Integer;
begin Result := FList.Count; end;

function TExampleLibrary.Items(I: Integer): TExampleProject;
begin Result := FList[I]; end;

function TExampleLibrary.Categories: TStringList;
var
  I   : Integer;
  Cat : string;
begin
  Result := TStringList.Create;
  Result.Duplicates := dupIgnore;
  Result.Sorted     := False;
  for I := 0 to FList.Count - 1 do
  begin
    Cat := FList[I].Category;
    if Result.IndexOf(Cat) < 0 then
      Result.Add(Cat);
  end;
end;

// ---------------------------------------------------------------------------
//  Helper to add an example cleanly
// ---------------------------------------------------------------------------
procedure TExampleLibrary.Build;

  procedure Add(const Name, Cat, Desc, Src: string);
  var E: TExampleProject;
  begin
    E.Name        := Name;
    E.Category    := Cat;
    E.Description := Desc;
    E.Source      := Src;
    E.IsMultiFile := False;
    E.Files       := nil;
    FList.Add(E);
  end;

  procedure AddMulti(const Name, Cat, Desc: string;
                     const Files: array of TExampleFile);
  var
    E : TExampleProject;
    I : Integer;
  begin
    E.Name        := Name;
    E.Category    := Cat;
    E.Description := Desc;
    E.Source      := '';
    E.IsMultiFile := True;
    SetLength(E.Files, Length(Files));
    for I := 0 to High(Files) do
      E.Files[I] := Files[I];
    FList.Add(E);
  end;

  function F(const FileName, Src: string; IsMain: Boolean = False): TExampleFile;
  begin
    Result.FileName := FileName;
    Result.Source   := Src;
    Result.IsMain   := IsMain;
  end;

begin

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY: Beginners
// ═══════════════════════════════════════════════════════════════════════════

Add('Hello World', 'Beginners', 'The classic first program — print a greeting',
'// ============================================================' + #13#10 +
'// HELLO WORLD' + #13#10 +
'// The very first program every programmer writes.' + #13#10 +
'// Teaches: writeln, strings, begin/end block' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  // writeln prints a line of text to the output window.' + #13#10 +
'  // Text must be wrapped in single quotes.' + #13#10 +
'  writeln(''Hello, World!'');' + #13#10 +
'' + #13#10 +
'  // You can call writeln as many times as you like.' + #13#10 +
'  writeln(''Welcome to MiniDelphi!'');' + #13#10 +
'  writeln(''Learning Delphi is fun.'');' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Personal Greeter', 'Beginners', 'Ask your name and greet you personally',
'// ============================================================' + #13#10 +
'// PERSONAL GREETER' + #13#10 +
'// Teaches: InputBox, variables, string concatenation' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  name : String;   // will hold the user''s name' + #13#10 +
'  age  : String;   // will hold their age as text' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  // InputBox pops up a dialog asking the user to type something.' + #13#10 +
'  // Parameters: prompt message, title, default value' + #13#10 +
'  name := InputBox(''What is your name?'', ''Greeter'', ''Friend'');' + #13#10 +
'' + #13#10 +
'  age := InputBox(''How old are you?'', ''Greeter'', ''0'');' + #13#10 +
'' + #13#10 +
'  // The + operator joins strings together (concatenation)' + #13#10 +
'  ShowMessage(''Hello, '' + name + ''! Happy birthday year '' + age + ''!'');' + #13#10 +
'' + #13#10 +
'  writeln(''Name: '', name);' + #13#10 +
'  writeln(''Age : '', age);' + #13#10 +
'  writeln(''Nice to meet you, '', name, ''!'');' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Simple Calculator', 'Beginners', 'Ask two numbers and show all operations',
'// ============================================================' + #13#10 +
'// SIMPLE CALCULATOR' + #13#10 +
'// Teaches: InputBox, StrToFloat, arithmetic operators,' + #13#10 +
'//          FloatToStr, ShowMessage' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  a, b   : Real;    // the two numbers the user types' + #13#10 +
'  result : Real;    // stores each calculation result' + #13#10 +
'  sa, sb : String;  // temporary string versions' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  // Get two numbers from the user via dialog boxes' + #13#10 +
'  sa := InputBox(''Enter first number:'', ''Calculator'', ''10'');' + #13#10 +
'  sb := InputBox(''Enter second number:'', ''Calculator'', ''5'');' + #13#10 +
'' + #13#10 +
'  // *** NOTE: StrToFloat converts a string like "3.14" into a number' + #13#10 +
'  a := StrToFloat(sa);' + #13#10 +
'  b := StrToFloat(sb);' + #13#10 +
'' + #13#10 +
'  writeln(''=== Calculator Results ==='');' + #13#10 +
'  writeln(a, '' + '', b, '' = '', a + b);' + #13#10 +
'  writeln(a, '' - '', b, '' = '', a - b);' + #13#10 +
'  writeln(a, '' * '', b, '' = '', a * b);' + #13#10 +
'' + #13#10 +
'  // *** NOTE: Guard against dividing by zero!' + #13#10 +
'  if b <> 0 then' + #13#10 +
'    writeln(a, '' / '', b, '' = '', a / b)' + #13#10 +
'  else' + #13#10 +
'    writeln(''Cannot divide by zero!'');' + #13#10 +
'' + #13#10 +
'  // div and mod only work on integers, so we use round()' + #13#10 +
'  writeln(round(a), '' div '', round(b), '' = '', round(a) div round(b));' + #13#10 +
'  writeln(round(a), '' mod '', round(b), '' = '', round(a) mod round(b));' + #13#10 +
'end.');

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY: Numbers & Maths
// ═══════════════════════════════════════════════════════════════════════════

Add('FizzBuzz', 'Numbers & Maths', 'The classic programming interview challenge',
'// ============================================================' + #13#10 +
'// FIZZBUZZ' + #13#10 +
'// The classic programming challenge — used in job interviews!' + #13#10 +
'// Teaches: for loops, mod operator, if/else if chains' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  i : Integer;   // our loop counter' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  writeln(''FizzBuzz from 1 to 100:'');' + #13#10 +
'  writeln(''----------------------------'');' + #13#10 +
'' + #13#10 +
'  // Count from 1 to 100' + #13#10 +
'  for i := 1 to 100 do' + #13#10 +
'  begin' + #13#10 +
'    // *** NOTE: Check mod 15 FIRST (divisible by both 3 and 5)' + #13#10 +
'    // If we checked mod 3 first, FizzBuzz would never print!' + #13#10 +
'    if i mod 15 = 0 then' + #13#10 +
'      writeln(''FizzBuzz'')' + #13#10 +
'    else if i mod 3 = 0 then' + #13#10 +
'      writeln(''Fizz'')' + #13#10 +
'    else if i mod 5 = 0 then' + #13#10 +
'      writeln(''Buzz'')' + #13#10 +
'    else' + #13#10 +
'      writeln(i);   // just print the number' + #13#10 +
'  end;' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Fibonacci Sequence', 'Numbers & Maths', 'Generate Fibonacci numbers — nature''s favourite sequence',
'// ============================================================' + #13#10 +
'// FIBONACCI SEQUENCE' + #13#10 +
'// Each number is the sum of the two before it: 0,1,1,2,3,5,8...' + #13#10 +
'// Found in sunflowers, shells, galaxies, and stock markets!' + #13#10 +
'// Teaches: variables, for loops, accumulation pattern' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  a, b, c : Integer;   // three consecutive Fibonacci numbers' + #13#10 +
'  i       : Integer;   // loop counter' + #13#10 +
'  howMany : Integer;   // how many to generate' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  howMany := 20;   // change this to generate more or fewer' + #13#10 +
'' + #13#10 +
'  writeln(''Fibonacci Sequence ('', howMany, '' numbers):'');' + #13#10 +
'  writeln(''----------------------------'');' + #13#10 +
'' + #13#10 +
'  // Seed the sequence with the first two values' + #13#10 +
'  a := 0;' + #13#10 +
'  b := 1;' + #13#10 +
'  writeln(a);' + #13#10 +
'  writeln(b);' + #13#10 +
'' + #13#10 +
'  // Generate the rest: each new number = previous two added together' + #13#10 +
'  for i := 3 to howMany do' + #13#10 +
'  begin' + #13#10 +
'    c := a + b;      // new number' + #13#10 +
'    writeln(c);' + #13#10 +
'    a := b;          // slide the window forward' + #13#10 +
'    b := c;' + #13#10 +
'  end;' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Prime Numbers', 'Numbers & Maths', 'Find all primes up to N using trial division',
'// ============================================================' + #13#10 +
'// PRIME NUMBERS' + #13#10 +
'// A prime is only divisible by 1 and itself: 2,3,5,7,11,13...' + #13#10 +
'// Teaches: functions, nested loops, early exit with exit' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// A function that tests whether a number is prime.' + #13#10 +
'// Returns true if prime, false if not.' + #13#10 +
'function IsPrime(n: Integer): Boolean;' + #13#10 +
'var' + #13#10 +
'  i : Integer;' + #13#10 +
'begin' + #13#10 +
'  // Numbers less than 2 are never prime' + #13#10 +
'  if n < 2 then begin Result := false; exit; end;' + #13#10 +
'' + #13#10 +
'  // Assume prime until proven otherwise' + #13#10 +
'  Result := true;' + #13#10 +
'  i := 2;' + #13#10 +
'' + #13#10 +
'  // *** NOTE: We only need to check up to sqrt(n).' + #13#10 +
'  // If n has a factor bigger than sqrt(n), it must also' + #13#10 +
'  // have one smaller — so we would have found it already.' + #13#10 +
'  while i * i <= n do' + #13#10 +
'  begin' + #13#10 +
'    if n mod i = 0 then' + #13#10 +
'    begin' + #13#10 +
'      Result := false;   // found a factor — not prime!' + #13#10 +
'      exit;              // no need to check further' + #13#10 +
'    end;' + #13#10 +
'    inc(i);' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  n, count : Integer;' + #13#10 +
'  limit    : Integer;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  limit := 100;   // find all primes up to this number' + #13#10 +
'  count := 0;' + #13#10 +
'' + #13#10 +
'  writeln(''Prime numbers up to '', limit, '':'');' + #13#10 +
'  for n := 2 to limit do' + #13#10 +
'    if IsPrime(n) then' + #13#10 +
'    begin' + #13#10 +
'      write(n, ''  '');' + #13#10 +
'      inc(count);' + #13#10 +
'    end;' + #13#10 +
'  writeln('''');' + #13#10 +
'  writeln(''Total: '', count, '' primes found.'');' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Factorial', 'Numbers & Maths', 'Calculate factorials using recursion',
'// ============================================================' + #13#10 +
'// FACTORIAL' + #13#10 +
'// n! = n * (n-1) * (n-2) * ... * 1   e.g. 5! = 120' + #13#10 +
'// Teaches: recursive functions, the beauty of self-reference' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// Recursive function: it calls ITSELF with a smaller number' + #13#10 +
'// until it reaches the base case (n=1)' + #13#10 +
'function Factorial(n: Integer): Integer;' + #13#10 +
'begin' + #13#10 +
'  // *** NOTE: Every recursive function needs a BASE CASE' + #13#10 +
'  // Without it the function would call itself forever!' + #13#10 +
'  if n <= 1 then' + #13#10 +
'    Result := 1                           // base case: stop here' + #13#10 +
'  else' + #13#10 +
'    Result := n * Factorial(n - 1);       // recursive case' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  i : Integer;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  writeln(''Factorial Table:'');' + #13#10 +
'  writeln(''----------------'');' + #13#10 +
'  for i := 0 to 12 do' + #13#10 +
'    writeln(i, ''! = '', Factorial(i));' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Times Tables', 'Numbers & Maths', 'Print a full multiplication grid',
'// ============================================================' + #13#10 +
'// TIMES TABLES' + #13#10 +
'// Generates a complete multiplication grid.' + #13#10 +
'// Teaches: nested for loops, write vs writeln, formatting' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  row, col : Integer;   // row = first number, col = second' + #13#10 +
'  product  : Integer;   // their product' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  writeln(''Multiplication Table (1-10):'');' + #13#10 +
'  writeln(''     1   2   3   4   5   6   7   8   9  10'');' + #13#10 +
'  writeln(''   ----------------------------------------'');' + #13#10 +
'' + #13#10 +
'  // *** NOTE: Nested loops — the outer loop controls rows,' + #13#10 +
'  // the inner loop controls columns within each row.' + #13#10 +
'  for row := 1 to 10 do' + #13#10 +
'  begin' + #13#10 +
'    // Print the row header (the number on the left)' + #13#10 +
'    write(row, '' |'');' + #13#10 +
'' + #13#10 +
'    // Print each product in the row' + #13#10 +
'    for col := 1 to 10 do' + #13#10 +
'    begin' + #13#10 +
'      product := row * col;' + #13#10 +
'      // write() (no ln) keeps us on the same line' + #13#10 +
'      write('' '', product);' + #13#10 +
'      if product < 10 then write(''  '')     // align single digits' + #13#10 +
'      else if product < 100 then write('' '') // align double digits' + #13#10 +
'      else write('''');' + #13#10 +
'    end;' + #13#10 +
'    writeln('''');   // end the row with a newline' + #13#10 +
'  end;' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Pascal''s Triangle', 'Numbers & Maths', 'Draw the famous number triangle',
'// ============================================================' + #13#10 +
'// PASCAL''S TRIANGLE' + #13#10 +
'// Each number is the sum of the two numbers above it.' + #13#10 +
'// Row 0: 1  Row 1: 1 1  Row 2: 1 2 1  Row 3: 1 3 3 1' + #13#10 +
'// Teaches: nested loops, the binomial coefficient formula' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// Computes C(n,k) = n! / (k! * (n-k)!) using a safe iterative method' + #13#10 +
'function BinCoeff(n, k: Integer): Integer;' + #13#10 +
'var' + #13#10 +
'  i, r : Integer;' + #13#10 +
'begin' + #13#10 +
'  r := 1;' + #13#10 +
'  for i := 0 to k - 1 do' + #13#10 +
'    r := r * (n - i) div (i + 1);' + #13#10 +
'  Result := r;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  row, col, rows : Integer;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  rows := 10;   // how many rows to print' + #13#10 +
'  writeln(''Pascal''''s Triangle ('', rows, '' rows):'');' + #13#10 +
'  for row := 0 to rows - 1 do' + #13#10 +
'  begin' + #13#10 +
'    for col := 0 to row do' + #13#10 +
'    begin' + #13#10 +
'      write(BinCoeff(row, col));' + #13#10 +
'      if col < row then write(''  '');' + #13#10 +
'    end;' + #13#10 +
'    writeln('''');' + #13#10 +
'  end;' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Number Base Converter', 'Numbers & Maths', 'Convert decimal to binary, octal, hex',
'// ============================================================' + #13#10 +
'// NUMBER BASE CONVERTER' + #13#10 +
'// Converts a decimal number to binary, octal and hexadecimal.' + #13#10 +
'// Teaches: while loops, div, mod, string building, caseof' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// Convert n to a string in the given base (2, 8, or 16)' + #13#10 +
'function ToBase(n, base: Integer): String;' + #13#10 +
'var' + #13#10 +
'  digits : String;' + #13#10 +
'  digit  : Integer;' + #13#10 +
'begin' + #13#10 +
'  if n = 0 then begin Result := ''0''; exit; end;' + #13#10 +
'  digits := '''';' + #13#10 +
'  while n > 0 do' + #13#10 +
'  begin' + #13#10 +
'    digit := n mod base;   // get the rightmost digit' + #13#10 +
'    n     := n div base;   // remove it' + #13#10 +
'    // For hex we need letters A-F for values 10-15' + #13#10 +
'    if digit < 10 then' + #13#10 +
'      digits := IntToStr(digit) + digits   // prepend digit' + #13#10 +
'    else' + #13#10 +
'      digits := Chr(Ord(''A'') + digit - 10) + digits;' + #13#10 +
'  end;' + #13#10 +
'  Result := digits;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  n   : Integer;' + #13#10 +
'  inp : String;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  inp := InputBox(''Enter a decimal number (0-65535):'', ''Base Converter'', ''255'');' + #13#10 +
'  n   := StrToInt(inp);' + #13#10 +
'' + #13#10 +
'  writeln(''Decimal    : '', n);' + #13#10 +
'  writeln(''Binary     : '', ToBase(n, 2));' + #13#10 +
'  writeln(''Octal      : '', ToBase(n, 8));' + #13#10 +
'  writeln(''Hexadecimal: '', ToBase(n, 16));' + #13#10 +
'end.');

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY: Games & Fun
// ═══════════════════════════════════════════════════════════════════════════

Add('Number Guessing Game', 'Games & Fun', 'Guess the secret number — computer gives hints',
'// ============================================================' + #13#10 +
'// NUMBER GUESSING GAME' + #13#10 +
'// The computer picks a secret number. You guess!' + #13#10 +
'// Teaches: random, while loops, if/else, InputBox, ShowMessage' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  secret  : Integer;   // the number the computer chose' + #13#10 +
'  guess   : Integer;   // the player''s guess' + #13#10 +
'  tries   : Integer;   // how many guesses taken so far' + #13#10 +
'  inp     : String;    // raw input from InputBox' + #13#10 +
'  playing : Boolean;   // is the game still going?' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  // *** NOTE: Randomize seeds the random number generator.' + #13#10 +
'  // Without this you get the same sequence every run!' + #13#10 +
'  Randomize;' + #13#10 +
'' + #13#10 +
'  // Pick a secret number from 1 to 100' + #13#10 +
'  secret  := Random(100) + 1;' + #13#10 +
'  tries   := 0;' + #13#10 +
'  playing := true;' + #13#10 +
'' + #13#10 +
'  ShowMessage(''I have picked a number between 1 and 100. Can you guess it?'');' + #13#10 +
'' + #13#10 +
'  while playing do' + #13#10 +
'  begin' + #13#10 +
'    inp   := InputBox(''Your guess (1-100):'', ''Guessing Game'', '''');' + #13#10 +
'    guess := StrToInt(inp);' + #13#10 +
'    inc(tries);' + #13#10 +
'' + #13#10 +
'    if guess < secret then' + #13#10 +
'      ShowMessage(''Too low! Try higher.'')'' )' + #13#10 +
'    else if guess > secret then' + #13#10 +
'      ShowMessage(''Too high! Try lower.'')' + #13#10 +
'    else' + #13#10 +
'    begin' + #13#10 +
'      // Correct!' + #13#10 +
'      ShowMessage(''Correct! You got it in '' + IntToStr(tries) + '' tries!'');' + #13#10 +
'      playing := false;' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  writeln(''Game over! The number was '', secret);' + #13#10 +
'  writeln(''You needed '', tries, '' guesses.'');' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Dice Roller', 'Games & Fun', 'Roll dice and track statistics',
'// ============================================================' + #13#10 +
'// DICE ROLLER' + #13#10 +
'// Rolls a six-sided die many times and counts each result.' + #13#10 +
'// Teaches: random, arrays (via individual vars), for loops,' + #13#10 +
'//          accumulation, percentages' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  rolls    : Integer;   // total number of dice rolls' + #13#10 +
'  i, face  : Integer;   // loop counter, dice face value' + #13#10 +
'  c1,c2,c3 : Integer;   // counts for faces 1,2,3' + #13#10 +
'  c4,c5,c6 : Integer;   // counts for faces 4,5,6' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  Randomize;' + #13#10 +
'  rolls := 600;   // try changing this to 60 or 6000' + #13#10 +
'  c1 := 0; c2 := 0; c3 := 0;' + #13#10 +
'  c4 := 0; c5 := 0; c6 := 0;' + #13#10 +
'' + #13#10 +
'  writeln(''Rolling a die '', rolls, '' times...'');' + #13#10 +
'' + #13#10 +
'  for i := 1 to rolls do' + #13#10 +
'  begin' + #13#10 +
'    // Random(6) gives 0..5, so +1 gives 1..6' + #13#10 +
'    face := Random(6) + 1;' + #13#10 +
'    case face of' + #13#10 +
'      1: inc(c1);' + #13#10 +
'      2: inc(c2);' + #13#10 +
'      3: inc(c3);' + #13#10 +
'      4: inc(c4);' + #13#10 +
'      5: inc(c5);' + #13#10 +
'      6: inc(c6);' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  writeln(''Results (each face should be ~'', round(100/6), ''%):'');' + #13#10 +
'  writeln(''Face 1: '', c1, ''  ('', round(c1*100/rolls), ''%)'');' + #13#10 +
'  writeln(''Face 2: '', c2, ''  ('', round(c2*100/rolls), ''%)'');' + #13#10 +
'  writeln(''Face 3: '', c3, ''  ('', round(c3*100/rolls), ''%)'');' + #13#10 +
'  writeln(''Face 4: '', c4, ''  ('', round(c4*100/rolls), ''%)'');' + #13#10 +
'  writeln(''Face 5: '', c5, ''  ('', round(c5*100/rolls), ''%)'');' + #13#10 +
'  writeln(''Face 6: '', c6, ''  ('', round(c6*100/rolls), ''%)'');' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Rock Paper Scissors', 'Games & Fun', 'Play against the computer',
'// ============================================================' + #13#10 +
'// ROCK PAPER SCISSORS' + #13#10 +
'// You vs the computer — best of 5 wins!' + #13#10 +
'// Teaches: caseof, random, while loops, score tracking' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'function ComputerChoice: String;' + #13#10 +
'var r : Integer;' + #13#10 +
'begin' + #13#10 +
'  r := Random(3);' + #13#10 +
'  case r of' + #13#10 +
'    0: Result := ''Rock'';' + #13#10 +
'    1: Result := ''Paper'';' + #13#10 +
'    2: Result := ''Scissors'';' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'// Returns 1 if player wins, -1 if computer wins, 0 if draw' + #13#10 +
'function RoundResult(player, computer: String): Integer;' + #13#10 +
'begin' + #13#10 +
'  if player = computer then Result := 0' + #13#10 +
'  else if ((player = ''Rock'')     and (computer = ''Scissors'')) or' + #13#10 +
'          ((player = ''Paper'')    and (computer = ''Rock''))     or' + #13#10 +
'          ((player = ''Scissors'') and (computer = ''Paper'')) then' + #13#10 +
'    Result := 1' + #13#10 +
'  else' + #13#10 +
'    Result := -1;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  player, computer : String;' + #13#10 +
'  pScore, cScore   : Integer;' + #13#10 +
'  res              : Integer;' + #13#10 +
'  playing          : Boolean;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  Randomize;' + #13#10 +
'  pScore := 0; cScore := 0;' + #13#10 +
'  playing := true;' + #13#10 +
'  writeln(''=== Rock Paper Scissors — First to 3 wins! ==='');' + #13#10 +
'' + #13#10 +
'  while playing do' + #13#10 +
'  begin' + #13#10 +
'    player   := InputBox(''Your choice:'', ''Rock / Paper / Scissors'', ''Rock'');' + #13#10 +
'    computer := ComputerChoice;' + #13#10 +
'    res      := RoundResult(player, computer);' + #13#10 +
'' + #13#10 +
'    write(''You: '', player, ''   Computer: '', computer, ''   -> '');' + #13#10 +
'    if res = 1  then begin writeln(''You win the round!'');  inc(pScore); end' + #13#10 +
'    else if res = -1 then begin writeln(''Computer wins!''); inc(cScore); end' + #13#10 +
'    else writeln(''Draw!'');' + #13#10 +
'' + #13#10 +
'    writeln(''Score: You '', pScore, ''  —  Computer '', cScore);' + #13#10 +
'' + #13#10 +
'    if (pScore >= 3) or (cScore >= 3) then playing := false;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  if pScore > cScore then ShowMessage(''You WIN the match! Well done!'')' + #13#10 +
'  else ShowMessage(''Computer wins the match. Better luck next time!'');' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Coin Flipper', 'Games & Fun', 'Flip coins and track heads vs tails',
'// ============================================================' + #13#10 +
'// COIN FLIPPER' + #13#10 +
'// Flip a coin many times and see if it really is 50/50.' + #13#10 +
'// Teaches: random, loops, counters, percentages, Confirm' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  heads, tails : Integer;' + #13#10 +
'  i, flips     : Integer;' + #13#10 +
'  keepGoing    : Boolean;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  Randomize;' + #13#10 +
'  heads := 0; tails := 0;' + #13#10 +
'  keepGoing := true;' + #13#10 +
'' + #13#10 +
'  while keepGoing do' + #13#10 +
'  begin' + #13#10 +
'    flips := StrToInt(InputBox(''How many flips?'', ''Coin Flipper'', ''100''));' + #13#10 +
'' + #13#10 +
'    for i := 1 to flips do' + #13#10 +
'      // Random(2) gives 0 or 1 — we call 0=Heads, 1=Tails' + #13#10 +
'      if Random(2) = 0 then inc(heads) else inc(tails);' + #13#10 +
'' + #13#10 +
'    writeln(''After '', heads + tails, '' flips:'');' + #13#10 +
'    writeln(''  Heads: '', heads, '' ('', round(heads*100/(heads+tails)), ''%)'');' + #13#10 +
'    writeln(''  Tails: '', tails, '' ('', round(tails*100/(heads+tails)), ''%)'');' + #13#10 +
'' + #13#10 +
'    // *** NOTE: Confirm returns true for Yes, false for No' + #13#10 +
'    keepGoing := Confirm(''Flip more coins?'');' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  writeln(''Final: Heads='', heads, '' Tails='', tails);' + #13#10 +
'end.');

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY: Science & Conversion
// ═══════════════════════════════════════════════════════════════════════════

Add('Temperature Converter', 'Science & Conversion', 'Convert between C, F and Kelvin',
'// ============================================================' + #13#10 +
'// TEMPERATURE CONVERTER' + #13#10 +
'// Converts between Celsius, Fahrenheit and Kelvin.' + #13#10 +
'// Teaches: functions, caseof, InputBox, real arithmetic' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'function CtoF(c: Real): Real;  begin Result := (c * 9/5) + 32;     end;' + #13#10 +
'function FtoC(f: Real): Real;  begin Result := (f - 32) * 5/9;     end;' + #13#10 +
'function CtoK(c: Real): Real;  begin Result := c + 273.15;         end;' + #13#10 +
'function KtoC(k: Real): Real;  begin Result := k - 273.15;         end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  temp, c, f, k : Real;' + #13#10 +
'  fromUnit       : String;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  fromUnit := InputBox(''Convert FROM which unit? (C / F / K)'', ''Converter'', ''C'');' + #13#10 +
'  temp     := StrToFloat(InputBox(''Enter temperature:'', ''Converter'', ''100''));' + #13#10 +
'' + #13#10 +
'  // *** NOTE: caseof is our MiniDelphi string switch statement' + #13#10 +
'  caseof UpperCase(fromUnit) of' + #13#10 +
'    ''C'': begin c := temp; f := CtoF(c); k := CtoK(c); end;' + #13#10 +
'    ''F'': begin f := temp; c := FtoC(f); k := CtoK(c); end;' + #13#10 +
'    ''K'': begin k := temp; c := KtoC(k); f := CtoF(c); end;' + #13#10 +
'  else' + #13#10 +
'    begin' + #13#10 +
'      ShowErrorBox(''Unknown unit. Use C, F or K.'');' + #13#10 +
'      exit;' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  writeln(''=== Temperature Conversion ==='');' + #13#10 +
'  writeln(''Celsius    : '', round(c * 100) / 100);' + #13#10 +
'  writeln(''Fahrenheit : '', round(f * 100) / 100);' + #13#10 +
'  writeln(''Kelvin     : '', round(k * 100) / 100);' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('BMI Calculator', 'Science & Conversion', 'Calculate Body Mass Index with category',
'// ============================================================' + #13#10 +
'// BMI CALCULATOR' + #13#10 +
'// BMI = weight(kg) / height(m)^2' + #13#10 +
'// Teaches: real arithmetic, if/else chains, sqr()' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  weight, height, bmi : Real;' + #13#10 +
'  category            : String;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  weight := StrToFloat(InputBox(''Weight in kg:'', ''BMI'', ''70''));' + #13#10 +
'  height := StrToFloat(InputBox(''Height in metres (e.g. 1.75):'', ''BMI'', ''1.75''));' + #13#10 +
'' + #13#10 +
'  // sqr(x) = x * x' + #13#10 +
'  bmi := weight / sqr(height);' + #13#10 +
'' + #13#10 +
'  // WHO categories' + #13#10 +
'  if      bmi < 18.5 then category := ''Underweight''' + #13#10 +
'  else if bmi < 25.0 then category := ''Normal weight''' + #13#10 +
'  else if bmi < 30.0 then category := ''Overweight''' + #13#10 +
'  else                    category := ''Obese'';' + #13#10 +
'' + #13#10 +
'  writeln(''=== BMI Result ==='');' + #13#10 +
'  writeln(''Weight   : '', weight, '' kg'');' + #13#10 +
'  writeln(''Height   : '', height, '' m'');' + #13#10 +
'  writeln(''BMI      : '', round(bmi * 10) / 10);' + #13#10 +
'  writeln(''Category : '', category);' + #13#10 +
'' + #13#10 +
'  ShowInfoBox(''Your BMI is '' + FloatToStr(round(bmi*10)/10) + '' — '' + category);' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Loan Calculator', 'Science & Conversion', 'Calculate monthly payments and total interest',
'// ============================================================' + #13#10 +
'// LOAN CALCULATOR' + #13#10 +
'// Calculates monthly repayments using the standard formula.' + #13#10 +
'// Teaches: real maths, exp/ln (for power), financial formulas' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  principal : Real;   // amount borrowed' + #13#10 +
'  rate      : Real;   // annual interest rate (e.g. 5 for 5%)' + #13#10 +
'  years     : Real;   // loan term in years' + #13#10 +
'  monthly   : Real;   // monthly payment' + #13#10 +
'  r, n      : Real;   // monthly rate, number of payments' + #13#10 +
'  total     : Real;   // total amount paid back' + #13#10 +
'  interest  : Real;   // total interest paid' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  principal := StrToFloat(InputBox(''Loan amount ($):'', ''Loan Calculator'', ''10000''));' + #13#10 +
'  rate      := StrToFloat(InputBox(''Annual interest rate (%):'', ''Loan Calculator'', ''5''));' + #13#10 +
'  years     := StrToFloat(InputBox(''Loan term (years):'', ''Loan Calculator'', ''5''));' + #13#10 +
'' + #13#10 +
'  // Convert annual rate to monthly decimal' + #13#10 +
'  r := (rate / 100) / 12;' + #13#10 +
'  n := years * 12;   // total months' + #13#10 +
'' + #13#10 +
'  // Standard mortgage formula: M = P * r*(1+r)^n / ((1+r)^n - 1)' + #13#10 +
'  // *** NOTE: power(base, exp) = exp(exp * ln(base))' + #13#10 +
'  if r = 0 then' + #13#10 +
'    monthly := principal / n   // zero interest' + #13#10 +
'  else' + #13#10 +
'    monthly := principal * r * power(1+r, n) / (power(1+r, n) - 1);' + #13#10 +
'' + #13#10 +
'  total    := monthly * n;' + #13#10 +
'  interest := total - principal;' + #13#10 +
'' + #13#10 +
'  writeln(''=== Loan Summary ==='');' + #13#10 +
'  writeln(''Principal       : $'', round(principal));' + #13#10 +
'  writeln(''Monthly Payment : $'', round(monthly * 100) / 100);' + #13#10 +
'  writeln(''Total Paid      : $'', round(total * 100) / 100);' + #13#10 +
'  writeln(''Total Interest  : $'', round(interest * 100) / 100);' + #13#10 +
'end.');

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY: Strings & Text
// ═══════════════════════════════════════════════════════════════════════════

Add('Caesar Cipher', 'Strings & Text', 'Encrypt and decrypt text by shifting letters',
'// ============================================================' + #13#10 +
'// CAESAR CIPHER' + #13#10 +
'// Julius Caesar encrypted messages by shifting each letter.' + #13#10 +
'// A shift of 3: A->D, B->E, ..., Z->C' + #13#10 +
'// Teaches: string loops, Ord, Chr, mod for wrapping' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// Encrypt a single character with the given shift' + #13#10 +
'function ShiftChar(ch: String; shift: Integer): String;' + #13#10 +
'var code : Integer;' + #13#10 +
'begin' + #13#10 +
'  // Only shift letters — leave spaces and punctuation alone' + #13#10 +
'  if (ch >= ''A'') and (ch <= ''Z'') then' + #13#10 +
'  begin' + #13#10 +
'    // Ord converts a character to its ASCII number (A=65)' + #13#10 +
'    // We subtract 65 to get 0-25, shift, wrap with mod, add 65 back' + #13#10 +
'    code   := (Ord(ch) - 65 + shift) mod 26;' + #13#10 +
'    if code < 0 then code := code + 26;   // handle negative shifts' + #13#10 +
'    Result := Chr(code + 65);' + #13#10 +
'  end' + #13#10 +
'  else if (ch >= ''a'') and (ch <= ''z'') then' + #13#10 +
'  begin' + #13#10 +
'    code   := (Ord(ch) - 97 + shift) mod 26;' + #13#10 +
'    if code < 0 then code := code + 26;' + #13#10 +
'    Result := Chr(code + 97);' + #13#10 +
'  end' + #13#10 +
'  else' + #13#10 +
'    Result := ch;   // not a letter — pass through unchanged' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'function Encrypt(msg: String; shift: Integer): String;' + #13#10 +
'var i : Integer;' + #13#10 +
'    r : String;' + #13#10 +
'begin' + #13#10 +
'  r := '''';' + #13#10 +
'  for i := 1 to Length(msg) do' + #13#10 +
'    r := r + ShiftChar(Copy(msg, i, 1), shift);' + #13#10 +
'  Result := r;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  msg, enc, dec : String;' + #13#10 +
'  shift         : Integer;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  msg   := InputBox(''Enter message to encrypt:'', ''Caesar Cipher'', ''Hello World'');' + #13#10 +
'  shift := StrToInt(InputBox(''Shift amount (1-25):'', ''Caesar Cipher'', ''13''));' + #13#10 +
'' + #13#10 +
'  enc := Encrypt(msg, shift);' + #13#10 +
'  dec := Encrypt(enc, -shift);   // decrypt = encrypt with negative shift' + #13#10 +
'' + #13#10 +
'  writeln(''Original  : '', msg);' + #13#10 +
'  writeln(''Encrypted : '', enc);' + #13#10 +
'  writeln(''Decrypted : '', dec);' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Palindrome Checker', 'Strings & Text', 'Check if a word reads the same backwards',
'// ============================================================' + #13#10 +
'// PALINDROME CHECKER' + #13#10 +
'// A palindrome reads the same forwards and backwards.' + #13#10 +
'// Examples: racecar, level, noon, madam' + #13#10 +
'// Teaches: string functions, Copy, Length, LowerCase' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// Reverse a string character by character' + #13#10 +
'function Reverse(s: String): String;' + #13#10 +
'var i : Integer;' + #13#10 +
'    r : String;' + #13#10 +
'begin' + #13#10 +
'  r := '''';' + #13#10 +
'  // Walk backwards through the string adding each character' + #13#10 +
'  for i := Length(s) downto 1 do' + #13#10 +
'    r := r + Copy(s, i, 1);' + #13#10 +
'  Result := r;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'// Check if a word is a palindrome (ignores case)' + #13#10 +
'function IsPalindrome(s: String): Boolean;' + #13#10 +
'var clean : String;' + #13#10 +
'begin' + #13#10 +
'  clean  := LowerCase(s);' + #13#10 +
'  Result := (clean = Reverse(clean));' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  word    : String;' + #13#10 +
'  testing : Boolean;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  testing := true;' + #13#10 +
'  writeln(''=== Palindrome Checker ==='');' + #13#10 +
'  writeln(''(type "quit" to stop)'');' + #13#10 +
'' + #13#10 +
'  // Test some well-known palindromes automatically' + #13#10 +
'  if IsPalindrome(''racecar'') then writeln(''racecar -> Palindrome!'') else writeln(''racecar -> Not a palindrome'');' + #13#10 +
'  if IsPalindrome(''level'') then writeln(''level -> Palindrome!'') else writeln(''level -> Not a palindrome'');' + #13#10 +
'  if IsPalindrome(''hello'') then writeln(''hello -> Not a palindrome'') else writeln(''hello -> Palindrome!'');' + #13#10 +
'  if IsPalindrome(''noon'') then writeln(''noon -> Palindrome!'') else writeln(''noon -> Not a palindrome'');' + #13#10 +
'  if IsPalindrome(''Delphi'') then writeln(''Delphi -> Not a palindrome'') else writeln(''Delphi -> Palindrome!'');' + #13#10 +
'' + #13#10 +
'  writeln('''');' + #13#10 +
'  while testing do' + #13#10 +
'  begin' + #13#10 +
'    word := InputBox(''Enter a word to check:'', ''Palindrome'', '''');' + #13#10 +
'    if LowerCase(word) = ''quit'' then' + #13#10 +
'      testing := false' + #13#10 +
'    else if IsPalindrome(word) then' + #13#10 +
'      ShowInfoBox(''"'' + word + ''" is a palindrome!'')' + #13#10 +
'    else' + #13#10 +
'      ShowInfoBox(''"'' + word + ''" is NOT a palindrome.'');' + #13#10 +
'  end;' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Word Counter', 'Strings & Text', 'Count words, characters and vowels in text',
'// ============================================================' + #13#10 +
'// WORD COUNTER' + #13#10 +
'// Analyses a sentence: counts words, chars, vowels.' + #13#10 +
'// Teaches: string loops, Pos, Copy, Length, counters' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'function CountWords(s: String): Integer;' + #13#10 +
'var' + #13#10 +
'  i, count : Integer;' + #13#10 +
'  inWord   : Boolean;' + #13#10 +
'begin' + #13#10 +
'  count  := 0;' + #13#10 +
'  inWord := false;' + #13#10 +
'  for i := 1 to Length(s) do' + #13#10 +
'  begin' + #13#10 +
'    if Copy(s, i, 1) <> '' '' then' + #13#10 +
'    begin' + #13#10 +
'      if not inWord then begin inc(count); inWord := true; end;' + #13#10 +
'    end' + #13#10 +
'    else' + #13#10 +
'      inWord := false;' + #13#10 +
'  end;' + #13#10 +
'  Result := count;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'function CountVowels(s: String): Integer;' + #13#10 +
'var' + #13#10 +
'  i, count : Integer;' + #13#10 +
'  ch       : String;' + #13#10 +
'begin' + #13#10 +
'  count := 0;' + #13#10 +
'  s     := LowerCase(s);' + #13#10 +
'  for i := 1 to Length(s) do' + #13#10 +
'  begin' + #13#10 +
'    ch := Copy(s, i, 1);' + #13#10 +
'    if (ch=''a'') or (ch=''e'') or (ch=''i'') or (ch=''o'') or (ch=''u'') then' + #13#10 +
'      inc(count);' + #13#10 +
'  end;' + #13#10 +
'  Result := count;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var text : String;' + #13#10 +
'begin' + #13#10 +
'  text := InputBox(''Enter some text to analyse:'', ''Word Counter'',' + #13#10 +
'                   ''The quick brown fox jumps over the lazy dog'');' + #13#10 +
'  writeln(''=== Text Analysis ==='');' + #13#10 +
'  writeln(''Text       : '', text);' + #13#10 +
'  writeln(''Characters : '', Length(text));' + #13#10 +
'  writeln(''Words      : '', CountWords(text));' + #13#10 +
'  writeln(''Vowels     : '', CountVowels(text));' + #13#10 +
'  writeln(''Uppercase  : '', UpperCase(text));' + #13#10 +
'end.');

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY: Algorithms
// ═══════════════════════════════════════════════════════════════════════════

Add('Bubble Sort', 'Algorithms', 'Sort 10 numbers using the bubble sort algorithm',
'// ============================================================' + #13#10 +
'// BUBBLE SORT' + #13#10 +
'// One of the simplest sorting algorithms.' + #13#10 +
'// Repeatedly swaps adjacent elements that are in the wrong order.' + #13#10 +
'// Teaches: nested loops, the swap pattern, sorting concepts' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// We simulate an array using 10 separate variables' + #13#10 +
'// (MiniDelphi does not yet have real arrays)' + #13#10 +
'var' + #13#10 +
'  a1,a2,a3,a4,a5   : Integer;' + #13#10 +
'  a6,a7,a8,a9,a10  : Integer;' + #13#10 +
'  temp, i, j       : Integer;' + #13#10 +
'  swapped          : Boolean;' + #13#10 +
'' + #13#10 +
'// Print all 10 values on one line' + #13#10 +
'procedure PrintAll;' + #13#10 +
'begin' + #13#10 +
'  write(a1,'' '',a2,'' '',a3,'' '',a4,'' '',a5,'' '');' + #13#10 +
'  writeln(a6,'' '',a7,'' '',a8,'' '',a9,'' '',a10);' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  // Start with a scrambled list' + #13#10 +
'  a1:=64; a2:=34; a3:=25; a4:=12; a5:=22;' + #13#10 +
'  a6:=11; a7:=90; a8:=45; a9:=78; a10:=3;' + #13#10 +
'' + #13#10 +
'  write(''Before: ''); PrintAll;' + #13#10 +
'' + #13#10 +
'  // *** NOTE: Bubble sort makes multiple passes.' + #13#10 +
'  // Each pass "bubbles" the largest unsorted element to its place.' + #13#10 +
'  // We stop early if no swaps happened (already sorted).' + #13#10 +
'  i := 10;' + #13#10 +
'  repeat' + #13#10 +
'    swapped := false;' + #13#10 +
'    // One pass — compare adjacent pairs' + #13#10 +
'    if a1  > a2  then begin temp:=a1;  a1 :=a2;  a2 :=temp; swapped:=true; end;' + #13#10 +
'    if a2  > a3  then begin temp:=a2;  a2 :=a3;  a3 :=temp; swapped:=true; end;' + #13#10 +
'    if a3  > a4  then begin temp:=a3;  a3 :=a4;  a4 :=temp; swapped:=true; end;' + #13#10 +
'    if a4  > a5  then begin temp:=a4;  a4 :=a5;  a5 :=temp; swapped:=true; end;' + #13#10 +
'    if a5  > a6  then begin temp:=a5;  a5 :=a6;  a6 :=temp; swapped:=true; end;' + #13#10 +
'    if a6  > a7  then begin temp:=a6;  a6 :=a7;  a7 :=temp; swapped:=true; end;' + #13#10 +
'    if a7  > a8  then begin temp:=a7;  a7 :=a8;  a8 :=temp; swapped:=true; end;' + #13#10 +
'    if a8  > a9  then begin temp:=a8;  a8 :=a9;  a9 :=temp; swapped:=true; end;' + #13#10 +
'    if a9  > a10 then begin temp:=a9;  a9 :=a10; a10:=temp; swapped:=true; end;' + #13#10 +
'    dec(i);' + #13#10 +
'  until (not swapped) or (i = 0);' + #13#10 +
'' + #13#10 +
'  write(''After:  ''); PrintAll;' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Binary Search', 'Algorithms', 'Find a number in a sorted list efficiently',
'// ============================================================' + #13#10 +
'// BINARY SEARCH' + #13#10 +
'// Finds a value in a SORTED list by halving the search range.' + #13#10 +
'// Much faster than checking every element!' + #13#10 +
'// Teaches: while loops, div (halving), algorithm thinking' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// Simulate searching in 1..100 (all numbers present)' + #13#10 +
'// Returns the step count to find the target' + #13#10 +
'function BinarySearch(target, lo, hi: Integer): Integer;' + #13#10 +
'var' + #13#10 +
'  mid, steps : Integer;' + #13#10 +
'begin' + #13#10 +
'  steps := 0;' + #13#10 +
'  while lo <= hi do' + #13#10 +
'  begin' + #13#10 +
'    inc(steps);' + #13#10 +
'    // *** NOTE: mid is the middle of the current range' + #13#10 +
'    mid := (lo + hi) div 2;' + #13#10 +
'    writeln(''  Step '', steps, '': checking '', mid);' + #13#10 +
'    if mid = target then' + #13#10 +
'    begin' + #13#10 +
'      writeln(''  Found '', target, '' in '', steps, '' steps!'');' + #13#10 +
'      Result := steps;' + #13#10 +
'      exit;' + #13#10 +
'    end' + #13#10 +
'    else if mid < target then' + #13#10 +
'      lo := mid + 1   // target is in the upper half' + #13#10 +
'    else' + #13#10 +
'      hi := mid - 1;  // target is in the lower half' + #13#10 +
'  end;' + #13#10 +
'  writeln(''  Not found!'');' + #13#10 +
'  Result := -1;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var target : Integer;' + #13#10 +
'begin' + #13#10 +
'  target := StrToInt(InputBox(''Search for (1-100):'', ''Binary Search'', ''73''));' + #13#10 +
'  writeln(''Searching for '', target, '' in range 1..100:'');' + #13#10 +
'  BinarySearch(target, 1, 100);' + #13#10 +
'  writeln(''(Linear search would need up to 100 steps)'');' + #13#10 +
'  writeln(''(Binary search needs at most 7 steps for 1..100)'');' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('GCD & LCM', 'Algorithms', 'Greatest common divisor and least common multiple',
'// ============================================================' + #13#10 +
'// GCD AND LCM' + #13#10 +
'// GCD: largest number that divides both evenly' + #13#10 +
'// LCM: smallest number both divide into evenly' + #13#10 +
'// Teaches: Euclidean algorithm, while loop, math relationships' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// Euclid''s algorithm — over 2000 years old and still the best!' + #13#10 +
'function GCD(a, b: Integer): Integer;' + #13#10 +
'var temp : Integer;' + #13#10 +
'begin' + #13#10 +
'  // *** NOTE: Keep replacing (a,b) with (b, a mod b)' + #13#10 +
'  // until b becomes 0. Whatever a is then — that is the GCD.' + #13#10 +
'  while b <> 0 do' + #13#10 +
'  begin' + #13#10 +
'    temp := b;' + #13#10 +
'    b    := a mod b;' + #13#10 +
'    a    := temp;' + #13#10 +
'  end;' + #13#10 +
'  Result := a;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'function LCM(a, b: Integer): Integer;' + #13#10 +
'begin' + #13#10 +
'  // LCM = (a * b) / GCD(a, b)' + #13#10 +
'  Result := (a * b) div GCD(a, b);' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var a, b : Integer;' + #13#10 +
'begin' + #13#10 +
'  a := StrToInt(InputBox(''First number:'',  ''GCD/LCM'', ''48''));' + #13#10 +
'  b := StrToInt(InputBox(''Second number:'', ''GCD/LCM'', ''18''));' + #13#10 +
'  writeln(''GCD('', a, '', '', b, '') = '', GCD(a, b));' + #13#10 +
'  writeln(''LCM('', a, '', '', b, '') = '', LCM(a, b));' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Star Patterns', 'Algorithms', 'Draw triangles, diamonds and pyramids with stars',
'// ============================================================' + #13#10 +
'// STAR PATTERNS' + #13#10 +
'// Drawing shapes with nested loops.' + #13#10 +
'// Teaches: nested for loops, write vs writeln, pattern logic' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'procedure DrawTriangle(size: Integer);' + #13#10 +
'var row, col : Integer;' + #13#10 +
'begin' + #13#10 +
'  writeln(''Right Triangle (size='', size, ''):'');' + #13#10 +
'  for row := 1 to size do' + #13#10 +
'  begin' + #13#10 +
'    for col := 1 to row do write(''* '');' + #13#10 +
'    writeln('''');' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'procedure DrawPyramid(size: Integer);' + #13#10 +
'var row, col : Integer;' + #13#10 +
'begin' + #13#10 +
'  writeln(''Pyramid (size='', size, ''):'');' + #13#10 +
'  for row := 1 to size do' + #13#10 +
'  begin' + #13#10 +
'    // Print leading spaces to centre the row' + #13#10 +
'    for col := 1 to size - row do write('' '');' + #13#10 +
'    // Print the stars' + #13#10 +
'    for col := 1 to 2 * row - 1 do write(''*'');' + #13#10 +
'    writeln('''');' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'procedure DrawDiamond(size: Integer);' + #13#10 +
'var row, col : Integer;' + #13#10 +
'begin' + #13#10 +
'  writeln(''Diamond (size='', size, ''):'');' + #13#10 +
'  // Top half' + #13#10 +
'  for row := 1 to size do' + #13#10 +
'  begin' + #13#10 +
'    for col := 1 to size - row do write('' '');' + #13#10 +
'    for col := 1 to 2*row-1 do write(''*'');' + #13#10 +
'    writeln('''');' + #13#10 +
'  end;' + #13#10 +
'  // Bottom half' + #13#10 +
'  for row := size - 1 downto 1 do' + #13#10 +
'  begin' + #13#10 +
'    for col := 1 to size - row do write('' '');' + #13#10 +
'    for col := 1 to 2*row-1 do write(''*'');' + #13#10 +
'    writeln('''');' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  DrawTriangle(6);' + #13#10 +
'  writeln('''');' + #13#10 +
'  DrawPyramid(6);' + #13#10 +
'  writeln('''');' + #13#10 +
'  DrawDiamond(5);' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Roman Numerals', 'Algorithms', 'Convert numbers to Roman numeral notation',
'// ============================================================' + #13#10 +
'// ROMAN NUMERALS' + #13#10 +
'// Converts integers to Roman numeral strings.' + #13#10 +
'// I=1 V=5 X=10 L=50 C=100 D=500 M=1000' + #13#10 +
'// Teaches: while loops, string building, greedy algorithm' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'function ToRoman(n: Integer): String;' + #13#10 +
'var result : String;' + #13#10 +
'begin' + #13#10 +
'  result := '''';' + #13#10 +
'  // *** NOTE: Greedy approach — subtract the largest possible' + #13#10 +
'  // Roman value each time until nothing is left.' + #13#10 +
'  while n >= 1000 do begin result := result + ''M'';    n := n - 1000; end;' + #13#10 +
'  while n >= 900  do begin result := result + ''CM'';   n := n - 900;  end;' + #13#10 +
'  while n >= 500  do begin result := result + ''D'';    n := n - 500;  end;' + #13#10 +
'  while n >= 400  do begin result := result + ''CD'';   n := n - 400;  end;' + #13#10 +
'  while n >= 100  do begin result := result + ''C'';    n := n - 100;  end;' + #13#10 +
'  while n >= 90   do begin result := result + ''XC'';   n := n - 90;   end;' + #13#10 +
'  while n >= 50   do begin result := result + ''L'';    n := n - 50;   end;' + #13#10 +
'  while n >= 40   do begin result := result + ''XL'';   n := n - 40;   end;' + #13#10 +
'  while n >= 10   do begin result := result + ''X'';    n := n - 10;   end;' + #13#10 +
'  while n >= 9    do begin result := result + ''IX'';   n := n - 9;    end;' + #13#10 +
'  while n >= 5    do begin result := result + ''V'';    n := n - 5;    end;' + #13#10 +
'  while n >= 4    do begin result := result + ''IV'';   n := n - 4;    end;' + #13#10 +
'  while n >= 1    do begin result := result + ''I'';    n := n - 1;    end;' + #13#10 +
'  Result := result;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var i : Integer;' + #13#10 +
'begin' + #13#10 +
'  writeln(''Roman Numerals 1-20:'');' + #13#10 +
'  for i := 1 to 20 do' + #13#10 +
'    writeln(i, '' = '', ToRoman(i));' + #13#10 +
'  writeln('''');' + #13#10 +
'  writeln(''Some notable numbers:'');' + #13#10 +
'  writeln(''2024 = '', ToRoman(2024));' + #13#10 +
'  writeln(''1999 = '', ToRoman(1999));' + #13#10 +
'  writeln(''3999 = '', ToRoman(3999));' + #13#10 +
'end.');

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY: File & Data
// ═══════════════════════════════════════════════════════════════════════════

Add('Grade Book', 'File & Data', 'Record student grades and save to file',
'// ============================================================' + #13#10 +
'// GRADE BOOK' + #13#10 +
'// Collects student names and scores, saves to a file.' + #13#10 +
'// Teaches: loops, file I/O, AppendFile, WriteFile, ReadFile' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  fname  : String;   // the file we save grades to' + #13#10 +
'  name   : String;   // student name' + #13#10 +
'  score  : String;   // score as text' + #13#10 +
'  adding : Boolean;  // keep adding students?' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  fname := GetAppPath + ''grades.txt'';' + #13#10 +
'  WriteFile(fname, ''=== Grade Book ===' + #13#10 + ''');' + #13#10 +
'' + #13#10 +
'  adding := true;' + #13#10 +
'  writeln(''=== Grade Book ==='');' + #13#10 +
'  writeln(''Enter student grades (Cancel to finish):'');' + #13#10 +
'' + #13#10 +
'  while adding do' + #13#10 +
'  begin' + #13#10 +
'    name := InputBox(''Student name (blank to finish):'', ''Grade Book'', '''');' + #13#10 +
'    if name = '''' then' + #13#10 +
'      adding := false' + #13#10 +
'    else' + #13#10 +
'    begin' + #13#10 +
'      score := InputBox(''Score for '' + name + '' (0-100):'', ''Grade Book'', ''0'');' + #13#10 +
'      // AppendFile adds a line to the file without erasing existing content' + #13#10 +
'      AppendFile(fname, name + '': '' + score);' + #13#10 +
'      writeln(''Recorded: '', name, '' = '', score);' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  writeln('''');' + #13#10 +
'  writeln(''=== Saved Grade Book ==='');' + #13#10 +
'  writeln(ReadFile(fname));' + #13#10 +
'  ShowInfoBox(''Grades saved to: '' + fname);' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('To-Do List', 'File & Data', 'A persistent to-do list saved to disk',
'// ============================================================' + #13#10 +
'// TO-DO LIST' + #13#10 +
'// Add tasks that persist between runs — saved to disk.' + #13#10 +
'// Teaches: WriteFile, AppendFile, ReadFile, FileExists, menus' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  fname  : String;' + #13#10 +
'  choice : String;' + #13#10 +
'  task   : String;' + #13#10 +
'  running: Boolean;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  fname   := GetAppPath + ''todo.txt'';' + #13#10 +
'  running := true;' + #13#10 +
'' + #13#10 +
'  // Create the file if it does not exist yet' + #13#10 +
'  if not FileExists(fname) then' + #13#10 +
'    WriteFile(fname, ''--- My To-Do List ---'');' + #13#10 +
'' + #13#10 +
'  while running do' + #13#10 +
'  begin' + #13#10 +
'    writeln(''=== TO-DO LIST ==='');' + #13#10 +
'    writeln(ReadFile(fname));' + #13#10 +
'    writeln(''---'');' + #13#10 +
'    choice := InputBox(' + #13#10 +
'      ''A=Add task  C=Clear all  Q=Quit'',' + #13#10 +
'      ''To-Do List'', ''A'');' + #13#10 +
'' + #13#10 +
'    caseof UpperCase(choice) of' + #13#10 +
'      ''A'':' + #13#10 +
'      begin' + #13#10 +
'        task := InputBox(''New task:'', ''Add Task'', '''');' + #13#10 +
'        if task <> '''' then' + #13#10 +
'        begin' + #13#10 +
'          AppendFile(fname, ''[ ] '' + task);' + #13#10 +
'          writeln(''Added: '', task);' + #13#10 +
'        end;' + #13#10 +
'      end;' + #13#10 +
'      ''C'':' + #13#10 +
'      begin' + #13#10 +
'        if Confirm(''Clear ALL tasks?'') then' + #13#10 +
'          WriteFile(fname, ''--- My To-Do List ---'');' + #13#10 +
'      end;' + #13#10 +
'      ''Q'': running := false;' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'  writeln(''Goodbye!'');' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Phone Book', 'File & Data', 'Save and search contacts stored in a file',
'// ============================================================' + #13#10 +
'// PHONE BOOK' + #13#10 +
'// A simple contact list saved to a text file.' + #13#10 +
'// Teaches: file I/O, string search with Pos, menus, loops' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  fname   : String;' + #13#10 +
'  choice  : String;' + #13#10 +
'  name    : String;' + #13#10 +
'  phone   : String;' + #13#10 +
'  search  : String;' + #13#10 +
'  all     : String;' + #13#10 +
'  running : Boolean;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  fname   := GetAppPath + ''phonebook.txt'';' + #13#10 +
'  running := true;' + #13#10 +
'' + #13#10 +
'  if not FileExists(fname) then' + #13#10 +
'    WriteFile(fname, ''=== Phone Book ==='');' + #13#10 +
'' + #13#10 +
'  while running do' + #13#10 +
'  begin' + #13#10 +
'    choice := InputBox(''A=Add  S=Search  L=List  Q=Quit'', ''Phone Book'', ''L'');' + #13#10 +
'    caseof UpperCase(choice) of' + #13#10 +
'      ''A'':' + #13#10 +
'      begin' + #13#10 +
'        name  := InputBox(''Contact name:'',  ''Add Contact'', '''');' + #13#10 +
'        phone := InputBox(''Phone number:'', ''Add Contact'', '''');' + #13#10 +
'        if name <> '''' then' + #13#10 +
'        begin' + #13#10 +
'          AppendFile(fname, name + '' | '' + phone);' + #13#10 +
'          writeln(''Added: '', name, '' | '', phone);' + #13#10 +
'        end;' + #13#10 +
'      end;' + #13#10 +
'      ''S'':' + #13#10 +
'      begin' + #13#10 +
'        search := InputBox(''Search for name:'', ''Search'', '''');' + #13#10 +
'        all    := ReadFile(fname);' + #13#10 +
'        // *** NOTE: Pos returns 0 if the string is not found' + #13#10 +
'        if Pos(search, all) > 0 then' + #13#10 +
'          writeln(''Found! Check the list below.'')' + #13#10 +
'        else' + #13#10 +
'          writeln(''Not found: '', search);' + #13#10 +
'        writeln(all);' + #13#10 +
'      end;' + #13#10 +
'      ''L'': writeln(ReadFile(fname));' + #13#10 +
'      ''Q'': running := false;' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Shopping Bill', 'File & Data', 'Build a shopping list and calculate the total',
'// ============================================================' + #13#10 +
'// SHOPPING BILL' + #13#10 +
'// Add items with prices, see running total, save receipt.' + #13#10 +
'// Teaches: running totals, string formatting, file saving' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  item    : String;' + #13#10 +
'  price   : Real;' + #13#10 +
'  total   : Real;' + #13#10 +
'  receipt : String;' + #13#10 +
'  adding  : Boolean;' + #13#10 +
'  fname   : String;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  total   := 0;' + #13#10 +
'  receipt := ''=== Shopping Bill ==='' + #13#10 + '''';' + #13#10 +
'  adding  := true;' + #13#10 +
'' + #13#10 +
'  writeln(''=== Shopping Bill ==='');' + #13#10 +
'  writeln(''Add items (leave name blank to finish):'');' + #13#10 +
'' + #13#10 +
'  while adding do' + #13#10 +
'  begin' + #13#10 +
'    item := InputBox(''Item name (blank=done):'', ''Shopping'', '''');' + #13#10 +
'    if item = '''' then' + #13#10 +
'      adding := false' + #13#10 +
'    else' + #13#10 +
'    begin' + #13#10 +
'      price   := StrToFloat(InputBox(''Price for '' + item + '':'', ''Shopping'', ''0''));' + #13#10 +
'      total   := total + price;' + #13#10 +
'      receipt := receipt + item + '': $'' + FloatToStr(round(price*100)/100) + #13#10 + '''';' + #13#10 +
'      writeln(item, '': $'', round(price*100)/100, ''  (Running total: $'', round(total*100)/100, '')'');' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  receipt := receipt + ''---'' + #13#10 + ''TOTAL: $'' + FloatToStr(round(total*100)/100);' + #13#10 +
'  writeln('''');' + #13#10 +
'  writeln(receipt);' + #13#10 +
'' + #13#10 +
'  if Confirm(''Save receipt to file?'') then' + #13#10 +
'  begin' + #13#10 +
'    fname := SaveFileDialog(''Text Files|*.txt'', ''txt'');' + #13#10 +
'    if fname <> '''' then' + #13#10 +
'    begin' + #13#10 +
'      WriteFile(fname, receipt);' + #13#10 +
'      ShowInfoBox(''Receipt saved to: '' + fname);' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'end.');

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY: Utilities
// ═══════════════════════════════════════════════════════════════════════════

Add('Password Generator', 'Utilities', 'Generate strong random passwords',
'// ============================================================' + #13#10 +
'// PASSWORD GENERATOR' + #13#10 +
'// Generates random passwords with letters, numbers, symbols.' + #13#10 +
'// Teaches: random, string building, Chr, Ord, loops' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  length   : Integer;' + #13#10 +
'  password : String;' + #13#10 +
'  i, kind  : Integer;' + #13#10 +
'  ch       : Integer;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  Randomize;' + #13#10 +
'  length   := StrToInt(InputBox(''Password length:'', ''Password Generator'', ''12''));' + #13#10 +
'  password := '''';' + #13#10 +
'' + #13#10 +
'  writeln(''Generating '', length, ''-character passwords:'');' + #13#10 +
'  writeln(''---'');' + #13#10 +
'' + #13#10 +
'  // Generate 5 passwords to choose from' + #13#10 +
'  var p, q : Integer;' + #13#10 +
'  var symbols : String;' + #13#10 +
'  symbols := ''!@#$%^&*-+='';' + #13#10 +
'  for p := 1 to 5 do' + #13#10 +
'  begin' + #13#10 +
'    password := '''';' + #13#10 +
'    for i := 1 to length do' + #13#10 +
'    begin' + #13#10 +
'      // Randomly pick: 0=uppercase, 1=lowercase, 2=digit, 3=symbol' + #13#10 +
'      kind := Random(4);' + #13#10 +
'      case kind of' + #13#10 +
'        0: ch := Ord(''A'') + Random(26);   // A-Z' + #13#10 +
'        1: ch := Ord(''a'') + Random(26);   // a-z' + #13#10 +
'        2: ch := Ord(''0'') + Random(10);   // 0-9' + #13#10 +
'        3: ch := Ord(Copy(symbols, Random(Length(symbols))+1, 1));' + #13#10 +
'      end;' + #13#10 +
'      password := password + Chr(ch);' + #13#10 +
'    end;' + #13#10 +
'    writeln(p, '': '', password);' + #13#10 +
'  end;' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Unit Converter', 'Utilities', 'Convert lengths, weights and volumes',
'// ============================================================' + #13#10 +
'// UNIT CONVERTER' + #13#10 +
'// Convert between metric and imperial units.' + #13#10 +
'// Teaches: caseof menus, functions, real arithmetic' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'function KmToMiles(km: Real): Real;  begin Result := km * 0.621371; end;' + #13#10 +
'function MilesToKm(m: Real): Real;   begin Result := m * 1.60934;  end;' + #13#10 +
'function KgToLbs(kg: Real): Real;    begin Result := kg * 2.20462; end;' + #13#10 +
'function LbsToKg(lb: Real): Real;    begin Result := lb * 0.453592; end;' + #13#10 +
'function LitToGal(l: Real): Real;    begin Result := l * 0.264172; end;' + #13#10 +
'function GalToLit(g: Real): Real;    begin Result := g * 3.78541;  end;' + #13#10 +
'function CmToIn(c: Real): Real;      begin Result := c * 0.393701; end;' + #13#10 +
'function InToCm(i: Real): Real;      begin Result := i * 2.54;     end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  cat, value : String;' + #13#10 +
'  n          : Real;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  writeln(''=== Unit Converter ==='');' + #13#10 +
'  cat := InputBox(''Category: KM/MILES/KG/LBS/LIT/GAL/CM/IN'', ''Converter'', ''KM'');' + #13#10 +
'  value := InputBox(''Enter value:'', ''Converter'', ''100'');' + #13#10 +
'  n := StrToFloat(value);' + #13#10 +
'' + #13#10 +
'  caseof UpperCase(cat) of' + #13#10 +
'    ''KM''   : writeln(n, '' km = '', round(KmToMiles(n)*1000)/1000, '' miles'');' + #13#10 +
'    ''MILES'': writeln(n, '' miles = '', round(MilesToKm(n)*1000)/1000, '' km'');' + #13#10 +
'    ''KG''   : writeln(n, '' kg = '', round(KgToLbs(n)*1000)/1000, '' lbs'');' + #13#10 +
'    ''LBS''  : writeln(n, '' lbs = '', round(LbsToKg(n)*1000)/1000, '' kg'');' + #13#10 +
'    ''LIT''  : writeln(n, '' litres = '', round(LitToGal(n)*1000)/1000, '' gallons'');' + #13#10 +
'    ''GAL''  : writeln(n, '' gallons = '', round(GalToLit(n)*1000)/1000, '' litres'');' + #13#10 +
'    ''CM''   : writeln(n, '' cm = '', round(CmToIn(n)*1000)/1000, '' inches'');' + #13#10 +
'    ''IN''   : writeln(n, '' inches = '', round(InToCm(n)*1000)/1000, '' cm'');' + #13#10 +
'  else' + #13#10 +
'    ShowWarningBox(''Unknown category: '' + cat);' + #13#10 +
'  end;' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Countdown Timer', 'Utilities', 'A simple countdown using a loop',
  '// ============================================================' + #13#10 +
  '// COUNTDOWN TIMER' + #13#10 +
  '// Counts down from N to zero, showing each second.' + #13#10 +
  '// Teaches: for downto, write, string formatting, Sleep' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'var' + #13#10 +
  '  seconds : Integer;' + #13#10 +
  '  i, mins, secs : Integer;' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  seconds := StrToInt(InputBox(''Count down from (seconds):'', ''Countdown'', ''10''));' + #13#10 +
  '' + #13#10 +
  '  writeln(''Starting countdown from '', seconds, '' seconds...'');' + #13#10 +
  '  writeln(''---'');' + #13#10 +
  '' + #13#10 +
  '  for i := seconds downto 0 do' + #13#10 +
  '  begin' + #13#10 +
  '    // Convert total seconds into minutes and seconds' + #13#10 +
  '    mins := i div 60;' + #13#10 +
  '    secs := i mod 60;' + #13#10 +
  '' + #13#10 +
  '    // Format as MM:SS (pad single digits with a leading zero)' + #13#10 +
  '    if secs < 10 then' + #13#10 +
  '      writeln(mins, '':0'', secs)' + #13#10 +
  '    else' + #13#10 +
  '      writeln(mins, '':'', secs);' + #13#10 +
  '' + #13#10 +
  '    // Pause execution for 1 second (1000 milliseconds)' + #13#10 +
  '    if i > 0 then' + #13#10 +
  '      Sleep(1000);' + #13#10 +
  '  end;' + #13#10 +
  '' + #13#10 +
  '  writeln(''---'');' + #13#10 +
  '  ShowMessage(''Time is up!'');' + #13#10 +
  '  writeln(''DONE!'');' + #13#10 +
  'end.');


// ---------------------------------------------------------------------------
Add('Statistics Calculator', 'Utilities', 'Enter numbers, get mean, min, max, range',
'// ============================================================' + #13#10 +
'// STATISTICS CALCULATOR' + #13#10 +
'// Enter a series of numbers and get key statistics.' + #13#10 +
'// Teaches: accumulation, min/max tracking, real arithmetic' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  n, count  : Integer;' + #13#10 +
'  total     : Real;' + #13#10 +
'  minVal    : Real;' + #13#10 +
'  maxVal    : Real;' + #13#10 +
'  value     : Real;' + #13#10 +
'  inp       : String;' + #13#10 +
'  going     : Boolean;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  count := 0;' + #13#10 +
'  total := 0;' + #13#10 +
'  going := true;' + #13#10 +
'  // Use extreme values so first entry always beats them' + #13#10 +
'  minVal :=  999999;' + #13#10 +
'  maxVal := -999999;' + #13#10 +
'' + #13#10 +
'  writeln(''=== Statistics Calculator ==='');' + #13#10 +
'  writeln(''Enter numbers one at a time. Blank to finish.'');' + #13#10 +
'' + #13#10 +
'  while going do' + #13#10 +
'  begin' + #13#10 +
'    inp := InputBox(''Enter a number (blank=done):'', ''Statistics'', '''');' + #13#10 +
'    if inp = '''' then' + #13#10 +
'      going := false' + #13#10 +
'    else' + #13#10 +
'    begin' + #13#10 +
'      value := StrToFloat(inp);' + #13#10 +
'      inc(count);' + #13#10 +
'      total := total + value;' + #13#10 +
'      // Track the smallest and largest values seen' + #13#10 +
'      if value < minVal then minVal := value;' + #13#10 +
'      if value > maxVal then maxVal := value;' + #13#10 +
'      writeln(''Added: '', value, ''  (count='', count, '')'');' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  if count = 0 then' + #13#10 +
'    writeln(''No numbers entered.'')' + #13#10 +
'  else' + #13#10 +
'  begin' + #13#10 +
'    writeln('''');' + #13#10 +
'    writeln(''=== Results ==='');' + #13#10 +
'    writeln(''Count  : '', count);' + #13#10 +
'    writeln(''Sum    : '', total);' + #13#10 +
'    writeln(''Mean   : '', round((total/count)*1000)/1000);' + #13#10 +
'    writeln(''Min    : '', minVal);' + #13#10 +
'    writeln(''Max    : '', maxVal);' + #13#10 +
'    writeln(''Range  : '', maxVal - minVal);' + #13#10 +
'  end;' + #13#10 +
'end.');

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY: Advanced
// ═══════════════════════════════════════════════════════════════════════════

Add('Collatz Conjecture', 'Advanced', 'Explore the famous unsolved 3n+1 sequence',
'// ============================================================' + #13#10 +
'// COLLATZ CONJECTURE' + #13#10 +
'// Pick any number. If even: halve it. If odd: multiply by 3 and add 1.' + #13#10 +
'// Repeat. The conjecture says you always reach 1. Nobody has proved it!' + #13#10 +
'// Teaches: while loops, mod, div, counters' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  n, steps : Integer;' + #13#10 +
'  maxN     : Integer;   // highest value reached' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  n     := StrToInt(InputBox(''Start number (try 27!):'', ''Collatz'', ''27''));' + #13#10 +
'  steps := 0;' + #13#10 +
'  maxN  := n;' + #13#10 +
'' + #13#10 +
'  writeln(''Collatz sequence starting at '', n, '':'');' + #13#10 +
'  write(n);' + #13#10 +
'' + #13#10 +
'  while n <> 1 do' + #13#10 +
'  begin' + #13#10 +
'    if n mod 2 = 0 then' + #13#10 +
'      n := n div 2          // even: halve' + #13#10 +
'    else' + #13#10 +
'      n := 3 * n + 1;       // odd: 3n+1' + #13#10 +
'' + #13#10 +
'    write('' -> '', n);' + #13#10 +
'    inc(steps);' + #13#10 +
'    if n > maxN then maxN := n;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  writeln('''');' + #13#10 +
'  writeln(''Reached 1 in '', steps, '' steps.'');' + #13#10 +
'  writeln(''Highest value reached: '', maxN);' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Sieve of Eratosthenes', 'Advanced', 'The fastest way to find all primes up to N',
'// ============================================================' + #13#10 +
'// SIEVE OF ERATOSTHENES' + #13#10 +
'// Ancient Greek method for finding all primes.' + #13#10 +
'// Mark multiples of each prime as composite.' + #13#10 +
'// Teaches: nested loops, boolean logic, efficiency thinking' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// We simulate a boolean array using 20 individual variables' + #13#10 +
'// (isPrime1..isPrime50 = whether each number is prime)' + #13#10 +
'// This version works up to 50 to fit in our variable model' + #13#10 +
'var' + #13#10 +
'  limit : Integer;' + #13#10 +
'  i, j  : Integer;' + #13#10 +
'  count : Integer;' + #13#10 +
'  // We use a String to track which numbers are prime' + #13#10 +
'  // P[i] = ''1'' means i is prime, ''0'' means composite' + #13#10 +
'  primes : String;' + #13#10 +
'  ch     : String;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  limit := 50;' + #13#10 +
'  // Build a string of ''1''s — we start assuming all are prime' + #13#10 +
'  primes := '''';' + #13#10 +
'  for i := 0 to limit do' + #13#10 +
'    primes := primes + ''1'';' + #13#10 +
'' + #13#10 +
'  // 0 and 1 are not prime' + #13#10 +
'  primes[1] := ''0'';   // index 1 = number 0' + #13#10 +
'  primes[2] := ''0'';   // index 2 = number 1' + #13#10 +
'' + #13#10 +
'  // Sieve: for each prime p, mark all its multiples as not prime' + #13#10 +
'  i := 2;' + #13#10 +
'  while i * i <= limit do' + #13#10 +
'  begin' + #13#10 +
'    // *** NOTE: i+1 because our string is 1-indexed' + #13#10 +
'    if Copy(primes, i+1, 1) = ''1'' then' + #13#10 +
'    begin' + #13#10 +
'      j := i * i;' + #13#10 +
'      while j <= limit do' + #13#10 +
'      begin' + #13#10 +
'        primes[j+1] := ''0'';   // mark as composite' + #13#10 +
'        j := j + i;' + #13#10 +
'      end;' + #13#10 +
'    end;' + #13#10 +
'    inc(i);' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  count := 0;' + #13#10 +
'  write(''Primes up to '', limit, '': '');' + #13#10 +
'  for i := 2 to limit do' + #13#10 +
'    if Copy(primes, i+1, 1) = ''1'' then' + #13#10 +
'    begin' + #13#10 +
'      write(i, '' '');' + #13#10 +
'      inc(count);' + #13#10 +
'    end;' + #13#10 +
'  writeln('''');' + #13#10 +
'  writeln(''Found '', count, '' primes.'');' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Sine Wave', 'Advanced', 'Draw an ASCII sine wave using maths',
'// ============================================================' + #13#10 +
'// ASCII SINE WAVE' + #13#10 +
'// Uses sin() to draw a text-art wave pattern.' + #13#10 +
'// Teaches: sin, pi, round, nested loops, real maths' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  x, y     : Integer;' + #13#10 +
'  height   : Integer;   // half-height of the wave' + #13#10 +
'  width    : Integer;   // how many columns wide' + #13#10 +
'  sineVal  : Real;' + #13#10 +
'  col      : Integer;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  height := 8;    // half-amplitude — wave goes from -8 to +8' + #13#10 +
'  width  := 60;   // one full cycle' + #13#10 +
'' + #13#10 +
'  writeln(''ASCII Sine Wave:'');' + #13#10 +
'  writeln('''');' + #13#10 +
'' + #13#10 +
'  // For each row (y axis), print stars where the sine curve passes' + #13#10 +
'  for y := height downto -height do' + #13#10 +
'  begin' + #13#10 +
'    for x := 0 to width - 1 do' + #13#10 +
'    begin' + #13#10 +
'      // sin() takes radians; 2*pi = one full cycle' + #13#10 +
'      sineVal := sin(2 * pi * x / width) * height;' + #13#10 +
'      col     := round(sineVal);' + #13#10 +
'' + #13#10 +
'      // Print a star if we are at the sine value for this column,' + #13#10 +
'      // or print the centre axis line' + #13#10 +
'      if col = y then' + #13#10 +
'        write(''*'')' + #13#10 +
'      else if y = 0 then' + #13#10 +
'        write(''-'')   // centre axis' + #13#10 +
'      else' + #13#10 +
'        write('' '');' + #13#10 +
'    end;' + #13#10 +
'    writeln('''');' + #13#10 +
'  end;' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Recursive Descent', 'Advanced', 'Build a tiny expression evaluator from scratch',
'// ============================================================' + #13#10 +
'// MINI EXPRESSION EVALUATOR' + #13#10 +
'// Evaluates simple maths expressions using recursive functions.' + #13#10 +
'// This is actually how MiniDelphi itself evaluates YOUR code!' + #13#10 +
'// Teaches: recursion, string parsing, the "eval" concept' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// We evaluate expressions of the form: number op number' + #13#10 +
'// e.g. "3 + 4", "10 * 5", "100 / 4"' + #13#10 +
'' + #13#10 +
'function FindOp(expr: String; out opPos: Integer): String;' + #13#10 +
'var i : Integer;' + #13#10 +
'    ch : String;' + #13#10 +
'begin' + #13#10 +
'  Result := '''';' + #13#10 +
'  for i := 2 to Length(expr) - 1 do' + #13#10 +
'  begin' + #13#10 +
'    ch := Copy(expr, i, 1);' + #13#10 +
'    if (ch = ''+'') or (ch = ''-'') or (ch = ''*'') or (ch = ''/'') then' + #13#10 +
'    begin' + #13#10 +
'      opPos  := i;' + #13#10 +
'      Result := ch;' + #13#10 +
'      exit;' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'function Evaluate(expr: String): Real;' + #13#10 +
'var' + #13#10 +
'  op    : String;' + #13#10 +
'  opPos : Integer;' + #13#10 +
'  left, right : Real;' + #13#10 +
'begin' + #13#10 +
'  expr  := Trim(expr);' + #13#10 +
'  op    := FindOp(expr, opPos);' + #13#10 +
'  if op = '''' then' + #13#10 +
'  begin' + #13#10 +
'    Result := StrToFloat(Trim(expr));' + #13#10 +
'    exit;' + #13#10 +
'  end;' + #13#10 +
'  left  := StrToFloat(Trim(Copy(expr, 1, opPos - 1)));' + #13#10 +
'  right := StrToFloat(Trim(Copy(expr, opPos + 1, Length(expr))));' + #13#10 +
'  caseof op of' + #13#10 +
'    ''+'': Result := left + right;' + #13#10 +
'    ''-'': Result := left - right;' + #13#10 +
'    ''*'': Result := left * right;' + #13#10 +
'    ''/'': if right <> 0 then Result := left / right else Result := 0;' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  expr   : String;' + #13#10 +
'  going  : Boolean;' + #13#10 +
'begin' + #13#10 +
'  going := true;' + #13#10 +
'  writeln(''Mini Expression Evaluator'');' + #13#10 +
'  writeln(''Enter: number op number  (e.g. 3 + 4.5)'');' + #13#10 +
'  writeln(''Type "quit" to exit.'');' + #13#10 +
'  while going do' + #13#10 +
'  begin' + #13#10 +
'    expr := InputBox(''Expression:'', ''Evaluator'', ''10 * 3.14'');' + #13#10 +
'    if LowerCase(expr) = ''quit'' then' + #13#10 +
'      going := false' + #13#10 +
'    else' + #13#10 +
'      writeln(expr, '' = '', Evaluate(expr));' + #13#10 +
'  end;' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Magic 8-Ball', 'Games & Fun', 'Ask a question, get a mystical answer',
'// ============================================================' + #13#10 +
'// MAGIC 8-BALL' + #13#10 +
'// Ask any yes/no question and receive wisdom!' + #13#10 +
'// Teaches: random, caseof, ShowMessage, while loops' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'function GetAnswer: String;' + #13#10 +
'var r : Integer;' + #13#10 +
'begin' + #13#10 +
'  r := Random(10);' + #13#10 +
'  case r of' + #13#10 +
'    0: Result := ''It is certain.'';' + #13#10 +
'    1: Result := ''Without a doubt.'';' + #13#10 +
'    2: Result := ''Yes, definitely!'';' + #13#10 +
'    3: Result := ''You may rely on it.'';' + #13#10 +
'    4: Result := ''Signs point to yes.'';' + #13#10 +
'    5: Result := ''Reply hazy, try again.'';' + #13#10 +
'    6: Result := ''Ask again later.'';' + #13#10 +
'    7: Result := ''Don''''t count on it.'';' + #13#10 +
'    8: Result := ''My sources say no.'';' + #13#10 +
'    9: Result := ''Outlook not so good.'';' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  question : String;' + #13#10 +
'  answer   : String;' + #13#10 +
'  going    : Boolean;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  Randomize;' + #13#10 +
'  going := true;' + #13#10 +
'  writeln(''=== Magic 8-Ball ==='');' + #13#10 +
'  writeln(''Ask any yes/no question...'');' + #13#10 +
'' + #13#10 +
'  while going do' + #13#10 +
'  begin' + #13#10 +
'    question := InputBox(''Ask the Magic 8-Ball:'', ''Magic 8-Ball'', '''');' + #13#10 +
'    if question = '''' then' + #13#10 +
'      going := false' + #13#10 +
'    else' + #13#10 +
'    begin' + #13#10 +
'      answer := GetAnswer;' + #13#10 +
'      writeln(''Q: '', question);' + #13#10 +
'      writeln(''A: '', answer);' + #13#10 +
'      writeln(''---'');' + #13#10 +
'      ShowInfoBox(''🎱 '' + answer);' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'  writeln(''The 8-Ball rests.'');' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Number Patterns', 'Numbers & Maths', 'Explore interesting number properties',
'// ============================================================' + #13#10 +
'// NUMBER PATTERNS' + #13#10 +
'// Explore perfect numbers, abundant, deficient, and Armstrong.' + #13#10 +
'// Teaches: nested loops, functions, number theory' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'// Sum of proper divisors (all divisors except the number itself)' + #13#10 +
'function SumDivisors(n: Integer): Integer;' + #13#10 +
'var i, s : Integer;' + #13#10 +
'begin' + #13#10 +
'  s := 1;   // 1 is always a divisor' + #13#10 +
'  i := 2;' + #13#10 +
'  while i * i <= n do' + #13#10 +
'  begin' + #13#10 +
'    if n mod i = 0 then' + #13#10 +
'    begin' + #13#10 +
'      s := s + i;' + #13#10 +
'      if i <> n div i then s := s + n div i;' + #13#10 +
'    end;' + #13#10 +
'    inc(i);' + #13#10 +
'  end;' + #13#10 +
'  Result := s;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'// Armstrong number: sum of digits^(number of digits) = number' + #13#10 +
'// e.g. 153 = 1^3 + 5^3 + 3^3' + #13#10 +
'function IsArmstrong(n: Integer): Boolean;' + #13#10 +
'var temp, digits, sum, d : Integer;' + #13#10 +
'begin' + #13#10 +
'  temp := n; digits := 0; sum := 0;' + #13#10 +
'  while temp > 0 do begin inc(digits); temp := temp div 10; end;' + #13#10 +
'  temp := n;' + #13#10 +
'  while temp > 0 do' + #13#10 +
'  begin' + #13#10 +
'    d    := temp mod 10;' + #13#10 +
'    sum  := sum + round(power(d, digits));' + #13#10 +
'    temp := temp div 10;' + #13#10 +
'  end;' + #13#10 +
'  Result := (sum = n);' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var i, s : Integer;' + #13#10 +
'begin' + #13#10 +
'  writeln(''=== Perfect Numbers (sum of divisors = itself) ==='');' + #13#10 +
'  for i := 2 to 1000 do' + #13#10 +
'    if SumDivisors(i) = i then' + #13#10 +
'      writeln(i, '' is perfect  (divisors sum to '', SumDivisors(i), '')'');' + #13#10 +
'' + #13#10 +
'  writeln('''');' + #13#10 +
'  writeln(''=== Armstrong Numbers up to 1000 ==='');' + #13#10 +
'  for i := 1 to 999 do' + #13#10 +
'    if IsArmstrong(i) then' + #13#10 +
'      writeln(i);' + #13#10 +
'end.');

// ---------------------------------------------------------------------------
Add('Morse Code', 'Strings & Text', 'Translate text into Morse code dots and dashes',
'// ============================================================' + #13#10 +
'// MORSE CODE TRANSLATOR' + #13#10 +
'// Converts text to Morse code (. and -)' + #13#10 +
'// Teaches: caseof strings, string loops, Copy, UpperCase' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'function LetterToMorse(ch: String): String;' + #13#10 +
'begin' + #13#10 +
'  caseof UpperCase(ch) of' + #13#10 +
'    ''A'': Result := ''.-'';    ''B'': Result := ''-...'';' + #13#10 +
'    ''C'': Result := ''-.-.'';  ''D'': Result := ''-..'';' + #13#10 +
'    ''E'': Result := ''.'';     ''F'': Result := ''..-.'';' + #13#10 +
'    ''G'': Result := ''--.'';   ''H'': Result := ''...."'';' + #13#10 +
'    ''I'': Result := ''..'';    ''J'': Result := ''.---'';' + #13#10 +
'    ''K'': Result := ''-.-'';   ''L'': Result := ''.-..'';' + #13#10 +
'    ''M'': Result := ''--'';    ''N'': Result := ''-.'';' + #13#10 +
'    ''O'': Result := ''---'';   ''P'': Result := ''.--.'';' + #13#10 +
'    ''Q'': Result := ''--.-'';  ''R'': Result := ''.-.'';' + #13#10 +
'    ''S'': Result := ''...'';   ''T'': Result := ''-'';' + #13#10 +
'    ''U'': Result := ''..-'';   ''V'': Result := ''...-'';' + #13#10 +
'    ''W'': Result := ''.--'';   ''X'': Result := ''-..-'';' + #13#10 +
'    ''Y'': Result := ''-.--'';  ''Z'': Result := ''--..'';' + #13#10 +
'    ''0'': Result := ''-----''; ''1'': Result := ''.----'';' + #13#10 +
'    ''2'': Result := ''..---''; ''3'': Result := ''...--'';' + #13#10 +
'    ''4'': Result := ''....-''; ''5'': Result := ''.....'';' + #13#10 +
'    ''6'': Result := ''-....''; ''7'': Result := ''--...'';' + #13#10 +
'    ''8'': Result := ''---..''; ''9'': Result := ''----.'';' + #13#10 +
'    '' '': Result := ''/'';' + #13#10 +
'  else' + #13#10 +
'    Result := ''?'';' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  text, morse : String;' + #13#10 +
'  i           : Integer;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  text  := InputBox(''Text to convert:'', ''Morse Code'', ''Hello World'');' + #13#10 +
'  morse := '''';' + #13#10 +
'  for i := 1 to Length(text) do' + #13#10 +
'    morse := morse + LetterToMorse(Copy(text, i, 1)) + '' '';' + #13#10 +
'  writeln(''Text : '', text);' + #13#10 +
'  writeln(''Morse: '', morse);' + #13#10 +
'end.');


// ═══════════════════════════════════════════════════════════════════════════
//  MULTI-FILE EXAMPLES
//  Each uses AddMulti() with an array of F() file records.
//  The project tab writes all files to a temp folder and opens the main one.
// ═══════════════════════════════════════════════════════════════════════════

// ---------------------------------------------------------------------------
// 1. MathLib — the simplest possible example of a library
// ---------------------------------------------------------------------------
AddMulti('MathLib Demo', 'Multi-File Projects',
  'Your first library: maths helpers imported by the main program',
[
  F('MathLib.mdp',
  '// ============================================================' + #13#10 +
  '// MATHLIB.MDP — A reusable maths library' + #13#10 +
  '//' + #13#10 +
  '// This is a LIBRARY file. It has no begin..end block.' + #13#10 +
  '// Other programs import it with:' + #13#10 +
  '//     uses' + #13#10 +
  '//       ''MathLib.mdp'';' + #13#10 +
  '//' + #13#10 +
  '// *** NOTE: A library is just a collection of reusable routines.' + #13#10 +
  '//     You write them once and use them in many programs.' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  '// Returns n squared (n * n)' + #13#10 +
  'function Square(n: Real): Real;' + #13#10 +
  'begin' + #13#10 +
  '  Result := n * n;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Returns n cubed (n * n * n)' + #13#10 +
  'function Cube(n: Real): Real;' + #13#10 +
  'begin' + #13#10 +
  '  Result := n * n * n;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Returns the hypotenuse of a right triangle (Pythagoras)' + #13#10 +
  'function Hypotenuse(a, b: Real): Real;' + #13#10 +
  'begin' + #13#10 +
  '  // a^2 + b^2 = c^2  =>  c = sqrt(a^2 + b^2)' + #13#10 +
  '  Result := sqrt(Square(a) + Square(b));' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Returns the average of two numbers' + #13#10 +
  'function Average(a, b: Real): Real;' + #13#10 +
  'begin' + #13#10 +
  '  Result := (a + b) / 2;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Clamps a value between lo and hi' + #13#10 +
  'function Clamp(value, lo, hi: Real): Real;' + #13#10 +
  'begin' + #13#10 +
  '  if value < lo then Result := lo' + #13#10 +
  '  else if value > hi then Result := hi' + #13#10 +
  '  else Result := value;' + #13#10 +
  'end;'),

  F('Main.mdp',
  '// ============================================================' + #13#10 +
  '// MAIN.MDP — Uses MathLib to do calculations' + #13#10 +
  '//' + #13#10 +
  '// *** NOTE: The uses clause tells MiniDelphi which library files' + #13#10 +
  '//     to load. The filename must be in single quotes.' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''MathLib.mdp'';' + #13#10 +
  '' + #13#10 +
  'var' + #13#10 +
  '  n : Real;' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  n := 5;' + #13#10 +
  '  writeln(''=== MathLib Demo ==='');' + #13#10 +
  '  writeln(''n           = '', n);' + #13#10 +
  '  writeln(''Square(n)   = '', Square(n));      // from MathLib' + #13#10 +
  '  writeln(''Cube(n)     = '', Cube(n));        // from MathLib' + #13#10 +
  '  writeln(''Hypotenuse(3,4) = '', Hypotenuse(3, 4));  // should be 5' + #13#10 +
  '  writeln(''Average(7,13)   = '', Average(7, 13));    // should be 10' + #13#10 +
  '  writeln(''Clamp(150,0,100)= '', Clamp(150, 0, 100)); // should be 100' + #13#10 +
  'end.', True)
]);

// ---------------------------------------------------------------------------
// 2. StringLib — string utility library
// ---------------------------------------------------------------------------
AddMulti('StringLib Demo', 'Multi-File Projects',
  'A string utilities library: reverse, repeat, contains, pad and more',
[
  F('StringLib.mdp',
  '// ============================================================' + #13#10 +
  '// STRINGLIB.MDP — Reusable string utility functions' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  '// Reverse a string: ''hello'' becomes ''olleh''' + #13#10 +
  'function StrReverse(s: String): String;' + #13#10 +
  'var i : Integer;' + #13#10 +
  '    r : String;' + #13#10 +
  'begin' + #13#10 +
  '  r := '''';' + #13#10 +
  '  for i := Length(s) downto 1 do' + #13#10 +
  '    r := r + Copy(s, i, 1);' + #13#10 +
  '  Result := r;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Repeat a string n times: StrRep(''ab'',3) = ''ababab''' + #13#10 +
  'function StrRep(s: String; n: Integer): String;' + #13#10 +
  'var i : Integer;' + #13#10 +
  '    r : String;' + #13#10 +
  'begin' + #13#10 +
  '  r := '''';' + #13#10 +
  '  for i := 1 to n do r := r + s;' + #13#10 +
  '  Result := r;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// True if s contains substr' + #13#10 +
  'function StrContains(s, substr: String): Boolean;' + #13#10 +
  'begin' + #13#10 +
  '  Result := Pos(substr, s) > 0;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Pad s on the left to width w using padChar' + #13#10 +
  'function PadLeft(s: String; w: Integer; padChar: String): String;' + #13#10 +
  'begin' + #13#10 +
  '  while Length(s) < w do s := padChar + s;' + #13#10 +
  '  Result := s;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Count how many times substr appears in s' + #13#10 +
  'function StrCount(s, substr: String): Integer;' + #13#10 +
  'var p, count : Integer;' + #13#10 +
  'begin' + #13#10 +
  '  count := 0;' + #13#10 +
  '  p     := Pos(substr, s);' + #13#10 +
  '  while p > 0 do' + #13#10 +
  '  begin' + #13#10 +
  '    inc(count);' + #13#10 +
  '    s := Copy(s, p + Length(substr), Length(s));' + #13#10 +
  '    p := Pos(substr, s);' + #13#10 +
  '  end;' + #13#10 +
  '  Result := count;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// True if s is a palindrome' + #13#10 +
  'function IsPalindrome(s: String): Boolean;' + #13#10 +
  'begin' + #13#10 +
  '  Result := LowerCase(s) = StrReverse(LowerCase(s));' + #13#10 +
  'end;'),

  F('Main.mdp',
  '// ============================================================' + #13#10 +
  '// MAIN.MDP — Demonstrates StringLib' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''StringLib.mdp'';' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  writeln(''=== StringLib Demo ==='');' + #13#10 +
  '  writeln(''StrReverse("hello")    = '', StrReverse(''hello''));' + #13#10 +
  '  writeln(''StrRep("ab", 4)        = '', StrRep(''ab'', 4));' + #13#10 +
  '  writeln(''StrContains("Delphi","ph") = '', StrContains(''Delphi'', ''ph''));' + #13#10 +
  '  writeln(''PadLeft("7", 4, "0")   = '', PadLeft(''7'', 4, ''0''));' + #13#10 +
  '  writeln(''StrCount("banana","a") = '', StrCount(''banana'', ''a''));' + #13#10 +
  '  writeln(''IsPalindrome("racecar")= '', IsPalindrome(''racecar''));' + #13#10 +
  '  writeln(''IsPalindrome("hello")  = '', IsPalindrome(''hello''));' + #13#10 +
  'end.', True)
]);

// ---------------------------------------------------------------------------
// 3. Student Grade System — three files working together
// ---------------------------------------------------------------------------
AddMulti('Student Grade System', 'Multi-File Projects',
  'Three units: MathLib + GradeLib + Main — shows unit chaining',
[
  F('MathUtils.mdp',
  '// ============================================================' + #13#10 +
  '// MATHUTILS.MDP — Low-level maths helpers' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'function RoundTo2(n: Real): Real;' + #13#10 +
  'begin' + #13#10 +
  '  Result := round(n * 100) / 100;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'function Percentage(score, total: Real): Real;' + #13#10 +
  'begin' + #13#10 +
  '  if total = 0 then Result := 0' + #13#10 +
  '  else Result := RoundTo2(score / total * 100);' + #13#10 +
  'end;'),

  F('GradeLib.mdp',
  '// ============================================================' + #13#10 +
  '// GRADELIB.MDP — Grade classification built on MathUtils' + #13#10 +
  '//' + #13#10 +
  '// *** NOTE: A library can itself import another library!' + #13#10 +
  '//     This is called a dependency chain.' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''MathUtils.mdp'';   // GradeLib depends on MathUtils' + #13#10 +
  '' + #13#10 +
  '// Convert a percentage score to a letter grade' + #13#10 +
  'function LetterGrade(pct: Real): String;' + #13#10 +
  'begin' + #13#10 +
  '  if      pct >= 90 then Result := ''A+''' + #13#10 +
  '  else if pct >= 80 then Result := ''A''' + #13#10 +
  '  else if pct >= 70 then Result := ''B''' + #13#10 +
  '  else if pct >= 60 then Result := ''C''' + #13#10 +
  '  else if pct >= 50 then Result := ''D''' + #13#10 +
  '  else                    Result := ''F'';' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Print one student result line' + #13#10 +
  'procedure PrintResult(name: String; score, total: Real);' + #13#10 +
  'var pct : Real;' + #13#10 +
  'begin' + #13#10 +
  '  pct := Percentage(score, total);   // from MathUtils' + #13#10 +
  '  writeln(name, '': '', score, ''/'', total,' + #13#10 +
  '          ''  ('', pct, ''%)  Grade: '', LetterGrade(pct));' + #13#10 +
  'end;'),

  F('Main.mdp',
  '// ============================================================' + #13#10 +
  '// MAIN.MDP — Student Grade System' + #13#10 +
  '//' + #13#10 +
  '// *** NOTE: We only import GradeLib here.' + #13#10 +
  '//     GradeLib automatically imports MathUtils for us.' + #13#10 +
  '//     This is the power of dependency chains!' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''GradeLib.mdp'';' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  writeln(''=== Student Report Card ==='');' + #13#10 +
  '  writeln(''----------------------------'');' + #13#10 +
  '  PrintResult(''Alice'',   87, 100);' + #13#10 +
  '  PrintResult(''Bob'',     63, 100);' + #13#10 +
  '  PrintResult(''Carol'',   95, 100);' + #13#10 +
  '  PrintResult(''Dave'',    42, 100);' + #13#10 +
  '  PrintResult(''Eve'',     78, 100);' + #13#10 +
  '  writeln(''----------------------------'');' + #13#10 +
  '  writeln(''Class average: '', Percentage(87+63+95+42+78, 500), ''%'');' + #13#10 +
  'end.', True)
]);

// ---------------------------------------------------------------------------
// 4. Shape Calculator — geometry library
// ---------------------------------------------------------------------------
AddMulti('Shape Calculator', 'Multi-File Projects',
  'GeometryLib provides area/perimeter for circles, rectangles and triangles',
[
  F('GeometryLib.mdp',
  '// ============================================================' + #13#10 +
  '// GEOMETRYLIB.MDP — Area and perimeter calculations' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  '// Circle' + #13#10 +
  'function CircleArea(r: Real): Real;' + #13#10 +
  'begin Result := pi * r * r; end;' + #13#10 +
  '' + #13#10 +
  'function CirclePerimeter(r: Real): Real;' + #13#10 +
  'begin Result := 2 * pi * r; end;' + #13#10 +
  '' + #13#10 +
  '// Rectangle' + #13#10 +
  'function RectArea(w, h: Real): Real;' + #13#10 +
  'begin Result := w * h; end;' + #13#10 +
  '' + #13#10 +
  'function RectPerimeter(w, h: Real): Real;' + #13#10 +
  'begin Result := 2 * (w + h); end;' + #13#10 +
  '' + #13#10 +
  '// Triangle (Heron''s formula for area from 3 sides)' + #13#10 +
  'function TriangleArea(a, b, c: Real): Real;' + #13#10 +
  'var s : Real;' + #13#10 +
  'begin' + #13#10 +
  '  s      := (a + b + c) / 2;   // semi-perimeter' + #13#10 +
  '  Result := sqrt(s * (s-a) * (s-b) * (s-c));' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'function TrianglePerimeter(a, b, c: Real): Real;' + #13#10 +
  'begin Result := a + b + c; end;' + #13#10 +
  '' + #13#10 +
  '// Print a formatted shape report' + #13#10 +
  'procedure ShapeReport(shape: String; area, perim: Real);' + #13#10 +
  'begin' + #13#10 +
  '  writeln(shape);' + #13#10 +
  '  writeln(''  Area      : '', round(area * 100) / 100);' + #13#10 +
  '  writeln(''  Perimeter : '', round(perim * 100) / 100);' + #13#10 +
  'end;'),

  F('Main.mdp',
  '// ============================================================' + #13#10 +
  '// MAIN.MDP — Shape Calculator using GeometryLib' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''GeometryLib.mdp'';' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  writeln(''=== Shape Calculator ==='');' + #13#10 +
  '  writeln('''');' + #13#10 +
  '  ShapeReport(''Circle (r=5):'', CircleArea(5), CirclePerimeter(5));' + #13#10 +
  '  writeln('''');' + #13#10 +
  '  ShapeReport(''Rectangle (8x3):'', RectArea(8,3), RectPerimeter(8,3));' + #13#10 +
  '  writeln('''');' + #13#10 +
  '  ShapeReport(''Triangle (3,4,5):'', TriangleArea(3,4,5), TrianglePerimeter(3,4,5));' + #13#10 +
  'end.', True)
]);

// ---------------------------------------------------------------------------
// 5. Personal Finance — two libraries, one main
// ---------------------------------------------------------------------------
AddMulti('Personal Finance Tracker', 'Multi-File Projects',
  'TaxLib + InterestLib + main program — real-world finance calculations',
[
  F('TaxLib.mdp',
  '// ============================================================' + #13#10 +
  '// TAXLIB.MDP — Income tax calculations' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  '// Simple progressive tax: 0% on first 12000, 20% next, 40% above 50000' + #13#10 +
  'function IncomeTax(income: Real): Real;' + #13#10 +
  'var tax : Real;' + #13#10 +
  'begin' + #13#10 +
  '  tax := 0;' + #13#10 +
  '  if income > 50000 then tax := tax + (income - 50000) * 0.40;' + #13#10 +
  '  if income > 12000 then' + #13#10 +
  '    tax := tax + (min(income, 50000) - 12000) * 0.20;' + #13#10 +
  '  Result := tax;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'function TakeHomePay(gross: Real): Real;' + #13#10 +
  'begin' + #13#10 +
  '  Result := gross - IncomeTax(gross);' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'procedure PrintTaxSummary(gross: Real);' + #13#10 +
  'begin' + #13#10 +
  '  writeln(''Gross income  : $'', round(gross));' + #13#10 +
  '  writeln(''Income tax    : $'', round(IncomeTax(gross)));' + #13#10 +
  '  writeln(''Take-home pay : $'', round(TakeHomePay(gross)));' + #13#10 +
  'end;'),

  F('InterestLib.mdp',
  '// ============================================================' + #13#10 +
  '// INTERESTLIB.MDP — Savings and loan interest' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  '// Simple interest: P * R * T' + #13#10 +
  'function SimpleInterest(principal, rate, years: Real): Real;' + #13#10 +
  'begin' + #13#10 +
  '  Result := principal * (rate / 100) * years;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Compound interest: P * (1 + R)^T' + #13#10 +
  'function CompoundInterest(principal, rate, years: Real): Real;' + #13#10 +
  'begin' + #13#10 +
  '  Result := principal * power(1 + rate/100, years) - principal;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Future value of a savings account' + #13#10 +
  'function FutureValue(principal, rate, years: Real): Real;' + #13#10 +
  'begin' + #13#10 +
  '  Result := principal * power(1 + rate/100, years);' + #13#10 +
  'end;'),

  F('Main.mdp',
  '// ============================================================' + #13#10 +
  '// MAIN.MDP — Personal Finance Tracker' + #13#10 +
  '//' + #13#10 +
  '// *** NOTE: We import TWO libraries here.' + #13#10 +
  '//     Each one provides a different set of tools.' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''TaxLib.mdp'',' + #13#10 +
  '  ''InterestLib.mdp'';' + #13#10 +
  '' + #13#10 +
  'var salary : Real;' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  salary := StrToFloat(InputBox(''Annual salary ($):'', ''Finance'', ''45000''));' + #13#10 +
  '' + #13#10 +
  '  writeln(''=== Personal Finance Report ==='');' + #13#10 +
  '  writeln('''');' + #13#10 +
  '  writeln(''--- Tax Summary ---'');' + #13#10 +
  '  PrintTaxSummary(salary);          // from TaxLib' + #13#10 +
  '' + #13#10 +
  '  writeln('''');' + #13#10 +
  '  writeln(''--- If you save $5000 for 10 years at 4% ---'');' + #13#10 +
  '  writeln(''Simple interest   : $'', round(SimpleInterest(5000, 4, 10)));' + #13#10 +
  '  writeln(''Compound interest : $'', round(CompoundInterest(5000, 4, 10)));' + #13#10 +
  '  writeln(''Future value      : $'', round(FutureValue(5000, 4, 10)));' + #13#10 +
  'end.', True)
]);

// ---------------------------------------------------------------------------
// 6. Text Adventure Game — GameEngine + Rooms + Main
// ---------------------------------------------------------------------------
AddMulti('Mini Text Adventure', 'Multi-File Projects',
  'GameEngine library powers a tiny text adventure — shows event-driven design',
[
  F('GameEngine.mdp',
  '// ============================================================' + #13#10 +
  '// GAMEENGINE.MDP — Core engine for a text adventure game' + #13#10 +
  '//' + #13#10 +
  '// Provides: player state, movement, inventory basics' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  '// Global player state' + #13#10 +
  'var' + #13#10 +
  '  PlayerHealth  : Integer;' + #13#10 +
  '  PlayerGold    : Integer;' + #13#10 +
  '  PlayerRoom    : Integer;   // 1=Entrance 2=Hall 3=Dungeon 4=Treasure' + #13#10 +
  '  GameOver      : Boolean;' + #13#10 +
  '' + #13#10 +
  'procedure InitPlayer;' + #13#10 +
  'begin' + #13#10 +
  '  PlayerHealth := 100;' + #13#10 +
  '  PlayerGold   := 0;' + #13#10 +
  '  PlayerRoom   := 1;' + #13#10 +
  '  GameOver     := false;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'procedure ShowStatus;' + #13#10 +
  'begin' + #13#10 +
  '  writeln(''[ Health: '', PlayerHealth, ''  Gold: '', PlayerGold, '' ]'');' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'procedure TakeDamage(amount: Integer);' + #13#10 +
  'begin' + #13#10 +
  '  PlayerHealth := PlayerHealth - amount;' + #13#10 +
  '  if PlayerHealth <= 0 then' + #13#10 +
  '  begin' + #13#10 +
  '    PlayerHealth := 0;' + #13#10 +
  '    GameOver     := true;' + #13#10 +
  '    writeln(''You have been defeated!'');' + #13#10 +
  '  end;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'procedure AddGold(amount: Integer);' + #13#10 +
  'begin' + #13#10 +
  '  PlayerGold := PlayerGold + amount;' + #13#10 +
  '  writeln(''You found '', amount, '' gold!'');' + #13#10 +
  'end;'),

  F('Main.mdp',
  '// ============================================================' + #13#10 +
  '// MAIN.MDP — Mini Text Adventure' + #13#10 +
  '//' + #13#10 +
  '// Uses GameEngine for all player state and combat.' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''GameEngine.mdp'';' + #13#10 +
  '' + #13#10 +
  'procedure DoRoom;' + #13#10 +
  'var choice : String;' + #13#10 +
  'begin' + #13#10 +
  '  case PlayerRoom of' + #13#10 +
  '    1:' + #13#10 +
  '    begin' + #13#10 +
  '      writeln(''=== Castle Entrance ==='');' + #13#10 +
  '      writeln(''A dark castle looms before you.'');' + #13#10 +
  '      writeln(''Exits: NORTH=Hall'');' + #13#10 +
  '      ShowStatus;' + #13#10 +
  '      choice := InputBox(''Which way? (NORTH/QUIT):'', ''Adventure'', ''NORTH'');' + #13#10 +
  '      caseof UpperCase(choice) of' + #13#10 +
  '        ''NORTH'' : PlayerRoom := 2;' + #13#10 +
  '        ''QUIT''  : GameOver  := true;' + #13#10 +
  '      end;' + #13#10 +
  '    end;' + #13#10 +
  '    2:' + #13#10 +
  '    begin' + #13#10 +
  '      writeln(''=== Great Hall ==='');' + #13#10 +
  '      writeln(''A goblin blocks the way! It attacks!'');' + #13#10 +
  '      TakeDamage(20);' + #13#10 +
  '      if not GameOver then' + #13#10 +
  '      begin' + #13#10 +
  '        writeln(''You defeat the goblin.'');' + #13#10 +
  '        AddGold(15);' + #13#10 +
  '        writeln(''Exits: SOUTH=Entrance NORTH=Dungeon'');' + #13#10 +
  '        ShowStatus;' + #13#10 +
  '        choice := InputBox(''Which way?:'', ''Adventure'', ''NORTH'');' + #13#10 +
  '        caseof UpperCase(choice) of' + #13#10 +
  '          ''SOUTH'' : PlayerRoom := 1;' + #13#10 +
  '          ''NORTH'' : PlayerRoom := 3;' + #13#10 +
  '        end;' + #13#10 +
  '      end;' + #13#10 +
  '    end;' + #13#10 +
  '    3:' + #13#10 +
  '    begin' + #13#10 +
  '      writeln(''=== The Dungeon ==='');' + #13#10 +
  '      writeln(''A dragon lurks here! Massive claws rake you!'');' + #13#10 +
  '      TakeDamage(40);' + #13#10 +
  '      if not GameOver then' + #13#10 +
  '      begin' + #13#10 +
  '        writeln(''You slay the dragon!'');' + #13#10 +
  '        AddGold(100);' + #13#10 +
  '        writeln(''Exits: SOUTH=Hall EAST=Treasure Room'');' + #13#10 +
  '        ShowStatus;' + #13#10 +
  '        choice := InputBox(''Which way?:'', ''Adventure'', ''EAST'');' + #13#10 +
  '        caseof UpperCase(choice) of' + #13#10 +
  '          ''SOUTH'' : PlayerRoom := 2;' + #13#10 +
  '          ''EAST''  : PlayerRoom := 4;' + #13#10 +
  '        end;' + #13#10 +
  '      end;' + #13#10 +
  '    end;' + #13#10 +
  '    4:' + #13#10 +
  '    begin' + #13#10 +
  '      writeln(''=== Treasure Room ==='');' + #13#10 +
  '      writeln(''Piles of gold glitter everywhere!'');' + #13#10 +
  '      AddGold(500);' + #13#10 +
  '      writeln(''YOU WIN! Final gold: '', PlayerGold);' + #13#10 +
  '      ShowMessage(''YOU WIN! Total gold: '' + IntToStr(PlayerGold));' + #13#10 +
  '      GameOver := true;' + #13#10 +
  '    end;' + #13#10 +
  '  end;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  InitPlayer;' + #13#10 +
  '  ShowMessage(''Welcome to the Mini Text Adventure! Use dialogs to navigate.'');' + #13#10 +
  '  while not GameOver do' + #13#10 +
  '    DoRoom;' + #13#10 +
  '  writeln(''Game over. Final gold: '', PlayerGold);' + #13#10 +
  'end.', True)
]);

// ---------------------------------------------------------------------------
// 7. Statistics Suite — DataLib + StatsLib + Main
// ---------------------------------------------------------------------------
AddMulti('Statistics Suite', 'Multi-File Projects',
  'DataLib handles collections, StatsLib computes mean/variance/stddev',
[
  F('DataLib.mdp',
  '// ============================================================' + #13#10 +
  '// DATALIB.MDP — Simple data collection into a string-encoded list' + #13#10 +
  '//' + #13#10 +
  '// Since MiniDelphi has no arrays, we encode numbers as a' + #13#10 +
  '// comma-separated string and parse them back when needed.' + #13#10 +
  '// *** NOTE: This is a common trick in constrained environments!' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  '// Add a number to the dataset (stored as CSV string)' + #13#10 +
  'function DataAdd(data: String; value: Real): String;' + #13#10 +
  'begin' + #13#10 +
  '  if data = '''' then Result := FloatToStr(value)' + #13#10 +
  '  else Result := data + '','' + FloatToStr(value);' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Count items in dataset' + #13#10 +
  'function DataCount(data: String): Integer;' + #13#10 +
  'var i, count : Integer;' + #13#10 +
  'begin' + #13#10 +
  '  if data = '''' then begin Result := 0; exit; end;' + #13#10 +
  '  count := 1;' + #13#10 +
  '  for i := 1 to Length(data) do' + #13#10 +
  '    if Copy(data, i, 1) = '','' then inc(count);' + #13#10 +
  '  Result := count;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Get item at position k (1-based) from dataset' + #13#10 +
  'function DataGet(data: String; k: Integer): Real;' + #13#10 +
  'var i, cur, p : Integer;' + #13#10 +
  '    token     : String;' + #13#10 +
  'begin' + #13#10 +
  '  cur := 1; p := 1;' + #13#10 +
  '  for i := 1 to Length(data) + 1 do' + #13#10 +
  '  begin' + #13#10 +
  '    if (i > Length(data)) or (Copy(data, i, 1) = '','') then' + #13#10 +
  '    begin' + #13#10 +
  '      if cur = k then' + #13#10 +
  '      begin' + #13#10 +
  '        Result := StrToFloat(Copy(data, p, i - p));' + #13#10 +
  '        exit;' + #13#10 +
  '      end;' + #13#10 +
  '      inc(cur); p := i + 1;' + #13#10 +
  '    end;' + #13#10 +
  '  end;' + #13#10 +
  '  Result := 0;' + #13#10 +
  'end;'),

  F('StatsLib.mdp',
  '// ============================================================' + #13#10 +
  '// STATSLIB.MDP — Statistical functions built on DataLib' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''DataLib.mdp'';' + #13#10 +
  '' + #13#10 +
  'function StatSum(data: String): Real;' + #13#10 +
  'var i : Integer;' + #13#10 +
  '    s : Real;' + #13#10 +
  'begin' + #13#10 +
  '  s := 0;' + #13#10 +
  '  for i := 1 to DataCount(data) do s := s + DataGet(data, i);' + #13#10 +
  '  Result := s;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'function StatMean(data: String): Real;' + #13#10 +
  'var n : Integer;' + #13#10 +
  'begin' + #13#10 +
  '  n := DataCount(data);' + #13#10 +
  '  if n = 0 then Result := 0' + #13#10 +
  '  else Result := StatSum(data) / n;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'function StatMin(data: String): Real;' + #13#10 +
  'var i : Integer;' + #13#10 +
  '    m : Real;' + #13#10 +
  'begin' + #13#10 +
  '  m := DataGet(data, 1);' + #13#10 +
  '  for i := 2 to DataCount(data) do' + #13#10 +
  '    if DataGet(data, i) < m then m := DataGet(data, i);' + #13#10 +
  '  Result := m;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'function StatMax(data: String): Real;' + #13#10 +
  'var i : Integer;' + #13#10 +
  '    m : Real;' + #13#10 +
  'begin' + #13#10 +
  '  m := DataGet(data, 1);' + #13#10 +
  '  for i := 2 to DataCount(data) do' + #13#10 +
  '    if DataGet(data, i) > m then m := DataGet(data, i);' + #13#10 +
  '  Result := m;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'function StatVariance(data: String): Real;' + #13#10 +
  'var i, n : Integer;' + #13#10 +
  '    mean, sum : Real;' + #13#10 +
  'begin' + #13#10 +
  '  n := DataCount(data);' + #13#10 +
  '  if n < 2 then begin Result := 0; exit; end;' + #13#10 +
  '  mean := StatMean(data);' + #13#10 +
  '  sum  := 0;' + #13#10 +
  '  for i := 1 to n do' + #13#10 +
  '    sum := sum + sqr(DataGet(data, i) - mean);' + #13#10 +
  '  Result := sum / (n - 1);   // sample variance' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'function StatStdDev(data: String): Real;' + #13#10 +
  'begin' + #13#10 +
  '  Result := sqrt(StatVariance(data));' + #13#10 +
  'end;'),

  F('Main.mdp',
  '// ============================================================' + #13#10 +
  '// MAIN.MDP — Statistics Suite' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''StatsLib.mdp'';   // StatsLib pulls in DataLib automatically' + #13#10 +
  '' + #13#10 +
  'var' + #13#10 +
  '  data  : String;   // our dataset as CSV' + #13#10 +
  '  inp   : String;' + #13#10 +
  '  going : Boolean;' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  data  := '''';' + #13#10 +
  '  going := true;' + #13#10 +
  '  writeln(''=== Statistics Suite ==='');' + #13#10 +
  '  writeln(''Enter numbers one at a time. Blank = calculate.'');' + #13#10 +
  '' + #13#10 +
  '  while going do' + #13#10 +
  '  begin' + #13#10 +
  '    inp := InputBox(''Add value (blank=done):'', ''Stats'', '''');' + #13#10 +
  '    if inp = '''' then' + #13#10 +
  '      going := false' + #13#10 +
  '    else' + #13#10 +
  '      data := DataAdd(data, StrToFloat(inp));' + #13#10 +
  '  end;' + #13#10 +
  '' + #13#10 +
  '  if DataCount(data) = 0 then' + #13#10 +
  '    writeln(''No data entered.'')' + #13#10 +
  '  else' + #13#10 +
  '  begin' + #13#10 +
  '    writeln(''Count  : '', DataCount(data));' + #13#10 +
  '    writeln(''Sum    : '', StatSum(data));' + #13#10 +
  '    writeln(''Mean   : '', round(StatMean(data)*1000)/1000);' + #13#10 +
  '    writeln(''Min    : '', StatMin(data));' + #13#10 +
  '    writeln(''Max    : '', StatMax(data));' + #13#10 +
  '    writeln(''StdDev : '', round(StatStdDev(data)*1000)/1000);' + #13#10 +
  '  end;' + #13#10 +
  'end.', True)
]);

// ---------------------------------------------------------------------------
// 8. Unit Conversion System — UnitsLib shared across two programs
// ---------------------------------------------------------------------------
AddMulti('Shared Units Demo', 'Multi-File Projects',
  'One UnitsLib used by TWO different main programs — shows true reuse',
[
  F('UnitsLib.mdp',
  '// ============================================================' + #13#10 +
  '// UNITSLIB.MDP — Conversion functions used by multiple programs' + #13#10 +
  '//' + #13#10 +
  '// *** NOTE: This is WHY libraries exist.' + #13#10 +
  '//     Write the conversion logic ONCE, use it EVERYWHERE.' + #13#10 +
  '//     If the formula needs fixing, fix it in ONE place.' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  '// Length' + #13#10 +
  'function MetresToFeet(m: Real): Real;   begin Result := m * 3.28084;  end;' + #13#10 +
  'function FeetToMetres(f: Real): Real;   begin Result := f * 0.3048;   end;' + #13#10 +
  'function KmToMiles(k: Real): Real;      begin Result := k * 0.621371; end;' + #13#10 +
  '' + #13#10 +
  '// Weight' + #13#10 +
  'function KgToLbs(kg: Real): Real;       begin Result := kg * 2.20462; end;' + #13#10 +
  'function LbsToKg(lb: Real): Real;       begin Result := lb * 0.453592; end;' + #13#10 +
  '' + #13#10 +
  '// Temperature' + #13#10 +
  'function CelsiusToF(c: Real): Real;     begin Result := c * 9/5 + 32;  end;' + #13#10 +
  'function FahrenheitToC(f: Real): Real;  begin Result := (f-32) * 5/9;  end;' + #13#10 +
  '' + #13#10 +
  '// Speed' + #13#10 +
  'function KphToMph(k: Real): Real;       begin Result := k * 0.621371; end;' + #13#10 +
  'function MphToKph(m: Real): Real;       begin Result := m * 1.60934;  end;'),

  F('ScientificConverter.mdp',
  '// ============================================================' + #13#10 +
  '// SCIENTIFICCONVERTER.MDP' + #13#10 +
  '// A scientific-style converter using UnitsLib' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''UnitsLib.mdp'';' + #13#10 +
  '' + #13#10 +
  'var n : Real;' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  writeln(''=== Scientific Converter ==='');' + #13#10 +
  '  n := StrToFloat(InputBox(''Enter metres:'', ''Converter'', ''1''));' + #13#10 +
  '  writeln(n, '' metres = '', round(MetresToFeet(n)*1000)/1000, '' feet'');' + #13#10 +
  '  n := StrToFloat(InputBox(''Enter km/h:'', ''Converter'', ''100''));' + #13#10 +
  '  writeln(n, '' km/h = '', round(KphToMph(n)*100)/100, '' mph'');' + #13#10 +
  '  n := StrToFloat(InputBox(''Enter Celsius:'', ''Converter'', ''100''));' + #13#10 +
  '  writeln(n, '' C = '', CelsiusToF(n), '' F'');' + #13#10 +
  'end.', True),

  F('CookingConverter.mdp',
  '// ============================================================' + #13#10 +
  '// COOKINGCONVERTER.MDP' + #13#10 +
  '// A cooking-style converter — SAME library, different purpose!' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''UnitsLib.mdp'';' + #13#10 +
  '' + #13#10 +
  'var oz, lbs, f : Real;' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  writeln(''=== Cooking Converter ==='');' + #13#10 +
  '  lbs := StrToFloat(InputBox(''Recipe calls for (lbs):'', ''Cooking'', ''2.5''));' + #13#10 +
  '  writeln(lbs, '' lbs = '', round(LbsToKg(lbs)*100)/100, '' kg'');' + #13#10 +
  '  f := StrToFloat(InputBox(''Oven temp (Fahrenheit):'', ''Cooking'', ''350''));' + #13#10 +
  '  writeln(f, '' F = '', round(FahrenheitToC(f)), '' C (Gas mark ~'', round((FahrenheitToC(f)-121)/14), '')'');' + #13#10 +
  'end.')
]);

// ---------------------------------------------------------------------------
// 9. Logging System — LogLib used by an app
// ---------------------------------------------------------------------------
AddMulti('Logging System', 'Multi-File Projects',
  'LogLib writes timestamped entries to a file — used by any program',
[
  F('LogLib.mdp',
  '// ============================================================' + #13#10 +
  '// LOGLIB.MDP — Reusable logging library' + #13#10 +
  '//' + #13#10 +
  '// Writes timestamped log entries to a file.' + #13#10 +
  '// Any program that imports this gets professional logging.' + #13#10 +
  '//' + #13#10 +
  '// *** NOTE: This is a real pattern used in every serious app.' + #13#10 +
  '//     Logging lets you trace what your program did.' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'var' + #13#10 +
  '  LogFile    : String;    // path to the log file' + #13#10 +
  '  LogEnabled : Boolean;   // can be turned off' + #13#10 +
  '' + #13#10 +
  '// Call this first to set the log file path' + #13#10 +
  'procedure LogInit(fname: String);' + #13#10 +
  'begin' + #13#10 +
  '  LogFile    := fname;' + #13#10 +
  '  LogEnabled := true;' + #13#10 +
  '  AppendFile(LogFile, ''=== Log started ==='');' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Write an INFO entry' + #13#10 +
  'procedure LogInfo(msg: String);' + #13#10 +
  'begin' + #13#10 +
  '  if LogEnabled then' + #13#10 +
  '    AppendFile(LogFile, ''[INFO]    '' + msg);' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Write a WARNING entry' + #13#10 +
  'procedure LogWarn(msg: String);' + #13#10 +
  'begin' + #13#10 +
  '  if LogEnabled then' + #13#10 +
  '    AppendFile(LogFile, ''[WARNING] '' + msg);' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Write an ERROR entry' + #13#10 +
  'procedure LogError(msg: String);' + #13#10 +
  'begin' + #13#10 +
  '  if LogEnabled then' + #13#10 +
  '    AppendFile(LogFile, ''[ERROR]   '' + msg);' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Read and display the whole log' + #13#10 +
  'procedure LogShow;' + #13#10 +
  'begin' + #13#10 +
  '  if FileExists(LogFile) then' + #13#10 +
  '    writeln(ReadFile(LogFile))' + #13#10 +
  '  else' + #13#10 +
  '    writeln(''(log file not found)'');' + #13#10 +
  'end;'),

  F('Main.mdp',
  '// ============================================================' + #13#10 +
  '// MAIN.MDP — A program that uses LogLib for audit logging' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''LogLib.mdp'';' + #13#10 +
  '' + #13#10 +
  'var' + #13#10 +
  '  username : String;' + #13#10 +
  '  action   : String;' + #13#10 +
  '  running  : Boolean;' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  // Initialise logging to a file next to the program' + #13#10 +
  '  LogInit(GetAppPath + ''app.log'');' + #13#10 +
  '  LogInfo(''Application started'');' + #13#10 +
  '' + #13#10 +
  '  username := InputBox(''Username:'', ''Login'', ''admin'');' + #13#10 +
  '  LogInfo(''User logged in: '' + username);' + #13#10 +
  '  writeln(''Welcome, '', username, ''!'');' + #13#10 +
  '' + #13#10 +
  '  running := true;' + #13#10 +
  '  while running do' + #13#10 +
  '  begin' + #13#10 +
  '    action := InputBox(''Action (save/delete/warn/quit):'', ''App'', ''save'');' + #13#10 +
  '    caseof LowerCase(action) of' + #13#10 +
  '      ''save''  : begin LogInfo(''User saved data'');   writeln(''Data saved.''); end;' + #13#10 +
  '      ''delete'': begin LogWarn(''User deleted data''); writeln(''Data deleted.''); end;' + #13#10 +
  '      ''warn''  : begin LogError(''User triggered error''); ShowErrorBox(''Error logged!''); end;' + #13#10 +
  '      ''quit''  : begin LogInfo(''User quit''); running := false; end;' + #13#10 +
  '    else' + #13#10 +
  '      LogWarn(''Unknown action: '' + action);' + #13#10 +
  '    end;' + #13#10 +
  '  end;' + #13#10 +
  '' + #13#10 +
  '  writeln('''');' + #13#10 +
  '  writeln(''=== Session Log ==='');' + #13#10 +
  '  LogShow;' + #13#10 +
  'end.', True)
]);

// ---------------------------------------------------------------------------
// 10. Quiz Engine — QuizLib + a Science Quiz + a Maths Quiz
// ---------------------------------------------------------------------------
AddMulti('Quiz Engine', 'Multi-File Projects',
  'QuizLib runs any quiz — plug in Science or Maths question sets',
[
  F('QuizLib.mdp',
  '// ============================================================' + #13#10 +
  '// QUIZLIB.MDP — Generic quiz engine' + #13#10 +
  '//' + #13#10 +
  '// Provides: ask a question, check answer, keep score.' + #13#10 +
  '// The question CONTENT is defined by the calling program.' + #13#10 +
  '//' + #13#10 +
  '// *** NOTE: Separating the ENGINE from the CONTENT is great design.' + #13#10 +
  '//     One engine, unlimited quiz topics!' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'var' + #13#10 +
  '  QuizScore   : Integer;' + #13#10 +
  '  QuizTotal   : Integer;' + #13#10 +
  '' + #13#10 +
  'procedure QuizInit;' + #13#10 +
  'begin' + #13#10 +
  '  QuizScore := 0;' + #13#10 +
  '  QuizTotal := 0;' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  '// Ask one question. answer is the correct answer (case-insensitive).' + #13#10 +
  'procedure QuizAsk(question, answer: String);' + #13#10 +
  'var given : String;' + #13#10 +
  'begin' + #13#10 +
  '  inc(QuizTotal);' + #13#10 +
  '  given := InputBox(''Q'' + IntToStr(QuizTotal) + '': '' + question,' + #13#10 +
  '                    ''Quiz'', '''');' + #13#10 +
  '  if LowerCase(Trim(given)) = LowerCase(Trim(answer)) then' + #13#10 +
  '  begin' + #13#10 +
  '    inc(QuizScore);' + #13#10 +
  '    writeln(''CORRECT! '', answer);' + #13#10 +
  '  end' + #13#10 +
  '  else' + #13#10 +
  '    writeln(''Wrong. Answer was: '', answer);' + #13#10 +
  'end;' + #13#10 +
  '' + #13#10 +
  'procedure QuizResults(quizName: String);' + #13#10 +
  'var pct : Integer;' + #13#10 +
  'begin' + #13#10 +
  '  pct := round(QuizScore * 100 / QuizTotal);' + #13#10 +
  '  writeln('''');' + #13#10 +
  '  writeln(''=== '', quizName, '' Results ==='');' + #13#10 +
  '  writeln(''Score: '', QuizScore, '' / '', QuizTotal, '' ('', pct, ''%)'');' + #13#10 +
  '  if pct >= 80 then ShowInfoBox(''Excellent! '', pct, ''%!'')' + #13#10 +
  '  else if pct >= 60 then ShowInfoBox(''Good effort: '', pct, ''%'')' + #13#10 +
  '  else ShowInfoBox(''Keep studying! '', pct, ''%'');' + #13#10 +
  'end;'),

  F('ScienceQuiz.mdp',
  '// ============================================================' + #13#10 +
  '// SCIENCEQUIZ.MDP — A science quiz using QuizLib' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''QuizLib.mdp'';' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  QuizInit;' + #13#10 +
  '  ShowMessage(''Science Quiz — 5 questions. Good luck!'');' + #13#10 +
  '  QuizAsk(''What is the chemical symbol for water?'',            ''H2O'');' + #13#10 +
  '  QuizAsk(''How many planets are in our solar system?'',        ''8'');' + #13#10 +
  '  QuizAsk(''What gas do plants absorb from the air?'',          ''carbon dioxide'');' + #13#10 +
  '  QuizAsk(''What force keeps us on the ground?'',               ''gravity'');' + #13#10 +
  '  QuizAsk(''What is the speed of light (km/s, rounded)? '', ''300000'');' + #13#10 +
  '  QuizResults(''Science Quiz'');' + #13#10 +
  'end.', True),

  F('MathsQuiz.mdp',
  '// ============================================================' + #13#10 +
  '// MATHSQUIZ.MDP — A maths quiz using the SAME QuizLib' + #13#10 +
  '//' + #13#10 +
  '// *** NOTE: Same engine (QuizLib), completely different content.' + #13#10 +
  '//     This is the power of reusable libraries!' + #13#10 +
  '// ============================================================' + #13#10 +
  '' + #13#10 +
  'uses' + #13#10 +
  '  ''QuizLib.mdp'';' + #13#10 +
  '' + #13#10 +
  'begin' + #13#10 +
  '  QuizInit;' + #13#10 +
  '  ShowMessage(''Maths Quiz — 5 questions. Good luck!'');' + #13#10 +
  '  QuizAsk(''What is 7 x 8?'',                      ''56'');' + #13#10 +
  '  QuizAsk(''What is the square root of 144?'',     ''12'');' + #13#10 +
  '  QuizAsk(''What is 15% of 200?'',                 ''30'');' + #13#10 +
  '  QuizAsk(''How many sides does a hexagon have?'', ''6'');' + #13#10 +
  '  QuizAsk(''What is 2 to the power of 10?'',      ''1024'');' + #13#10 +
  '  QuizResults(''Maths Quiz'');' + #13#10 +
  'end.')
]);


// ═══════════════════════════════════════════════════════════════════════════
//  DATABASE EXAMPLES
// ═══════════════════════════════════════════════════════════════════════════

Add('SQLite Hello World', 'Database',
  'Create a database, insert records, query them back',
'// ============================================================' + #13#10 +
'// SQLITE HELLO WORLD' + #13#10 +
'// Your first database program!' + #13#10 +
'// Teaches: DbOpen, DbExec, DbQuery, DbClose' + #13#10 +
'//' + #13#10 +
'// REQUIRES: sqlite3.dll in the same folder as MiniDelphi.exe' + #13#10 +
'// Download from: https://sqlite.org/download.html' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  // Open (or create) a database file' + #13#10 +
'  if not DbOpen(GetAppPath + ''hello.db'') then' + #13#10 +
'  begin' + #13#10 +
'    writeln(''Cannot open database: '', DbLastError);' + #13#10 +
'    exit;' + #13#10 +
'  end;' + #13#10 +
'  writeln(''Database opened: '', DbFilename);' + #13#10 +
'' + #13#10 +
'  // Create a table (IF NOT EXISTS means it is safe to run again)' + #13#10 +
'  DbExec(''CREATE TABLE IF NOT EXISTS people ('' +' + #13#10 +
'         ''  id   INTEGER PRIMARY KEY AUTOINCREMENT,'' +' + #13#10 +
'         ''  name TEXT NOT NULL,'' +' + #13#10 +
'         ''  age  INTEGER'');' + #13#10 +
'' + #13#10 +
'  // Clear old data so we start fresh each run' + #13#10 +
'  DbExec(''DELETE FROM people'');' + #13#10 +
'' + #13#10 +
'  // Insert some records' + #13#10 +
'  DbExec(''INSERT INTO people (name, age) VALUES (''''Alice'''', 30)'');' + #13#10 +
'  DbExec(''INSERT INTO people (name, age) VALUES (''''Bob'''',   25)'');' + #13#10 +
'  DbExec(''INSERT INTO people (name, age) VALUES (''''Carol'''', 35)'');' + #13#10 +
'  writeln(''3 records inserted.'');' + #13#10 +
'' + #13#10 +
'  // Query all records' + #13#10 +
'  writeln('''');' + #13#10 +
'  writeln(''All people:'');' + #13#10 +
'  writeln(DbQuery(''SELECT * FROM people ORDER BY name''));' + #13#10 +
'' + #13#10 +
'  // Query with a condition' + #13#10 +
'  writeln(''People over 28:'');' + #13#10 +
'  writeln(DbQuery(''SELECT name, age FROM people WHERE age > 28''));' + #13#10 +
'' + #13#10 +
'  // Get a single value' + #13#10 +
'  writeln(''Count: '', DbQueryValue(''SELECT COUNT(*) FROM people''));' + #13#10 +
'  writeln(''Oldest: '', DbQueryValue(''SELECT MAX(age) FROM people''));' + #13#10 +
'' + #13#10 +
'  DbClose;' + #13#10 +
'  writeln(''Done.'');' + #13#10 +
'end.');

Add('Phone Book Database', 'Database',
  'A persistent phone book stored in SQLite',
'// ============================================================' + #13#10 +
'// PHONE BOOK DATABASE' + #13#10 +
'// Contacts stored in SQLite — survive between runs!' + #13#10 +
'// Teaches: INSERT, SELECT, DELETE, WHERE, LIKE search' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  choice  : String;' + #13#10 +
'  name    : String;' + #13#10 +
'  phone   : String;' + #13#10 +
'  search  : String;' + #13#10 +
'  running : Boolean;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  if not DbOpen(GetAppPath + ''phonebook.db'') then' + #13#10 +
'  begin' + #13#10 +
'    ShowErrorBox(''Cannot open database: '' + DbLastError);' + #13#10 +
'    exit;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  DbExec(''CREATE TABLE IF NOT EXISTS contacts ('' +' + #13#10 +
'         ''  id    INTEGER PRIMARY KEY AUTOINCREMENT,'' +' + #13#10 +
'         ''  name  TEXT NOT NULL,'' +' + #13#10 +
'         ''  phone TEXT)'');' + #13#10 +
'' + #13#10 +
'  running := true;' + #13#10 +
'  while running do' + #13#10 +
'  begin' + #13#10 +
'    choice := InputBox(''A=Add  S=Search  L=List  D=Delete  Q=Quit'',' + #13#10 +
'                       ''Phone Book'', ''L'');' + #13#10 +
'    caseof UpperCase(choice) of' + #13#10 +
'      ''A'':' + #13#10 +
'      begin' + #13#10 +
'        name  := InputBox(''Name:'',  ''Add Contact'', '''');' + #13#10 +
'        phone := InputBox(''Phone:'', ''Add Contact'', '''');' + #13#10 +
'        if name <> '''' then' + #13#10 +
'        begin' + #13#10 +
'          // *** NOTE: Use double quotes inside SQL strings' + #13#10 +
'          DbExec(''INSERT INTO contacts (name, phone) VALUES ('''''' + name + '''''', '''''' + phone + '''''')'');' + #13#10 +
'          writeln(''Added: '', name);' + #13#10 +
'        end;' + #13#10 +
'      end;' + #13#10 +
'      ''S'':' + #13#10 +
'      begin' + #13#10 +
'        search := InputBox(''Search name:'', ''Search'', '''');' + #13#10 +
'        // LIKE with % is a wildcard search' + #13#10 +
'        writeln(DbQuery(''SELECT name, phone FROM contacts WHERE name LIKE ''''%'' + search + ''%''''''));' + #13#10 +
'      end;' + #13#10 +
'      ''L'': writeln(DbQuery(''SELECT id, name, phone FROM contacts ORDER BY name''));' + #13#10 +
'      ''D'':' + #13#10 +
'      begin' + #13#10 +
'        name := InputBox(''Delete name:'', ''Delete'', '''');' + #13#10 +
'        if Confirm(''Delete '' + name + ''?'') then' + #13#10 +
'        begin' + #13#10 +
'          DbExec(''DELETE FROM contacts WHERE name = '''''' + name + '''''''' );' + #13#10 +
'          writeln(''Deleted: '', name);' + #13#10 +
'        end;' + #13#10 +
'      end;' + #13#10 +
'      ''Q'': running := false;' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'  DbClose;' + #13#10 +
'end.');

Add('Grade Book Database', 'Database',
  'Store student grades in SQLite with averages and statistics',
'// ============================================================' + #13#10 +
'// GRADE BOOK DATABASE' + #13#10 +
'// Student grades stored in SQLite with SQL aggregates.' + #13#10 +
'// Teaches: GROUP BY, AVG, MAX, MIN, aggregate functions' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  student : String;' + #13#10 +
'  subject : String;' + #13#10 +
'  score   : String;' + #13#10 +
'  adding  : Boolean;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  DbOpen(GetAppPath + ''grades.db'');' + #13#10 +
'  DbExec(''CREATE TABLE IF NOT EXISTS grades ('' +' + #13#10 +
'         ''  student TEXT, subject TEXT, score REAL)'');' + #13#10 +
'  DbExec(''DELETE FROM grades'');' + #13#10 +
'' + #13#10 +
'  // Pre-load some sample data' + #13#10 +
'  DbExec(''INSERT INTO grades VALUES (''''Alice'''',   ''''Maths'''',   92)'');' + #13#10 +
'  DbExec(''INSERT INTO grades VALUES (''''Alice'''',   ''''Science'''', 88)'');' + #13#10 +
'  DbExec(''INSERT INTO grades VALUES (''''Bob'''',     ''''Maths'''',   75)'');' + #13#10 +
'  DbExec(''INSERT INTO grades VALUES (''''Bob'''',     ''''Science'''', 82)'');' + #13#10 +
'  DbExec(''INSERT INTO grades VALUES (''''Carol'''',   ''''Maths'''',   95)'');' + #13#10 +
'  DbExec(''INSERT INTO grades VALUES (''''Carol'''',   ''''Science'''', 91)'');' + #13#10 +
'' + #13#10 +
'  writeln(''=== All Grades ==='');' + #13#10 +
'  writeln(DbQuery(''SELECT student, subject, score FROM grades ORDER BY student, subject''));' + #13#10 +
'' + #13#10 +
'  writeln(''=== Average per Student ==='');' + #13#10 +
'  // GROUP BY lets us summarise — one row per student' + #13#10 +
'  writeln(DbQuery(''SELECT student, AVG(score) as average, '' +' + #13#10 +
'                  ''MIN(score) as lowest, MAX(score) as highest '' +' + #13#10 +
'                  ''FROM grades GROUP BY student ORDER BY average DESC''));' + #13#10 +
'' + #13#10 +
'  writeln(''=== Class Statistics ==='');' + #13#10 +
'  writeln(''Class average: '', DbQueryValue(''SELECT AVG(score) FROM grades''));' + #13#10 +
'  writeln(''Top score:     '', DbQueryValue(''SELECT MAX(score) FROM grades''));' + #13#10 +
'' + #13#10 +
'  DbClose;' + #13#10 +
'end.');

// ═══════════════════════════════════════════════════════════════════════════
//  OOP EXAMPLES
// ═══════════════════════════════════════════════════════════════════════════

Add('OOP Hello World', 'Object Oriented',
  'Your first class — TGreeter with a field and a method',
'// ============================================================' + #13#10 +
'// OOP HELLO WORLD' + #13#10 +
'// The simplest possible class: one field, one method.' + #13#10 +
'// Teaches: type, class, fields, methods, Create, dot notation' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'type' + #13#10 +
'  // Define a class called TGreeter.' + #13#10 +
'  // By convention Delphi class names start with T.' + #13#10 +
'  TGreeter = class' + #13#10 +
'    // A field — this is data the object holds' + #13#10 +
'    Name : String;' + #13#10 +
'' + #13#10 +
'    // A method — this is something the object can DO' + #13#10 +
'    procedure SayHello;' + #13#10 +
'    procedure SayGoodbye;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'// Method implementations come after the type block.' + #13#10 +
'// *** NOTE: Use ClassName.MethodName format.' + #13#10 +
'procedure TGreeter.SayHello;' + #13#10 +
'begin' + #13#10 +
'  // Self refers to the object this method was called on' + #13#10 +
'  writeln(''Hello! My name is '', Self.Name, ''.'');' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'procedure TGreeter.SayGoodbye;' + #13#10 +
'begin' + #13#10 +
'  writeln(''Goodbye from '', Self.Name, ''!'');' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  g1, g2 : TGreeter;   // two variables that will hold objects' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  // Create two independent TGreeter objects' + #13#10 +
'  g1 := TGreeter.Create;' + #13#10 +
'  g2 := TGreeter.Create;' + #13#10 +
'' + #13#10 +
'  // Set each object''s Name field independently' + #13#10 +
'  g1.Name := ''Alice'';' + #13#10 +
'  g2.Name := ''Bob'';' + #13#10 +
'' + #13#10 +
'  // Call methods on each object using dot notation' + #13#10 +
'  g1.SayHello;' + #13#10 +
'  g2.SayHello;' + #13#10 +
'  g1.SayGoodbye;' + #13#10 +
'  writeln(''g1.Name = '', g1.Name);' + #13#10 +
'  writeln(''g2.Name = '', g2.Name);' + #13#10 +
'end.');

Add('Inheritance Demo', 'Object Oriented',
  'TAnimal → TDog and TCat — virtual methods and polymorphism',
'// ============================================================' + #13#10 +
'// INHERITANCE DEMO' + #13#10 +
'// TAnimal is the base class. TDog and TCat extend it.' + #13#10 +
'// Teaches: class(Parent), virtual, override, polymorphism' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'type' + #13#10 +
'  // Base class — all animals have a Name and can Speak' + #13#10 +
'  TAnimal = class' + #13#10 +
'    Name : String;' + #13#10 +
'    // virtual means subclasses CAN override this method' + #13#10 +
'    procedure Speak; virtual;' + #13#10 +
'    procedure Describe;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  // TDog extends TAnimal — it INHERITS Name and Describe' + #13#10 +
'  TDog = class(TAnimal)' + #13#10 +
'    Breed : String;' + #13#10 +
'    // override means we are replacing the parent''s version' + #13#10 +
'    procedure Speak; override;' + #13#10 +
'    procedure Fetch;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  TCat = class(TAnimal)' + #13#10 +
'    Indoor : Boolean;' + #13#10 +
'    procedure Speak; override;' + #13#10 +
'    procedure Purr;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'// Base class method implementations' + #13#10 +
'procedure TAnimal.Speak;' + #13#10 +
'begin' + #13#10 +
'  writeln(Self.Name, '' says: ...'');   // default — subclasses override this' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'procedure TAnimal.Describe;' + #13#10 +
'begin' + #13#10 +
'  write(Self.Name, '' is a '', Self.ClassName, '' and says: '');' + #13#10 +
'  Self.Speak;   // *** NOTE: This calls the OVERRIDDEN version!' + #13#10 +
'                // This is POLYMORPHISM — the behaviour depends on' + #13#10 +
'                // the actual type of Self at runtime.' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'// Dog implementations' + #13#10 +
'procedure TDog.Speak;' + #13#10 +
'begin' + #13#10 +
'  writeln(''Woof! Woof!'');' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'procedure TDog.Fetch;' + #13#10 +
'begin' + #13#10 +
'  writeln(Self.Name, '' fetches the ball!'');' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'// Cat implementations' + #13#10 +
'procedure TCat.Speak;' + #13#10 +
'begin' + #13#10 +
'  writeln(''Meow!'');' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'procedure TCat.Purr;' + #13#10 +
'begin' + #13#10 +
'  writeln(Self.Name, '' purrs contentedly...'');' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  dog : TDog;' + #13#10 +
'  cat : TCat;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  dog       := TDog.Create;' + #13#10 +
'  dog.Name  := ''Rex'';' + #13#10 +
'  dog.Breed := ''Labrador'';' + #13#10 +
'' + #13#10 +
'  cat        := TCat.Create;' + #13#10 +
'  cat.Name   := ''Whiskers'';' + #13#10 +
'  cat.Indoor := true;' + #13#10 +
'' + #13#10 +
'  writeln(''=== Animal Demo ==='');' + #13#10 +
'  dog.Describe;   // calls TDog.Speak via polymorphism' + #13#10 +
'  cat.Describe;   // calls TCat.Speak via polymorphism' + #13#10 +
'  dog.Fetch;' + #13#10 +
'  cat.Purr;' + #13#10 +
'  writeln(''Dog breed: '', dog.Breed);' + #13#10 +
'  writeln(''Cat indoor: '', cat.Indoor);' + #13#10 +
'end.');

Add('Interface Demo', 'Object Oriented',
  'IShape interface implemented by TCircle and TRectangle',
'// ============================================================' + #13#10 +
'// INTERFACE DEMO' + #13#10 +
'// An interface defines a CONTRACT — any class that implements' + #13#10 +
'// it MUST provide those methods.' + #13#10 +
'// Teaches: interface, implements, polymorphism via interface' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'type' + #13#10 +
'  // The interface — a contract with no implementation' + #13#10 +
'  IShape = interface' + #13#10 +
'    function  Area      : Real;' + #13#10 +
'    function  Perimeter : Real;' + #13#10 +
'    function  ShapeName : String;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  // TCircle PROMISES to implement IShape' + #13#10 +
'  TCircle = class(TObject, IShape)' + #13#10 +
'    Radius : Real;' + #13#10 +
'    function  Area      : Real;' + #13#10 +
'    function  Perimeter : Real;' + #13#10 +
'    function  ShapeName : String;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  TRectangle = class(TObject, IShape)' + #13#10 +
'    Width, Height : Real;' + #13#10 +
'    function  Area      : Real;' + #13#10 +
'    function  Perimeter : Real;' + #13#10 +
'    function  ShapeName : String;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'function TCircle.Area;      begin Result := pi * Self.Radius * Self.Radius; end;' + #13#10 +
'function TCircle.Perimeter; begin Result := 2 * pi * Self.Radius;           end;' + #13#10 +
'function TCircle.ShapeName; begin Result := ''Circle'';                       end;' + #13#10 +
'' + #13#10 +
'function TRectangle.Area;      begin Result := Self.Width * Self.Height;          end;' + #13#10 +
'function TRectangle.Perimeter; begin Result := 2 * (Self.Width + Self.Height);    end;' + #13#10 +
'function TRectangle.ShapeName; begin Result := ''Rectangle'';                       end;' + #13#10 +
'' + #13#10 +
'// This procedure works with ANY IShape — it doesn''t care about the type' + #13#10 +
'procedure PrintShapeInfo(s: TObject);' + #13#10 +
'begin' + #13#10 +
'  // *** NOTE: We check the interface using "is"' + #13#10 +
'  if s is IShape then' + #13#10 +
'    writeln(''Unknown shape — does not implement IShape'')' + #13#10 +
'  else' + #13#10 +
'  begin' + #13#10 +
'    // Call methods based on the class type' + #13#10 +
'    if s is TCircle then' + #13#10 +
'    begin' + #13#10 +
'      var c := TCircle(s);' + #13#10 +
'      writeln(c.ShapeName, '': area='', round(c.Area*100)/100,' + #13#10 +
'              '' perim='', round(c.Perimeter*100)/100);' + #13#10 +
'    end' + #13#10 +
'    else if s is TRectangle then' + #13#10 +
'    begin' + #13#10 +
'      var r := TRectangle(s);' + #13#10 +
'      writeln(r.ShapeName, '': area='', round(r.Area*100)/100,' + #13#10 +
'              '' perim='', round(r.Perimeter*100)/100);' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  c : TCircle;' + #13#10 +
'  r : TRectangle;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  c        := TCircle.Create;' + #13#10 +
'  c.Radius := 5;' + #13#10 +
'' + #13#10 +
'  r        := TRectangle.Create;' + #13#10 +
'  r.Width  := 8;' + #13#10 +
'  r.Height := 3;' + #13#10 +
'' + #13#10 +
'  writeln(''=== Shape Report ==='');' + #13#10 +
'  PrintShapeInfo(c);' + #13#10 +
'  PrintShapeInfo(r);' + #13#10 +
'end.');

Add('Constructor & Destructor', 'Object Oriented',
  'Show how constructors initialise objects properly',
'// ============================================================' + #13#10 +
'// CONSTRUCTOR AND DESTRUCTOR' + #13#10 +
'// Constructors run when an object is created.' + #13#10 +
'// Destructors run when it is destroyed.' + #13#10 +
'// Teaches: constructor, destructor, object lifecycle' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'type' + #13#10 +
'  TBankAccount = class' + #13#10 +
'    Owner   : String;' + #13#10 +
'    Balance : Real;' + #13#10 +
'' + #13#10 +
'    // Constructor takes parameters to initialise the object' + #13#10 +
'    constructor Create(ownerName: String; initialBalance: Real);' + #13#10 +
'    destructor  Destroy;' + #13#10 +
'' + #13#10 +
'    procedure Deposit(amount: Real);' + #13#10 +
'    procedure Withdraw(amount: Real);' + #13#10 +
'    procedure ShowBalance;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'constructor TBankAccount.Create(ownerName: String; initialBalance: Real);' + #13#10 +
'begin' + #13#10 +
'  // *** NOTE: The constructor sets up the object''s initial state' + #13#10 +
'  Self.Owner   := ownerName;' + #13#10 +
'  Self.Balance := initialBalance;' + #13#10 +
'  writeln(''Account created for '', Self.Owner,' + #13#10 +
'          '' with $'', initialBalance);' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'destructor TBankAccount.Destroy;' + #13#10 +
'begin' + #13#10 +
'  writeln(''Account for '', Self.Owner, '' closed. Final balance: $'', Self.Balance);' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'procedure TBankAccount.Deposit(amount: Real);' + #13#10 +
'begin' + #13#10 +
'  Self.Balance := Self.Balance + amount;' + #13#10 +
'  writeln(''Deposited $'', amount, ''. New balance: $'', Self.Balance);' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'procedure TBankAccount.Withdraw(amount: Real);' + #13#10 +
'begin' + #13#10 +
'  if amount > Self.Balance then' + #13#10 +
'    writeln(''Insufficient funds!'')' + #13#10 +
'  else' + #13#10 +
'  begin' + #13#10 +
'    Self.Balance := Self.Balance - amount;' + #13#10 +
'    writeln(''Withdrew $'', amount, ''. New balance: $'', Self.Balance);' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'procedure TBankAccount.ShowBalance;' + #13#10 +
'begin' + #13#10 +
'  writeln(Self.Owner, '' balance: $'', Self.Balance);' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  acc : TBankAccount;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  writeln(''=== Bank Account Demo ==='');' + #13#10 +
'  acc := TBankAccount.Create(''Alice'', 1000);' + #13#10 +
'  acc.Deposit(500);' + #13#10 +
'  acc.Withdraw(200);' + #13#10 +
'  acc.Withdraw(2000);   // should fail' + #13#10 +
'  acc.ShowBalance;' + #13#10 +
'  acc.Destroy;' + #13#10 +
'end.');



// ═══════════════════════════════════════════════════════════════════════════
//  GRAPHICS & ANIMATION EXAMPLES
// ═══════════════════════════════════════════════════════════════════════════

Add('Bouncing Ball', 'Graphics',
  'A glowing ball bouncing around the window with trail effect',
'// ============================================================' + #13#10 +
'// BOUNCING BALL' + #13#10 +
'// A colourful ball bounces around the window.' + #13#10 +
'// Close the window to stop.' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  x, y, dx, dy, r : Integer;' + #13#10 +
'  colors : String;' + #13#10 +
'  ci, frame : Integer;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  GfxOpen(640, 480, ''Bouncing Ball'');' + #13#10 +
'' + #13#10 +
'  x  := 320;  y  := 240;' + #13#10 +
'  dx := 5;    dy := 3;' + #13#10 +
'  r  := 30;' + #13#10 +
'  ci := 0;' + #13#10 +
'  frame := 0;' + #13#10 +
'' + #13#10 +
'  while GfxRunning do' + #13#10 +
'  begin' + #13#10 +
'    // Clear with dark background' + #13#10 +
'    GfxClear(''black'');' + #13#10 +
'' + #13#10 +
'    // Draw shadow' + #13#10 +
'    GfxColor(''#202020'');' + #13#10 +
'    GfxFillEllipse(x + 8, y + 8, r, r div 3);' + #13#10 +
'' + #13#10 +
'    // Pick colour based on frame' + #13#10 +
'    ci := (frame div 8) mod 7;' + #13#10 +
'    case ci of' + #13#10 +
'      0 : GfxColor(''red'');' + #13#10 +
'      1 : GfxColor(''orange'');' + #13#10 +
'      2 : GfxColor(''yellow'');' + #13#10 +
'      3 : GfxColor(''lime'');' + #13#10 +
'      4 : GfxColor(''cyan'');' + #13#10 +
'      5 : GfxColor(''blue'');' + #13#10 +
'      6 : GfxColor(''magenta'');' + #13#10 +
'    end;' + #13#10 +
'' + #13#10 +
'    // Draw glowing ball (concentric circles)' + #13#10 +
'    GfxFillCircle(x, y, r);' + #13#10 +
'    GfxColor(''white'');' + #13#10 +
'    GfxFillCircle(x - r div 4, y - r div 4, r div 5);' + #13#10 +
'' + #13#10 +
'    // Score / frame counter' + #13#10 +
'    GfxColor(''silver'');' + #13#10 +
'    GfxSetFont(14, false);' + #13#10 +
'    GfxDrawText(10, 10, ''Frame: '' + IntToStr(frame));' + #13#10 +
'    GfxDrawText(10, 30, ''Close window to stop'');' + #13#10 +
'' + #13#10 +
'    GfxShow;' + #13#10 +
'    GfxDelay(16);' + #13#10 +
'' + #13#10 +
'    // Move ball' + #13#10 +
'    x := x + dx;' + #13#10 +
'    y := y + dy;' + #13#10 +
'' + #13#10 +
'    // Bounce off walls' + #13#10 +
'    if (x - r < 0) or (x + r > 640) then dx := -dx;' + #13#10 +
'    if (y - r < 0) or (y + r > 480) then dy := -dy;' + #13#10 +
'' + #13#10 +
'    // Keep in bounds' + #13#10 +
'    if x - r < 0 then x := r;' + #13#10 +
'    if x + r > 640 then x := 640 - r;' + #13#10 +
'    if y - r < 0 then y := r;' + #13#10 +
'    if y + r > 480 then y := 480 - r;' + #13#10 +
'' + #13#10 +
'    inc(frame);' + #13#10 +
'  end;' + #13#10 +
'  writeln(''Simulation ran for '', frame, '' frames.'');' + #13#10 +
'end.');

Add('Starfield', 'Graphics',
  'Classic screensaver: stars flying towards you through space',
'// ============================================================' + #13#10 +
'// STARFIELD SCREENSAVER' + #13#10 +
'// Stars fly towards you — a classic screensaver effect.' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  i, frame : Integer;' + #13#10 +
'  cx, cy   : Integer;' + #13#10 +
'  // Each star: sx[i]=x  sy[i]=y  sz[i]=depth' + #13#10 +
'  sx1, sy1, sz1 : Integer;' + #13#10 +
'  sx2, sy2, sz2 : Integer;' + #13#10 +
'  sx3, sy3, sz3 : Integer;' + #13#10 +
'  sx4, sy4, sz4 : Integer;' + #13#10 +
'  sx5, sy5, sz5 : Integer;' + #13#10 +
'  px, py, br     : Integer;' + #13#10 +
'' + #13#10 +
'procedure DrawStar(var sx, sy, sz: Integer; cx, cy: Integer);' + #13#10 +
'var px, py, br, size : Integer;' + #13#10 +
'begin' + #13#10 +
'  // Project 3D -> 2D' + #13#10 +
'  if sz <= 0 then sz := 1;' + #13#10 +
'  px := cx + (sx * 400) div sz;' + #13#10 +
'  py := cy + (sy * 400) div sz;' + #13#10 +
'  br := 255 - (sz * 255) div 800;' + #13#10 +
'  size := 1 + (800 - sz) div 200;' + #13#10 +
'' + #13#10 +
'  if (px > 0) and (px < 640) and (py > 0) and (py < 480) then' + #13#10 +
'  begin' + #13#10 +
'    if br > 200 then GfxColor(''white'')' + #13#10 +
'    else if br > 100 then GfxColor(''silver'')' + #13#10 +
'    else GfxColor(''grey'');' + #13#10 +
'    GfxFillCircle(px, py, size);' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  // Move star closer' + #13#10 +
'  sz := sz - 8;' + #13#10 +
'  if sz <= 0 then' + #13#10 +
'  begin' + #13#10 +
'    sz := 700 + (sz mod 100);' + #13#10 +
'    sx := (sz mod 400) - 200;' + #13#10 +
'    sy := (sz mod 300) - 150;' + #13#10 +
'  end;' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  GfxOpen(640, 480, ''Starfield'');' + #13#10 +
'  cx := 320;  cy := 240;' + #13#10 +
'  sx1 := -100; sy1 := 80;  sz1 := 100;' + #13#10 +
'  sx2 :=  150; sy2 := -60; sz2 := 250;' + #13#10 +
'  sx3 :=  -50; sy3 := 130; sz3 := 400;' + #13#10 +
'  sx4 :=  200; sy4 := -90; sz4 := 550;' + #13#10 +
'  sx5 := -180; sy5 :=  40; sz5 := 650;' + #13#10 +
'  frame := 0;' + #13#10 +
'' + #13#10 +
'  while GfxRunning do' + #13#10 +
'  begin' + #13#10 +
'    GfxClear(''black'');' + #13#10 +
'    DrawStar(sx1, sy1, sz1, cx, cy);' + #13#10 +
'    DrawStar(sx2, sy2, sz2, cx, cy);' + #13#10 +
'    DrawStar(sx3, sy3, sz3, cx, cy);' + #13#10 +
'    DrawStar(sx4, sy4, sz4, cx, cy);' + #13#10 +
'    DrawStar(sx5, sy5, sz5, cx, cy);' + #13#10 +
'' + #13#10 +
'    GfxColor(''gold'');' + #13#10 +
'    GfxSetFont(16, true);' + #13#10 +
'    GfxDrawText(10, 10, ''STARFIELD'');' + #13#10 +
'    GfxShow;' + #13#10 +
'    GfxDelay(20);' + #13#10 +
'    inc(frame);' + #13#10 +
'  end;' + #13#10 +
'end.');

Add('Solar System', 'Graphics',
  'Animated solar system with planets orbiting the sun',
'// ============================================================' + #13#10 +
'// SOLAR SYSTEM ANIMATION' + #13#10 +
'// Planets orbit the sun. Uses trigonometry for circular motion.' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  frame, cx, cy : Integer;' + #13#10 +
'  angle1, angle2, angle3 : Real;' + #13#10 +
'  px, py : Integer;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  GfxOpen(640, 480, ''Solar System'');' + #13#10 +
'  cx := 320;  cy := 240;' + #13#10 +
'  angle1 := 0;  angle2 := 0;  angle3 := 0;' + #13#10 +
'  frame := 0;' + #13#10 +
'' + #13#10 +
'  while GfxRunning do' + #13#10 +
'  begin' + #13#10 +
'    GfxClear(''black'');' + #13#10 +
'' + #13#10 +
'    // Draw orbit rings' + #13#10 +
'    GfxColor(''#202020'');' + #13#10 +
'    GfxDrawCircle(cx, cy, 80);' + #13#10 +
'    GfxDrawCircle(cx, cy, 140);' + #13#10 +
'    GfxDrawCircle(cx, cy, 200);' + #13#10 +
'' + #13#10 +
'    // Sun' + #13#10 +
'    GfxColor(''gold'');' + #13#10 +
'    GfxFillCircle(cx, cy, 30);' + #13#10 +
'    GfxColor(''yellow'');' + #13#10 +
'    GfxFillCircle(cx - 8, cy - 8, 10);' + #13#10 +
'' + #13#10 +
'    // Mercury (fast, small, grey)' + #13#10 +
'    px := cx + round(80 * cos(angle1));' + #13#10 +
'    py := cy + round(80 * sin(angle1));' + #13#10 +
'    GfxColor(''grey'');' + #13#10 +
'    GfxFillCircle(px, py, 6);' + #13#10 +
'' + #13#10 +
'    // Earth (medium, blue)' + #13#10 +
'    px := cx + round(140 * cos(angle2));' + #13#10 +
'    py := cy + round(140 * sin(angle2));' + #13#10 +
'    GfxColor(''blue'');' + #13#10 +
'    GfxFillCircle(px, py, 10);' + #13#10 +
'    GfxColor(''lime'');' + #13#10 +
'    GfxFillCircle(px + 2, py - 2, 4);' + #13#10 +
'' + #13#10 +
'    // Mars (slower, red)' + #13#10 +
'    px := cx + round(200 * cos(angle3));' + #13#10 +
'    py := cy + round(200 * sin(angle3));' + #13#10 +
'    GfxColor(''red'');' + #13#10 +
'    GfxFillCircle(px, py, 8);' + #13#10 +
'' + #13#10 +
'    // Labels' + #13#10 +
'    GfxColor(''silver'');' + #13#10 +
'    GfxSetFont(12, false);' + #13#10 +
'    GfxDrawText(10, 10, ''SOLAR SYSTEM'');' + #13#10 +
'    GfxDrawText(10, 28, ''Mercury / Earth / Mars'');' + #13#10 +
'' + #13#10 +
'    GfxShow;' + #13#10 +
'    GfxDelay(16);' + #13#10 +
'' + #13#10 +
'    // Advance angles (different speeds)' + #13#10 +
'    angle1 := angle1 + 0.06;' + #13#10 +
'    angle2 := angle2 + 0.03;' + #13#10 +
'    angle3 := angle3 + 0.018;' + #13#10 +
'    inc(frame);' + #13#10 +
'  end;' + #13#10 +
'end.');

Add('Gorilla Game', 'Graphics',
  'Gorillas-style artillery game — two players throw bananas',
'// ============================================================' + #13#10 +
'// GORILLA GAME' + #13#10 +
'// Two gorillas throw bananas across the city skyline.' + #13#10 +
'// Enter angle and speed. Hit the other gorilla to win!' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  g1x, g1y, g2x, g2y : Integer;' + #13#10 +
'  player, round_no    : Integer;' + #13#10 +
'  score1, score2      : Integer;' + #13#10 +
'  playing             : Boolean;' + #13#10 +
'  angle, speed        : Real;' + #13#10 +
'  bx, by, vx, vy      : Real;' + #13#10 +
'  t, gravity          : Real;' + #13#10 +
'  step                : Integer;' + #13#10 +
'  hit                 : Boolean;' + #13#10 +
'  ang_str, spd_str    : String;' + #13#10 +
'  i                   : Integer;' + #13#10 +
'' + #13#10 +
'procedure DrawScene;' + #13#10 +
'var bh : Integer;' + #13#10 +
'begin' + #13#10 +
'  GfxClear(''#1a1a2e'');' + #13#10 +
'' + #13#10 +
'  // Stars' + #13#10 +
'  GfxColor(''white'');' + #13#10 +
'  GfxFillCircle(50,  30, 1);  GfxFillCircle(150, 20, 1);' + #13#10 +
'  GfxFillCircle(300, 40, 1);  GfxFillCircle(450, 15, 1);' + #13#10 +
'  GfxFillCircle(550, 35, 1);  GfxFillCircle(600, 60, 1);' + #13#10 +
'' + #13#10 +
'  // Moon' + #13#10 +
'  GfxColor(''gold'');' + #13#10 +
'  GfxFillCircle(580, 50, 20);' + #13#10 +
'  GfxColor(''#1a1a2e'');' + #13#10 +
'  GfxFillCircle(570, 42, 16);' + #13#10 +
'' + #13#10 +
'  // Buildings' + #13#10 +
'  GfxColor(''#2d2d5a'');' + #13#10 +
'  GfxFillRect(10,  310, 60, 170);  // building 1' + #13#10 +
'  GfxFillRect(80,  280, 50, 200);  // building 2' + #13#10 +
'  GfxFillRect(140, 320, 70, 160);  // building 3' + #13#10 +
'  GfxFillRect(230, 290, 55, 190);  // building 4' + #13#10 +
'  GfxFillRect(300, 300, 65, 180);  // building 5' + #13#10 +
'  GfxFillRect(380, 270, 50, 210);  // building 6' + #13#10 +
'  GfxFillRect(440, 310, 60, 170);  // building 7' + #13#10 +
'  GfxFillRect(510, 285, 55, 195);  // building 8' + #13#10 +
'  GfxFillRect(575, 300, 55, 180);  // building 9' + #13#10 +
'' + #13#10 +
'  // Building windows' + #13#10 +
'  GfxColor(''gold'');' + #13#10 +
'  GfxFillRect(20, 320, 10, 8);   GfxFillRect(40, 320, 10, 8);' + #13#10 +
'  GfxFillRect(20, 340, 10, 8);   GfxFillRect(40, 340, 10, 8);' + #13#10 +
'  GfxFillRect(90, 295, 10, 8);   GfxFillRect(110, 295, 10, 8);' + #13#10 +
'  GfxFillRect(90, 315, 10, 8);   GfxFillRect(110, 315, 10, 8);' + #13#10 +
'' + #13#10 +
'  // Ground' + #13#10 +
'  GfxColor(''#1a4a1a'');' + #13#10 +
'  GfxFillRect(0, 460, 640, 20);' + #13#10 +
'' + #13#10 +
'  // Gorilla 1 (left, player 1)' + #13#10 +
'  GfxColor(''#8B4513'');' + #13#10 +
'  GfxFillRect(g1x - 15, g1y - 30, 30, 30);  // body' + #13#10 +
'  GfxFillCircle(g1x, g1y - 35, 12);          // head' + #13#10 +
'  GfxColor(''black'');' + #13#10 +
'  GfxFillCircle(g1x - 4, g1y - 37, 3);      // left eye' + #13#10 +
'  GfxFillCircle(g1x + 4, g1y - 37, 3);      // right eye' + #13#10 +
'' + #13#10 +
'  // Gorilla 2 (right, player 2)' + #13#10 +
'  GfxColor(''#8B4513'');' + #13#10 +
'  GfxFillRect(g2x - 15, g2y - 30, 30, 30);  // body' + #13#10 +
'  GfxFillCircle(g2x, g2y - 35, 12);          // head' + #13#10 +
'  GfxColor(''black'');' + #13#10 +
'  GfxFillCircle(g2x - 4, g2y - 37, 3);' + #13#10 +
'  GfxFillCircle(g2x + 4, g2y - 37, 3);' + #13#10 +
'' + #13#10 +
'  // Scores and current player' + #13#10 +
'  GfxColor(''white'');' + #13#10 +
'  GfxSetFont(14, true);' + #13#10 +
'  GfxDrawText(10,  10, ''P1: '' + IntToStr(score1));' + #13#10 +
'  GfxDrawText(560, 10, ''P2: '' + IntToStr(score2));' + #13#10 +
'  GfxColor(''yellow'');' + #13#10 +
'  if player = 1 then GfxDrawText(250, 10, ''< PLAYER 1'')' + #13#10 +
'  else GfxDrawText(270, 10, ''PLAYER 2 >'');' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'function InRange(v, lo, hi: Integer): Boolean;' + #13#10 +
'begin' + #13#10 +
'  Result := (v >= lo) and (v <= hi);' + #13#10 +
'end;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  GfxOpen(640, 480, ''Gorilla Game'');' + #13#10 +
'' + #13#10 +
'  g1x := 65;    g1y := 308;' + #13#10 +
'  g2x := 570;   g2y := 298;' + #13#10 +
'  score1 := 0;  score2 := 0;' + #13#10 +
'  player := 1;  round_no := 1;' + #13#10 +
'  playing := true;' + #13#10 +
'  gravity := 0.4;' + #13#10 +
'' + #13#10 +
'  DrawScene;  GfxShow;' + #13#10 +
'' + #13#10 +
'  while playing and GfxRunning do' + #13#10 +
'  begin' + #13#10 +
'    // Get throw angle and speed from player' + #13#10 +
'    if player = 1 then' + #13#10 +
'      ang_str := InputBox(''Player 1 - Angle (0-90):'', ''Gorilla'', ''45'')' + #13#10 +
'    else' + #13#10 +
'      ang_str := InputBox(''Player 2 - Angle (90-180):'', ''Gorilla'', ''135'');' + #13#10 +
'' + #13#10 +
'    if not GfxRunning then exit;' + #13#10 +
'' + #13#10 +
'    spd_str := InputBox(''Throw speed (1-100):'', ''Gorilla'', ''50'');' + #13#10 +
'' + #13#10 +
'    angle := StrToFloat(ang_str) * 3.14159 / 180;' + #13#10 +
'    speed := StrToFloat(spd_str) / 5;' + #13#10 +
'' + #13#10 +
'    // Launch banana from gorilla position' + #13#10 +
'    if player = 1 then' + #13#10 +
'    begin' + #13#10 +
'      bx := g1x;  by := g1y - 30;' + #13#10 +
'    end' + #13#10 +
'    else' + #13#10 +
'    begin' + #13#10 +
'      bx := g2x;  by := g2y - 30;' + #13#10 +
'    end;' + #13#10 +
'' + #13#10 +
'    vx := cos(angle) * speed;' + #13#10 +
'    vy := -sin(angle) * speed;' + #13#10 +
'    hit := false;  t := 0;' + #13#10 +
'' + #13#10 +
'    // Animate the banana' + #13#10 +
'    while (by < 490) and (not hit) and GfxRunning do' + #13#10 +
'    begin' + #13#10 +
'      DrawScene;' + #13#10 +
'' + #13#10 +
'      // Draw banana (rotating yellow circle)' + #13#10 +
'      GfxColor(''yellow'');' + #13#10 +
'      GfxFillCircle(round(bx), round(by), 6);' + #13#10 +
'      GfxColor(''gold'');' + #13#10 +
'      GfxFillCircle(round(bx) + 2, round(by) - 2, 3);' + #13#10 +
'' + #13#10 +
'      GfxShow;' + #13#10 +
'      GfxDelay(16);' + #13#10 +
'' + #13#10 +
'      bx := bx + vx;' + #13#10 +
'      vy := vy + gravity;' + #13#10 +
'      by := by + vy;' + #13#10 +
'' + #13#10 +
'      // Check hit gorilla 2 (player 1 throwing)' + #13#10 +
'      if player = 1 then' + #13#10 +
'      begin' + #13#10 +
'        if InRange(round(bx), g2x-20, g2x+20) and' + #13#10 +
'           InRange(round(by), g2y-45, g2y) then' + #13#10 +
'        begin' + #13#10 +
'          hit := true;' + #13#10 +
'          inc(score1);' + #13#10 +
'          GfxColor(''orange'');' + #13#10 +
'          GfxFillCircle(g2x, g2y - 20, 30);' + #13#10 +
'          GfxColor(''yellow'');' + #13#10 +
'          GfxDrawText(g2x - 30, g2y - 60, ''BOOM!'');' + #13#10 +
'          GfxShow;  GfxDelay(1500);' + #13#10 +
'        end;' + #13#10 +
'      end' + #13#10 +
'      else' + #13#10 +
'      begin' + #13#10 +
'        if InRange(round(bx), g1x-20, g1x+20) and' + #13#10 +
'           InRange(round(by), g1y-45, g1y) then' + #13#10 +
'        begin' + #13#10 +
'          hit := true;' + #13#10 +
'          inc(score2);' + #13#10 +
'          GfxColor(''orange'');' + #13#10 +
'          GfxFillCircle(g1x, g1y - 20, 30);' + #13#10 +
'          GfxColor(''yellow'');' + #13#10 +
'          GfxDrawText(g1x - 30, g1y - 60, ''BOOM!'');' + #13#10 +
'          GfxShow;  GfxDelay(1500);' + #13#10 +
'        end;' + #13#10 +
'      end;' + #13#10 +
'    end;' + #13#10 +
'' + #13#10 +
'    // Check win condition' + #13#10 +
'    if score1 >= 3 then' + #13#10 +
'    begin' + #13#10 +
'      DrawScene;' + #13#10 +
'      GfxColor(''gold'');' + #13#10 +
'      GfxSetFont(32, true);' + #13#10 +
'      GfxDrawText(160, 180, ''PLAYER 1 WINS!'');' + #13#10 +
'      GfxShow;  GfxDelay(3000);' + #13#10 +
'      playing := false;' + #13#10 +
'    end' + #13#10 +
'    else if score2 >= 3 then' + #13#10 +
'    begin' + #13#10 +
'      DrawScene;' + #13#10 +
'      GfxColor(''cyan'');' + #13#10 +
'      GfxSetFont(32, true);' + #13#10 +
'      GfxDrawText(160, 180, ''PLAYER 2 WINS!'');' + #13#10 +
'      GfxShow;  GfxDelay(3000);' + #13#10 +
'      playing := false;' + #13#10 +
'    end' + #13#10 +
'    else' + #13#10 +
'    begin' + #13#10 +
'      // Switch player' + #13#10 +
'      if player = 1 then player := 2' + #13#10 +
'      else player := 1;' + #13#10 +
'    end;' + #13#10 +
'  end;' + #13#10 +
'' + #13#10 +
'  writeln(''Game over. P1='', score1, '' P2='', score2);' + #13#10 +
'  GfxClose;' + #13#10 +
'end.');

Add('Kaleidoscope', 'Graphics',
  'Hypnotic animated kaleidoscope pattern using symmetry',
'// ============================================================' + #13#10 +
'// KALEIDOSCOPE' + #13#10 +
'// Mesmerising rotating symmetric pattern.' + #13#10 +
'// ============================================================' + #13#10 +
'' + #13#10 +
'var' + #13#10 +
'  frame, cx, cy : Integer;' + #13#10 +
'  t : Real;' + #13#10 +
'  r, px, py, px2, py2 : Integer;' + #13#10 +
'  a : Real;' + #13#10 +
'  seg : Integer;' + #13#10 +
'' + #13#10 +
'begin' + #13#10 +
'  GfxOpen(640, 480, ''Kaleidoscope'');' + #13#10 +
'  cx := 320;  cy := 240;' + #13#10 +
'  frame := 0;  t := 0;' + #13#10 +
'' + #13#10 +
'  while GfxRunning do' + #13#10 +
'  begin' + #13#10 +
'    GfxClear(''black'');' + #13#10 +
'' + #13#10 +
'    // Draw 12 symmetric segments' + #13#10 +
'    for seg := 0 to 11 do' + #13#10 +
'    begin' + #13#10 +
'      a := (seg * 3.14159 / 6) + t;' + #13#10 +
'      r := 80 + round(60 * sin(t * 3 + seg));' + #13#10 +
'' + #13#10 +
'      px := cx + round(r * cos(a));' + #13#10 +
'      py := cy + round(r * sin(a));' + #13#10 +
'      px2 := cx + round((r div 2) * cos(a + 0.5));' + #13#10 +
'      py2 := cy + round((r div 2) * sin(a + 0.5));' + #13#10 +
'' + #13#10 +
'      // Colour cycles' + #13#10 +
'      case seg mod 6 of' + #13#10 +
'        0 : GfxColor(''red'');' + #13#10 +
'        1 : GfxColor(''orange'');' + #13#10 +
'        2 : GfxColor(''yellow'');' + #13#10 +
'        3 : GfxColor(''lime'');' + #13#10 +
'        4 : GfxColor(''cyan'');' + #13#10 +
'        5 : GfxColor(''magenta'');' + #13#10 +
'      end;' + #13#10 +
'' + #13#10 +
'      GfxDrawLine(cx, cy, px, py);' + #13#10 +
'      GfxFillCircle(px, py, 8);' + #13#10 +
'      GfxFillCircle(px2, py2, 5);' + #13#10 +
'    end;' + #13#10 +
'' + #13#10 +
'    // Centre decoration' + #13#10 +
'    GfxColor(''white'');' + #13#10 +
'    GfxFillCircle(cx, cy, 15);' + #13#10 +
'' + #13#10 +
'    GfxColor(''silver'');' + #13#10 +
'    GfxSetFont(12, false);' + #13#10 +
'    GfxDrawText(10, 10, ''KALEIDOSCOPE  —  Close to stop'');' + #13#10 +
'' + #13#10 +
'    GfxShow;' + #13#10 +
'    GfxDelay(20);' + #13#10 +
'    t := t + 0.04;' + #13#10 +
'    inc(frame);' + #13#10 +
'  end;' + #13#10 +
'end.');


end; // Build

end.
