unit UInterpreter;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  UInterpreter.pas  -  Tree-walking interpreter for MiniDelphi
//  Walks the AST produced by TParser and executes each node directly.
//  No machine code is generated — this IS the "runtime".
// =============================================================================

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.UITypes,
  System.Math, System.IOUtils, System.Win.Registry,
  UUnitLoader,
  USQLite,
  UObjectRuntime,
  UGraphics,
  Winapi.Windows,
  Vcl.Dialogs, Vcl.Forms, Vcl.FileCtrl,
  UAST;

type

  // -------------------------------------------------------------------
  //  The three possible types a MiniDelphi value can have at runtime
  // -------------------------------------------------------------------
  TValueKind = (vkInt, vkFloat, vkString, vkBool, vkNil, vkObject);

  TValue = record
    // *** All fields MUST come before methods in a Delphi record ***
    Kind    : TValueKind;
    IVal    : Int64;
    FVal    : Double;
    SVal    : string;
    BVal    : Boolean;
    ObjVal  : TObjectInstance;   // for vkObject — must be here with other fields

    class function MakeInt   (V: Int64)           : TValue; static;
    class function MakeFloat (V: Double)          : TValue; static;
    class function MakeStr   (V: string)          : TValue; static;
    class function MakeBool  (V: Boolean)         : TValue; static;
    class function MakeNil                        : TValue; static;
    class function MakeObject(V: TObjectInstance) : TValue; static;
    function  ToStr    : string;
    function  ToFloat  : Double;
    function  ToInt    : Int64;
    function  ToBool   : Boolean;
  end;

  // -------------------------------------------------------------------
  //  Special exceptions used for control flow
  // -------------------------------------------------------------------
  EBreakSignal    = class(Exception);
  EContinueSignal = class(Exception);
  EExitSignal     = class(Exception)
  public
    ReturnVal : TValue;
    constructor Create(const V: TValue);
  end;

  // -------------------------------------------------------------------
  //  Variable store — a simple name→value dictionary
  // -------------------------------------------------------------------
  TEnvironment = class
  private
    FVars   : TDictionary<string, TValue>;
    FParent : TEnvironment;  // enclosing scope (nil for global)
  public
    constructor Create(AParent: TEnvironment = nil);
    destructor  Destroy; override;

    procedure SetVar(const Name: string; const Val: TValue);
    function  GetVar(const Name: string; out Val: TValue): Boolean;
    function  HasVar(const Name: string): Boolean;
    // Force-set in this frame even if it exists in parent
    procedure DeclareVar(const Name: string; const Val: TValue);
  end;

  // -------------------------------------------------------------------
  //  Stored routine (procedure or function)
  // -------------------------------------------------------------------
  TRoutineEntry = record
    Decl : TRoutineDecl;  // pointer into AST; NOT owned here
  end;

  // Type aliases so generic parameters resolve cleanly in the class declaration
  TVarDeclList   = TObjectList<TVarDecl>;
  TRoutineDeclMap= TDictionary<string, TRoutineDecl>;

  // -------------------------------------------------------------------
  //  The Interpreter
  // -------------------------------------------------------------------
  TInterpreter = class
  private
    FProgram   : TProgramNode;
    FGlobal    : TEnvironment;
    FRoutines  : TRoutineDeclMap;
    FOutput    : TStrings;          // where writeln output goes
    FInputLine : string;            // single pre-set input line for readln
    FMaxSteps  : Int64;             // safety step counter limit
    FSteps     : Int64;
    FSourcePath: string;               // folder of the .mdp file (for unit loading)
    FSourceText: string;               // raw source (so loader can scan uses clause)

    procedure Tick;
    procedure RegisterRoutines;
    procedure DeclareVars(Env: TEnvironment; Decls: TVarDeclList);

    // Statement execution
    procedure ExecBlock      (Node: TBlockStmt;   Env: TEnvironment);
    procedure ExecStmt       (Node: TStmtNode;    Env: TEnvironment);
    procedure ExecAssign     (Node: TAssignStmt;  Env: TEnvironment);
    procedure ExecWriteln    (Node: TWritelnStmt; Env: TEnvironment);
    procedure ExecReadln     (Node: TReadlnStmt;  Env: TEnvironment);
    procedure ExecIf         (Node: TIfStmt;      Env: TEnvironment);
    procedure ExecWhile      (Node: TWhileStmt;   Env: TEnvironment);
    procedure ExecRepeat     (Node: TRepeatStmt;  Env: TEnvironment);
    procedure ExecFor        (Node: TForStmt;     Env: TEnvironment);
    procedure ExecCall       (Node: TCallStmt;    Env: TEnvironment);
    procedure ExecExit       (Node: TExitStmt;    Env: TEnvironment);
    procedure ExecCase           (Node: TCaseStmt;        Env: TEnvironment);
    procedure ExecCaseOf         (Node: TCaseOfStmt;      Env: TEnvironment);
    // OOP execution
    procedure ExecFieldAssign    (Node: TFieldAssignStmt; Env: TEnvironment);
    procedure ExecMethodCall     (Node: TMethodCallStmt;  Env: TEnvironment);
    procedure ExecInherited      (Node: TInheritedCallStmt; Env: TEnvironment);
    function  EvalFieldExpr      (Node: TFieldExpr;       Env: TEnvironment) : TValue;
    function  EvalMethodCallExpr (Node: TMethodCallExpr;  Env: TEnvironment) : TValue;
    function  EvalCreateExpr     (Node: TCreateExpr;      Env: TEnvironment) : TValue;
    function  EvalIsExpr         (Obj: TValue; const TypeName: string) : TValue;
    function  InvokeMethod       (Obj: TObjectInstance; M: TMethodDecl;
                                  Args: TExprList; CallerEnv: TEnvironment) : TValue;
    procedure InitObjectFields   (Obj: TObjectInstance);

    // Expression evaluation
    function  EvalExpr       (Node: TExprNode;    Env: TEnvironment) : TValue;
    function  EvalBinOp      (Node: TBinOpExpr;   Env: TEnvironment) : TValue;
    function  EvalUnary      (Node: TUnaryExpr;   Env: TEnvironment) : TValue;
    function  EvalCallExpr   (Node: TCallExpr;    Env: TEnvironment) : TValue;

    // Call a named routine; returns its Result value
    function  CallRoutine(const Name: string; Args: TExprList;
                          CallerEnv: TEnvironment) : TValue;

    // Built-in functions
    function  CallBuiltin(const Name: string; Args: TExprList;
                          CallerEnv: TEnvironment; out Val: TValue) : Boolean;

    procedure Output(const S: string);

  public
    constructor Create(AProgram: TProgramNode; AOutput: TStrings);
    destructor  Destroy; override;

    // Run the program; raises on error or step limit
    procedure Run;

    // Optionally pre-load a string that readln will consume
    property InputLine   : string  read FInputLine   write FInputLine;
    property MaxSteps    : Int64   read FMaxSteps    write FMaxSteps;
    // Set these before Run so the unit loader can find imported .mdp files
    property SourcePath  : string  read FSourcePath  write FSourcePath;
    property SourceText  : string  read FSourceText  write FSourceText;
  end;

// =============================================================================
implementation
// =============================================================================

function IfThenInt(B: Boolean; T, F: Integer): Integer; forward;

{ TValue }

class function TValue.MakeInt(V: Int64): TValue;
begin
  Result.Kind := vkInt;
  Result.IVal := V;
  Result.FVal := V;
  Result.SVal := '';
  Result.BVal := False;
end;

class function TValue.MakeFloat(V: Double): TValue;
begin
  Result.Kind := vkFloat;
  Result.IVal := Round(V);
  Result.FVal := V;
  Result.SVal := '';
  Result.BVal := False;
end;

class function TValue.MakeStr(V: string): TValue;
begin
  Result.Kind := vkString;
  Result.IVal := 0;
  Result.FVal := 0;
  Result.SVal := V;
  Result.BVal := False;
end;

class function TValue.MakeBool(V: Boolean): TValue;
begin
  Result.Kind := vkBool;
  Result.IVal := Ord(V);
  Result.FVal := 0;
  Result.SVal := '';
  Result.BVal := V;
end;

class function TValue.MakeObject(V: TObjectInstance): TValue;
begin
  Result.Kind   := vkObject;
  Result.IVal   := 0;
  Result.FVal   := 0;
  Result.SVal   := '';
  Result.BVal   := False;
  Result.ObjVal := V;
end;

class function TValue.MakeNil: TValue;
begin
  Result.Kind := vkNil;
  Result.IVal := 0;
  Result.FVal := 0;
  Result.SVal := '';
  Result.BVal := False;
end;

function TValue.ToStr: string;
begin
  case Kind of
    vkInt    : Result := IntToStr(IVal);
    vkFloat  : Result := FloatToStr(FVal);
    vkString : Result := SVal;
    vkBool   : if BVal then Result := 'True' else Result := 'False';
    vkNil    : Result := 'nil';
    vkObject : if Assigned(ObjVal) then
                 Result := '[' + ObjVal.ObjClass + ' object]'
               else
                 Result := 'nil';
  end;
end;

function TValue.ToFloat: Double;
begin
  case Kind of
    vkInt    : Result := IVal;
    vkFloat  : Result := FVal;
    vkString : Result := StrToFloatDef(SVal, 0);
    vkBool   : Result := Ord(BVal);
  else         Result := 0;
  end;
end;

function TValue.ToInt: Int64;
begin
  case Kind of
    vkInt    : Result := IVal;
    vkFloat  : Result := Round(FVal);
    vkString : Result := StrToInt64Def(SVal, 0);
    vkBool   : Result := Ord(BVal);
  else         Result := 0;
  end;
end;

function TValue.ToBool: Boolean;
begin
  case Kind of
    vkBool   : Result := BVal;
    vkInt    : Result := IVal <> 0;
    vkFloat  : Result := FVal <> 0;
    vkString : Result := SVal <> '';
  else         Result := False;
  end;
end;

{ EExitSignal }
constructor EExitSignal.Create(const V: TValue);
begin
  inherited Create('exit');
  ReturnVal := V;
end;

{ TEnvironment }
constructor TEnvironment.Create(AParent: TEnvironment);
begin
  inherited Create;
  FVars   := TDictionary<string, TValue>.Create;
  FParent := AParent;
end;

destructor TEnvironment.Destroy;
begin
  FVars.Free;
  inherited;
end;

procedure TEnvironment.DeclareVar(const Name: string; const Val: TValue);
begin
  FVars.AddOrSetValue(LowerCase(Name), Val);
end;

procedure TEnvironment.SetVar(const Name: string; const Val: TValue);
var
  Key : string;
begin
  Key := LowerCase(Name);
  if FVars.ContainsKey(Key) then
    FVars[Key] := Val
  else if Assigned(FParent) then
    FParent.SetVar(Name, Val)
  else
    FVars.AddOrSetValue(Key, Val);  // auto-declare at global level
end;

function TEnvironment.GetVar(const Name: string; out Val: TValue): Boolean;
var
  Key : string;
begin
  Key    := LowerCase(Name);
  Result := FVars.TryGetValue(Key, Val);
  if (not Result) and Assigned(FParent) then
    Result := FParent.GetVar(Name, Val);
end;

function TEnvironment.HasVar(const Name: string): Boolean;
var
  Dummy : TValue;
begin
  Result := GetVar(Name, Dummy);
end;

{ TInterpreter }

constructor TInterpreter.Create(AProgram: TProgramNode; AOutput: TStrings);
begin
  inherited Create;
  FProgram  := AProgram;
  FOutput   := AOutput;
  FGlobal   := TEnvironment.Create;
  FRoutines := TRoutineDeclMap.Create;
  FMaxSteps := 1000000;   // safety limit
  FSteps    := 0;
end;

destructor TInterpreter.Destroy;
begin
  FGlobal.Free;
  FRoutines.Free;
  inherited;
end;

procedure TInterpreter.Output(const S: string);
begin
  if Assigned(FOutput) then
    FOutput.Add(S);
end;

procedure TInterpreter.Tick;
begin
  Inc(FSteps);
  if FSteps > FMaxSteps then
    raise Exception.Create('Step limit reached — possible infinite loop');
end;

procedure TInterpreter.RegisterRoutines;
var
  R   : TRoutineDecl;
  RRI : Integer;
begin
  for RRI := 0 to FProgram.Routines.Count - 1 do
    FRoutines.AddOrSetValue(LowerCase(FProgram.Routines[RRI].Name), FProgram.Routines[RRI]);
end;

procedure TInterpreter.DeclareVars(Env: TEnvironment; Decls: TVarDeclList);
var
  D   : TVarDecl;
  Val : TValue;
  TN  : string;
  DVI : Integer;
begin
  for DVI := 0 to Decls.Count - 1 do
  begin
    D := Decls[DVI];
    if Assigned(D.InitExpr) then
      Val := EvalExpr(D.InitExpr, Env)
    else
    begin
      TN := LowerCase(D.TypeName);
      if      TN = 'integer' then Val := TValue.MakeInt(0)
      else if TN = 'real'    then Val := TValue.MakeFloat(0)
      else if TN = 'string'  then Val := TValue.MakeStr('')
      else if TN = 'boolean' then Val := TValue.MakeBool(False)
      else                        Val := TValue.MakeNil;
    end;
    Env.DeclareVar(D.Name, Val);
  end;
end;

procedure TInterpreter.Run;
var
  Loader : TUnitLoader;
  I      : Integer;
begin
  FSteps := 0;

  // Register classes and interfaces with the global registry
  InitClassRegistry;
  ClassRegistry.RegisterProgram(FProgram);

  // Load imported units if the source path is known
  if FSourcePath <> '' then
  begin
    Loader := TUnitLoader.Create(FSourcePath);
    try
      // Pass the main program's source so we can scan its uses clause.
      // We get it by re-reading from the program's own token origin — but
      // the simplest approach is to let the caller set SourcePath, then
      // the loader resolves filenames relative to that folder.
      // We load using the program name stored in the AST.
      Loader.LoadUnits(FSourceText);   // scan uses clause of the main source
      if Loader.HasUnits then
        Loader.MergeInto(FProgram);
      // Report any loading errors to output but don't abort
      if Loader.Errors.Count > 0 then
        for I := 0 to Loader.Errors.Count - 1 do
          Output('*** Unit load warning: ' + Loader.Errors[I]);
    finally
      Loader.Free;
    end;
  end;

  RegisterRoutines;
  DeclareVars(FGlobal, FProgram.Globals);
  if Assigned(FProgram.MainBlock) then
  try
    ExecBlock(FProgram.MainBlock, FGlobal);
  except
    on EExitSignal do ;  // top-level exit — normal termination
  end;
end;

// ---------------------------------------------------------------------------
//  Statement execution
// ---------------------------------------------------------------------------

procedure TInterpreter.ExecBlock(Node: TBlockStmt; Env: TEnvironment);
var
  S  : TStmtNode;
  BI : Integer;
begin
  for BI := 0 to Node.Stmts.Count - 1 do
  begin
    S := Node.Stmts[BI];
    Tick;
    ExecStmt(S, Env);
  end;
end;

procedure TInterpreter.ExecStmt(Node: TStmtNode; Env: TEnvironment);
begin
  if Node is TBlockStmt    then ExecBlock  (TBlockStmt(Node),   Env) else
  if Node is TAssignStmt   then ExecAssign (TAssignStmt(Node),  Env) else
  if Node is TWritelnStmt  then ExecWriteln(TWritelnStmt(Node), Env) else
  if Node is TReadlnStmt   then ExecReadln (TReadlnStmt(Node),  Env) else
  if Node is TIfStmt       then ExecIf     (TIfStmt(Node),      Env) else
  if Node is TWhileStmt    then ExecWhile  (TWhileStmt(Node),   Env) else
  if Node is TRepeatStmt   then ExecRepeat (TRepeatStmt(Node),  Env) else
  if Node is TForStmt      then ExecFor    (TForStmt(Node),     Env) else
  if Node is TCallStmt     then ExecCall   (TCallStmt(Node),    Env) else
  if Node is TExitStmt     then ExecExit   (TExitStmt(Node),    Env) else
  if Node is TBreakStmt    then raise EBreakSignal.Create('')        else
  if Node is TContinueStmt then raise EContinueSignal.Create('') else
  if Node is TCaseStmt         then ExecCase       (TCaseStmt(Node),         Env) else
  if Node is TCaseOfStmt       then ExecCaseOf     (TCaseOfStmt(Node),       Env) else
  if Node is TFieldAssignStmt  then ExecFieldAssign(TFieldAssignStmt(Node),  Env) else
  if Node is TMethodCallStmt   then ExecMethodCall (TMethodCallStmt(Node),   Env) else
  if Node is TInheritedCallStmt then ExecInherited (TInheritedCallStmt(Node), Env);
end;

procedure TInterpreter.ExecAssign(Node: TAssignStmt; Env: TEnvironment);
begin
  Env.SetVar(Node.VarName, EvalExpr(Node.Expr, Env));
end;

procedure TInterpreter.ExecWriteln(Node: TWritelnStmt; Env: TEnvironment);
var
  S   : string;
  Val : TValue;
  WI  : Integer;
begin
  S := '';
  for WI := 0 to Node.Args.Count - 1 do
  begin
    Val := EvalExpr(Node.Args[WI], Env);
    S   := S + Val.ToStr;
  end;
  if Node.NewLine then
    Output(S)
  else
  begin
    // write without newline — append to last line if possible
    if FOutput.Count > 0 then
      FOutput[FOutput.Count - 1] := FOutput[FOutput.Count - 1] + S
    else
      Output(S);
  end;
end;

procedure TInterpreter.ExecReadln(Node: TReadlnStmt; Env: TEnvironment);
begin
  // In this toy we use a pre-set input string; in a real UI you would
  // prompt the user via an InputBox.  For now, consume FInputLine.
  if Node.VarName <> '' then
    Env.SetVar(Node.VarName, TValue.MakeStr(FInputLine));
end;

procedure TInterpreter.ExecIf(Node: TIfStmt; Env: TEnvironment);
begin
  if EvalExpr(Node.Condition, Env).ToBool then
    ExecStmt(Node.ThenBranch, Env)
  else if Assigned(Node.ElseBranch) then
    ExecStmt(Node.ElseBranch, Env);
end;

procedure TInterpreter.ExecWhile(Node: TWhileStmt; Env: TEnvironment);
begin
  try
    while EvalExpr(Node.Condition, Env).ToBool do
    begin
      Tick;
      try
        ExecStmt(Node.Body, Env);
      except
        on EContinueSignal do ; // continue — just re-evaluate condition
      end;
    end;
  except
    on EBreakSignal do ; // break — exit loop silently
  end;
end;

procedure TInterpreter.ExecRepeat(Node: TRepeatStmt; Env: TEnvironment);
var
  S  : TStmtNode;
  RI : Integer;
begin
  try
    repeat
      Tick;
      try
        for RI := 0 to Node.Body.Count - 1 do
        begin
          S := Node.Body[RI];
          Tick;
          ExecStmt(S, Env);
        end;
      except
        on EContinueSignal do ; // continue
      end;
    until EvalExpr(Node.Condition, Env).ToBool;
  except
    on EBreakSignal do ;
  end;
end;

procedure TInterpreter.ExecFor(Node: TForStmt; Env: TEnvironment);
var
  Start, Finish, I : Int64;
begin
  Start  := EvalExpr(Node.StartVal, Env).ToInt;
  Finish := EvalExpr(Node.EndVal,   Env).ToInt;
  Env.SetVar(Node.VarName, TValue.MakeInt(Start));
  I := Start;
  try
    if not Node.IsDownTo then
    begin
      while I <= Finish do
      begin
        Tick;
        Env.SetVar(Node.VarName, TValue.MakeInt(I));
        try
          ExecStmt(Node.Body, Env);
        except
          on EContinueSignal do ;
        end;
        Inc(I);
      end;
    end
    else
    begin
      while I >= Finish do
      begin
        Tick;
        Env.SetVar(Node.VarName, TValue.MakeInt(I));
        try
          ExecStmt(Node.Body, Env);
        except
          on EContinueSignal do ;
        end;
        Dec(I);
      end;
    end;
  except
    on EBreakSignal do ;
  end;
end;

procedure TInterpreter.ExecCall(Node: TCallStmt; Env: TEnvironment);
var
  Dummy : TValue;
begin
  // Try built-ins first, then user routines
  if not CallBuiltin(Node.Name, Node.Args, Env, Dummy) then
    CallRoutine(Node.Name, Node.Args, Env);
end;

procedure TInterpreter.ExecExit(Node: TExitStmt; Env: TEnvironment);
var
  Val : TValue;
begin
  if Assigned(Node.Expr) then
    Val := EvalExpr(Node.Expr, Env)
  else
    Val := TValue.MakeNil;
  raise EExitSignal.Create(Val);
end;

// ---------------------------------------------------------------------------
//  Expression evaluation
// ---------------------------------------------------------------------------

function TInterpreter.EvalExpr(Node: TExprNode; Env: TEnvironment): TValue;
var
  EmptyArgs : TExprList;
begin
  Tick;
  if Node is TIntLitExpr   then Result := TValue.MakeInt  (TIntLitExpr(Node).Value)  else
  if Node is TFloatLitExpr then Result := TValue.MakeFloat(TFloatLitExpr(Node).Value) else
  if Node is TStrLitExpr   then Result := TValue.MakeStr  (TStrLitExpr(Node).Value)  else
  if Node is TBoolLitExpr  then Result := TValue.MakeBool (TBoolLitExpr(Node).Value) else
  if Node is TNilLitExpr   then Result := TValue.MakeNil                              else

  if Node is TVarExpr then
  begin
    if not Env.GetVar(TVarExpr(Node).Name, Result) then
    begin
      // Not a variable — try as a zero-argument builtin (e.g. GfxRunning, Pi)
      EmptyArgs := TExprList.Create(False);
      try
        if not CallBuiltin(TVarExpr(Node).Name, EmptyArgs, Env, Result) then
          Result := TValue.MakeNil;
      finally
        EmptyArgs.Free;
      end;
    end;
  end else

  if Node is TBinOpExpr      then Result := EvalBinOp        (TBinOpExpr(Node),      Env) else
  if Node is TUnaryExpr      then Result := EvalUnary        (TUnaryExpr(Node),      Env) else
  if Node is TCallExpr       then Result := EvalCallExpr     (TCallExpr(Node),       Env) else
  if Node is TFieldExpr      then Result := EvalFieldExpr    (TFieldExpr(Node),      Env) else
  if Node is TMethodCallExpr then Result := EvalMethodCallExpr(TMethodCallExpr(Node), Env) else
  if Node is TCreateExpr     then Result := EvalCreateExpr   (TCreateExpr(Node),     Env)
  else
    Result := TValue.MakeNil;
end;

function TInterpreter.EvalBinOp(Node: TBinOpExpr; Env: TEnvironment): TValue;
var
  L, R : TValue;
  BothNumeric, EitherFloat : Boolean;
begin
  L := EvalExpr(Node.Left, Env);

  // Short-circuit for and/or
  if Node.Op = 'and' then
  begin
    if not L.ToBool then Exit(TValue.MakeBool(False));
    Exit(TValue.MakeBool(EvalExpr(Node.Right, Env).ToBool));
  end;
  if Node.Op = 'or' then
  begin
    if L.ToBool then Exit(TValue.MakeBool(True));
    Exit(TValue.MakeBool(EvalExpr(Node.Right, Env).ToBool));
  end;

  R := EvalExpr(Node.Right, Env);

  BothNumeric  := (L.Kind in [vkInt, vkFloat]) and (R.Kind in [vkInt, vkFloat]);
  EitherFloat  := (L.Kind = vkFloat) or (R.Kind = vkFloat);

  // String concatenation with +
  if (Node.Op = '+') and ((L.Kind = vkString) or (R.Kind = vkString)) then
    Exit(TValue.MakeStr(L.ToStr + R.ToStr));

  case Node.Op[1] of
    '+': if BothNumeric then
           if EitherFloat then Result := TValue.MakeFloat(L.ToFloat + R.ToFloat)
           else                Result := TValue.MakeInt  (L.ToInt   + R.ToInt);
    '-': if BothNumeric then
           if EitherFloat then Result := TValue.MakeFloat(L.ToFloat - R.ToFloat)
           else                Result := TValue.MakeInt  (L.ToInt   - R.ToInt);
    '*': if BothNumeric then
           if EitherFloat then Result := TValue.MakeFloat(L.ToFloat * R.ToFloat)
           else                Result := TValue.MakeInt  (L.ToInt   * R.ToInt);
    '/':                       Result := TValue.MakeFloat(L.ToFloat / R.ToFloat);
    '=': if L.Kind = vkString then Result := TValue.MakeBool(L.SVal  =  R.SVal)
         else                       Result := TValue.MakeBool(L.ToFloat = R.ToFloat);
    '<': if Node.Op = '<>' then
         begin
           if L.Kind = vkString then Result := TValue.MakeBool(L.SVal <> R.SVal)
           else                       Result := TValue.MakeBool(L.ToFloat <> R.ToFloat);
         end
         else if Node.Op = '<=' then
           Result := TValue.MakeBool(L.ToFloat <= R.ToFloat)
         else
           Result := TValue.MakeBool(L.ToFloat < R.ToFloat);
    '>': if Node.Op = '>=' then
           Result := TValue.MakeBool(L.ToFloat >= R.ToFloat)
         else
           Result := TValue.MakeBool(L.ToFloat > R.ToFloat);
    'd': // div
         if R.ToInt <> 0 then Result := TValue.MakeInt(L.ToInt div R.ToInt)
         else raise Exception.Create('Division by zero (div)');
    'm': // mod
         if R.ToInt <> 0 then Result := TValue.MakeInt(L.ToInt mod R.ToInt)
         else raise Exception.Create('Division by zero (mod)');
  else
    Result := TValue.MakeNil;
  end;
end;

function TInterpreter.EvalUnary(Node: TUnaryExpr; Env: TEnvironment): TValue;
var
  V : TValue;
begin
  V := EvalExpr(Node.Operand, Env);
  if Node.Op = '-' then
  begin
    if V.Kind = vkFloat then Result := TValue.MakeFloat(-V.FVal)
    else                     Result := TValue.MakeInt  (-V.IVal);
  end
  else if Node.Op = 'not' then
    Result := TValue.MakeBool(not V.ToBool)
  else
    Result := V;
end;

function TInterpreter.EvalCallExpr(Node: TCallExpr; Env: TEnvironment): TValue;
begin
  if not CallBuiltin(Node.Name, Node.Args, Env, Result) then
    Result := CallRoutine(Node.Name, Node.Args, Env);
end;

// ---------------------------------------------------------------------------
//  Call a user-defined routine
// ---------------------------------------------------------------------------
function TInterpreter.CallRoutine(const Name: string; Args: TExprList;
  CallerEnv: TEnvironment): TValue;
var
  Decl  : TRoutineDecl;
  Env   : TEnvironment;
  I     : Integer;
  Param : TParamDecl;
  ArgVal: TValue;
begin
  Result := TValue.MakeNil;

  if not FRoutines.TryGetValue(LowerCase(Name), Decl) then
    raise Exception.CreateFmt('Unknown procedure/function: %s', [Name]);

  Env := TEnvironment.Create(FGlobal);
  try
    // Bind parameters
    for I := 0 to Decl.Params.Count - 1 do
    begin
      Param := Decl.Params[I];
      if I < Args.Count then
        ArgVal := EvalExpr(Args[I], CallerEnv)
      else
        ArgVal := TValue.MakeNil;
      Env.DeclareVar(Param.Name, ArgVal);
    end;

    // Declare local variables
    DeclareVars(Env, Decl.Locals);

    // Pre-declare Result variable for functions
    if Decl.ReturnType <> '' then
      Env.DeclareVar('result', TValue.MakeNil);

    // Execute body — catch exit signal from inside routines
    try
      ExecBlock(Decl.Body, Env);
    except
      on E: EExitSignal do ;
    end;

    // Retrieve function result
    if Decl.ReturnType <> '' then
      Env.GetVar('result', Result);

  finally
    Env.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Built-in functions:  Abs, Sqr, Sqrt, Ord, Chr, Length, Pos,
//                       Copy, UpperCase, LowerCase, IntToStr, StrToInt,
//                       FloatToStr, Odd, Succ, Pred, Inc, Dec
// ---------------------------------------------------------------------------
function TInterpreter.CallBuiltin(const Name: string; Args: TExprList;
  CallerEnv: TEnvironment; out Val: TValue): Boolean;

  function A(I: Integer): TValue;
  begin
    if I < Args.Count then Result := EvalExpr(Args[I], CallerEnv)
    else Result := TValue.MakeNil;
  end;

var
  N        : string;
  IB_Title : string;
  IB_Def   : string;
  SelDir   : string;
  ODlg     : TOpenDialog;
  SDlg3    : TSaveDialog;
  IncCur   : TValue;
  IncStep  : Int64;
  DecCur   : TValue;
  DecStep  : Int64;
begin
  Result := True;
  N      := LowerCase(Name);

  if      N = 'abs'         then Val := TValue.MakeFloat(Abs(A(0).ToFloat))
  else if N = 'sqr'         then Val := TValue.MakeFloat(Sqr(A(0).ToFloat))
  else if N = 'sqrt'        then Val := TValue.MakeFloat(Sqrt(A(0).ToFloat))
  else if N = 'round'       then Val := TValue.MakeInt  (Round(A(0).ToFloat))
  else if N = 'trunc'       then Val := TValue.MakeInt  (Trunc(A(0).ToFloat))
  else if N = 'int'         then Val := TValue.MakeFloat(Int(A(0).ToFloat))
  else if N = 'frac'        then Val := TValue.MakeFloat(Frac(A(0).ToFloat))
  else if N = 'sin'         then Val := TValue.MakeFloat(Sin(A(0).ToFloat))
  else if N = 'cos'         then Val := TValue.MakeFloat(Cos(A(0).ToFloat))
  else if N = 'ln'          then Val := TValue.MakeFloat(Ln (A(0).ToFloat))
  else if N = 'exp'         then Val := TValue.MakeFloat(Exp(A(0).ToFloat))
  else if N = 'pi'          then Val := TValue.MakeFloat(Pi)
  else if N = 'power'       then Val := TValue.MakeFloat(Power(A(0).ToFloat, A(1).ToFloat))
  else if N = 'max'         then Val := TValue.MakeFloat(Max(A(0).ToFloat, A(1).ToFloat))
  else if N = 'min'         then Val := TValue.MakeFloat(Min(A(0).ToFloat, A(1).ToFloat))
  else if N = 'odd'         then Val := TValue.MakeBool ((A(0).ToInt mod 2) <> 0)
  else if N = 'succ'        then Val := TValue.MakeInt  (A(0).ToInt + 1)
  else if N = 'pred'        then Val := TValue.MakeInt  (A(0).ToInt - 1)
  else if N = 'ord'         then Val := TValue.MakeInt  (Ord(A(0).SVal[1]))
  else if N = 'chr'         then Val := TValue.MakeStr  (Chr(A(0).ToInt))
  else if N = 'length'      then Val := TValue.MakeInt  (Length(A(0).SVal))
  else if N = 'pos'         then Val := TValue.MakeInt  (Pos(A(0).SVal, A(1).SVal))
  else if N = 'copy'        then Val := TValue.MakeStr  (Copy(A(0).SVal, A(1).ToInt, A(2).ToInt))
  else if N = 'uppercase'   then Val := TValue.MakeStr  (UpperCase(A(0).SVal))
  else if N = 'lowercase'   then Val := TValue.MakeStr  (LowerCase(A(0).SVal))
  else if N = 'trim'        then Val := TValue.MakeStr  (Trim(A(0).SVal))
  else if N = 'inttostr'    then Val := TValue.MakeStr  (IntToStr(A(0).ToInt))
  else if N = 'strtoint'    then Val := TValue.MakeInt  (StrToIntDef(A(0).SVal, 0))
  else if N = 'strtofloat'  then Val := TValue.MakeFloat(StrToFloatDef(A(0).SVal, 0))
  else if N = 'floattostr'  then Val := TValue.MakeStr  (FloatToStr(A(0).ToFloat))
  else if N = 'str'         then Val := TValue.MakeStr  (A(0).ToStr)
  else if N = 'val'         then Val := TValue.MakeFloat(StrToFloatDef(A(0).SVal, 0))
  else if N = 'random'      then
  begin
    if Args.Count > 0 then Val := TValue.MakeInt(Random(A(0).ToInt))
    else                   Val := TValue.MakeFloat(Random);
  end
  else if N = 'randomize'   then begin Randomize; Val := TValue.MakeNil; end
  else if N = 'inc'         then
  begin
    // inc(v) or inc(v, n)  — modifies variable in place
    if (Args.Count > 0) and (Args[0] is TVarExpr) then
    begin
      IncStep := 1;
      if not CallerEnv.GetVar(TVarExpr(Args[0]).Name, IncCur) then IncCur := TValue.MakeInt(0);
      if Args.Count > 1 then IncStep := A(1).ToInt;
      CallerEnv.SetVar(TVarExpr(Args[0]).Name, TValue.MakeInt(IncCur.ToInt + IncStep));
    end;
    Val := TValue.MakeNil;
  end
  else if N = 'dec'         then
  begin
    if (Args.Count > 0) and (Args[0] is TVarExpr) then
    begin
      DecStep := 1;
      if not CallerEnv.GetVar(TVarExpr(Args[0]).Name, DecCur) then DecCur := TValue.MakeInt(0);
      if Args.Count > 1 then DecStep := A(1).ToInt;
      CallerEnv.SetVar(TVarExpr(Args[0]).Name, TValue.MakeInt(DecCur.ToInt - DecStep));
    end;
    Val := TValue.MakeNil;
  end
  // -----------------------------------------------------------------------
  //  UI & Dialog builtins
  // -----------------------------------------------------------------------
  else if N = 'showmessage'   then
  begin
    Vcl.Dialogs.ShowMessage(A(0).ToStr);
    Val := TValue.MakeNil;
  end
  else if N = 'confirm'       then
  begin
    Val := TValue.MakeBool(
      MessageDlg(A(0).ToStr, mtConfirmation, [mbYes, mbNo], 0) = mrYes);
  end
  else if N = 'inputbox'      then
  begin
    // inputbox(prompt, title, default)
    if Args.Count > 1 then IB_Title := A(1).ToStr else IB_Title := 'Input';
    if Args.Count > 2 then IB_Def   := A(2).ToStr else IB_Def   := '';
    Val := TValue.MakeStr(InputBox(IB_Title, A(0).ToStr, IB_Def));
  end
  else if N = 'showinfobox'   then
  begin
    MessageDlg(A(0).ToStr, mtInformation, [mbOK], 0);
    Val := TValue.MakeNil;
  end
  else if N = 'showwarningbox' then
  begin
    MessageDlg(A(0).ToStr, mtWarning, [mbOK], 0);
    Val := TValue.MakeNil;
  end
  else if N = 'showerrorbox'  then
  begin
    MessageDlg(A(0).ToStr, mtError, [mbOK], 0);
    Val := TValue.MakeNil;
  end

  // -----------------------------------------------------------------------
  //  File dialog builtins
  // -----------------------------------------------------------------------
  else if N = 'openfiledialog' then
  begin
    ODlg := TOpenDialog.Create(nil);
    try
      if Args.Count > 0 then ODlg.Filter := A(0).ToStr
      else ODlg.Filter := 'All Files|*.*';
      ODlg.Options := [ofFileMustExist];
      if ODlg.Execute then
        Val := TValue.MakeStr(ODlg.FileName)
      else
        Val := TValue.MakeStr('');
    finally
      ODlg.Free;
    end;
  end
  else if N = 'savefiledialog' then
  begin
    SDlg3 := TSaveDialog.Create(nil);
    try
      if Args.Count > 0 then SDlg3.Filter := A(0).ToStr
      else SDlg3.Filter := 'All Files|*.*';
      if Args.Count > 1 then SDlg3.DefaultExt := A(1).ToStr;
      if SDlg3.Execute then
        Val := TValue.MakeStr(SDlg3.FileName)
      else
        Val := TValue.MakeStr('');
    finally
      SDlg3.Free;
    end;
  end
  else if N = 'selectdirectorydialog' then
  begin
    SelDir := '';
    if SelectDirectory('Select a folder', '', SelDir) then
      Val := TValue.MakeStr(SelDir)
    else
      Val := TValue.MakeStr('');
  end

  // -----------------------------------------------------------------------
  //  File I/O builtins
  // -----------------------------------------------------------------------
  else if N = 'writefile'     then
  begin
    // writefile(filename, text)
    TFile.WriteAllText(A(0).ToStr, A(1).ToStr);
    Val := TValue.MakeNil;
  end
  else if N = 'appendfile'    then
  begin
    // appendfile(filename, text)
    TFile.AppendAllText(A(0).ToStr, A(1).ToStr + sLineBreak);
    Val := TValue.MakeNil;
  end
  else if N = 'readfile'      then
  begin
    // readfile(filename) -> string
    if TFile.Exists(A(0).ToStr) then
      Val := TValue.MakeStr(TFile.ReadAllText(A(0).ToStr))
    else
      Val := TValue.MakeStr('');
  end
  else if N = 'fileexists'    then
    Val := TValue.MakeBool(TFile.Exists(A(0).ToStr))
  else if N = 'deletefile'    then
  begin
    if TFile.Exists(A(0).ToStr) then
      TFile.Delete(A(0).ToStr);
    Val := TValue.MakeNil;
  end
  else if N = 'getapppath'    then
    Val := TValue.MakeStr(ExtractFilePath(ParamStr(0)))
  else if N = 'getdesktoppath' then
    Val := TValue.MakeStr(
      GetEnvironmentVariable('USERPROFILE') + '\Desktop')



  // -----------------------------------------------------------------------
  //  Graphics / Animation builtins (GfxXxx functions)
  // -----------------------------------------------------------------------
  else if N = 'gfxopen' then
  begin
    var GW1, GH1 : Integer;
    var GT1 : string;
    GW1 := A(0).ToInt; GH1 := A(1).ToInt;
    if Args.Count > 2 then GT1 := A(2).ToStr else GT1 := 'MiniDelphi Graphics';
    GfxOpenWindow(GW1, GH1, GT1);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxclose' then
  begin
    GfxCloseWindow;
    Val := TValue.MakeNil;
  end
  else if N = 'gfxclear' then
  begin
    if Assigned(GfxWin) then GfxWin.GfxClear(A(0).ToStr);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxshow' then
  begin
    if Assigned(GfxWin) then GfxWin.GfxShow;
    Val := TValue.MakeNil;
  end
  else if N = 'gfxdelay' then
  begin
    var GMS1 : Integer;
    GMS1 := A(0).ToInt;
    if GMS1 > 0 then Sleep(GMS1);
    Application.ProcessMessages;
    Val := TValue.MakeNil;
  end
  else if N = 'gfxrunning' then
  begin
    Val := TValue.MakeBool(Assigned(GfxWin) and GfxWin.Running);
  end
  else if N = 'gfxcolor' then
  begin
    if Assigned(GfxWin) then GfxWin.GfxColor(A(0).ToStr);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxpenwidth' then
  begin
    if Assigned(GfxWin) then GfxWin.GfxPenWidth(A(0).ToInt);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxdrawline' then
  begin
    if Assigned(GfxWin) then
      GfxWin.GfxDrawLine(A(0).ToInt, A(1).ToInt, A(2).ToInt, A(3).ToInt);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxdrawrect' then
  begin
    if Assigned(GfxWin) then
      GfxWin.GfxDrawRect(A(0).ToInt, A(1).ToInt, A(2).ToInt, A(3).ToInt);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxfillrect' then
  begin
    if Assigned(GfxWin) then
      GfxWin.GfxFillRect(A(0).ToInt, A(1).ToInt, A(2).ToInt, A(3).ToInt);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxdrawcircle' then
  begin
    if Assigned(GfxWin) then
      GfxWin.GfxDrawCircle(A(0).ToInt, A(1).ToInt, A(2).ToInt);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxfillcircle' then
  begin
    if Assigned(GfxWin) then
      GfxWin.GfxFillCircle(A(0).ToInt, A(1).ToInt, A(2).ToInt);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxdrawellipse' then
  begin
    if Assigned(GfxWin) then
      GfxWin.GfxDrawEllipse(A(0).ToInt, A(1).ToInt, A(2).ToInt, A(3).ToInt);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxfillellipse' then
  begin
    if Assigned(GfxWin) then
      GfxWin.GfxFillEllipse(A(0).ToInt, A(1).ToInt, A(2).ToInt, A(3).ToInt);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxdrawtext' then
  begin
    if Assigned(GfxWin) then
      GfxWin.GfxDrawText(A(0).ToInt, A(1).ToInt, A(2).ToStr);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxsetfont' then
  begin
    if Assigned(GfxWin) then
      GfxWin.GfxSetFont(A(0).ToInt, A(1).ToBool);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxdrawpixel' then
  begin
    if Assigned(GfxWin) then GfxWin.GfxDrawPixel(A(0).ToInt, A(1).ToInt);
    Val := TValue.MakeNil;
  end
  else if N = 'gfxkeypressed' then
    Val := TValue.MakeBool(Assigned(GfxWin) and GfxWin.GfxKeyPressed)
  else if N = 'gfxreadkey' then
  begin
    if Assigned(GfxWin) then Val := TValue.MakeStr(GfxWin.GfxReadKey)
    else Val := TValue.MakeStr('');
  end
  else if N = 'gfxmousex' then
    Val := TValue.MakeInt(IfThenInt(Assigned(GfxWin), GfxWin.MouseX, 0))
  else if N = 'gfxmousey' then
    Val := TValue.MakeInt(IfThenInt(Assigned(GfxWin), GfxWin.MouseY, 0))
  else if N = 'gfxmousedown' then
    Val := TValue.MakeBool(Assigned(GfxWin) and GfxWin.MouseDown)

  // -----------------------------------------------------------------------
  //  Database builtins (SQLite via dynamic DLL loading)
  // -----------------------------------------------------------------------
  else if N = 'dbopen' then
  begin
    InitMiniDB;
    if MiniDB.Open(A(0).ToStr) then
    begin
      Val := TValue.MakeBool(True);
      Output('Database opened: ' + A(0).ToStr);
    end
    else
    begin
      Val := TValue.MakeBool(False);
      Output('DB Error: ' + MiniDB.LastError);
    end;
  end
  else if N = 'dbclose' then
  begin
    if Assigned(MiniDB) then MiniDB.Close;
    Val := TValue.MakeNil;
    Output('Database closed.');
  end
  else if N = 'dbexec' then
  begin
    InitMiniDB;
    if MiniDB.Exec(A(0).ToStr) then
      Val := TValue.MakeBool(True)
    else
    begin
      Val := TValue.MakeBool(False);
      Output('DB Error: ' + MiniDB.LastError);
    end;
  end
  else if N = 'dbquery' then
  begin
    InitMiniDB;
    Val := TValue.MakeStr(MiniDB.Query(A(0).ToStr));
    if MiniDB.LastError <> '' then
      Output('DB Error: ' + MiniDB.LastError);
  end
  else if N = 'dbqueryvalue' then
  begin
    InitMiniDB;
    Val := TValue.MakeStr(MiniDB.QueryValue(A(0).ToStr));
    if MiniDB.LastError <> '' then
      Output('DB Error: ' + MiniDB.LastError);
  end
  else if N = 'dblasterror' then
  begin
    if Assigned(MiniDB) then Val := TValue.MakeStr(MiniDB.LastError)
    else                      Val := TValue.MakeStr('No database initialised');
  end
  else if N = 'dbisopen' then
  begin
    Val := TValue.MakeBool(Assigned(MiniDB) and MiniDB.IsOpen);
  end
  else if N = 'dbfilename' then
  begin
    if Assigned(MiniDB) then Val := TValue.MakeStr(MiniDB.Filename)
    else                      Val := TValue.MakeStr('');
  end

  else
    Result := False;   // not a built-in
end;

// ---------------------------------------------------------------------------
//  case (integer / ordinal)
// ---------------------------------------------------------------------------
procedure TInterpreter.ExecCase(Node: TCaseStmt; Env: TEnvironment);
var
  Val      : TValue;
  IVal     : Int64;
  Arm      : TCaseArm;
  V        : Int64;
  Hit      : Boolean;
  CAI, CAJ : Integer;
begin
  Val  := EvalExpr(Node.Expr, Env);
  IVal := Val.ToInt;
  Hit  := False;

  for CAI := 0 to Node.Arms.Count - 1 do
  begin
    Arm := Node.Arms[CAI];
    for CAJ := 0 to Arm.Values.Count - 1 do
    begin
      if Arm.Values[CAJ] = IVal then
      begin
        ExecStmt(Arm.Body, Env);
        Hit := True;
        Break;
      end;
    end;
    if Hit then Break;
  end;

  if (not Hit) and Assigned(Node.ElseBody) then
    ExecStmt(Node.ElseBody, Env);
end;

// ---------------------------------------------------------------------------
//  caseof (string switch — our invention)
// ---------------------------------------------------------------------------
procedure TInterpreter.ExecCaseOf(Node: TCaseOfStmt; Env: TEnvironment);
var
  Val      : TValue;
  SVal     : string;
  Arm      : TCaseOfArm;
  S        : string;
  Hit      : Boolean;
  COI, COJ : Integer;
begin
  Val  := EvalExpr(Node.Expr, Env);
  SVal := Val.ToStr;
  Hit  := False;

  for COI := 0 to Node.Arms.Count - 1 do
  begin
    Arm := Node.Arms[COI];
    for COJ := 0 to Arm.Values.Count - 1 do
    begin
      if Arm.Values[COJ] = SVal then
      begin
        ExecStmt(Arm.Body, Env);
        Hit := True;
        Break;
      end;
    end;
    if Hit then Break;
  end;

  if (not Hit) and Assigned(Node.ElseBody) then
    ExecStmt(Node.ElseBody, Env);
end;


// ===========================================================================
//  OOP EXECUTION IMPLEMENTATIONS
// ===========================================================================

// ---------------------------------------------------------------------------
//  Create a new object instance, initialise its fields, run constructor
// ---------------------------------------------------------------------------
function TInterpreter.EvalCreateExpr(Node: TCreateExpr;
  Env: TEnvironment): TValue;
var
  Obj  : TObjectInstance;
  ML   : TMethodLookup;
begin
  Result := TValue.MakeNil;

  if not ClassRegistry.ClassExists(Node.ClassRef) then
    raise Exception.CreateFmt('Unknown class: %s', [Node.ClassRef]);

  // Create the instance
  Obj := TObjectInstance.Create(Node.ClassRef);

  // Initialise all fields (including inherited) to defaults
  InitObjectFields(Obj);

  // Wrap in a TValue immediately so constructor can refer to Self
  Result := TValue.MakeObject(Obj);

  // Run the constructor if one exists
  ML := ClassRegistry.ResolveMethod(Node.ClassRef, 'Create');
  if ML.Found and ML.Method.IsConstructor then
    InvokeMethod(Obj, ML.Method, Node.Args, Env);
end;

// ---------------------------------------------------------------------------
//  Initialise all fields of a new object to type-appropriate defaults
// ---------------------------------------------------------------------------
procedure TInterpreter.InitObjectFields(Obj: TObjectInstance);
var
  Fields : TObjectList<TFieldDecl>;
  F      : TFieldDecl;
  DefVal : TValue;
  PVal   : ^TValue;
  FTN    : string;
  OFI    : Integer;
begin
  Fields := TObjectList<TFieldDecl>.Create(False);  // non-owning
  try
    ClassRegistry.CollectFields(Obj.ObjClass, Fields);
    for OFI := 0 to Fields.Count - 1 do
    begin
      F := Fields[OFI];
      FTN := LowerCase(F.TypeName);
      if      FTN = 'integer' then DefVal := TValue.MakeInt(0)
      else if FTN = 'real'    then DefVal := TValue.MakeFloat(0)
      else if FTN = 'boolean' then DefVal := TValue.MakeBool(False)
      else if FTN = 'string'  then DefVal := TValue.MakeStr('')
      else                         DefVal := TValue.MakeNil;

      // Store a heap-allocated copy of the TValue
      New(PVal);
      PVal^ := DefVal;
      Obj.Fields.AddOrSetValue(LowerCase(F.Name), PVal);
    end;
  finally
    Fields.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Invoke a method on an object instance
// ---------------------------------------------------------------------------
function TInterpreter.InvokeMethod(Obj: TObjectInstance; M: TMethodDecl;
  Args: TExprList; CallerEnv: TEnvironment): TValue;
var
  Env     : TEnvironment;
  I       : Integer;
  Param   : TParamDecl;
  ArgVal  : TValue;
  FKey    : string;
  PVal    : ^TValue;
  FPtr    : Pointer;
  KeyList : TList<string>;
  KI      : Integer;
  UpdVal  : TValue;
begin
  Result := TValue.MakeNil;
  if M.IsAbstract then
    raise Exception.CreateFmt('Cannot call abstract method %s', [M.Name]);

  Env := TEnvironment.Create(FGlobal);
  try
    // Bind 'Self' to the object
    Env.DeclareVar('self', TValue.MakeObject(Obj));

    // Bind object fields as local variables that sync back
    KeyList := TList<string>.Create;
    try
      for FKey in Obj.Fields.Keys do KeyList.Add(FKey);
      for KI := 0 to KeyList.Count - 1 do
      begin
        FKey := KeyList[KI];
        FPtr := Obj.Fields[FKey];
        if Assigned(FPtr) then
          Env.DeclareVar(FKey, TValue(FPtr^));
      end;
    finally
      KeyList.Free;
    end;

    // Bind parameters
    for I := 0 to M.Params.Count - 1 do
    begin
      Param := M.Params[I];
      if I < Args.Count then
        ArgVal := EvalExpr(Args[I], CallerEnv)
      else
        ArgVal := TValue.MakeNil;
      Env.DeclareVar(Param.Name, ArgVal);
    end;

    // Declare local variables
    DeclareVars(Env, M.Locals);

    // Pre-declare Result for functions
    if M.ReturnType <> '' then
      Env.DeclareVar('result', TValue.MakeNil);

    // Execute body
    if Assigned(M.Body) then
    try
      ExecBlock(M.Body, Env);
    except
      on E: EExitSignal do Result := E.ReturnVal;
    end;

    // Retrieve function result
    if M.ReturnType <> '' then
      Env.GetVar('result', Result);

    // Write field values BACK to the object
    KeyList := TList<string>.Create;
    try
      for FKey in Obj.Fields.Keys do KeyList.Add(FKey);
      for KI := 0 to KeyList.Count - 1 do
      begin
        FKey := KeyList[KI];
        if Env.GetVar(FKey, UpdVal) then
        begin
          FPtr := Obj.Fields[FKey];
          if Assigned(FPtr) then
            TValue(FPtr^) := UpdVal
          else
          begin
            New(PVal);
            PVal^ := UpdVal;
            Obj.Fields[FKey] := PVal;
          end;
        end;
      end;
    finally
      KeyList.Free;
    end;

  finally
    Env.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Evaluate a field access:  obj.FieldName
// ---------------------------------------------------------------------------
function TInterpreter.EvalFieldExpr(Node: TFieldExpr;
  Env: TEnvironment): TValue;
var
  OV    : TValue;
  Obj   : TObjectInstance;
  FPtr  : Pointer;
  FName : string;
begin
  Result := TValue.MakeNil;
  OV := EvalExpr(Node.Obj, Env);

  if OV.Kind <> vkObject then
    raise Exception.CreateFmt('Cannot access field "%s" on non-object',
      [Node.FieldName]);

  Obj   := OV.ObjVal;
  FName := LowerCase(Node.FieldName);

  if Obj.Fields.TryGetValue(FName, FPtr) and Assigned(FPtr) then
    Result := TValue(FPtr^)
  else
    raise Exception.CreateFmt('Unknown field "%s" on %s',
      [Node.FieldName, Obj.ObjClass]);
end;

// ---------------------------------------------------------------------------
//  Evaluate a method call:  obj.MethodName(args)
// ---------------------------------------------------------------------------
function TInterpreter.EvalMethodCallExpr(Node: TMethodCallExpr;
  Env: TEnvironment): TValue;
var
  OV  : TValue;
  Obj : TObjectInstance;
  ML  : TMethodLookup;
  CE  : TCreateExpr;
  AI  : Integer;
begin
  Result := TValue.MakeNil;

  // Special case: handle ClassName.Create as object construction
  if (Node.Obj is TVarExpr) and
     ClassRegistry.ClassExists(TVarExpr(Node.Obj).Name) and
     (LowerCase(Node.MethodName) = 'create') then
  begin
    CE := TCreateExpr.Create;
    CE.ClassRef := TVarExpr(Node.Obj).Name;
    for AI := 0 to Node.Args.Count - 1 do
      CE.Args.Add(Node.Args[AI]);
    Result := EvalCreateExpr(CE, Env);
    CE.Args.Clear;  // args belong to Node — don't free them
    CE.Free;
    Exit;
  end;

  OV := EvalExpr(Node.Obj, Env);

  // Handle Free / Destroy silently
  if LowerCase(Node.MethodName) = 'free'    then Exit;
  if LowerCase(Node.MethodName) = 'destroy' then Exit;

  if OV.Kind <> vkObject then
    raise Exception.CreateFmt('Cannot call method "%s" on non-object',
      [Node.MethodName]);

  Obj := OV.ObjVal;
  ML  := ClassRegistry.ResolveMethod(Obj.ObjClass, Node.MethodName);

  if not ML.Found then
    raise Exception.CreateFmt('Unknown method "%s" on class "%s"',
      [Node.MethodName, Obj.ObjClass]);

  Result := InvokeMethod(Obj, ML.Method, Node.Args, Env);
end;

// ---------------------------------------------------------------------------
//  Execute a field assignment:  obj.Name := value
// ---------------------------------------------------------------------------
procedure TInterpreter.ExecFieldAssign(Node: TFieldAssignStmt;
  Env: TEnvironment);
var
  OV    : TValue;
  Obj   : TObjectInstance;
  FName : string;
  Val   : TValue;
  FPtr  : ^TValue;
  P     : Pointer;
begin
  OV := EvalExpr(Node.Obj, Env);

  if OV.Kind <> vkObject then
    raise Exception.CreateFmt('Cannot assign field "%s" on non-object',
      [Node.FieldName]);

  Obj   := OV.ObjVal;
  FName := LowerCase(Node.FieldName);
  Val   := EvalExpr(Node.Value, Env);

  if Obj.Fields.TryGetValue(FName, P) and Assigned(P) then
    TValue(P^) := Val
  else
  begin
    New(FPtr);
    FPtr^ := Val;
    Obj.Fields.AddOrSetValue(FName, FPtr);
  end;
end;

// ---------------------------------------------------------------------------
//  Execute a method call statement:  obj.Speak;  obj.Run(speed);
// ---------------------------------------------------------------------------
procedure TInterpreter.ExecMethodCall(Node: TMethodCallStmt;
  Env: TEnvironment);
var
  OV  : TValue;
  Obj : TObjectInstance;
  ML  : TMethodLookup;
begin
  OV := EvalExpr(Node.Obj, Env);

  // Handle Free/Destroy silently
  if LowerCase(Node.MethodName) = 'free'    then Exit;
  if LowerCase(Node.MethodName) = 'destroy' then Exit;

  if OV.Kind <> vkObject then
    raise Exception.CreateFmt('Cannot call method "%s" on non-object',
      [Node.MethodName]);

  Obj := OV.ObjVal;
  ML  := ClassRegistry.ResolveMethod(Obj.ObjClass, Node.MethodName);

  if not ML.Found then
    raise Exception.CreateFmt('Unknown method "%s" on class "%s"',
      [Node.MethodName, Obj.ObjClass]);

  InvokeMethod(Obj, ML.Method, Node.Args, Env);
end;

// ---------------------------------------------------------------------------
//  Execute inherited call
// ---------------------------------------------------------------------------
procedure TInterpreter.ExecInherited(Node: TInheritedCallStmt;
  Env: TEnvironment);
var
  SelfVal     : TValue;
  Obj         : TObjectInstance;
  CurrentClass: string;
  ParentName  : string;
  ML          : TMethodLookup;
  MethodName  : string;
  ParentDecl  : TClassDecl;
  MNVal       : TValue;
begin
  // Get Self
  if not Env.GetVar('self', SelfVal) or (SelfVal.Kind <> vkObject) then
    raise Exception.Create('"inherited" used outside a method');

  Obj := SelfVal.ObjVal;

  // Find current class from environment (set during method invocation)
  if not Env.GetVar('__class__', SelfVal) then
    CurrentClass := Obj.ObjClass
  else
    CurrentClass := SelfVal.SVal;

  // Get the parent class
  ParentDecl := ClassRegistry.FindClass(CurrentClass);
  if not Assigned(ParentDecl) then Exit;
  ParentName := ParentDecl.ParentName;
  if ParentName = '' then Exit;

  MethodName := Node.MethodName;
  if MethodName = '' then
  begin
    // bare "inherited" — get current method name from env
    if Env.GetVar('__method__', MNVal) then
      MethodName := MNVal.SVal;
  end;

  if MethodName = '' then Exit;

  ML := ClassRegistry.ResolveMethod(ParentName, MethodName);
  if ML.Found then
    InvokeMethod(Obj, ML.Method, Node.Args, Env);
end;

// ---------------------------------------------------------------------------
//  is  operator  (type checking)
// ---------------------------------------------------------------------------
function TInterpreter.EvalIsExpr(Obj: TValue;
  const TypeName: string): TValue;
begin
  if Obj.Kind <> vkObject then
  begin
    Result := TValue.MakeBool(False);
    Exit;
  end;

  // Check class inheritance
  if ClassRegistry.ClassExists(TypeName) then
    Result := TValue.MakeBool(
      ClassRegistry.IsDescendant(Obj.ObjVal.ObjClass, TypeName))
  // Check interface
  else if ClassRegistry.InterfaceExists(TypeName) then
    Result := TValue.MakeBool(
      ClassRegistry.Implements(Obj.ObjVal.ObjClass, TypeName))
  else
    Result := TValue.MakeBool(False);
end;


function IfThenInt(B: Boolean; T, F: Integer): Integer;
begin
  if B then Result := T else Result := F;
end;

end.
