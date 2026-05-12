unit ULexer;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  ULexer.pas  -  Lexical Analyser for the MiniDelphi Toy Compiler
//  Breaks raw source text into a stream of tokens.
//  Compatible with Embarcadero Delphi 13 / Win64 / VCL
// =============================================================================

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type

  // -------------------------------------------------------------------
  //  Every possible kind of token the lexer can produce
  // -------------------------------------------------------------------
  TTokenKind = (
    // Literals
    tkInteger,        // 42
    tkFloat,          // 3.14
    tkString,         // 'hello'
    tkTrue,           // true
    tkFalse,          // false

    // Identifiers & keywords
    tkIdentifier,     // myVar
    tkVar,            // var
    tkBegin,          // begin
    tkEnd,            // end
    tkIf,             // if
    tkThen,           // then
    tkElse,           // else
    tkWhile,          // while
    tkDo,             // do
    tkFor,            // for
    tkTo,             // to
    tkDownTo,         // downto
    tkProcedure,      // procedure
    tkFunction,       // function
    tkResult,         // Result
    tkWriteln,        // writeln
    tkWrite,          // write
    tkReadln,         // readln
    tkProgram,        // program
    tkUses,           // uses
    tkType,           // type
    tkConst,          // const
    tkArray,          // array
    tkOf,             // of
    tkRecord,         // record
    tkNil,            // nil
    tkNot,            // not
    tkAnd,            // and
    tkOr,             // or
    tkDiv,            // div
    tkMod,            // mod
    tkRepeat,         // repeat
    tkUntil,          // until
    tkBreak,          // break
    tkContinue,       // continue
    tkCase,           // case
    tkCaseOf,         // caseof (string switch)
    tkExit,           // exit
    tkInteger_kw,     // Integer  (the type name)
    tkString_kw,      // String   (the type name)
    tkBoolean_kw,     // Boolean  (the type name)
    tkReal_kw,        // Real     (the type name)

    // OOP keywords
    tkClass,          // class
    tkObject_kw,      // object
    tkInherited,      // inherited
    tkInterface_kw,   // interface
    tkImplements,     // implements
    tkVirtual,        // virtual
    tkOverride_kw,    // override
    tkAbstract,       // abstract
    tkPublic,         // public
    tkPrivate,        // private
    tkProtected,      // protected
    tkPublished,      // published
    tkProperty_kw,    // property
    tkSelf,           // self
    tkConstructor_kw, // constructor
    tkDestructor_kw,  // destructor
    tkOverloaded,     // overload
    tkAs,             // as
    tkIs_kw,           // is

    // Operators
    tkPlus,           // +
    tkMinus,          // -
    tkStar,           // *
    tkSlash,          // /
    tkAssign,         // :=
    tkEqual,          // =
    tkNotEqual,       // <>
    tkLess,           // <
    tkLessEq,         // <=
    tkGreater,        // >
    tkGreaterEq,      // >=

    // Punctuation
    tkSemicolon,      // ;
    tkColon,          // :
    tkDot,            // .
    tkComma,          // ,
    tkLParen,         // (
    tkRParen,         // )
    tkLBracket,       // [
    tkRBracket,       // ]

    // Special
    tkEOF,            // end of source
    tkUnknown         // anything we did not recognise
  );

  // -------------------------------------------------------------------
  //  One token: its kind, the raw text, and where it came from
  // -------------------------------------------------------------------
  TToken = record
    Kind    : TTokenKind;
    Value   : string;       // the raw text
    Line    : Integer;      // 1-based line number
    Col     : Integer;      // 1-based column number
  end;

  // -------------------------------------------------------------------
  //  The Lexer class
  // -------------------------------------------------------------------
  TLexer = class
  private
    FSource  : string;          // full source text
    FPos     : Integer;         // current character index (1-based)
    FLine    : Integer;         // current line
    FCol     : Integer;         // current column
    FTokens  : TList<TToken>;   // output list

    function  CurrentChar : Char;
    function  PeekChar(Offset: Integer = 1) : Char;
    procedure Advance;
    procedure SkipWhitespaceAndComments;
    function  ReadString    : TToken;
    function  ReadNumber    : TToken;
    function  ReadIdentOrKeyword : TToken;
    function  MakeToken(Kind: TTokenKind; const Val: string) : TToken;
    class function KeywordKind(const S: string; out Kind: TTokenKind) : Boolean;
  public
    constructor Create(const ASource: string);
    destructor  Destroy; override;

    // Tokenise the whole source and return the token list
    procedure Tokenise;

    property Tokens : TList<TToken> read FTokens;

    // Helper: human-readable name for a token kind (useful for the UI)
    class function TokenKindName(K: TTokenKind) : string;
  end;

// =============================================================================
implementation
// =============================================================================

// ---------------------------------------------------------------------------
//  Keyword table
// ---------------------------------------------------------------------------
class function TLexer.KeywordKind(const S: string; out Kind: TTokenKind): Boolean;
var
  Low: string;
begin
  Low := System.SysUtils.LowerCase(S);
  Result := True;
  if      Low = 'var'       then Kind := tkVar
  else if Low = 'begin'     then Kind := tkBegin
  else if Low = 'end'       then Kind := tkEnd
  else if Low = 'if'        then Kind := tkIf
  else if Low = 'then'      then Kind := tkThen
  else if Low = 'else'      then Kind := tkElse
  else if Low = 'while'     then Kind := tkWhile
  else if Low = 'do'        then Kind := tkDo
  else if Low = 'for'       then Kind := tkFor
  else if Low = 'to'        then Kind := tkTo
  else if Low = 'downto'    then Kind := tkDownTo
  else if Low = 'procedure' then Kind := tkProcedure
  else if Low = 'function'  then Kind := tkFunction
  else if Low = 'result'    then Kind := tkResult
  else if Low = 'writeln'   then Kind := tkWriteln
  else if Low = 'write'     then Kind := tkWrite
  else if Low = 'readln'    then Kind := tkReadln
  else if Low = 'program'   then Kind := tkProgram
  else if Low = 'uses'      then Kind := tkUses
  else if Low = 'type'      then Kind := tkType
  else if Low = 'const'     then Kind := tkConst
  else if Low = 'array'     then Kind := tkArray
  else if Low = 'of'        then Kind := tkOf
  else if Low = 'record'    then Kind := tkRecord
  else if Low = 'nil'       then Kind := tkNil
  else if Low = 'not'       then Kind := tkNot
  else if Low = 'and'       then Kind := tkAnd
  else if Low = 'or'        then Kind := tkOr
  else if Low = 'div'       then Kind := tkDiv
  else if Low = 'mod'       then Kind := tkMod
  else if Low = 'true'      then Kind := tkTrue
  else if Low = 'false'     then Kind := tkFalse
  else if Low = 'repeat'    then Kind := tkRepeat
  else if Low = 'until'     then Kind := tkUntil
  else if Low = 'break'     then Kind := tkBreak
  else if Low = 'continue'  then Kind := tkContinue
  else if Low = 'case'      then Kind := tkCase
  else if Low = 'caseof'    then Kind := tkCaseOf
  else if Low = 'class'       then Kind := tkClass
  else if Low = 'object'      then Kind := tkObject_kw
  else if Low = 'inherited'   then Kind := tkInherited
  else if Low = 'interface'   then Kind := tkInterface_kw
  else if Low = 'implements'  then Kind := tkImplements
  else if Low = 'virtual'     then Kind := tkVirtual
  else if Low = 'override'    then Kind := tkOverride_kw
  else if Low = 'abstract'    then Kind := tkAbstract
  else if Low = 'public'      then Kind := tkPublic
  else if Low = 'private'     then Kind := tkPrivate
  else if Low = 'protected'   then Kind := tkProtected
  else if Low = 'published'   then Kind := tkPublished
  else if Low = 'property'    then Kind := tkProperty_kw
  else if Low = 'self'        then Kind := tkSelf
  else if Low = 'constructor' then Kind := tkConstructor_kw
  else if Low = 'destructor'  then Kind := tkDestructor_kw
  else if Low = 'overload'    then Kind := tkOverloaded
  else if Low = 'as'          then Kind := tkAs
  else if Low = 'is'          then Kind := tkIs_kw
  else if Low = 'exit'        then Kind := tkExit
  else if Low = 'integer'   then Kind := tkInteger_kw
  else if Low = 'string'    then Kind := tkString_kw
  else if Low = 'boolean'   then Kind := tkBoolean_kw
  else if Low = 'real'      then Kind := tkReal_kw
  else Result := False;
end;

// ---------------------------------------------------------------------------
//  Constructor / Destructor
// ---------------------------------------------------------------------------
constructor TLexer.Create(const ASource: string);
begin
  inherited Create;
  FSource  := ASource;
  FPos     := 1;
  FLine    := 1;
  FCol     := 1;
  FTokens  := TList<TToken>.Create;
end;

destructor TLexer.Destroy;
begin
  FTokens.Free;
  inherited;
end;

// ---------------------------------------------------------------------------
//  Low-level character access
// ---------------------------------------------------------------------------
function TLexer.CurrentChar: Char;
begin
  if FPos <= Length(FSource) then
    Result := FSource[FPos]
  else
    Result := #0;
end;

function TLexer.PeekChar(Offset: Integer): Char;
var
  P: Integer;
begin
  P := FPos + Offset;
  if P <= Length(FSource) then
    Result := FSource[P]
  else
    Result := #0;
end;

procedure TLexer.Advance;
begin
  if FPos <= Length(FSource) then
  begin
    if FSource[FPos] = #10 then
    begin
      Inc(FLine);
      FCol := 1;
    end
    else
      Inc(FCol);
    Inc(FPos);
  end;
end;

// ---------------------------------------------------------------------------
//  Skip whitespace and both comment styles  { }  and  //
// ---------------------------------------------------------------------------
procedure TLexer.SkipWhitespaceAndComments;
var
  InComment : Boolean;
begin
  repeat
    InComment := False;

    // Skip plain whitespace
    while (CurrentChar <= ' ') and (CurrentChar <> #0) do
      Advance;

    // Brace comment  { ... }
    if CurrentChar = '{' then
    begin
      InComment := True;
      Advance;
      while (CurrentChar <> '}') and (CurrentChar <> #0) do
        Advance;
      if CurrentChar = '}' then Advance;
    end;

    // Line comment  // ...
    if (CurrentChar = '/') and (PeekChar = '/') then
    begin
      InComment := True;
      while (CurrentChar <> #10) and (CurrentChar <> #0) do
        Advance;
    end;

    // (* ... *) style comment
    if (CurrentChar = '(') and (PeekChar = '*') then
    begin
      InComment := True;
      Advance; Advance;
      while not ((CurrentChar = '*') and (PeekChar = ')')) and (CurrentChar <> #0) do
        Advance;
      if CurrentChar <> #0 then begin Advance; Advance; end;
    end;

  until not InComment;
end;

// ---------------------------------------------------------------------------
//  Make a token stamped with current line/col
// ---------------------------------------------------------------------------
function TLexer.MakeToken(Kind: TTokenKind; const Val: string): TToken;
begin
  Result.Kind  := Kind;
  Result.Value := Val;
  Result.Line  := FLine;
  Result.Col   := FCol;
end;

// ---------------------------------------------------------------------------
//  Read a quoted string  'hello world'
// ---------------------------------------------------------------------------
function TLexer.ReadString: TToken;
var
  S    : string;
  StartLine, StartCol : Integer;
begin
  StartLine := FLine;
  StartCol  := FCol;
  Advance;  // skip opening quote
  S := '';
  while (CurrentChar <> #0) do
  begin
    if CurrentChar = '''' then
    begin
      if PeekChar = '''' then
      begin
        // two single quotes = escaped quote inside string
        S := S + '''';
        Advance; Advance;
      end
      else
      begin
        Advance; // skip closing quote
        Break;
      end;
    end
    else
    begin
      S := S + CurrentChar;
      Advance;
    end;
  end;
  Result.Kind  := tkString;
  Result.Value := S;
  Result.Line  := StartLine;
  Result.Col   := StartCol;
end;

// ---------------------------------------------------------------------------
//  Read an integer or float literal
// ---------------------------------------------------------------------------
function TLexer.ReadNumber: TToken;
var
  S    : string;
  Kind : TTokenKind;
begin
  S    := '';
  Kind := tkInteger;
  while CharInSet(CurrentChar, ['0'..'9']) do
  begin
    S := S + CurrentChar;
    Advance;
  end;
  if (CurrentChar = '.') and CharInSet(PeekChar, ['0'..'9']) then
  begin
    Kind := tkFloat;
    S := S + '.';
    Advance;
    while CharInSet(CurrentChar, ['0'..'9']) do
    begin
      S := S + CurrentChar;
      Advance;
    end;
  end;
  Result := MakeToken(Kind, S);
end;

// ---------------------------------------------------------------------------
//  Read an identifier, then check if it is a keyword
// ---------------------------------------------------------------------------
function TLexer.ReadIdentOrKeyword: TToken;
var
  S    : string;
  Kind : TTokenKind;
begin
  S := '';
  while CharInSet(CurrentChar, ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
  begin
    S := S + CurrentChar;
    Advance;
  end;
  if KeywordKind(S, Kind) then
    Result := MakeToken(Kind, S)
  else
    Result := MakeToken(tkIdentifier, S);
end;

// ---------------------------------------------------------------------------
//  Main tokenise loop
// ---------------------------------------------------------------------------
procedure TLexer.Tokenise;
var
  Tok : TToken;
  C   : Char;
begin
  FTokens.Clear;
  FPos  := 1;
  FLine := 1;
  FCol  := 1;

  repeat
    SkipWhitespaceAndComments;
    C := CurrentChar;

    if C = #0 then
    begin
      FTokens.Add(MakeToken(tkEOF, '<EOF>'));
      Break;
    end;

    // String literal
    if C = '''' then
    begin
      FTokens.Add(ReadString);
      Continue;
    end;

    // Number
    if CharInSet(C, ['0'..'9']) then
    begin
      FTokens.Add(ReadNumber);
      Continue;
    end;

    // Identifier or keyword
    if CharInSet(C, ['A'..'Z', 'a'..'z', '_']) then
    begin
      FTokens.Add(ReadIdentOrKeyword);
      Continue;
    end;

    // Operators and punctuation
    case C of
      '+': begin Tok := MakeToken(tkPlus,      '+'); Advance; FTokens.Add(Tok); end;
      '-': begin Tok := MakeToken(tkMinus,     '-'); Advance; FTokens.Add(Tok); end;
      '*': begin Tok := MakeToken(tkStar,      '*'); Advance; FTokens.Add(Tok); end;
      '/': begin Tok := MakeToken(tkSlash,     '/'); Advance; FTokens.Add(Tok); end;
      ';': begin Tok := MakeToken(tkSemicolon, ';'); Advance; FTokens.Add(Tok); end;
      '.': begin Tok := MakeToken(tkDot,       '.'); Advance; FTokens.Add(Tok); end;
      ',': begin Tok := MakeToken(tkComma,     ','); Advance; FTokens.Add(Tok); end;
      '(': begin Tok := MakeToken(tkLParen,    '('); Advance; FTokens.Add(Tok); end;
      ')': begin Tok := MakeToken(tkRParen,    ')'); Advance; FTokens.Add(Tok); end;
      '[': begin Tok := MakeToken(tkLBracket,  '['); Advance; FTokens.Add(Tok); end;
      ']': begin Tok := MakeToken(tkRBracket,  ']'); Advance; FTokens.Add(Tok); end;
      '=': begin Tok := MakeToken(tkEqual,     '='); Advance; FTokens.Add(Tok); end;

      ':': begin
             Advance;
             if CurrentChar = '=' then
             begin
               Tok := MakeToken(tkAssign, ':='); Advance;
             end
             else
               Tok := MakeToken(tkColon, ':');
             FTokens.Add(Tok);
           end;

      '<': begin
             Advance;
             if CurrentChar = '=' then
             begin
               Tok := MakeToken(tkLessEq, '<='); Advance;
             end
             else if CurrentChar = '>' then
             begin
               Tok := MakeToken(tkNotEqual, '<>'); Advance;
             end
             else
               Tok := MakeToken(tkLess, '<');
             FTokens.Add(Tok);
           end;

      '>': begin
             Advance;
             if CurrentChar = '=' then
             begin
               Tok := MakeToken(tkGreaterEq, '>='); Advance;
             end
             else
               Tok := MakeToken(tkGreater, '>');
             FTokens.Add(Tok);
           end;

    else
      // Unknown character — record it and move on
      Tok := MakeToken(tkUnknown, C);
      Advance;
      FTokens.Add(Tok);
    end;

  until False;
end;

// ---------------------------------------------------------------------------
//  Human-readable token kind name (for the UI display)
// ---------------------------------------------------------------------------
class function TLexer.TokenKindName(K: TTokenKind): string;
begin
  case K of
    tkInteger     : Result := 'INTEGER';
    tkFloat       : Result := 'FLOAT';
    tkString      : Result := 'STRING';
    tkTrue        : Result := 'TRUE';
    tkFalse       : Result := 'FALSE';
    tkIdentifier  : Result := 'IDENT';
    tkVar         : Result := 'VAR';
    tkBegin       : Result := 'BEGIN';
    tkEnd         : Result := 'END';
    tkIf          : Result := 'IF';
    tkThen        : Result := 'THEN';
    tkElse        : Result := 'ELSE';
    tkWhile       : Result := 'WHILE';
    tkDo          : Result := 'DO';
    tkFor         : Result := 'FOR';
    tkTo          : Result := 'TO';
    tkDownTo      : Result := 'DOWNTO';
    tkProcedure   : Result := 'PROCEDURE';
    tkFunction    : Result := 'FUNCTION';
    tkResult      : Result := 'RESULT';
    tkWriteln     : Result := 'WRITELN';
    tkWrite       : Result := 'WRITE';
    tkReadln      : Result := 'READLN';
    tkProgram     : Result := 'PROGRAM';
    tkUses        : Result := 'USES';
    tkType        : Result := 'TYPE';
    tkConst       : Result := 'CONST';
    tkArray       : Result := 'ARRAY';
    tkOf          : Result := 'OF';
    tkRecord      : Result := 'RECORD';
    tkNil         : Result := 'NIL';
    tkNot         : Result := 'NOT';
    tkAnd         : Result := 'AND';
    tkOr          : Result := 'OR';
    tkDiv         : Result := 'DIV';
    tkMod         : Result := 'MOD';
    tkRepeat      : Result := 'REPEAT';
    tkUntil       : Result := 'UNTIL';
    tkBreak       : Result := 'BREAK';
    tkContinue    : Result := 'CONTINUE';
    tkExit        : Result := 'EXIT';
    tkInteger_kw  : Result := 'TYPE:INTEGER';
    tkString_kw   : Result := 'TYPE:STRING';
    tkBoolean_kw  : Result := 'TYPE:BOOLEAN';
    tkReal_kw     : Result := 'TYPE:REAL';
    tkPlus        : Result := 'PLUS';
    tkMinus       : Result := 'MINUS';
    tkStar        : Result := 'STAR';
    tkSlash       : Result := 'SLASH';
    tkAssign      : Result := 'ASSIGN';
    tkEqual       : Result := 'EQUAL';
    tkNotEqual    : Result := 'NOTEQUAL';
    tkLess        : Result := 'LESS';
    tkLessEq      : Result := 'LESSEQ';
    tkGreater     : Result := 'GREATER';
    tkGreaterEq   : Result := 'GREATEREQ';
    tkSemicolon   : Result := 'SEMICOLON';
    tkColon       : Result := 'COLON';
    tkDot         : Result := 'DOT';
    tkComma       : Result := 'COMMA';
    tkLParen      : Result := 'LPAREN';
    tkRParen      : Result := 'RPAREN';
    tkLBracket    : Result := 'LBRACKET';
    tkRBracket    : Result := 'RBRACKET';
    tkEOF         : Result := 'EOF';
  else              Result := 'UNKNOWN';
  end;
end;

end.
