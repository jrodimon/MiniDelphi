program MiniDelphi;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  MiniDelphi.dpr  -  Project file for the MiniDelphi Toy Compiler
//
//  Units in this project:
//    ULexer.pas        — Tokeniser
//    UAST.pas          — Abstract Syntax Tree node definitions
//    UParser.pas       — Recursive-descent parser
//    UInterpreter.pas  — Tree-walking interpreter / runtime
//    UMainForm.pas        — VCL main form
//    UUnitLoader.pas      — Unit import system (.mdp uses clause)
// =============================================================================

uses
  Vcl.Forms,
  UMainForm in 'UMainForm.pas' {FormMain},
  ULexer in 'ULexer.pas',
  UAST in 'UAST.pas',
  UParser in 'UParser.pas',
  UInterpreter in 'UInterpreter.pas',
  ULearnTab in 'ULearnTab.pas',
  UProjectTab in 'UProjectTab.pas',
  UExampleProjects in 'UExampleProjects.pas',
  UUnitLoader in 'UUnitLoader.pas',
  USQLite in 'USQLite.pas',
  UObjectRuntime in 'UObjectRuntime.pas',
  UValidator in 'UValidator.pas',
  UGraphics in 'UGraphics.pas',
  UAboutDialog in 'UAboutDialog.pas',
  UFormBuilderTab in 'UFormBuilderTab.pas',
  UFormDef in 'UFormDef.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'MiniDelphi Toy Compiler';
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
