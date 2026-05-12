# MiniDelphi — A Toy Compiler & Learning IDE

> *Copyright © 2026 Nomidor Software, LLC. All rights reserved.*

---

## What Is It?

MiniDelphi is a complete **interpreted programming language and learning IDE** built entirely in Embarcadero Delphi 13 (VCL, Win64). It implements a substantial subset of the Pascal/Delphi language and runs programs instantly — no compilation step, no external tools, no setup.

The goal is simple: give someone who has never programmed before a friendly, immediate, and visually rewarding environment to learn the fundamentals of structured programming, object-oriented design, and algorithm thinking — all in a language that looks and feels like real Delphi.

---

## Architecture

MiniDelphi is a classic **tree-walking interpreter** built from scratch across 12 Pascal units totalling roughly 14,000 lines of source:

```
Source text
    │
    ▼
ULexer.pas          Tokeniser — breaks source into a stream of typed tokens
    │
    ▼
UParser.pas         Recursive-descent parser — builds an Abstract Syntax Tree
    │
    ▼
UAST.pas            AST node definitions (expressions, statements, declarations)
    │
    ▼
UInterpreter.pas    Tree-walking interpreter — executes the AST directly
    │
    ├── UObjectRuntime.pas   OOP class registry, object instances, method dispatch
    ├── USQLite.pas          SQLite3 dynamic DLL binding (database support)
    ├── UGraphics.pas        Animation window (TGfxPanel + WM_PAINT + BitBlt)
    └── UUnitLoader.pas      Multi-file unit import system (.mdp files)

UMainForm.pas       4-tab VCL shell (editor, output, learn, projects)
ULearnTab.pas       13-lesson interactive curriculum
UProjectTab.pas     Example browser and project management
UExampleProjects.pas  40+ fully-documented example programs
```

---

## Language Features

MiniDelphi supports a rich subset of Pascal/Delphi syntax.

### Core Language

| Feature | Example |
|---|---|
| Variables | `var x, y : Integer;` |
| Types | `Integer`, `Real`, `String`, `Boolean` |
| Arithmetic | `+  -  *  /  div  mod` |
| Comparison | `=  <>  <  <=  >  >=  is` |
| Logic | `and  or  not` |
| Assignment | `:=` |
| Output | `writeln(...)` / `write(...)` |

### Control Flow

```pascal
if condition then ... else ...
while condition do ...
repeat ... until condition
for i := 1 to 100 do ...
for i := 10 downto 1 do ...
case n of 1: ...; 2: ...; else ...; end;
caseof s of 'A': ...; 'B': ...; else ...; end;   { string switch }
break   continue   exit
```

### Procedures & Functions

```pascal
procedure Greet(name: String);
begin
  writeln('Hello, ', name);
end;

function Square(n: Real): Real;
begin
  Result := n * n;
end;
```

Supports recursion, nested calls, comma-separated parameters, and local `var` blocks.

### Object-Oriented Programming

```pascal
type
  TAnimal = class
    Name : String;
    procedure Speak; virtual;
  end;

  TDog = class(TAnimal)
    Breed : String;
    procedure Speak; override;
  end;

procedure TAnimal.Speak;
begin
  writeln(Self.Name, ' says: ...');
end;

procedure TDog.Speak;
begin
  writeln('Woof!');
end;

var dog : TDog;
begin
  dog       := TDog.Create;
  dog.Name  := 'Rex';
  dog.Breed := 'Labrador';
  dog.Speak;
end.
```

Full OOP support including:
- Classes and single inheritance (`class(Parent)`)
- Interfaces (`interface`)
- `virtual` / `override` / `abstract` methods
- `constructor` / `destructor`
- `Self` keyword and field access via dot notation
- `is` type-checking operator
- `inherited` calls
- `Self.ClassName` built-in property
- Comma-separated field declarations (`Width, Height : Real`)

### Multi-File Projects

```pascal
uses
  'MathLib.mdp',
  'StringLib.mdp';

begin
  writeln(Hypotenuse(3, 4));   // from MathLib
  writeln(StrReverse('hello')); // from StringLib
end.
```

Programs can import other `.mdp` files as libraries. The unit loader scans the `uses` clause, loads and parses each file, and merges their declarations into the main program — enabling real multi-file projects with dependency chains (a library can itself import another library).

### Built-in Functions

**Math:** `abs`, `sqr`, `sqrt`, `round`, `trunc`, `sin`, `cos`, `ln`, `exp`, `power`, `max`, `min`, `pi`, `random`, `randomize`, `odd`

**String:** `length`, `copy`, `pos`, `uppercase`, `lowercase`, `trim`, `inttostr`, `strtoint`, `strtofloat`, `floattostr`, `chr`, `ord`

**Loop control:** `inc`, `dec`, `succ`, `pred`

**UI dialogs:** `showmessage`, `inputbox`, `confirm`, `showinfobox`, `showwarningbox`, `showerrorbox`

**File I/O:** `writefile`, `appendfile`, `readfile`, `fileexists`, `deletefile`, `getapppath`, `openfiledialog`, `savefiledialog`

**Database (SQLite):** `dbopen`, `dbclose`, `dbexec`, `dbquery`, `dbqueryvalue`, `dblasterror`, `dbisopen`, `dbfilename`

**Graphics (26 functions):** see below

---

## Graphics & Animation

MiniDelphi programs can open a floating graphics window and draw real-time animated scenes in a simple game-loop style:

```pascal
var x, dx, frame : Integer;
begin
  GfxOpen(640, 480, 'Bouncing Ball');
  x := 320;  dx := 5;

  while GfxRunning do
  begin
    GfxClear('black');
    GfxColor('cyan');
    GfxFillCircle(x, 240, 30);
    GfxColor('white');
    GfxDrawText(10, 10, 'Frame: ' + IntToStr(frame));
    GfxShow;
    GfxDelay(16);
    x := x + dx;
    if (x < 30) or (x > 610) then dx := -dx;
    inc(frame);
  end;
  writeln('Ran for ', frame, ' frames.');
end.
```

**Drawing:** `GfxClear`, `GfxColor`, `GfxPenWidth`, `GfxDrawLine`, `GfxDrawRect`, `GfxFillRect`, `GfxDrawCircle`, `GfxFillCircle`, `GfxDrawEllipse`, `GfxFillEllipse`, `GfxDrawText`, `GfxSetFont`, `GfxDrawPixel`

**Window & timing:** `GfxOpen`, `GfxClose`, `GfxShow`, `GfxDelay`, `GfxRunning`

**Input:** `GfxKeyPressed`, `GfxReadKey`, `GfxMouseX`, `GfxMouseY`, `GfxMouseDown`

**Colours:** 25 named colours (`black`, `white`, `red`, `lime`, `blue`, `gold`, `skyblue`, `orange`, `purple`, `cyan`, `magenta`, ...) plus arbitrary `#RRGGBB` hex values.

The graphics engine uses a `TGfxPanel` (`TWinControl` subclass with a real HWND) backed by a `TBitmap`. Drawing goes to the bitmap; `GfxShow` calls `InvalidateRect` + `UpdateWindow` for immediate synchronous painting via `WM_PAINT` and `BitBlt`.

---

## The IDE

The main window has four tabs:

### Compiler Tab
A full source editor with run controls and an output panel. Press **F5** or click **Run** to execute. Programs run in milliseconds — the interpreter is fast enough for smooth 60fps animation loops.

### Calculator Tab
A quick expression evaluator — type any MiniDelphi expression and see the result immediately without writing a full program.

### Learn Delphi Tab
An interactive 13-lesson curriculum built into the IDE:

1. Your First Program
2. Variables and Types
3. Getting Input
4. Making Decisions
5. Loops — While
6. Loops — For
7. Procedures
8. Functions
9. String Operations
10. Working with Numbers
11. Case Statements
12. Repeat..Until
13. Putting It All Together

Each lesson has explanatory text, a live code example that loads directly into the editor, and lesson-by-lesson progress tracking.

### Projects Tab
A categorised browser of 40+ fully-documented example programs. Every example has:
- A header comment explaining what the program teaches
- Inline comments on every non-trivial line
- Teaching moments called out with `// *** NOTE:`

**Example categories:**

| Category | Highlights |
|---|---|
| Beginners | Hello World, Personal Greeter, Simple Calculator |
| Numbers & Maths | FizzBuzz, Fibonacci, Primes, Factorial, Times Tables, Pascal's Triangle, Base Converter, Number Patterns |
| Games & Fun | Number Guessing, Dice Roller, Rock Paper Scissors, Coin Flipper, Magic 8-Ball |
| Science & Conversion | Temperature Converter, BMI Calculator, Loan Calculator |
| Strings & Text | Caesar Cipher, Palindrome Checker, Word Counter, Morse Code |
| Algorithms | Bubble Sort, Binary Search, GCD & LCM, Star Patterns, Roman Numerals, Sieve of Eratosthenes, ASCII Sine Wave, Collatz Conjecture, Recursive Descent |
| File & Data | Grade Book, To-Do List, Phone Book, Shopping Bill |
| Utilities | Password Generator, Unit Converter, Countdown Timer, Statistics Calculator |
| Multi-File Projects | MathLib, StringLib, Student Grade System, Shape Calculator, Personal Finance Tracker, Mini Text Adventure, Statistics Suite, Shared Units Demo, Logging System, Quiz Engine |
| Database | SQLite Hello World, Phone Book Database, Grade Book Database |
| Object Oriented | OOP Hello World, Inheritance Demo, Interface Demo, Constructor & Destructor |
| Graphics | Bouncing Ball, Starfield Screensaver, Solar System, Gorilla Game, Kaleidoscope |

---

## Database Support

MiniDelphi includes a full SQLite binding via dynamic DLL loading (no import library needed):

```pascal
DbOpen(GetAppPath + 'school.db');
DbExec('CREATE TABLE IF NOT EXISTS grades (student TEXT, subject TEXT, score REAL)');
DbExec('INSERT INTO grades VALUES (''Alice'', ''Maths'', 92)');
DbExec('INSERT INTO grades VALUES (''Bob'',   ''Maths'', 75)');

writeln(DbQuery('SELECT student, AVG(score) as avg FROM grades GROUP BY student'));
writeln('Class average: ', DbQueryValue('SELECT AVG(score) FROM grades'));
DbClose;
```

Drop `sqlite3.dll` from [sqlite.org](https://sqlite.org/download.html) next to the executable to enable all database examples.

---

## Project Structure

```
MiniDelphi.dpr / .dproj     Project files
UAST.pas                    AST node class hierarchy            (740 lines)
ULexer.pas                  Tokeniser                          (631 lines)
UParser.pas                 Recursive-descent parser         (1,378 lines)
UInterpreter.pas            Interpreter + all builtins       (1,755 lines)
UObjectRuntime.pas          OOP runtime                        (424 lines)
USQLite.pas                 SQLite3 dynamic binding            (397 lines)
UGraphics.pas               Animation graphics window          (475 lines)
UUnitLoader.pas             Multi-file unit import system      (343 lines)
UMainForm.pas               Main VCL shell                     (967 lines)
ULearnTab.pas               Interactive curriculum           (1,943 lines)
UProjectTab.pas             Example browser                    (973 lines)
UExampleProjects.pas        40+ built-in examples           (3,929 lines)
─────────────────────────────────────────────────────────────────────────
Total                                                        ~13,955 lines
```

---

## Requirements & Building

- **Embarcadero Delphi 13** (Community Edition works fine)
- Target platform: **Win64**
- No third-party components, no NuGet, no install

Steps:
1. Open `MiniDelphi.dproj` in Delphi 13
2. Ensure the target platform is **Win64** (Project → Options → Building)
3. Press **F9** to build and run
4. Optionally place `sqlite3.dll` next to the executable for database support

---

## Design Notes

**Why a tree-walking interpreter?**
Speed of implementation and transparency of behaviour. Every `ParseXxx` function maps directly to a grammar rule; every `ExecXxx` / `EvalXxx` function maps to its runtime behaviour. A learner reading the MiniDelphi source can trace exactly how `if x > 5 then writeln('big')` becomes output — the interpreter is its own documentation.

**Why invent `caseof` for string switches?**
Standard Pascal `case` only works on ordinal types. Rather than silently coercing strings to integers or throwing a runtime error, MiniDelphi adds `caseof` as a first-class construct. The different keyword keeps the teaching intent clear: strings and integers are different things.

**Why `.mdp` files?**
A distinct extension makes it immediately obvious these are MiniDelphi source files, not real Delphi `.pas` files, preventing confusion for learners who also have Delphi installed.

**Why double-buffered graphics with `BitBlt`?**
The interpreter runs on the VCL main thread. `Application.ProcessMessages` inside `GfxShow` keeps the window alive during animation loops. Drawing to a `TBitmap` then blitting it synchronously via `WM_PAINT` is the only reliable way to animate from the main thread without a background rendering thread — it avoids all the DC ownership and `WM_PAINT` queue issues that arise from trying to draw to the window directly during a tight loop.

---

## Licence

Copyright © 2026 Nomidor Software, LLC.

MiniDelphi is free software released under the **GNU General Public License v3.0**.

You are free to use, study, modify, and distribute this software under the terms of the GPL v3. Any modified version you distribute must also be released under the GPL v3 and must clearly attribute the original work to Nomidor Software, LLC.

Nomidor Software, LLC retains full copyright ownership of the original source code. The GPL licence grants you rights to use and build upon it — it does not transfer ownership.

See the [LICENSE](LICENSE) file for the full licence text, or visit [gnu.org/licenses/gpl-3.0](https://www.gnu.org/licenses/gpl-3.0.html).

> **In plain English:** Use it, learn from it, modify it, share it — just keep it open source and give credit to Nomidor Software, LLC.
