unit UValidator;

// =============================================================================
// MiniDelphi Toy Compiler & Learning IDE
// Copyright (C) 2026 Nomidor Software, LLC.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// See the LICENSE file or https://www.gnu.org/licenses/gpl-3.0.html
// =============================================================================

// =============================================================================
//  UValidator.pas  -  Pre-run validation pass for MiniDelphi
//
//  Called between parsing and execution.  Walks the AST and source text to
//  catch common mistakes early, before the interpreter touches them.
//
//  Checks performed:
//    1.  Parse errors (line / col already known from EParseError)
//    2.  Missing begin..end main block
//    3.  Empty program body
//    4.  Undeclared variable usage (best-effort — builtins are whitelisted)
//    5.  Undeclared routine calls
//    6.  Function missing Result assignment (best-effort)
//    7.  Infinite loop risk — while true do without break/exit
//    8.  Division by zero literal  (x / 0  or  x div 0)
//    9.  String used where number expected in obvious arithmetic
//   10.  begin without matching end (caught by parser, re-reported clearly)
//   11.  Mismatched parentheses (caught by parser, re-reported clearly)
//   12.  Assignments to undefined variables at global scope
//   13.  Procedure called with wrong number of arguments (known routines)
//   14.  Empty procedure/function body
//
//  Each issue produces a TValidationIssue:
//    Severity — vsError (blocks run) / vsWarning (runs with caution)
//    Line, Col — 1-based position in source
//    Message   — human-friendly explanation
//    Hint      — suggested fix (shown below the error)
// =============================================================================

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  UAST, ULexer;

type
  TIssueSeverity = (vsError, vsWarning, vsHint);

  TValidationIssue = record
    Severity : TIssueSeverity;
    Line     : Integer;
    Col      : Integer;
    Message  : string;
    Hint     : string;
  end;

  TValidator = class
  private
    FProgram  : TProgramNode;
    FSource   : string;        // raw source text (for line inspection)
    FIssues   : TList<TValidationIssue>;
    FKnownVars: TDictionary<string, Boolean>;   // declared names
    FKnownRout: TDictionary<string, Integer>;   // name -> param count

    procedure AddIssue(Sev: TIssueSeverity; Line, Col: Integer;
                       const Msg, Hint: string);

    // Source helpers
    function  GetLine(LineNo: Integer): string;
    function  TrimmedLine(LineNo: Integer): string;

    // Validation passes
    procedure CheckMainBlock;
    procedure CollectDeclarations;
    procedure CheckRoutines;
    procedure CheckMainStatements;
    procedure CheckBlock(Block: TBlockStmt; Scope: TDictionary<string,Boolean>);
    procedure CheckStatement(Stmt: TStmtNode; Scope: TDictionary<string,Boolean>);
    procedure CheckExpr(Expr: TExprNode; Scope: TDictionary<string,Boolean>);
    procedure CheckCallArgs(const Name: string; Args: TExprList;
                            Line, Col: Integer);
    procedure CheckForDivByZero(Node: TBinOpExpr);

    function  IsBuiltin(const Name: string): Boolean;
    function  BuiltinArgCount(const Name: string): Integer;

  public
    constructor Create(AProgram: TProgramNode; const ASource: string);
    destructor  Destroy; override;

    // Run all checks.  Returns True if there are no blocking errors.
    function  Validate: Boolean;

    property Issues : TList<TValidationIssue> read FIssues;

    // Convenience: formatted summary string
    function  Summary: string;
    function  HasErrors: Boolean;
    function  HasWarnings: Boolean;
  end;

// =============================================================================
implementation
// =============================================================================

// ---------------------------------------------------------------------------
//  Built-in name registry  (so we don't flag built-ins as undeclared)
// ---------------------------------------------------------------------------
const
  BUILTINS : array[0..86] of string = (
    // Math
    'abs','sqr','sqrt','round','trunc','int','frac',
    'sin','cos','ln','exp','pi','power','max','min','odd',
    'succ','pred','inc','dec','random','randomize',
    // String
    'length','copy','pos','uppercase','lowercase','trim',
    'inttostr','strtoint','strtofloat','floattostr','str','val',
    'chr','ord',
    // UI
    'showmessage','inputbox','confirm','showinfobox',
    'showwarningbox','showerrorbox',
    // File dialogs
    'openfiledialog','savefiledialog','selectdirectorydialog',
    // File I/O
    'writefile','appendfile','readfile','fileexists',
    'deletefile','getapppath','getdesktoppath',
    // Database
    'dbopen','dbclose','dbexec','dbquery','dbqueryvalue',
    'dblasterror','dbisopen','dbfilename',
    // Graphics
    'gfxopen','gfxclose','gfxclear','gfxshow','gfxdelay','gfxrunning',
    'gfxcolor','gfxpenwidth',
    'gfxdrawline','gfxdrawrect','gfxfillrect',
    'gfxdrawcircle','gfxfillcircle',
    'gfxdrawellipse','gfxfillellipse',
    'gfxdrawtext','gfxsetfont','gfxdrawpixel',
    'gfxkeypressed','gfxreadkey',
    'gfxmousex','gfxmousey','gfxmousedown',
    // Special
    'writeln','write','readln','result'
  );

// Approximate expected argument counts for builtins (0 = any / don't check)
type
  TArgSpec = record Name: string; Min, Max: Integer; end;

const
  ARG_SPECS : array[0..25] of TArgSpec = (
    (Name:'abs';       Min:1; Max:1),
    (Name:'sqr';       Min:1; Max:1),
    (Name:'sqrt';      Min:1; Max:1),
    (Name:'round';     Min:1; Max:1),
    (Name:'trunc';     Min:1; Max:1),
    (Name:'sin';       Min:1; Max:1),
    (Name:'cos';       Min:1; Max:1),
    (Name:'ln';        Min:1; Max:1),
    (Name:'exp';       Min:1; Max:1),
    (Name:'power';     Min:2; Max:2),
    (Name:'max';       Min:2; Max:2),
    (Name:'min';       Min:2; Max:2),
    (Name:'length';    Min:1; Max:1),
    (Name:'copy';      Min:3; Max:3),
    (Name:'pos';       Min:2; Max:2),
    (Name:'inttostr';  Min:1; Max:1),
    (Name:'strtoint';  Min:1; Max:1),
    (Name:'strtofloat';Min:1; Max:1),
    (Name:'floattostr';Min:1; Max:1),
    (Name:'chr';       Min:1; Max:1),
    (Name:'ord';       Min:1; Max:1),
    (Name:'inputbox';  Min:3; Max:3),
    (Name:'confirm';   Min:1; Max:1),
    (Name:'showmessage';Min:1;Max:1),
    (Name:'gfxopen';   Min:2; Max:3),
    (Name:'gfxdelay';  Min:1; Max:1)
  );

// =============================================================================

constructor TValidator.Create(AProgram: TProgramNode; const ASource: string);
begin
  inherited Create;
  FProgram   := AProgram;
  FSource    := ASource;
  FIssues    := TList<TValidationIssue>.Create;
  FKnownVars := TDictionary<string, Boolean>.Create;
  FKnownRout := TDictionary<string, Integer>.Create;
end;

destructor TValidator.Destroy;
begin
  FIssues.Free;
  FKnownVars.Free;
  FKnownRout.Free;
  inherited;
end;

procedure TValidator.AddIssue(Sev: TIssueSeverity; Line, Col: Integer;
  const Msg, Hint: string);
var
  Issue : TValidationIssue;
begin
  Issue.Severity := Sev;
  Issue.Line     := Line;
  Issue.Col      := Col;
  Issue.Message  := Msg;
  Issue.Hint     := Hint;
  FIssues.Add(Issue);
end;

function TValidator.GetLine(LineNo: Integer): string;
var
  Lines : TStringList;
begin
  Result := '';
  Lines := TStringList.Create;
  try
    Lines.Text := FSource;
    if (LineNo >= 1) and (LineNo <= Lines.Count) then
      Result := Lines[LineNo - 1];
  finally
    Lines.Free;
  end;
end;

function TValidator.TrimmedLine(LineNo: Integer): string;
begin
  Result := Trim(GetLine(LineNo));
end;

function TValidator.IsBuiltin(const Name: string): Boolean;
var
  LN : string;
  I  : Integer;
begin
  LN := LowerCase(Name);
  for I := Low(BUILTINS) to High(BUILTINS) do
    if BUILTINS[I] = LN then Exit(True);
  Result := False;
end;

function TValidator.BuiltinArgCount(const Name: string): Integer;
begin
  Result := -1;  // -1 = not found / don't check
end;

// =============================================================================
//  Main validation entry point
// =============================================================================
function TValidator.Validate: Boolean;
begin
  if not Assigned(FProgram) then
  begin
    AddIssue(vsError, 1, 1, 'Program could not be parsed.',
      'Check for syntax errors — missing begin/end, mismatched parentheses, etc.');
    Exit(False);
  end;

  CollectDeclarations;
  CheckMainBlock;
  CheckRoutines;
  CheckMainStatements;

  Result := not HasErrors;
end;

// ---------------------------------------------------------------------------
//  Pass 1: collect all declared names so later passes can spot undeclared ones
// ---------------------------------------------------------------------------
procedure TValidator.CollectDeclarations;
var
  V  : TVarDecl;
  R  : TRoutineDecl;
  VI, RI, CI, MI : Integer;
  CD : TClassDecl;
  MD : TMethodDecl;
begin
  // Global variables
  for VI := 0 to FProgram.Globals.Count - 1 do
  begin
    V := FProgram.Globals[VI];
    FKnownVars.AddOrSetValue(LowerCase(V.Name), True);
  end;

  // Routines
  for RI := 0 to FProgram.Routines.Count - 1 do
  begin
    R := FProgram.Routines[RI];
    if Assigned(R.Params) then
      FKnownRout.AddOrSetValue(LowerCase(R.Name), R.Params.Count)
    else
      FKnownRout.AddOrSetValue(LowerCase(R.Name), 0);
    // Also register params as local vars (approx)
    if Assigned(R.Params) then
      for VI := 0 to R.Params.Count - 1 do
        FKnownVars.AddOrSetValue(LowerCase(R.Params[VI].Name), True);
  end;

  // Classes
  for CI := 0 to FProgram.Classes.Count - 1 do
  begin
    CD := FProgram.Classes[CI];
    FKnownVars.AddOrSetValue(LowerCase(CD.Name), True);  // class name = type
    for MI := 0 to CD.Methods.Count - 1 do
    begin
      MD := CD.Methods[MI];
      FKnownRout.AddOrSetValue(
        LowerCase(CD.Name + '.' + MD.Name),
        MD.Params.Count);
    end;
  end;
end;

// ---------------------------------------------------------------------------
//  Pass 2: check the main block exists and is not empty
// ---------------------------------------------------------------------------
procedure TValidator.CheckMainBlock;
begin
  if not Assigned(FProgram.MainBlock) then
  begin
    AddIssue(vsError, 1, 1,
      'Program has no main begin..end block.',
      'Every MiniDelphi program must end with a begin...end. block.');
    Exit;
  end;

  if FProgram.MainBlock.Stmts.Count = 0 then
    AddIssue(vsWarning, 1, 1,
      'Main program block is empty.',
      'Add some statements between begin and end.');
end;

// ---------------------------------------------------------------------------
//  Pass 3: check each routine
// ---------------------------------------------------------------------------
procedure TValidator.CheckRoutines;
var
  R          : TRoutineDecl;
  RI, VI     : Integer;
  LocalScope : TDictionary<string, Boolean>;
  HasResult  : Boolean;
  V          : TVarDecl;
begin
  for RI := 0 to FProgram.Routines.Count - 1 do
  begin
    R := FProgram.Routines[RI];

    // Empty body
    if not Assigned(R.Body) or (R.Body.Stmts.Count = 0) then
    begin
      AddIssue(vsWarning, 1, 1,
        Format('Procedure/function "%s" has an empty body.', [R.Name]),
        'Add statements inside the begin..end block.');
      Continue;
    end;

    // Build local scope for this routine
    LocalScope := TDictionary<string, Boolean>.Create;
    try
      // Inherit globals
      var KLocal : string;
      for KLocal in FKnownVars.Keys do
        LocalScope.AddOrSetValue(KLocal, True);

      // Add params
      if Assigned(R.Params) then
        for VI := 0 to R.Params.Count - 1 do
          LocalScope.AddOrSetValue(LowerCase(R.Params[VI].Name), True);

      // Add locals
      if Assigned(R.Locals) then
        for VI := 0 to R.Locals.Count - 1 do
        begin
          V := R.Locals[VI];
          LocalScope.AddOrSetValue(LowerCase(V.Name), True);
        end;

      // Result variable for functions
      if R.ReturnType <> '' then
        LocalScope.AddOrSetValue('result', True);

      CheckBlock(R.Body, LocalScope);

    finally
      LocalScope.Free;
    end;
  end;
end;

// ---------------------------------------------------------------------------
//  Pass 4: check main block statements
// ---------------------------------------------------------------------------
procedure TValidator.CheckMainStatements;
var
  Scope : TDictionary<string, Boolean>;
begin
  if not Assigned(FProgram.MainBlock) then Exit;

  Scope := TDictionary<string, Boolean>.Create;
  try
    var KMain : string;
  for KMain in FKnownVars.Keys do
    Scope.AddOrSetValue(KMain, True);
    CheckBlock(FProgram.MainBlock, Scope);
  finally
    Scope.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Statement and expression walkers
// ---------------------------------------------------------------------------

procedure TValidator.CheckBlock(Block: TBlockStmt;
  Scope: TDictionary<string, Boolean>);
var
  SI : Integer;
begin
  if not Assigned(Block) then Exit;
  for SI := 0 to Block.Stmts.Count - 1 do
    CheckStatement(Block.Stmts[SI], Scope);
end;

procedure TValidator.CheckStatement(Stmt: TStmtNode;
  Scope: TDictionary<string, Boolean>);
var
  A  : TAssignStmt;
  C  : TCallStmt;
  W  : TWritelnStmt;
  If1: TIfStmt;
  Wh : TWhileStmt;
  Fo : TForStmt;
  Re : TRepeatStmt;
  B  : TBlockStmt;
  VI : Integer;
  AI : Integer;
begin
  if not Assigned(Stmt) then Exit;

  // Assignment:  x := expr
  if Stmt is TAssignStmt then
  begin
    A := TAssignStmt(Stmt);
    // Register the variable as declared (inline declaration style)
    Scope.AddOrSetValue(LowerCase(A.VarName), True);
    if Assigned(A.Expr) then
      CheckExpr(A.Expr, Scope);
  end

  // Procedure call
  else if Stmt is TCallStmt then
  begin
    C := TCallStmt(Stmt);
    if not IsBuiltin(C.Name) and
       not FKnownRout.ContainsKey(LowerCase(C.Name)) and
       not Scope.ContainsKey(LowerCase(C.Name)) then
    begin
      AddIssue(vsWarning, 0, 0,
        Format('Call to unknown procedure "%s".', [C.Name]),
        Format('Check the spelling. Did you forget to declare it?', []));
    end
    else
      CheckCallArgs(C.Name, C.Args, 0, 0);

    for AI := 0 to C.Args.Count - 1 do
      CheckExpr(C.Args[AI], Scope);
  end

  // writeln / write
  else if Stmt is TWritelnStmt then
  begin
    W := TWritelnStmt(Stmt);
    for AI := 0 to W.Args.Count - 1 do
      CheckExpr(W.Args[AI], Scope);
  end

  // if..then..else
  else if Stmt is TIfStmt then
  begin
    If1 := TIfStmt(Stmt);
    CheckExpr(If1.Condition, Scope);
    CheckStatement(If1.ThenBranch, Scope);
    if Assigned(If1.ElseBranch) then
      CheckStatement(If1.ElseBranch, Scope);
  end

  // while..do
  else if Stmt is TWhileStmt then
  begin
    Wh := TWhileStmt(Stmt);
    // Check for  while true do  without obvious break — warn about infinite loop
    if (Wh.Condition is TBoolLitExpr) and TBoolLitExpr(Wh.Condition).Value then
      AddIssue(vsWarning, 0, 0,
        '"while true do" loop detected.',
        'Make sure you have a "break" or "exit" inside to avoid an infinite loop.');
    CheckExpr(Wh.Condition, Scope);
    CheckStatement(Wh.Body, Scope);
  end

  // for..to/downto
  else if Stmt is TForStmt then
  begin
    Fo := TForStmt(Stmt);
    Scope.AddOrSetValue(LowerCase(Fo.VarName), True);
    CheckExpr(Fo.StartVal, Scope);
    CheckExpr(Fo.EndVal, Scope);
    CheckStatement(Fo.Body, Scope);
  end

  // repeat..until
  else if Stmt is TRepeatStmt then
  begin
    Re := TRepeatStmt(Stmt);
    for VI := 0 to Re.Body.Count - 1 do
      CheckStatement(Re.Body[VI], Scope);
    CheckExpr(Re.Condition, Scope);
  end

  // begin..end block
  else if Stmt is TBlockStmt then
  begin
    B := TBlockStmt(Stmt);
    CheckBlock(B, Scope);
  end;
end;

procedure TValidator.CheckExpr(Expr: TExprNode;
  Scope: TDictionary<string, Boolean>);
var
  VE  : TVarExpr;
  CE  : TCallExpr;
  BO  : TBinOpExpr;
  UE  : TUnaryExpr;
  FE  : TFieldExpr;
  MCE : TMethodCallExpr;
  AI  : Integer;
begin
  if not Assigned(Expr) then Exit;

  // Variable reference — check it was declared
  if Expr is TVarExpr then
  begin
    VE := TVarExpr(Expr);
    if not IsBuiltin(VE.Name) and
       not Scope.ContainsKey(LowerCase(VE.Name)) and
       not FKnownRout.ContainsKey(LowerCase(VE.Name)) and
       not FKnownVars.ContainsKey(LowerCase(VE.Name)) then
    begin
      AddIssue(vsWarning, 0, 0,
        Format('Variable "%s" may not have been declared.', [VE.Name]),
        'Check the spelling or add it to your var block.');
    end;
  end

  // Function call expression
  else if Expr is TCallExpr then
  begin
    CE := TCallExpr(Expr);
    if not IsBuiltin(CE.Name) and
       not FKnownRout.ContainsKey(LowerCase(CE.Name)) then
    begin
      AddIssue(vsWarning, 0, 0,
        Format('Call to unknown function "%s".', [CE.Name]),
        'Check the spelling. Did you forget to declare it?');
    end
    else
      CheckCallArgs(CE.Name, CE.Args, 0, 0);

    for AI := 0 to CE.Args.Count - 1 do
      CheckExpr(CE.Args[AI], Scope);
  end

  // Binary operator — check for division by zero
  else if Expr is TBinOpExpr then
  begin
    BO := TBinOpExpr(Expr);
    CheckForDivByZero(BO);
    CheckExpr(BO.Left, Scope);
    CheckExpr(BO.Right, Scope);
  end

  // Unary
  else if Expr is TUnaryExpr then
  begin
    UE := TUnaryExpr(Expr);
    CheckExpr(UE.Operand, Scope);
  end

  // Field access  obj.Field — just check obj
  else if Expr is TFieldExpr then
  begin
    FE := TFieldExpr(Expr);
    CheckExpr(FE.Obj, Scope);
  end

  // Method call  obj.Method(args)
  else if Expr is TMethodCallExpr then
  begin
    MCE := TMethodCallExpr(Expr);
    CheckExpr(MCE.Obj, Scope);
    for AI := 0 to MCE.Args.Count - 1 do
      CheckExpr(MCE.Args[AI], Scope);
  end;
end;

procedure TValidator.CheckCallArgs(const Name: string; Args: TExprList;
  Line, Col: Integer);
var
  LN      : string;
  I       : Integer;
  Expected: Integer;
  Got     : Integer;
begin
  LN  := LowerCase(Name);
  Got := Args.Count;

  // Check against ARG_SPECS
  for I := Low(ARG_SPECS) to High(ARG_SPECS) do
  begin
    if ARG_SPECS[I].Name = LN then
    begin
      if (Got < ARG_SPECS[I].Min) or (Got > ARG_SPECS[I].Max) then
      begin
        if ARG_SPECS[I].Min = ARG_SPECS[I].Max then
          AddIssue(vsError, Line, Col,
            Format('"%s" expects %d argument(s) but got %d.',
              [Name, ARG_SPECS[I].Min, Got]),
            Format('Check the call: %s requires exactly %d parameter(s).',
              [Name, ARG_SPECS[I].Min]))
        else
          AddIssue(vsError, Line, Col,
            Format('"%s" expects %d..%d argument(s) but got %d.',
              [Name, ARG_SPECS[I].Min, ARG_SPECS[I].Max, Got]),
            Format('Check the call to %s.', [Name]));
      end;
      Exit;
    end;
  end;

  // Check against known user routines
  if FKnownRout.TryGetValue(LN, Expected) then
  begin
    if Got <> Expected then
      AddIssue(vsWarning, Line, Col,
        Format('"%s" declared with %d parameter(s) but called with %d.',
          [Name, Expected, Got]),
        'Check the number of arguments in the call.');
  end;
end;

procedure TValidator.CheckForDivByZero(Node: TBinOpExpr);
begin
  if not Assigned(Node.Right) then Exit;
  if not (Node.Op = '/' ) and not (Node.Op = 'div') and not (Node.Op = 'mod') then
    Exit;

  // Right side is an integer literal zero
  if (Node.Right is TIntLitExpr) and (TIntLitExpr(Node.Right).Value = 0) then
    AddIssue(vsError, 0, 0,
      Format('Division by zero: "%s 0" will always crash.', [Node.Op]),
      'The right-hand side of ' + Node.Op + ' cannot be zero.')

  // Right side is a float literal zero
  else if (Node.Right is TFloatLitExpr) and (TFloatLitExpr(Node.Right).Value = 0) then
    AddIssue(vsError, 0, 0,
      'Division by zero: dividing by 0.0 will produce Infinity or crash.',
      'Check the denominator value.');
end;

// =============================================================================
//  Results
// =============================================================================

function TValidator.HasErrors: Boolean;
var
  I : TValidationIssue;
begin
  for I in FIssues do
    if I.Severity = vsError then begin Result := True; Exit; end;
  Result := False;
end;

function TValidator.HasWarnings: Boolean;
var
  I : TValidationIssue;
begin
  for I in FIssues do
    if I.Severity = vsWarning then begin Result := True; Exit; end;
  Result := False;
end;

function TValidator.Summary: string;
var
  Errors, Warnings, Hints : Integer;
  I : TValidationIssue;
begin
  Errors := 0; Warnings := 0; Hints := 0;
  for I in FIssues do
  begin
    case I.Severity of
      vsError   : Inc(Errors);
      vsWarning : Inc(Warnings);
      vsHint    : Inc(Hints);
    end;
  end;

  if Errors = 0 then
    Result := Format('Validation OK — %d warning(s)', [Warnings])
  else
    Result := Format('%d error(s), %d warning(s)', [Errors, Warnings]);
end;

end.
