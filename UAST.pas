unit UAST;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  UAST.pas  -  Abstract Syntax Tree node definitions
//  Every grammatical construct in MiniDelphi becomes one of these nodes.
//  The Parser builds the tree; the Interpreter walks it.
//
//  Declaration order matters in Delphi — nodes that reference other nodes
//  must come AFTER those nodes, or use forward declarations.
// =============================================================================

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type

  // =========================================================================
  //  FORWARD DECLARATIONS
  //  These allow nodes to reference each other before full declaration.
  // =========================================================================
  TASTNode      = class;
  TExprNode     = class;
  TStmtNode     = class;
  TVarDecl      = class;
  TParamDecl    = class;
  TBlockStmt    = class;
  TClassDecl    = class;
  TInterfaceDecl = class;
  TMethodDecl   = class;

  // Typed list aliases
  TExprList  = TObjectList<TExprNode>;
  TStmtList  = TObjectList<TStmtNode>;

  // =========================================================================
  //  BASE NODE
  // =========================================================================
  TASTNode = class
  public
    Line : Integer;
    Col  : Integer;
  end;

  // =========================================================================
  //  EXPRESSION NODES  (produce a value)
  // =========================================================================
  TExprNode = class(TASTNode);

  // Integer literal:  42
  TIntLitExpr = class(TExprNode)
    Value : Int64;
  end;

  // Float literal:  3.14
  TFloatLitExpr = class(TExprNode)
    Value : Double;
  end;

  // String literal:  'hello'
  TStrLitExpr = class(TExprNode)
    Value : string;
  end;

  // Boolean literal:  true / false
  TBoolLitExpr = class(TExprNode)
    Value : Boolean;
  end;

  // nil literal
  TNilLitExpr = class(TExprNode)
  end;

  // Variable reference:  x
  TVarExpr = class(TExprNode)
    Name : string;
  end;

  // Binary operator:  a + b,  x < y
  TBinOpExpr = class(TExprNode)
    Left  : TExprNode;
    Op    : string;
    Right : TExprNode;
    destructor Destroy; override;
  end;

  // Unary operator:  -x,  not b
  TUnaryExpr = class(TExprNode)
    Op      : string;
    Operand : TExprNode;
    destructor Destroy; override;
  end;

  // Function call expression:  foo(a, b)
  TCallExpr = class(TExprNode)
    Name : string;
    Args : TExprList;
    constructor Create;
    destructor  Destroy; override;
  end;

  // Field access expression:  obj.Name
  TFieldExpr = class(TExprNode)
    Obj       : TExprNode;
    FieldName : string;
    destructor Destroy; override;
  end;

  // Method call expression:  obj.Speak(args)
  TMethodCallExpr = class(TExprNode)
    Obj        : TExprNode;
    MethodName : string;
    Args       : TExprList;
    constructor Create;
    destructor  Destroy; override;
  end;

  // Object creation:  TDog.Create  or  TDog.Create(args)
  TCreateExpr = class(TExprNode)
    ClassRef  : string;
    Args      : TExprList;
    constructor Create;
    destructor  Destroy; override;
  end;

  // =========================================================================
  //  STATEMENT NODES  (do something, produce no value)
  // =========================================================================
  TStmtNode = class(TASTNode);

  // Assignment:  x := expr
  TAssignStmt = class(TStmtNode)
    VarName : string;
    Expr    : TExprNode;
    destructor Destroy; override;
  end;

  // Field assignment:  obj.Name := expr
  TFieldAssignStmt = class(TStmtNode)
    Obj       : TExprNode;
    FieldName : string;
    Value     : TExprNode;
    destructor Destroy; override;
  end;

  // writeln(...) / write(...)
  TWritelnStmt = class(TStmtNode)
    Args    : TExprList;
    NewLine : Boolean;
    constructor Create;
    destructor  Destroy; override;
  end;

  // readln(varName)
  TReadlnStmt = class(TStmtNode)
    VarName : string;
  end;

  // if expr then stmt [else stmt]
  TIfStmt = class(TStmtNode)
    Condition  : TExprNode;
    ThenBranch : TStmtNode;
    ElseBranch : TStmtNode;
    destructor Destroy; override;
  end;

  // while expr do stmt
  TWhileStmt = class(TStmtNode)
    Condition : TExprNode;
    Body      : TStmtNode;
    destructor Destroy; override;
  end;

  // repeat stmts until expr
  TRepeatStmt = class(TStmtNode)
    Body      : TStmtList;
    Condition : TExprNode;
    constructor Create;
    destructor  Destroy; override;
  end;

  // for i := start to/downto finish do stmt
  TForStmt = class(TStmtNode)
    VarName  : string;
    StartVal : TExprNode;
    EndVal   : TExprNode;
    IsDownTo : Boolean;       // renamed from DownTo to avoid keyword clash
    Body     : TStmtNode;
    destructor Destroy; override;
  end;

  // begin ... end block
  TBlockStmt = class(TStmtNode)
    Stmts : TStmtList;
    constructor Create;
    destructor  Destroy; override;
  end;

  // Procedure/function call as statement:  foo(a, b);
  TCallStmt = class(TStmtNode)
    Name : string;
    Args : TExprList;
    constructor Create;
    destructor  Destroy; override;
  end;

  // Method call as statement:  obj.Speak;
  TMethodCallStmt = class(TStmtNode)
    Obj        : TExprNode;
    MethodName : string;
    Args       : TExprList;
    constructor Create;
    destructor  Destroy; override;
  end;

  // exit / exit(expr)
  TExitStmt = class(TStmtNode)
    Expr : TExprNode;
    destructor Destroy; override;
  end;

  // inherited / inherited MethodName(args)
  TInheritedCallStmt = class(TStmtNode)
    MethodName : string;
    Args       : TExprList;
    constructor Create;
    destructor  Destroy; override;
  end;

  // break / continue
  TBreakStmt    = class(TStmtNode);
  TContinueStmt = class(TStmtNode);

  // =========================================================================
  //  CASE STATEMENTS
  // =========================================================================

  // One arm of a case statement:  1, 2 : stmt
  TCaseArm = class(TASTNode)
    Values : TList<Int64>;
    Body   : TStmtNode;
    constructor Create;
    destructor  Destroy; override;
  end;

  // case expr of  1: ...; 2: ...; else ...; end
  TCaseStmt = class(TStmtNode)
    Expr     : TExprNode;
    Arms     : TObjectList<TCaseArm>;
    ElseBody : TStmtNode;
    constructor Create;
    destructor  Destroy; override;
  end;

  // One arm of a caseof statement:  'cat', 'kitten' : stmt
  TCaseOfArm = class(TASTNode)
    Values : TStringList;
    Body   : TStmtNode;
    constructor Create;
    destructor  Destroy; override;
  end;

  // caseof expr of  'cat': ...; 'dog': ...; else ...; end
  TCaseOfStmt = class(TStmtNode)
    Expr     : TExprNode;
    Arms     : TObjectList<TCaseOfArm>;
    ElseBody : TStmtNode;
    constructor Create;
    destructor  Destroy; override;
  end;

  // =========================================================================
  //  DECLARATIONS
  //  These must come BEFORE any OOP nodes that reference them.
  // =========================================================================

  // Variable declaration:  name : TypeName
  TVarDecl = class(TASTNode)
    Name     : string;
    TypeName : string;
    InitExpr : TExprNode;
    destructor Destroy; override;
  end;

  // Parameter declaration:  name : TypeName
  TParamDecl = class(TASTNode)
    Name     : string;
    TypeName : string;
    IsVar    : Boolean;
  end;

  // Standalone procedure/function declaration
  TRoutineDecl = class(TASTNode)
    Name       : string;
    Params     : TObjectList<TParamDecl>;
    ReturnType : string;
    Locals     : TObjectList<TVarDecl>;
    Body       : TBlockStmt;
    constructor Create;
    destructor  Destroy; override;
  end;

  // =========================================================================
  //  OOP DECLARATIONS
  //  TVarDecl and TParamDecl are declared above so TMethodDecl can use them.
  // =========================================================================

  // Visibility modifier
  TVisibility = (visPublic, visPrivate, visProtected, visPublished);

  // Field inside a class:  Name : TypeName;
  TFieldDecl = class(TASTNode)
    Name       : string;
    TypeName   : string;
    Visibility : TVisibility;
  end;

  // Property inside a class:  property Name : Type read F write F;
  TPropertyDecl = class(TASTNode)
    Name       : string;
    TypeName   : string;
    ReadName   : string;
    WriteName  : string;
    Visibility : TVisibility;
  end;

  // Method declaration — can be virtual/override/abstract
  TMethodDecl = class(TASTNode)
    Name         : string;
    Params       : TObjectList<TParamDecl>;   // TParamDecl declared above
    ReturnType   : string;
    Locals       : TObjectList<TVarDecl>;     // TVarDecl declared above
    Body         : TBlockStmt;               // nil for abstract
    IsVirtual    : Boolean;
    IsOverride   : Boolean;
    IsAbstract   : Boolean;
    IsConstructor: Boolean;
    IsDestructor : Boolean;
    Visibility   : TVisibility;
    OwnerClass   : string;
    constructor Create;
    destructor  Destroy; override;
  end;

  // Class declaration:  TDog = class(TAnimal) ... end;
  TClassDecl = class(TASTNode)
    Name       : string;
    ParentName : string;
    Interfaces : TStringList;
    Fields     : TObjectList<TFieldDecl>;
    Methods    : TObjectList<TMethodDecl>;
    Properties : TObjectList<TPropertyDecl>;
    IsAbstract : Boolean;
    constructor Create;
    destructor  Destroy; override;
  end;

  // Interface declaration:  IGreeter = interface ... end;
  TInterfaceDecl = class(TASTNode)
    Name    : string;
    Methods : TObjectList<TMethodDecl>;
    constructor Create;
    destructor  Destroy; override;
  end;

  // Type block:  type TFoo = class ... end; IBar = interface ... end;
  TTypeBlock = class(TASTNode)
    Classes    : TObjectList<TClassDecl>;
    Interfaces : TObjectList<TInterfaceDecl>;
    constructor Create;
    destructor  Destroy; override;
  end;

  // =========================================================================
  //  TOP-LEVEL PROGRAM NODE
  // =========================================================================
  TProgramNode = class(TASTNode)
    ProgramName : string;
    TypeBlocks  : TObjectList<TTypeBlock>;
    Classes     : TObjectList<TClassDecl>;
    Interfaces  : TObjectList<TInterfaceDecl>;
    Globals     : TObjectList<TVarDecl>;
    Routines    : TObjectList<TRoutineDecl>;
    MainBlock   : TBlockStmt;
    constructor Create;
    destructor  Destroy; override;
  end;

// =============================================================================
implementation
// =============================================================================

{ TBinOpExpr }
destructor TBinOpExpr.Destroy;
begin
  Left.Free;
  Right.Free;
  inherited;
end;

{ TUnaryExpr }
destructor TUnaryExpr.Destroy;
begin
  Operand.Free;
  inherited;
end;

{ TCallExpr }
constructor TCallExpr.Create;
begin
  inherited;
  Args := TExprList.Create(True);
end;
destructor TCallExpr.Destroy;
begin
  Args.Free;
  inherited;
end;

{ TFieldExpr }
destructor TFieldExpr.Destroy;
begin
  Obj.Free;
  inherited;
end;

{ TMethodCallExpr }
constructor TMethodCallExpr.Create;
begin
  inherited;
  Args := TExprList.Create(True);
end;
destructor TMethodCallExpr.Destroy;
begin
  Obj.Free;
  Args.Free;
  inherited;
end;

{ TCreateExpr }
constructor TCreateExpr.Create;
begin
  inherited;
  Args := TExprList.Create(True);
end;
destructor TCreateExpr.Destroy;
begin
  Args.Free;
  inherited;
end;

{ TAssignStmt }
destructor TAssignStmt.Destroy;
begin
  Expr.Free;
  inherited;
end;

{ TFieldAssignStmt }
destructor TFieldAssignStmt.Destroy;
begin
  Obj.Free;
  Value.Free;
  inherited;
end;

{ TWritelnStmt }
constructor TWritelnStmt.Create;
begin
  inherited;
  Args    := TExprList.Create(True);
  NewLine := True;
end;
destructor TWritelnStmt.Destroy;
begin
  Args.Free;
  inherited;
end;

{ TIfStmt }
destructor TIfStmt.Destroy;
begin
  Condition.Free;
  ThenBranch.Free;
  ElseBranch.Free;
  inherited;
end;

{ TWhileStmt }
destructor TWhileStmt.Destroy;
begin
  Condition.Free;
  Body.Free;
  inherited;
end;

{ TRepeatStmt }
constructor TRepeatStmt.Create;
begin
  inherited;
  Body := TStmtList.Create(True);
end;
destructor TRepeatStmt.Destroy;
begin
  Body.Free;
  Condition.Free;
  inherited;
end;

{ TForStmt }
destructor TForStmt.Destroy;
begin
  StartVal.Free;
  EndVal.Free;
  Body.Free;
  inherited;
end;

{ TBlockStmt }
constructor TBlockStmt.Create;
begin
  inherited;
  Stmts := TStmtList.Create(True);
end;
destructor TBlockStmt.Destroy;
begin
  Stmts.Free;
  inherited;
end;

{ TCallStmt }
constructor TCallStmt.Create;
begin
  inherited;
  Args := TExprList.Create(True);
end;
destructor TCallStmt.Destroy;
begin
  Args.Free;
  inherited;
end;

{ TMethodCallStmt }
constructor TMethodCallStmt.Create;
begin
  inherited;
  Args := TExprList.Create(True);
end;
destructor TMethodCallStmt.Destroy;
begin
  Obj.Free;
  Args.Free;
  inherited;
end;

{ TExitStmt }
destructor TExitStmt.Destroy;
begin
  Expr.Free;
  inherited;
end;

{ TInheritedCallStmt }
constructor TInheritedCallStmt.Create;
begin
  inherited;
  Args := TExprList.Create(True);
end;
destructor TInheritedCallStmt.Destroy;
begin
  Args.Free;
  inherited;
end;

{ TCaseArm }
constructor TCaseArm.Create;
begin
  inherited;
  Values := TList<Int64>.Create;
end;
destructor TCaseArm.Destroy;
begin
  Values.Free;
  Body.Free;
  inherited;
end;

{ TCaseStmt }
constructor TCaseStmt.Create;
begin
  inherited;
  Arms := TObjectList<TCaseArm>.Create(True);
end;
destructor TCaseStmt.Destroy;
begin
  Expr.Free;
  Arms.Free;
  ElseBody.Free;
  inherited;
end;

{ TCaseOfArm }
constructor TCaseOfArm.Create;
begin
  inherited;
  Values := TStringList.Create;
end;
destructor TCaseOfArm.Destroy;
begin
  Values.Free;
  Body.Free;
  inherited;
end;

{ TCaseOfStmt }
constructor TCaseOfStmt.Create;
begin
  inherited;
  Arms := TObjectList<TCaseOfArm>.Create(True);
end;
destructor TCaseOfStmt.Destroy;
begin
  Expr.Free;
  Arms.Free;
  ElseBody.Free;
  inherited;
end;

{ TVarDecl }
destructor TVarDecl.Destroy;
begin
  InitExpr.Free;
  inherited;
end;

{ TRoutineDecl }
constructor TRoutineDecl.Create;
begin
  inherited;
  Params := TObjectList<TParamDecl>.Create(True);
  Locals := TObjectList<TVarDecl>.Create(True);
end;
destructor TRoutineDecl.Destroy;
begin
  Params.Free;
  Locals.Free;
  Body.Free;
  inherited;
end;

{ TMethodDecl }
constructor TMethodDecl.Create;
begin
  inherited;
  Params := TObjectList<TParamDecl>.Create(True);
  Locals := TObjectList<TVarDecl>.Create(True);
end;
destructor TMethodDecl.Destroy;
begin
  Params.Free;
  Locals.Free;
  Body.Free;
  inherited;
end;

{ TClassDecl }
constructor TClassDecl.Create;
begin
  inherited;
  Interfaces := TStringList.Create;
  Fields     := TObjectList<TFieldDecl>.Create(True);
  Methods    := TObjectList<TMethodDecl>.Create(True);
  Properties := TObjectList<TPropertyDecl>.Create(True);
end;
destructor TClassDecl.Destroy;
begin
  Interfaces.Free;
  Fields.Free;
  Methods.Free;
  Properties.Free;
  inherited;
end;

{ TInterfaceDecl }
constructor TInterfaceDecl.Create;
begin
  inherited;
  Methods := TObjectList<TMethodDecl>.Create(True);
end;
destructor TInterfaceDecl.Destroy;
begin
  Methods.Free;
  inherited;
end;

{ TTypeBlock }
constructor TTypeBlock.Create;
begin
  inherited;
  Classes    := TObjectList<TClassDecl>.Create(True);
  Interfaces := TObjectList<TInterfaceDecl>.Create(True);
end;
destructor TTypeBlock.Destroy;
begin
  Classes.Free;
  Interfaces.Free;
  inherited;
end;

{ TProgramNode }
constructor TProgramNode.Create;
begin
  inherited;
  TypeBlocks := TObjectList<TTypeBlock>.Create(True);
  Classes    := TObjectList<TClassDecl>.Create(False);  // non-owning — owned by TypeBlocks
  Interfaces := TObjectList<TInterfaceDecl>.Create(False); // non-owning
  Globals    := TObjectList<TVarDecl>.Create(True);
  Routines   := TObjectList<TRoutineDecl>.Create(True);
end;
destructor TProgramNode.Destroy;
begin
  TypeBlocks.Free;
  Classes.Free;
  Interfaces.Free;
  Globals.Free;
  Routines.Free;
  MainBlock.Free;
  inherited;
end;

end.
