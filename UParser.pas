unit UParser;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  UParser.pas  -  Recursive-descent parser for MiniDelphi
//  Consumes the token list produced by TLexer and builds a TProgramNode AST.
// =============================================================================

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  ULexer, UAST;

type
  EParseError = class(Exception)
  public
    Line, Col : Integer;
    constructor Create(const Msg: string; ALine, ACol: Integer);
  end;

  TParser = class
  private
    FTokens  : TList<TToken>;
    FPos     : Integer;       // current index into FTokens

    // ------------------------------------------------------------------
    //  Token access helpers
    // ------------------------------------------------------------------
    function  Current        : TToken;
    function  Consume        : TToken;
    function  Expect(Kind: TTokenKind) : TToken;
    function  Match(Kind: TTokenKind) : Boolean;
    procedure Error(const Msg: string);

    // ------------------------------------------------------------------
    //  Grammar rules  (each method = one grammar production)
    // ------------------------------------------------------------------
    function  ParseProgram     : TProgramNode;
    procedure ParseVarBlock    (Decls: TObjectList<TVarDecl>);
    function  ParseVarDecl     : TVarDecl;
    function  ParseRoutine     : TRoutineDecl;
    procedure ParseParamList   (Params: TObjectList<TParamDecl>);
    function  ParseBlock       : TBlockStmt;
    function  ParseStatement   : TStmtNode;
    function  ParseIfStmt      : TIfStmt;
    function  ParseWhileStmt   : TWhileStmt;
    function  ParseRepeatStmt  : TRepeatStmt;
    function  ParseForStmt     : TForStmt;
    function  ParseWriteln     : TWritelnStmt;
    function  ParseReadln      : TReadlnStmt;
    function  ParseCallOrAssign: TStmtNode;
    function  ParseExitStmt    : TExitStmt;
    function  ParseCaseStmt    : TCaseStmt;
    function  ParseCaseOfStmt  : TCaseOfStmt;
    // OOP parsing
    function  ParseTypeBlock   : TTypeBlock;
    function  ParseClassDecl   : TClassDecl;
    function  ParseInterfaceDecl : TInterfaceDecl;
    function  ParseMethodDecl  (const OwnerClass: string;
                                IsInterface: Boolean) : TMethodDecl;
    function  ParseInherited   : TStmtNode;
    function  ParseInlineVarStmt : TStmtNode;
    procedure ParseArgList     (Args: TExprList);

    // Expression parsing (precedence climbing)
    function  ParseExpr        : TExprNode;
    function  ParseOrExpr      : TExprNode;
    function  ParseAndExpr     : TExprNode;
    function  ParseRelExpr     : TExprNode;
    function  ParseAddExpr     : TExprNode;
    function  ParseMulExpr     : TExprNode;
    function  ParseUnaryExpr   : TExprNode;
    function  ParsePrimary     : TExprNode;

  public
    constructor Create(Tokens: TList<TToken>);
    // Parse tokens and return the program AST (caller owns it)
    function Parse : TProgramNode;
  end;

// =============================================================================
implementation
// =============================================================================

{ EParseError }
constructor EParseError.Create(const Msg: string; ALine, ACol: Integer);
begin
  inherited CreateFmt('Line %d, Col %d: %s', [ALine, ACol, Msg]);
  Line := ALine;
  Col  := ACol;
end;

{ TParser }
constructor TParser.Create(Tokens: TList<TToken>);
begin
  inherited Create;
  FTokens := Tokens;
  FPos    := 0;
end;

// ---------------------------------------------------------------------------
//  Token helpers
// ---------------------------------------------------------------------------
function TParser.Current: TToken;
begin
  if FPos < FTokens.Count then
    Result := FTokens[FPos]
  else
  begin
    Result.Kind  := tkEOF;
    Result.Value := '<EOF>';
    Result.Line  := 0;
    Result.Col   := 0;
  end;
end;


function TParser.Consume: TToken;
begin
  Result := Current;
  Inc(FPos);
end;

function TParser.Expect(Kind: TTokenKind): TToken;
begin
  if Current.Kind <> Kind then
    Error(Format('Expected %s but got ''%s''',
      [TLexer.TokenKindName(Kind), Current.Value]));
  Result := Consume;
end;

function TParser.Match(Kind: TTokenKind): Boolean;
begin
  Result := (Current.Kind = Kind);
  if Result then Inc(FPos);
end;

procedure TParser.Error(const Msg: string);
begin
  raise EParseError.Create(Msg, Current.Line, Current.Col);
end;

// ---------------------------------------------------------------------------
//  Public entry point
// ---------------------------------------------------------------------------
function TParser.Parse: TProgramNode;
begin
  Result := ParseProgram;
end;

// ---------------------------------------------------------------------------
//  program MyProg;
//  var ...
//  procedure/function ...
//  begin ... end.
// ---------------------------------------------------------------------------
function TParser.ParseProgram: TProgramNode;
var
  Node : TProgramNode;
  TB3  : TTypeBlock;
  CI3  : Integer;
begin
  Node := TProgramNode.Create;
  try
    // Optional  program Name;
    if Match(tkProgram) then
    begin
      Node.ProgramName := Expect(tkIdentifier).Value;
      Expect(tkSemicolon);
    end;

    // Accept var, type, and routine declarations in any order
    // Real Delphi programs often have routines followed by var blocks
    while Current.Kind in [tkVar, tkType, tkProcedure, tkFunction,
                           tkConstructor_kw, tkDestructor_kw] do
    begin
      if Current.Kind = tkVar then
        ParseVarBlock(Node.Globals)
      else if Current.Kind = tkType then
      begin
        TB3 := ParseTypeBlock;
        Node.TypeBlocks.Add(TB3);
        for CI3 := 0 to TB3.Classes.Count - 1 do
          Node.Classes.Add(TB3.Classes[CI3]);
        for CI3 := 0 to TB3.Interfaces.Count - 1 do
          Node.Interfaces.Add(TB3.Interfaces[CI3]);
      end
      else
        Node.Routines.Add(ParseRoutine);
    end;

    // Main begin..end block
    Node.MainBlock := ParseBlock;
    // Eat trailing dot if present
    Match(tkDot);

    Result := Node;
  except
    Node.Free;
    raise;
  end;
end;

// ---------------------------------------------------------------------------
//  var
//    x, y : Integer;
//    name  : String;
// ---------------------------------------------------------------------------
procedure TParser.ParseVarBlock(Decls: TObjectList<TVarDecl>);
var
  D        : TVarDecl;
  Names    : TStringList;
  TypeName : string;
  I        : Integer;
begin
  Expect(tkVar);
  // One or more declarations:  a, b, c : Integer;
  while Current.Kind = tkIdentifier do
  begin
    // Collect comma-separated names
    Names := TStringList.Create;
    try
      Names.Add(Expect(tkIdentifier).Value);
      while Match(tkComma) do
        Names.Add(Expect(tkIdentifier).Value);
      Expect(tkColon);
      // Type name
      if Current.Kind in [tkInteger_kw, tkString_kw,
                          tkBoolean_kw, tkReal_kw] then
        TypeName := LowerCase(Consume.Value)
      else
        TypeName := Expect(tkIdentifier).Value;
      Expect(tkSemicolon);
      // Create one TVarDecl per name
      for I := 0 to Names.Count - 1 do
      begin
        D          := TVarDecl.Create;
        D.Name     := Names[I];
        D.TypeName := TypeName;
        Decls.Add(D);
      end;
    finally
      Names.Free;
    end;
  end;
end;

// ParseVarDecl kept for compatibility (used by ParseRoutine locals)
function TParser.ParseVarDecl: TVarDecl;
var
  D    : TVarDecl;
begin
  D    := TVarDecl.Create;
  D.Name := Expect(tkIdentifier).Value;
  Expect(tkColon);
  if Current.Kind in [tkInteger_kw, tkString_kw, tkBoolean_kw, tkReal_kw] then
    D.TypeName := LowerCase(Consume.Value)
  else
    D.TypeName := Expect(tkIdentifier).Value;
  Expect(tkSemicolon);
  Result := D;
end;

// ---------------------------------------------------------------------------
//  procedure Foo(a: Integer; var b: String);
//  var ...
//  begin ... end;
// ---------------------------------------------------------------------------
function TParser.ParseRoutine: TRoutineDecl;
var
  R       : TRoutineDecl;
  IsFunc  : Boolean;
begin
  R      := TRoutineDecl.Create;
  IsFunc := (Current.Kind = tkFunction);
  Consume;  // eat procedure / function
  R.Name := Expect(tkIdentifier).Value;

  // Optional parameter list
  if Match(tkLParen) then
  begin
    ParseParamList(R.Params);
    Expect(tkRParen);
  end;

  // Return type for functions
  if IsFunc then
  begin
    Expect(tkColon);
    if Current.Kind in [tkInteger_kw, tkString_kw, tkBoolean_kw, tkReal_kw] then
      R.ReturnType := LowerCase(Consume.Value)
    else
      R.ReturnType := Expect(tkIdentifier).Value;
  end;
  Expect(tkSemicolon);

  // Local var block
  while Current.Kind = tkVar do
    ParseVarBlock(R.Locals);

  R.Body := ParseBlock;
  Expect(tkSemicolon);
  Result := R;
end;

procedure TParser.ParseParamList(Params: TObjectList<TParamDecl>);
var
  P        : TParamDecl;
  IsVar    : Boolean;
  TypeName : string;
  Names    : TStringList;
  I        : Integer;
begin
  repeat
    IsVar := Match(tkVar);
    // Collect comma-separated names:  a, b, c : Integer
    Names := TStringList.Create;
    try
      Names.Add(Expect(tkIdentifier).Value);
      while Match(tkComma) do
        Names.Add(Expect(tkIdentifier).Value);
      Expect(tkColon);
      if Current.Kind in [tkInteger_kw, tkString_kw,
                          tkBoolean_kw, tkReal_kw] then
        TypeName := LowerCase(Consume.Value)
      else
        TypeName := Expect(tkIdentifier).Value;
      for I := 0 to Names.Count - 1 do
      begin
        P          := TParamDecl.Create;
        P.Name     := Names[I];
        P.TypeName := TypeName;
        P.IsVar    := IsVar;
        Params.Add(P);
      end;
    finally
      Names.Free;
    end;
  until not Match(tkSemicolon);
end;

// ---------------------------------------------------------------------------
//  begin
//    stmt; stmt; ...
//  end
// ---------------------------------------------------------------------------
function TParser.ParseBlock: TBlockStmt;
var
  B    : TBlockStmt;
  Stmt : TStmtNode;
begin
  B := TBlockStmt.Create;
  Expect(tkBegin);
  while not (Current.Kind in [tkEnd, tkEOF]) do
  begin
    Stmt := ParseStatement;
    if Stmt <> nil then
      B.Stmts.Add(Stmt);
    // Eat optional semicolon between statements
    if Current.Kind = tkSemicolon then
      Consume
    else if not (Current.Kind in [tkEnd, tkEOF, tkElse]) then
      Break;  // something unexpected – stop gracefully
  end;
  Expect(tkEnd);
  Result := B;
end;

// ---------------------------------------------------------------------------
//  Dispatch to the right statement parser
// ---------------------------------------------------------------------------
function TParser.ParseStatement: TStmtNode;
begin
  case Current.Kind of
    tkBegin   : Result := ParseBlock;
    tkIf      : Result := ParseIfStmt;
    tkWhile   : Result := ParseWhileStmt;
    tkRepeat  : Result := ParseRepeatStmt;
    tkFor     : Result := ParseForStmt;
    tkWriteln : Result := ParseWriteln;
    tkWrite   : Result := ParseWriteln;
    tkReadln  : Result := ParseReadln;
    tkCase    : Result := ParseCaseStmt;
    tkCaseOf  : Result := ParseCaseOfStmt;
    tkExit    : Result := ParseExitStmt;
    tkVar       : Result := ParseInlineVarStmt;
    tkBreak     : begin Consume; Result := TBreakStmt.Create; end;
    tkContinue  : begin Consume; Result := TContinueStmt.Create; end;
    tkInherited : Result := ParseInherited;
    tkIdentifier,
    tkResult  : Result := ParseCallOrAssign;
  else
    Result := nil;
  end;
end;

// ---------------------------------------------------------------------------
//  if expr then stmt [else stmt]
// ---------------------------------------------------------------------------
function TParser.ParseIfStmt: TIfStmt;
var
  N : TIfStmt;
begin
  N := TIfStmt.Create;
  Expect(tkIf);
  N.Condition  := ParseExpr;
  Expect(tkThen);
  N.ThenBranch := ParseStatement;
  if Current.Kind = tkElse then
  begin
    Consume;
    N.ElseBranch := ParseStatement;
  end;
  Result := N;
end;

// ---------------------------------------------------------------------------
//  while expr do stmt
// ---------------------------------------------------------------------------
function TParser.ParseWhileStmt: TWhileStmt;
var
  N : TWhileStmt;
begin
  N := TWhileStmt.Create;
  Expect(tkWhile);
  N.Condition := ParseExpr;
  Expect(tkDo);
  N.Body      := ParseStatement;
  Result      := N;
end;

// ---------------------------------------------------------------------------
//  repeat stmts until expr
// ---------------------------------------------------------------------------
function TParser.ParseRepeatStmt: TRepeatStmt;
var
  N    : TRepeatStmt;
  Stmt : TStmtNode;
begin
  N := TRepeatStmt.Create;
  Expect(tkRepeat);
  while not (Current.Kind in [tkUntil, tkEOF]) do
  begin
    Stmt := ParseStatement;
    if Stmt <> nil then N.Body.Add(Stmt);
    Match(tkSemicolon);
  end;
  Expect(tkUntil);
  N.Condition := ParseExpr;
  Result := N;
end;

// ---------------------------------------------------------------------------
//  for i := start to/downto finish do stmt
// ---------------------------------------------------------------------------
function TParser.ParseForStmt: TForStmt;
var
  N : TForStmt;
begin
  N := TForStmt.Create;
  Expect(tkFor);
  N.VarName := Expect(tkIdentifier).Value;
  Expect(tkAssign);
  N.StartVal := ParseExpr;
  if Current.Kind = tkDownTo then
  begin
    N.IsDownTo := True;
    Consume;
  end
  else
  begin
    N.IsDownTo := False;
    Expect(tkTo);
  end;
  N.EndVal := ParseExpr;
  Expect(tkDo);
  N.Body   := ParseStatement;
  Result   := N;
end;

// ---------------------------------------------------------------------------
//  writeln(a, b, c)  /  write(a, b, c)
// ---------------------------------------------------------------------------
function TParser.ParseWriteln: TWritelnStmt;
var
  N : TWritelnStmt;
begin
  N         := TWritelnStmt.Create;
  N.NewLine := (Current.Kind = tkWriteln);
  Consume;  // eat writeln or write
  if Match(tkLParen) then
  begin
    ParseArgList(N.Args);
    Expect(tkRParen);
  end;
  Result := N;
end;

// ---------------------------------------------------------------------------
//  readln(varName)
// ---------------------------------------------------------------------------
function TParser.ParseReadln: TReadlnStmt;
var
  N : TReadlnStmt;
begin
  N := TReadlnStmt.Create;
  Expect(tkReadln);
  if Match(tkLParen) then
  begin
    N.VarName := Expect(tkIdentifier).Value;
    Expect(tkRParen);
  end;
  Result := N;
end;

// ---------------------------------------------------------------------------
//  exit  /  exit(expr)
// ---------------------------------------------------------------------------
function TParser.ParseExitStmt: TExitStmt;
var
  N : TExitStmt;
begin
  N := TExitStmt.Create;
  Expect(tkExit);
  if Match(tkLParen) then
  begin
    N.Expr := ParseExpr;
    Expect(tkRParen);
  end;
  Result := N;
end;

// ---------------------------------------------------------------------------
//  Could be:   Foo := expr        (assignment)
//           or Foo(args)          (procedure call)
// ---------------------------------------------------------------------------
function TParser.ParseCallOrAssign: TStmtNode;
var
  Name    : string;
  AssStmt : TAssignStmt;
  CallStmt: TCallStmt;
begin
  Name := Consume.Value;  // eat identifier / Result

  if Current.Kind = tkAssign then
  begin
    // Assignment
    Consume;
    AssStmt         := TAssignStmt.Create;
    AssStmt.VarName := Name;
    AssStmt.Expr    := ParseExpr;
    Result          := AssStmt;
  end
  else if Current.Kind = tkLParen then
  begin
    // Procedure call
    Consume;
    CallStmt      := TCallStmt.Create;
    CallStmt.Name := Name;
    ParseArgList(CallStmt.Args);
    Expect(tkRParen);
    Result := CallStmt;
  end
  else
  begin
    // Bare name — treat as zero-arg procedure call
    CallStmt      := TCallStmt.Create;
    CallStmt.Name := Name;
    Result        := CallStmt;
  end;
end;

// ---------------------------------------------------------------------------
//  Comma-separated expression list  (shared by writeln, calls, etc.)
// ---------------------------------------------------------------------------
procedure TParser.ParseArgList(Args: TExprList);
begin
  if Current.Kind in [tkRParen, tkEOF] then Exit;
  Args.Add(ParseExpr);
  while Match(tkComma) do
    Args.Add(ParseExpr);
end;

// ---------------------------------------------------------------------------
//  Expression grammar  (precedence lowest → highest)
//
//  Expr      = OrExpr
//  OrExpr    = AndExpr  { 'or'  AndExpr }
//  AndExpr   = RelExpr  { 'and' RelExpr }
//  RelExpr   = AddExpr  { ('=' | '<>' | '<' | '<=' | '>' | '>=') AddExpr }
//  AddExpr   = MulExpr  { ('+' | '-') MulExpr }
//  MulExpr   = Unary    { ('*' | '/' | 'div' | 'mod') Unary }
//  Unary     = ('-' | 'not') Unary  |  Primary
//  Primary   = IntLit | FloatLit | StringLit | 'true' | 'false' | 'nil'
//            | Identifier ['(' args ')']
//            | '(' Expr ')'
// ---------------------------------------------------------------------------

function TParser.ParseExpr: TExprNode;
begin
  Result := ParseOrExpr;
end;

function TParser.ParseOrExpr: TExprNode;
var
  Left  : TExprNode;
  BinOp : TBinOpExpr;
begin
  Left := ParseAndExpr;
  while Current.Kind = tkOr do
  begin
    Consume;
    BinOp       := TBinOpExpr.Create;
    BinOp.Left  := Left;
    BinOp.Op    := 'or';
    BinOp.Right := ParseAndExpr;
    Left        := BinOp;
  end;
  Result := Left;
end;

function TParser.ParseAndExpr: TExprNode;
var
  Left  : TExprNode;
  BinOp : TBinOpExpr;
begin
  Left := ParseRelExpr;
  while Current.Kind = tkAnd do
  begin
    Consume;
    BinOp       := TBinOpExpr.Create;
    BinOp.Left  := Left;
    BinOp.Op    := 'and';
    BinOp.Right := ParseRelExpr;
    Left        := BinOp;
  end;
  Result := Left;
end;

function TParser.ParseRelExpr: TExprNode;
var
  Left  : TExprNode;
  Op    : string;
  BinOp : TBinOpExpr;
begin
  Left := ParseAddExpr;
  while Current.Kind in [tkEqual, tkNotEqual, tkLess, tkLessEq, tkGreater, tkGreaterEq] do
  begin
    case Current.Kind of
      tkEqual     : Op := '=';
      tkNotEqual  : Op := '<>';
      tkLess      : Op := '<';
      tkLessEq    : Op := '<=';
      tkGreater   : Op := '>';
      tkGreaterEq : Op := '>=';
    else Op := '?';
    end;
    Consume;
    BinOp       := TBinOpExpr.Create;
    BinOp.Left  := Left;
    BinOp.Op    := Op;
    BinOp.Right := ParseAddExpr;
    Left        := BinOp;
  end;
  Result := Left;
end;

function TParser.ParseAddExpr: TExprNode;
var
  Left  : TExprNode;
  Op    : string;
  BinOp : TBinOpExpr;
begin
  Left := ParseMulExpr;
  while Current.Kind in [tkPlus, tkMinus] do
  begin
    if Current.Kind = tkPlus then Op := '+' else Op := '-';
    Consume;
    BinOp       := TBinOpExpr.Create;
    BinOp.Left  := Left;
    BinOp.Op    := Op;
    BinOp.Right := ParseMulExpr;
    Left        := BinOp;
  end;
  Result := Left;
end;

function TParser.ParseMulExpr: TExprNode;
var
  Left  : TExprNode;
  Op    : string;
  BinOp : TBinOpExpr;
begin
  Left := ParseUnaryExpr;
  while Current.Kind in [tkStar, tkSlash, tkDiv, tkMod] do
  begin
    case Current.Kind of
      tkStar  : Op := '*';
      tkSlash : Op := '/';
      tkDiv   : Op := 'div';
      tkMod   : Op := 'mod';
    else Op := '?';
    end;
    Consume;
    BinOp       := TBinOpExpr.Create;
    BinOp.Left  := Left;
    BinOp.Op    := Op;
    BinOp.Right := ParseUnaryExpr;
    Left        := BinOp;
  end;
  Result := Left;
end;

function TParser.ParseUnaryExpr: TExprNode;
var
  U : TUnaryExpr;
begin
  if Current.Kind = tkMinus then
  begin
    Consume;
    U         := TUnaryExpr.Create;
    U.Op      := '-';
    U.Operand := ParseUnaryExpr;
    Result    := U;
  end
  else if Current.Kind = tkNot then
  begin
    Consume;
    U         := TUnaryExpr.Create;
    U.Op      := 'not';
    U.Operand := ParseUnaryExpr;
    Result    := U;
  end
  else
    Result := ParsePrimary;
end;

function TParser.ParsePrimary: TExprNode;
var
  Tok  : TToken;
  IL   : TIntLitExpr;
  FL   : TFloatLitExpr;
  SL   : TStrLitExpr;
  BL   : TBoolLitExpr;
  VE   : TVarExpr;
  CE   : TCallExpr;
  Sub  : TExprNode;
begin
  Tok := Current;

  case Tok.Kind of

    tkInteger:
    begin
      Consume;
      IL       := TIntLitExpr.Create;
      IL.Value := StrToInt64(Tok.Value);
      Result   := IL;
    end;

    tkFloat:
    begin
      Consume;
      FL       := TFloatLitExpr.Create;
      FL.Value := StrToFloat(Tok.Value, TFormatSettings.Create('en-US'));
      Result   := FL;
    end;

    tkString:
    begin
      Consume;
      SL       := TStrLitExpr.Create;
      SL.Value := Tok.Value;
      Result   := SL;
    end;

    tkTrue:
    begin
      Consume;
      BL       := TBoolLitExpr.Create;
      BL.Value := True;
      Result   := BL;
    end;

    tkFalse:
    begin
      Consume;
      BL       := TBoolLitExpr.Create;
      BL.Value := False;
      Result   := BL;
    end;

    tkNil:
    begin
      Consume;
      Result := TNilLitExpr.Create;
    end;

    tkIdentifier, tkResult:
    begin
      Consume;
      if Current.Kind = tkLParen then
      begin
        // Function call expression
        Consume;
        CE      := TCallExpr.Create;
        CE.Name := Tok.Value;
        ParseArgList(CE.Args);
        Expect(tkRParen);
        Result := CE;
      end
      else
      begin
        VE      := TVarExpr.Create;
        VE.Name := Tok.Value;
        Result  := VE;
      end;
    end;

    tkLParen:
    begin
      Consume;
      Sub := ParseExpr;
      Expect(tkRParen);
      Result := Sub;
    end;

  else
    Error(Format('Unexpected token ''%s'' in expression', [Tok.Value]));
    Result := nil; // keep compiler happy
  end;
end;

// ---------------------------------------------------------------------------
//  case Expr of
//    1, 2 : stmt;
//    3    : stmt;
//  else
//    stmt;
//  end;
// ---------------------------------------------------------------------------
function TParser.ParseCaseStmt: TCaseStmt;
var
  N   : TCaseStmt;
  Arm : TCaseArm;
  V   : Int64;
begin
  N := TCaseStmt.Create;
  Expect(tkCase);
  N.Expr := ParseExpr;
  Expect(tkOf);

  // Parse arms until we see else or end
  while not (Current.Kind in [tkElse, tkEnd, tkEOF]) do
  begin
    Arm := TCaseArm.Create;
    // One or more integer constants separated by commas
    V := StrToInt64(Expect(tkInteger).Value);
    Arm.Values.Add(V);
    while Match(tkComma) do
    begin
      V := StrToInt64(Expect(tkInteger).Value);
      Arm.Values.Add(V);
    end;
    Expect(tkColon);
    Arm.Body := ParseStatement;
    N.Arms.Add(Arm);
    Match(tkSemicolon);  // optional trailing semicolon after each arm
  end;

  // Optional else clause
  if Match(tkElse) then
  begin
    N.ElseBody := ParseStatement;
    Match(tkSemicolon);
  end;

  Expect(tkEnd);
  Result := N;
end;

// ---------------------------------------------------------------------------
//  caseof Expr of
//    'cat'       : stmt;
//    'dog','hound' : stmt;
//  else
//    stmt;
//  end;
// ---------------------------------------------------------------------------
function TParser.ParseCaseOfStmt: TCaseOfStmt;
var
  N   : TCaseOfStmt;
  Arm : TCaseOfArm;
begin
  N := TCaseOfStmt.Create;
  Expect(tkCaseOf);
  N.Expr := ParseExpr;
  Expect(tkOf);

  while not (Current.Kind in [tkElse, tkEnd, tkEOF]) do
  begin
    Arm := TCaseOfArm.Create;
    // One or more string constants separated by commas
    Arm.Values.Add(Expect(tkString).Value);
    while Match(tkComma) do
      Arm.Values.Add(Expect(tkString).Value);
    Expect(tkColon);
    Arm.Body := ParseStatement;
    N.Arms.Add(Arm);
    Match(tkSemicolon);
  end;

  if Match(tkElse) then
  begin
    N.ElseBody := ParseStatement;
    Match(tkSemicolon);
  end;

  Expect(tkEnd);
  Result := N;
end;

// ---------------------------------------------------------------------------
//  type
//    TAnimal = class ... end;
//    IGreeter = interface ... end;
// ---------------------------------------------------------------------------
function TParser.ParseTypeBlock: TTypeBlock;
var
  TB   : TTypeBlock;
  Name : string;
begin
  TB := TTypeBlock.Create;
  Expect(tkType);

  // One or more  Name = class/interface ... end;
  while Current.Kind = tkIdentifier do
  begin
    Name := Consume.Value;
    Expect(tkEqual);

    if Current.Kind = tkClass then
    begin
      TB.Classes.Add(ParseClassDecl);
      TB.Classes[TB.Classes.Count-1].Name := Name;
    end
    else if Current.Kind = tkInterface_kw then
    begin
      TB.Interfaces.Add(ParseInterfaceDecl);
      TB.Interfaces[TB.Interfaces.Count-1].Name := Name;
    end
    else
    begin
      // Unknown type — skip to semicolon
      while not (Current.Kind in [tkSemicolon, tkEOF]) do Consume;
    end;
    Match(tkSemicolon);
  end;

  Result := TB;
end;

// ---------------------------------------------------------------------------
//  class [(ParentClass)] [(IFace1, IFace2)]
//    [visibility section]
//    fields and methods
//  end;
// ---------------------------------------------------------------------------
function TParser.ParseClassDecl: TClassDecl;
var
  CD  : TClassDecl;
  Vis : TVisibility;

  procedure SetVis;
  begin
    case Current.Kind of
      tkPublic    : begin Vis := visPublic;    Consume; end;
      tkPrivate   : begin Vis := visPrivate;   Consume; end;
      tkProtected : begin Vis := visProtected; Consume; end;
      tkPublished : begin Vis := visPublished; Consume; end;
    end;
  end;

begin
  CD  := TClassDecl.Create;
  Vis := visPublic;   // default visibility
  Expect(tkClass);

  // Optional parent class:  class(TAnimal)
  if Match(tkLParen) then
  begin
    CD.ParentName := Expect(tkIdentifier).Value;
    // Optional interface list:  class(TAnimal, IGreeter, IRunnable)
    while Match(tkComma) do
      CD.Interfaces.Add(LowerCase(Expect(tkIdentifier).Value));
    Expect(tkRParen);
  end;

  // Class body
  while not (Current.Kind in [tkEnd, tkEOF]) do
  begin
    SetVis;
    if Current.Kind in [tkEnd, tkEOF] then Break;

    if Current.Kind in [tkProcedure, tkFunction,
                        tkConstructor_kw, tkDestructor_kw] then
    begin
      begin
        var MethD : TMethodDecl;
        MethD := ParseMethodDecl(CD.Name, False);
        MethD.Visibility := Vis;
        CD.Methods.Add(MethD);
      end
    end
    else if Current.Kind = tkProperty_kw then
    begin
      // property Name : Type read FField write FField;
      begin
        var PropD : TPropertyDecl;
        PropD := TPropertyDecl.Create;
        PropD.Visibility := Vis;
        Consume; // eat 'property'
        PropD.Name     := Expect(tkIdentifier).Value;
        Expect(tkColon);
        if Current.Kind in [tkInteger_kw, tkString_kw,
                            tkBoolean_kw, tkReal_kw] then
          PropD.TypeName := LowerCase(Consume.Value)
        else
          PropD.TypeName := Expect(tkIdentifier).Value;
        if Match(tkIdentifier) then  // 'read'
          PropD.ReadName := Expect(tkIdentifier).Value;
        if Match(tkIdentifier) then  // 'write'
          PropD.WriteName := Expect(tkIdentifier).Value;
        Match(tkSemicolon);
        CD.Properties.Add(PropD);
      end
    end
    else if Current.Kind = tkIdentifier then
    begin
      // Field declaration:  Name : TypeName;
      begin
        var FldD : TFieldDecl;
        FldD := TFieldDecl.Create;
        FldD.Visibility := Vis;
        FldD.Name     := Consume.Value;
        Expect(tkColon);
        if Current.Kind in [tkInteger_kw, tkString_kw,
                            tkBoolean_kw, tkReal_kw] then
          FldD.TypeName := LowerCase(Consume.Value)
        else
          FldD.TypeName := Expect(tkIdentifier).Value;
        Match(tkSemicolon);
        CD.Fields.Add(FldD);
      end
    end
    else
      Consume; // skip unknown tokens gracefully
  end;

  Expect(tkEnd);
  Result := CD;
end;

// ---------------------------------------------------------------------------
//  interface
//    procedure/function signatures (no bodies)
//  end;
// ---------------------------------------------------------------------------
function TParser.ParseInterfaceDecl: TInterfaceDecl;
var
  ID : TInterfaceDecl;
begin
  ID := TInterfaceDecl.Create;
  Expect(tkInterface_kw);

  while not (Current.Kind in [tkEnd, tkEOF]) do
  begin
    if Current.Kind in [tkProcedure, tkFunction] then
    begin
      ID.Methods.Add(ParseMethodDecl('', True));
    end
    else
      Consume;
  end;

  Expect(tkEnd);
  Result := ID;
end;

// ---------------------------------------------------------------------------
//  Parse a method declaration (header + optional body)
// ---------------------------------------------------------------------------
function TParser.ParseMethodDecl(const OwnerClass: string;
  IsInterface: Boolean): TMethodDecl;
var
  M : TMethodDecl;
begin
  M           := TMethodDecl.Create;
  M.OwnerClass := OwnerClass;

  // constructor / destructor / procedure / function
  case Current.Kind of
    tkConstructor_kw : begin M.IsConstructor := True;  Consume; end;
    tkDestructor_kw  : begin M.IsDestructor  := True;  Consume; end;
    tkProcedure      : Consume;
    tkFunction       : Consume;
  end;

  // For method implementations:  ClassName.MethodName
  M.Name := Expect(tkIdentifier).Value;
  if (Current.Kind = tkDot) and (OwnerClass = '') then
  begin
    Consume;
    M.OwnerClass := M.Name;
    M.Name      := Expect(tkIdentifier).Value;
  end;

  // Parameters
  if Match(tkLParen) then
  begin
    ParseParamList(M.Params);
    Expect(tkRParen);
  end;

  // Return type for functions
  if Current.Kind = tkColon then
  begin
    Consume;
    if Current.Kind in [tkInteger_kw, tkString_kw,
                        tkBoolean_kw, tkReal_kw] then
      M.ReturnType := LowerCase(Consume.Value)
    else
      M.ReturnType := Expect(tkIdentifier).Value;
  end;
  Expect(tkSemicolon);

  // Modifiers: virtual; override; abstract; overload;
  while Current.Kind in [tkVirtual, tkOverride_kw, tkAbstract,
                         tkOverloaded] do
  begin
    case Current.Kind of
      tkVirtual    : M.IsVirtual   := True;
      tkOverride_kw: M.IsOverride  := True;
      tkAbstract   : M.IsAbstract  := True;
    end;
    Consume;
    Match(tkSemicolon);
  end;

  // Body — only for non-interface, non-abstract methods
  if (not IsInterface) and (not M.IsAbstract) then
  begin
    // Skip the class-level method bodies  — they are parsed separately
    // when we see   procedure TDog.Speak;  at the top level
    // Here in the class declaration we only parse the signature
    // unless this is a standalone method implementation (OwnerClass='')
  end;

  Result := M;
end;

// ---------------------------------------------------------------------------
//  inherited  or  inherited MethodName(args);
// ---------------------------------------------------------------------------
function TParser.ParseInherited: TStmtNode;
var
  N : TInheritedCallStmt;
begin
  N := TInheritedCallStmt.Create;
  Expect(tkInherited);

  // Optional:  inherited MethodName(args)
  if Current.Kind = tkIdentifier then
  begin
    N.MethodName := Consume.Value;
    if Match(tkLParen) then
    begin
      ParseArgList(N.Args);
      Expect(tkRParen);
    end;
  end;
  // else: bare  inherited  — call same method name in parent

  Result := N;
end;

// ---------------------------------------------------------------------------
//  var x : Integer;  declared inside a begin..end block
//  We parse it, declare the var, and return a no-op statement.
//  The variable is added to the current routine's local scope via a special
//  mechanism: we emit an TAssignStmt with a sentinel to trigger declaration.
//  Simplest approach: just consume it and add to the enclosing context.
//  Since we don't have scope context here, we add to a thread-local list
//  and let the interpreter declare it on first assignment.
// ---------------------------------------------------------------------------
function TParser.ParseInlineVarStmt: TStmtNode;
var
  Names    : TStringList;
  TypeName : string;
  Dummy    : TAssignStmt;
  NilExpr  : TNilLitExpr;
  I        : Integer;
begin
  Expect(tkVar);
  Names := TStringList.Create;
  try
    Names.Add(Expect(tkIdentifier).Value);
    while Match(tkComma) do
      Names.Add(Expect(tkIdentifier).Value);
    Expect(tkColon);
    if Current.Kind in [tkInteger_kw, tkString_kw,
                        tkBoolean_kw, tkReal_kw] then
      TypeName := LowerCase(Consume.Value)
    else
      TypeName := Expect(tkIdentifier).Value;
    Match(tkSemicolon);
    // Return assignment to nil for each var — interpreter auto-declares on set
    // For multiple names, wrap in a block
    if Names.Count = 1 then
    begin
      Dummy         := TAssignStmt.Create;
      Dummy.VarName := Names[0];
      NilExpr       := TNilLitExpr.Create;
      Dummy.Expr    := NilExpr;
      Result        := Dummy;
    end
    else
    begin
      var Blk := TBlockStmt.Create;
      for I := 0 to Names.Count - 1 do
      begin
        Dummy         := TAssignStmt.Create;
        Dummy.VarName := Names[I];
        NilExpr       := TNilLitExpr.Create;
        Dummy.Expr    := NilExpr;
        Blk.Stmts.Add(Dummy);
      end;
      Result := Blk;
    end;
  finally
    Names.Free;
  end;
end;


end.
