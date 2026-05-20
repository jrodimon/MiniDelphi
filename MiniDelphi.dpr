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
//    UTheme.pas           — VCL Styles theme wrapper
//    UPreferencesDialog.pas — Theme preference dialog
// =============================================================================
uses
  Vcl.Forms,
  UTheme in 'UTheme.pas',
  UPreferencesDialog in 'UPreferencesDialog.pas',
  UMainForm in 'UMainForm.pas' {FormMain},
  ULexer in 'ULexer.pas',
  UAST in 'UAST.pas',
  UParser in 'UParser.pas',
  UInterpreter in 'UInterpreter.pas',
  ULearnTab in 'ULearnTab.pas',
  UProjectTab in 'UProjectTab.pas',
  UMacroLibrary in 'UMacroLibrary.pas',
  UExampleProjects in 'UExampleProjects.pas',
  UUnitLoader in 'UUnitLoader.pas',
  USQLite in 'USQLite.pas',
  UObjectRuntime in 'UObjectRuntime.pas',
  UValidator in 'UValidator.pas',
  UGraphics in 'UGraphics.pas',
  UAboutDialog in 'UAboutDialog.pas',
  UFormBuilderTab in 'UFormBuilderTab.pas',
  UFormDef in 'UFormDef.pas',
  UMacroTab in 'UMacroTab.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}
begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Iceberg Classico');
  Application.Title := 'MiniDelphi Toy Compiler';

  // Apply theme BEFORE creating any forms so VCL Styles paints correctly.
  Theme.Load;

  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
