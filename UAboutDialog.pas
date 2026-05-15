unit UAboutDialog;

// =============================================================================
// MiniDelphi Toy Compiler & Learning IDE
// Copyright (C) 2026 Nomidor Software, LLC.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// =============================================================================

// =============================================================================
//  UAboutDialog.pas  -  Modal About dialog with two tabs:
//                       [About]            version, copyright, license, feature list
//                       [Programming Guide] language reference for MiniDelphi
//
//  Usage:
//     ShowAboutDialog;
//
//  The form is built entirely in code -- no DFM required.
// =============================================================================

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Vcl.Graphics, Vcl.Dialogs, System.UITypes;

procedure ShowAboutDialog;

// =============================================================================
implementation
// =============================================================================

type
  TAboutForm = class(TForm)
  private
    FPages         : TPageControl;
    FTabAbout      : TTabSheet;
    FTabGuide      : TTabSheet;
    FMemoAbout     : TMemo;
    FMemoGuide     : TMemo;
    FBtnOK         : TButton;
    procedure BuildUI;
    procedure FillAbout;
    procedure FillGuide;
    procedure OnOKClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

// ---------------------------------------------------------------------------
//  Public entry point
// ---------------------------------------------------------------------------
procedure ShowAboutDialog;
var
  Dlg : TAboutForm;
begin
  Dlg := TAboutForm.Create(nil);
  try
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Constructor
// ---------------------------------------------------------------------------
constructor TAboutForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption       := 'About MiniDelphi';
  Width         := 720;
  Height        := 600;
  Position      := poScreenCenter;
  BorderStyle   := bsDialog;
  Font.Name     := 'Segoe UI';
  Font.Size     := 10;

  BuildUI;
  FillAbout;
  FillGuide;
end;

// ---------------------------------------------------------------------------
//  Build the UI: tab control with two tabs + an OK button
// ---------------------------------------------------------------------------
procedure TAboutForm.BuildUI;
var
  ButtonPanel : TPanel;
begin
  // OK button strip at the bottom
  ButtonPanel             := TPanel.Create(Self);
  ButtonPanel.Parent      := Self;
  ButtonPanel.Align       := alBottom;
  ButtonPanel.Height      := 48;
  ButtonPanel.BevelOuter  := bvNone;

  FBtnOK                  := TButton.Create(ButtonPanel);
  FBtnOK.Parent           := ButtonPanel;
  FBtnOK.Caption          := 'OK';
  FBtnOK.Width            := 90;
  FBtnOK.Height           := 30;
  FBtnOK.Top              := 10;
  FBtnOK.Anchors          := [akTop, akRight];
  FBtnOK.Left             := ButtonPanel.Width - FBtnOK.Width - 16;
  FBtnOK.Default          := True;
  FBtnOK.OnClick          := OnOKClick;
  FBtnOK.ModalResult      := mrOK;

  // Page control fills the rest
  FPages                  := TPageControl.Create(Self);
  FPages.Parent           := Self;
  FPages.Align            := alClient;

  FTabAbout               := TTabSheet.Create(FPages);
  FTabAbout.PageControl   := FPages;
  FTabAbout.Caption       := '  About  ';

  FTabGuide               := TTabSheet.Create(FPages);
  FTabGuide.PageControl   := FPages;
  FTabGuide.Caption       := '  Programming Guide  ';

  // About memo
  FMemoAbout              := TMemo.Create(FTabAbout);
  FMemoAbout.Parent       := FTabAbout;
  FMemoAbout.Align        := alClient;
  FMemoAbout.ReadOnly     := True;
  FMemoAbout.ScrollBars   := ssVertical;
  FMemoAbout.WordWrap     := True;
  FMemoAbout.Font.Name    := 'Segoe UI';
  FMemoAbout.Font.Size    := 10;
  FMemoAbout.BorderStyle  := bsNone;
  FMemoAbout.Color        := clWindow;

  // Guide memo - monospace for code samples
  FMemoGuide              := TMemo.Create(FTabGuide);
  FMemoGuide.Parent       := FTabGuide;
  FMemoGuide.Align        := alClient;
  FMemoGuide.ReadOnly     := True;
  FMemoGuide.ScrollBars   := ssBoth;
  FMemoGuide.WordWrap     := False;
  FMemoGuide.Font.Name    := 'Consolas';
  FMemoGuide.Font.Size    := 10;
  FMemoGuide.BorderStyle  := bsNone;
  FMemoGuide.Color        := clWindow;
end;

procedure TAboutForm.OnOKClick(Sender: TObject);
begin
  ModalResult := mrOK;
end;

// ---------------------------------------------------------------------------
//  About tab content
// ---------------------------------------------------------------------------
procedure TAboutForm.FillAbout;
begin
  with FMemoAbout.Lines do
  begin
    BeginUpdate;
    try
      Clear;
      Add('MiniDelphi Toy Compiler & Learning IDE');
      Add('------------------------------------------------------');
      Add('');
      Add('Version 1.0   |   May 2026');
      Add('');
      Add('Copyright (c) 2026 Nomidor Software, LLC.');
      Add('All rights reserved.');
      Add('');
      Add('Licensed under the GNU General Public License v3.0');
      Add('See https://www.gnu.org/licenses/gpl-3.0.html for the full text.');
      Add('');
      Add('This program is free software: you can redistribute it and/or');
      Add('modify it under the terms of the GNU GPL v3 as published by the');
      Add('Free Software Foundation. This program is distributed in the hope');
      Add('that it will be useful, but WITHOUT ANY WARRANTY; without even');
      Add('the implied warranty of MERCHANTABILITY or FITNESS FOR A');
      Add('PARTICULAR PURPOSE.');
      Add('');
      Add('A complete Delphi learning environment featuring:');
      Add('');
      Add('  * Full lexer, parser and tree-walking interpreter');
      Add('  * Four tabs: Compiler, Calculator, Learn Delphi, Projects');
      Add('  * Snippet insert menu (toolbar, right-click, or Tab-trigger)');
      Add('  * 13 lessons, 45 challenges, completion certificate');
      Add('  * 40+ single-file and 10+ multi-file example programs');
      Add('  * Object-oriented programming: classes, inheritance,');
      Add('    interfaces, polymorphism');
      Add('  * SQLite database support (requires sqlite3.dll)');
      Add('  * Unit import system using .mdp library files');
      Add('  * File dialogs, message boxes, file I/O builtins');
      Add('  * 2D graphics window (GfxOpen, drawing primitives)');
      Add('  * Project save/load with .mdp source and .mdproj project files');
      Add('');
      Add('Built with Embarcadero Delphi 13 (Athens) for Win64.');
      Add('');
      Add('www.nomidor.com');
    finally
      EndUpdate;
    end;
  end;

  // Scroll to top
  FMemoAbout.SelStart := 0;
  FMemoAbout.Perform(EM_SCROLLCARET, 0, 0);
end;

// ---------------------------------------------------------------------------
//  Programming Guide tab content
// ---------------------------------------------------------------------------
procedure TAboutForm.FillGuide;
begin
  with FMemoGuide.Lines do
  begin
    BeginUpdate;
    try
      Clear;

      Add('============================================================');
      Add(' MINIDELPHI PROGRAMMING GUIDE');
      Add(' Quick reference for the MiniDelphi language');
      Add('============================================================');
      Add('');
      Add('');

      Add('1. PROGRAM STRUCTURE');
      Add('--------------------');
      Add('');
      Add('  // Optional program header');
      Add('  program MyProgram;');
      Add('');
      Add('  // Optional uses clause to import library files (.mdp)');
      Add('  uses');
      Add('    ''MathLib.mdp'';');
      Add('');
      Add('  // Optional global var declarations');
      Add('  var');
      Add('    counter : Integer;');
      Add('    name    : String;');
      Add('');
      Add('  // Optional procedure / function declarations');
      Add('  procedure Greet(who: String);');
      Add('  begin');
      Add('    writeln(''Hello, '', who);');
      Add('  end;');
      Add('');
      Add('  // The main block is the program entry point');
      Add('  begin');
      Add('    Greet(''World'');');
      Add('  end.');
      Add('');
      Add('Library files (.mdp imported via uses) omit the main begin..end');
      Add('block and contain only declarations.');
      Add('');
      Add('');

      Add('2. DATA TYPES');
      Add('-------------');
      Add('');
      Add('  Integer  - 64-bit whole number    e.g.  42, -17, 0');
      Add('  Real     - 64-bit floating point  e.g.  3.14, -0.5, 1e10');
      Add('  String   - text                   e.g.  ''Hello'', ''''');
      Add('  Boolean  - logical value          True or False');
      Add('  nil      - empty / no object reference');
      Add('');
      Add('Variables default to zero / empty / False if not initialised.');
      Add('');
      Add('');

      Add('3. VARIABLES AND ASSIGNMENT');
      Add('---------------------------');
      Add('');
      Add('  var');
      Add('    age   : Integer;');
      Add('    pi    : Real;');
      Add('    name  : String;');
      Add('    ready : Boolean;');
      Add('');
      Add('  begin');
      Add('    age   := 25;');
      Add('    pi    := 3.14159;');
      Add('    name  := ''Alice'';');
      Add('    ready := True;');
      Add('  end.');
      Add('');
      Add('Use  :=  for assignment.  Use  =  for comparison.');
      Add('');
      Add('');

      Add('4. OPERATORS');
      Add('------------');
      Add('');
      Add('  Arithmetic :   +   -   *   /   div   mod');
      Add('  Comparison :   =   <>   <   >   <=   >=');
      Add('  Logical    :   and   or   not');
      Add('  String     :   +    (concatenation)');
      Add('');
      Add('  div = integer division   7 div 2 = 3');
      Add('  mod = remainder          7 mod 2 = 1');
      Add('  /   = real division      7 / 2   = 3.5');
      Add('');
      Add('');

      Add('5. CONTROL FLOW');
      Add('---------------');
      Add('');
      Add('  -- if / then / else --');
      Add('  if x > 0 then');
      Add('    writeln(''positive'')');
      Add('  else if x < 0 then');
      Add('    writeln(''negative'')');
      Add('  else');
      Add('    writeln(''zero'');');
      Add('');
      Add('  -- while loop (test before) --');
      Add('  while i < 10 do');
      Add('  begin');
      Add('    writeln(i);');
      Add('    inc(i);');
      Add('  end;');
      Add('');
      Add('  -- repeat / until (test after, runs at least once) --');
      Add('  repeat');
      Add('    writeln(i);');
      Add('    dec(i);');
      Add('  until i = 0;');
      Add('');
      Add('  -- for / to / downto --');
      Add('  for i := 1 to 10 do      writeln(i);');
      Add('  for i := 10 downto 1 do  writeln(i);');
      Add('');
      Add('  -- case (integer) --');
      Add('  case score div 10 of');
      Add('    10, 9 : writeln(''A'');');
      Add('    8     : writeln(''B'');');
      Add('    7     : writeln(''C'');');
      Add('  else');
      Add('    writeln(''F'');');
      Add('  end;');
      Add('');
      Add('  -- caseof (string switch -- MiniDelphi extension) --');
      Add('  caseof animal of');
      Add('    ''cat''   : writeln(''Meow!'');');
      Add('    ''dog''   : writeln(''Woof!'');');
      Add('  else');
      Add('    writeln(''Unknown'');');
      Add('  end;');
      Add('');
      Add('Use  break  to exit a loop and  continue  to skip to next iter.');
      Add('');
      Add('');

      Add('6. PROCEDURES AND FUNCTIONS');
      Add('---------------------------');
      Add('');
      Add('  // A procedure returns no value');
      Add('  procedure Greet(name: String);');
      Add('  begin');
      Add('    writeln(''Hello, '', name);');
      Add('  end;');
      Add('');
      Add('  // A function returns a value via the Result variable');
      Add('  function Square(n: Integer): Integer;');
      Add('  begin');
      Add('    Result := n * n;');
      Add('  end;');
      Add('');
      Add('  // Local variables');
      Add('  function Sum(a, b: Integer): Integer;');
      Add('  var');
      Add('    total : Integer;');
      Add('  begin');
      Add('    total  := a + b;');
      Add('    Result := total;');
      Add('  end;');
      Add('');
      Add('Use  exit  or  exit(value)  to return early from a function.');
      Add('');
      Add('');

      Add('7. INPUT AND OUTPUT');
      Add('-------------------');
      Add('');
      Add('  // Console output');
      Add('  write(''No newline'');');
      Add('  writeln(''With newline'');');
      Add('  writeln(''Multiple '', ''args '', ''ok'');');
      Add('');
      Add('  // Dialogs');
      Add('  ShowMessage(''Hi!'');');
      Add('  ShowInfoBox(''Information.'');');
      Add('  ShowWarningBox(''Careful!'');');
      Add('  ShowErrorBox(''Oh no.'');');
      Add('');
      Add('  // Get text from user');
      Add('  name := InputBox(''What is your name?'', ''Input'', ''Anonymous'');');
      Add('');
      Add('  // Yes/No dialog');
      Add('  if Confirm(''Continue?'') then ...');
      Add('');
      Add('  // File picking');
      Add('  fname := OpenFileDialog(''Text files|*.txt'');');
      Add('  fname := SaveFileDialog(''Text files|*.txt'', ''txt'');');
      Add('  dir   := SelectDirectoryDialog;');
      Add('');
      Add('');

      Add('8. STRING FUNCTIONS');
      Add('-------------------');
      Add('');
      Add('  Length(s)         - number of characters in s');
      Add('  Pos(sub, s)       - position of sub in s (0 if not found)');
      Add('  Copy(s, i, n)     - n characters starting at position i (1-based)');
      Add('  UpperCase(s)      - convert to upper case');
      Add('  LowerCase(s)      - convert to lower case');
      Add('  Trim(s)           - remove leading and trailing whitespace');
      Add('  IntToStr(n)       - integer to string');
      Add('  StrToInt(s)       - string to integer');
      Add('  FloatToStr(x)     - real to string');
      Add('  StrToFloat(s)     - string to real');
      Add('  Chr(n)            - character with ASCII code n');
      Add('  Ord(c)            - ASCII code of first char of c');
      Add('');
      Add('');

      Add('9. MATH FUNCTIONS');
      Add('-----------------');
      Add('');
      Add('  abs(x)         sqr(x)         sqrt(x)');
      Add('  sin(x)         cos(x)         ln(x)         exp(x)');
      Add('  round(x)       trunc(x)       int(x)        frac(x)');
      Add('  power(x, y)    max(a, b)      min(a, b)');
      Add('  odd(n)         succ(n)        pred(n)');
      Add('  pi             random         random(n)     randomize');
      Add('  inc(v)         inc(v, n)      dec(v)        dec(v, n)');
      Add('');
      Add('');

      Add('10. FILE I/O');
      Add('------------');
      Add('');
      Add('  WriteFile(name, text)         - overwrite');
      Add('  AppendFile(name, text)        - add line');
      Add('  text := ReadFile(name)        - read whole file');
      Add('  if FileExists(name) then ...');
      Add('  DeleteFile(name)');
      Add('  GetAppPath                    - folder where MiniDelphi runs from');
      Add('  GetDesktopPath                - user''s desktop folder');
      Add('');
      Add('');

      Add('11. TIMING');
      Add('----------');
      Add('');
      Add('  Sleep(1000);    // pause for one second (1000 ms)');
      Add('');
      Add('The Stop button on the Projects tab can interrupt a long-running');
      Add('program; Sleep yields between iterations so Stop stays responsive.');
      Add('');
      Add('');

      Add('12. OBJECT-ORIENTED PROGRAMMING');
      Add('-------------------------------');
      Add('');
      Add('  type');
      Add('    TAnimal = class');
      Add('      Name  : String;');
      Add('      Sound : String;');
      Add('      constructor Create(n, s: String);');
      Add('      procedure Speak; virtual;');
      Add('    end;');
      Add('');
      Add('    TDog = class(TAnimal)');
      Add('      procedure Speak; override;');
      Add('    end;');
      Add('');
      Add('  constructor TAnimal.Create(n, s: String);');
      Add('  begin');
      Add('    Self.Name  := n;');
      Add('    Self.Sound := s;');
      Add('  end;');
      Add('');
      Add('  procedure TAnimal.Speak;');
      Add('  begin');
      Add('    writeln(Self.Name, '' says '', Self.Sound);');
      Add('  end;');
      Add('');
      Add('  procedure TDog.Speak;');
      Add('  begin');
      Add('    inherited Speak;');
      Add('    writeln(''(wagging tail)'');');
      Add('  end;');
      Add('');
      Add('  var');
      Add('    a : TAnimal;');
      Add('  begin');
      Add('    a := TDog.Create(''Rex'', ''Woof'');');
      Add('    a.Speak;');
      Add('  end.');
      Add('');
      Add('Use  Self  to refer to the current instance inside a method.');
      Add('Use  inherited Method  to call the parent class version.');
      Add('Use  obj is TSomeClass  to test the type at runtime.');
      Add('');
      Add('');

      Add('13. GRAPHICS WINDOW');
      Add('-------------------');
      Add('');
      Add('  GfxOpen(width, height, title)  - open the graphics window');
      Add('  GfxClose                        - close it');
      Add('  GfxRunning                      - True while the window is open');
      Add('  GfxClear(color)                 - fill the window');
      Add('  GfxShow                         - flip back buffer to screen');
      Add('  GfxDelay(ms)                    - pause for ms milliseconds');
      Add('');
      Add('  GfxColor(name)        ''red'', ''#FF00FF'', ''black'' ...');
      Add('  GfxPenWidth(px)');
      Add('  GfxDrawLine(x1, y1, x2, y2)');
      Add('  GfxDrawRect(x, y, w, h)        GfxFillRect(x, y, w, h)');
      Add('  GfxDrawCircle(x, y, r)         GfxFillCircle(x, y, r)');
      Add('  GfxDrawEllipse(x, y, w, h)     GfxFillEllipse(x, y, w, h)');
      Add('  GfxDrawText(x, y, text)        GfxSetFont(size, bold)');
      Add('  GfxDrawPixel(x, y)');
      Add('');
      Add('  GfxKeyPressed                  - True if user pressed a key');
      Add('  GfxReadKey                     - the pressed key as a string');
      Add('  GfxMouseX  GfxMouseY  GfxMouseDown');
      Add('');
      Add('Typical animation pattern:');
      Add('');
      Add('  GfxOpen(800, 600, ''My Demo'');');
      Add('  while GfxRunning do');
      Add('  begin');
      Add('    GfxClear(''black'');');
      Add('    GfxColor(''white'');');
      Add('    GfxFillCircle(400, 300, 50);');
      Add('    GfxShow;');
      Add('    GfxDelay(30);');
      Add('  end;');
      Add('');
      Add('');

      Add('14. SQLITE DATABASE');
      Add('-------------------');
      Add('');
      Add('Requires sqlite3.dll alongside the MiniDelphi executable.');
      Add('');
      Add('  DbOpen(filename)              - open / create a database');
      Add('  DbClose                       - close it');
      Add('  DbIsOpen                      - True if a db is open');
      Add('  DbExec(sql)                   - run any SQL (no result)');
      Add('  result := DbQuery(sql)        - SELECT, returns text grid');
      Add('  v := DbQueryValue(sql)        - single value SELECT');
      Add('  err := DbLastError            - last error message');
      Add('');
      Add('Example:');
      Add('');
      Add('  DbOpen(''contacts.db'');');
      Add('  DbExec(''CREATE TABLE IF NOT EXISTS people (name TEXT, age INTEGER)'');');
      Add('  DbExec(''INSERT INTO people VALUES (''''Alice'''', 30)'');');
      Add('  writeln(DbQuery(''SELECT * FROM people''));');
      Add('  DbClose;');
      Add('');
      Add('');

      Add('15. UNITS AND MULTI-FILE PROJECTS');
      Add('---------------------------------');
      Add('');
      Add('A library file (.mdp) contains only declarations -- no main block.');
      Add('Import it in your main program with a uses clause:');
      Add('');
      Add('  // MathLib.mdp');
      Add('  function Square(n: Integer): Integer;');
      Add('  begin');
      Add('    Result := n * n;');
      Add('  end;');
      Add('');
      Add('  // Main.mdp');
      Add('  uses');
      Add('    ''MathLib.mdp'';');
      Add('');
      Add('  begin');
      Add('    writeln(Square(7));');
      Add('  end.');
      Add('');
      Add('Library paths are relative to the main file''s folder.');
      Add('Use the Projects tab to manage multi-file projects (.mdproj).');
      Add('');
      Add('');

      Add('16. SNIPPETS AND EDITOR SHORTCUTS');
      Add('---------------------------------');
      Add('');
      Add('On the Compiler tab Source Code editor:');
      Add('');
      Add('  * Click the Insert button -- snippet menu drops below');
      Add('  * Right-click in the editor -- same menu pops at cursor');
      Add('  * Type a trigger keyword + Tab to expand it inline:');
      Add('');
      Add('       if + Tab       -> if .. then');
      Add('       ife + Tab      -> if .. then .. else');
      Add('       while + Tab    -> while .. do .. end');
      Add('       repeat + Tab   -> repeat .. until');
      Add('       for + Tab      -> for .. to .. do');
      Add('       ford + Tab     -> for .. downto .. do');
      Add('       case + Tab     -> case .. of (integer)');
      Add('       caseof + Tab   -> caseof .. of (string)');
      Add('       wl + Tab       -> writeln('''')');
      Add('       msg + Tab      -> ShowMessage('''')');
      Add('       inp + Tab      -> := InputBox(...)');
      Add('       conf + Tab     -> if Confirm(...) then');
      Add('       proc + Tab     -> procedure skeleton');
      Add('       func + Tab     -> function skeleton');
      Add('       class + Tab    -> class declaration + impl');
      Add('');
      Add('Toolbar shortcuts (Projects tab):');
      Add('');
      Add('  Ctrl+N   New file');
      Add('  Ctrl+O   Open .mdp file');
      Add('  Ctrl+S   Save current file');
      Add('  F5       Run');
      Add('');
      Add('');

      Add('17. COMMON ERROR MESSAGES');
      Add('-------------------------');
      Add('');
      Add('  "Expected BEGIN but got <X>"');
      Add('     Likely missing or misplaced semicolon; check the preceding');
      Add('     line for a stray  end.  or unclosed expression.');
      Add('');
      Add('  "Unknown identifier"');
      Add('     Variable, function, or procedure not declared. For uses-');
      Add('     imported library routines, check the uses clause filename.');
      Add('');
      Add('  "Division by zero"');
      Add('     Use   if y <> 0 then z := x / y   to guard.');
      Add('');
      Add('  "Step limit reached"');
      Add('     Probable infinite loop. Check the loop''s exit condition.');
      Add('     The Projects tab Stop button can interrupt running code.');
      Add('');
      Add('  "Cannot call method on non-object"');
      Add('     The variable on the left of the dot is nil. Construct the');
      Add('     object first:    obj := TMyClass.Create;');
      Add('');
      Add('');

      Add('============================================================');
      Add(' END OF GUIDE');
      Add('');
      Add(' For runnable examples of every feature above, see the');
      Add(' Examples menu (Compiler tab) and the Projects tab tree.');
      Add(' Lessons and challenges live on the Learn Delphi tab.');
      Add('============================================================');

    finally
      EndUpdate;
    end;
  end;

  // Scroll to top
  FMemoGuide.SelStart := 0;
  FMemoGuide.Perform(EM_SCROLLCARET, 0, 0);
end;

end.
