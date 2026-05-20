# MiniDelphi

A toy Pascal/Delphi interpreter and learning IDE, written in Delphi 13 (Athens) for Windows.

Think of MiniDelphi as a sandbox: a real Pascal-like language with a full tokeniser, parser, and tree-walking interpreter, wrapped in a friendly IDE with lessons, examples, snippets, a calculator, a visual form builder, and a project system. It runs your code, draws your forms, opens database files, and teaches Delphi syntax with side-by-side tutorials.

It is **not** a Delphi compiler. It does not produce native binaries. It is a learning environment.

---

## Why?

Delphi is a beautiful language with a steep beginner ramp. A new programmer opening the real Delphi IDE meets an overwhelming wall of menus, components, properties, and tooling that has nothing to do with learning the language itself. MiniDelphi is what happens if you strip all of that away and keep only the parts that help a person actually learn Pascal: a place to type code, a button to run it, examples that don't assume prior knowledge, and a built-in reference for every feature.

It's also a fun toy for old hands who want a quick scratchpad for Pascal experiments.

---

## Features

### Language

- Pascal-like syntax: `program`, `uses`, `var`, `procedure`, `function`, `begin..end`
- Types: `Integer`, `Real`, `String`, `Boolean`, plus objects via `class`
- Control flow: `if..then..else`, `while..do`, `repeat..until`, `for..to..do`, `for..downto..do`
- `case..of` for integers with multi-value labels and `else` branch
- `caseof..of` extension for switching on strings
- Classes: fields, methods, constructors, `Self`, inheritance, virtual methods
- Recursion, mutual recursion, nested calls
- `Result` return convention for functions

### Built-in routines

- Output: `writeln`, `write`
- Input: `readln`, `InputBox`
- Dialogs: `ShowMessage`, `Confirm`
- Math: `abs`, `sqr`, `sqrt`, `power`, `round`, `trunc`, `sin`, `cos`, `tan`, `ln`, `exp`, `pi`, `max`, `min`, `random`, `randomize`
- Strings: `length`, `uppercase`, `lowercase`, `copy`, `pos`, `trim`, `inttostr`, `strtoint`, `strtointdef`, `floattostr`, `strtofloat`
- Files: `fileexists`, `readfile`, `writefile`, `appendfile`, `deletefile`
- Graphics: `GfxOpen`, `GfxClose`, `GfxLine`, `GfxRect`, `GfxCircle`, `GfxText`, `GfxColor`, `GfxClear`, `GfxUpdate`
- Database: `DbOpen`, `DbClose`, `DbExec`, `DbQuery`, `DbNext`, `DbField` (requires sqlite3.dll alongside the exe)
- Timing: `Sleep`

### IDE

- **Compiler tab** — source editor on the left, output on the right, token stream at the bottom. Right-click for code snippets, F5 to run.
- **Calculator tab** — type any expression and press Enter. `2 + 3 * sqrt(16)` works as expected.
- **Learn Delphi tab** — 13 lessons covering language fundamentals, plus 45 graded challenges with hints and a completion certificate.
- **Projects tab** — multi-file projects with a `.mdproj` project file, library `.mdp` files, and an internal `[Source]` section for the main program.
- **Forms tab** — a Phase 1 visual form builder with palette (Pointer / Label / Button / Edit), drag-and-drop placement, an object inspector, and modal preview at runtime.
- **Macros tab** — small scripts that run against the project, with a trusted-flag system for shell-using macros.

### IDE niceties

- Themes: Dark (Carbon), Light (Iceberg Classico), or Follow Windows setting — set under View → Preferences
- Three menus: File, View, Help. Help → Examples loads any of 8 built-in programs into the Compiler tab.
- Right-click in any code editor for a snippet menu (`if..then`, `for`, `while`, class skeleton, etc.)

---

## Quick build

### Prerequisites

- **Embarcadero Delphi 13 (Athens)** with VCL Styles support
- **Windows 10 or 11** (the app is Win64-only)
- Optional: `sqlite3.dll` placed next to the exe if you want to use the `Db*` builtins

### Building

1. Clone this repository
2. Open `MiniDelphi.dpr` in Delphi
3. **Project → Options → Application → Appearance** — tick the boxes for `Carbon`, `Iceberg Classico`, and (optionally) `Windows10 SlateGray` and `Glossy` as fallbacks
4. **Project → Build** (Shift+F9)
5. Run with **F9** or launch the produced `MiniDelphi.exe`

### Running

The IDE opens on the Compiler tab with a Hello World example pre-loaded. Click **Run** to execute it. Try **Help → Examples → FizzBuzz** for a slightly more interesting first program.

---

## Hello, MiniDelphi

```pascal
program HelloWorld;
begin
  writeln('Hello, World!');
  writeln('Welcome to MiniDelphi!');
end.
```

A slightly bigger taste — `caseof` switching on a string:

```pascal
program AnimalSounds;

procedure Describe(animal: String);
begin
  write(animal, ' -> ');
  caseof animal of
    'cat'           : writeln('Meow!');
    'dog', 'hound'  : writeln('Woof!');
    'cow'           : writeln('Moo!');
  else
    writeln('Unknown!');
  end;
end;

begin
  Describe('cat');
  Describe('dog');
  Describe('unicorn');
end.
```

Recursion works as you'd expect:

```pascal
function Fact(n: Integer): Integer;
begin
  if n <= 1 then Result := 1
  else Result := n * Fact(n - 1);
end;

var i : Integer;
begin
  for i := 0 to 10 do writeln(i, '! = ', Fact(i));
end.
```

---

## Project structure

A MiniDelphi project lives in a folder with one `.mdproj` file and any number of `.mdp` library files and `.mdfrm` form definition files.

The `.mdproj` is an INI-style file with three sections:

```ini
[Project]
Name=MyApp

[Files]
0=MathLib.mdp
1=Strings.mdp

[Source]
program MyApp;
uses
  'MathLib.mdp',
  'Strings.mdp';
begin
  writeln(Add(2, 3));
end.
```

The main program lives in `[Source]`, exactly like a real Delphi `.dpr`. Library `.mdp` files contain declarations only (no `begin..end`).

---

## Architecture

```
MiniDelphi/
├── MiniDelphi.dpr            # project entry point
├── UMainForm.pas             # main VCL form with the tab pages
├── ULexer.pas                # source → tokens
├── UParser.pas                # tokens → AST (recursive descent)
├── UAST.pas                  # AST node definitions
├── UValidator.pas            # post-parse semantic checks
├── UInterpreter.pas          # tree-walking interpreter
├── UObjectRuntime.pas        # class/object runtime support
├── UUnitLoader.pas           # uses clause / .mdp import
├── UGraphics.pas             # Gfx* builtins
├── USQLite.pas               # Db* builtins (via sqlite3.dll)
├── UProjectTab.pas           # Projects tab
├── UFormBuilderTab.pas       # Forms tab
├── UFormDef.pas              # .mdfrm form definition model
├── UMacroTab.pas             # Macros tab
├── UMacroLibrary.pas         # macro storage
├── ULearnTab.pas             # Learn Delphi tab
├── UExampleProjects.pas      # built-in example projects
├── UAboutDialog.pas          # About + Programmer's Guide
├── UTheme.pas                # VCL Styles wrapper
└── UPreferencesDialog.pas    # View → Preferences
```

---

## License

GPL-3.0. See [LICENSE](LICENSE) for the full text.

This means: you can use, modify, and distribute MiniDelphi freely, as long as derivative works remain GPL-3.0 licensed and their source is made available.

---

## Author

MiniDelphi is developed by **Nomidor Software, LLC.**

For bugs, suggestions, or contributions, open an issue or pull request on GitHub.
