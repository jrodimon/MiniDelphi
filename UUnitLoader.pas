unit UUnitLoader;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  UUnitLoader.pas  —  Unit import system for MiniDelphi
//
//  Allows a .mdp program to import routines from other .mdp files:
//
//      uses
//        'MathHelpers.mdp',
//        'StringUtils.mdp';
//
//      begin
//        writeln(Square(5));      // defined in MathHelpers.mdp
//        writeln(Reverse('hi')); // defined in StringUtils.mdp
//      end.
//
//  A library .mdp has no main begin..end block — just var and
//  procedure/function declarations.  If it does have a main block
//  it is silently ignored (only routines are imported).
//
//  Architecture
//  ────────────
//  TUnitLoader.LoadUnits(MainSource, BaseDir)
//    1. Scans the uses clause of MainSource for quoted filenames
//    2. Loads each file from disk (relative to BaseDir)
//    3. Lexes and parses each one
//    4. Collects all TRoutineDecl nodes into a flat list
//    5. Returns that list — the interpreter merges it with the
//       main program's own routines before executing
//
//  Circular imports are detected and skipped.
//  Missing files generate a clear error message.
// =============================================================================

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.IOUtils,
  ULexer, UParser, UAST;

type
  // One loaded unit — its parsed program node and the path it came from
  TLoadedUnit = class
    Path    : string;
    Source  : string;
    PNode   : TProgramNode;   // OWNED here — freed with this object
    constructor Create(const APath, ASource: string; ANode: TProgramNode);
    destructor  Destroy; override;
  end;

  // The loader
  TUnitLoader = class
  private
    FBaseDir  : string;
    FLoaded   : TObjectList<TLoadedUnit>;   // prevents circular loads
    FErrors   : TStringList;

    function  AlreadyLoaded(const Path: string): Boolean;
    function  ResolvePath(const FileName: string): string;
    procedure LoadOne(const FileName: string);
    function  ExtractUsesClause(const Source: string): TStringList;

  public
    constructor Create(const BaseDir: string);
    destructor  Destroy; override;

    // Load all units referenced in MainSource.
    // Call BEFORE parsing/running the main program.
    procedure LoadUnits(const MainSource: string);

    // Merge all imported routines into the target program node.
    // Call AFTER parsing the main program, BEFORE running it.
    procedure MergeInto(Target: TProgramNode);

    // Any errors encountered during loading
    property  Errors : TStringList read FErrors;

    // True if any units were successfully loaded
    function  HasUnits : Boolean;
  end;

// =============================================================================
implementation
// =============================================================================

{ TLoadedUnit }

constructor TLoadedUnit.Create(const APath, ASource: string;
  ANode: TProgramNode);
begin
  inherited Create;
  Path   := APath;
  Source := ASource;
  PNode  := ANode;
end;

destructor TLoadedUnit.Destroy;
begin
  PNode.Free;
  inherited;
end;

{ TUnitLoader }

constructor TUnitLoader.Create(const BaseDir: string);
begin
  inherited Create;
  FBaseDir := BaseDir;
  FLoaded  := TObjectList<TLoadedUnit>.Create(True);
  FErrors  := TStringList.Create;
end;

destructor TUnitLoader.Destroy;
begin
  FLoaded.Free;
  FErrors.Free;
  inherited;
end;

function TUnitLoader.AlreadyLoaded(const Path: string): Boolean;
var U: TLoadedUnit;
begin
  for U in FLoaded do
    if SameText(U.Path, Path) then
      Exit(True);
  Result := False;
end;

function TUnitLoader.ResolvePath(const FileName: string): string;
begin
  // If the user wrote an absolute path use it directly,
  // otherwise resolve relative to the main program's folder
  if TPath.IsPathRooted(FileName) then
    Result := FileName
  else
    Result := TPath.Combine(FBaseDir, FileName);
  Result := TPath.GetFullPath(Result);
end;

// ---------------------------------------------------------------------------
//  Scan the uses clause of a source file and return the filenames listed.
//  We look for the pattern:
//      uses
//        'file1.mdp',
//        'file2.mdp';
//  The filenames must be single-quoted strings.
// ---------------------------------------------------------------------------
function TUnitLoader.ExtractUsesClause(const Source: string): TStringList;
var
  Lex   : TLexer;
  Toks  : TList<TToken>;
  I     : Integer;
  Tok   : TToken;
  InUses: Boolean;
begin
  Result := TStringList.Create;
  Lex    := TLexer.Create(Source);
  try
    Lex.Tokenise;
    Toks   := Lex.Tokens;
    InUses := False;
    I      := 0;

    while I < Toks.Count do
    begin
      Tok := Toks[I];

      if Tok.Kind = tkEOF then Break;

      if (not InUses) and (Tok.Kind = tkUses) then
      begin
        InUses := True;
        Inc(I);
        Continue;
      end;

      if InUses then
      begin
        // A string token is a filename
        if Tok.Kind = tkString then
          Result.Add(Tok.Value)
        // Comma — keep going
        else if Tok.Kind = tkComma then
          { skip }
        // Semicolon — end of uses clause
        else if Tok.Kind = tkSemicolon then
          Break
        // Anything else that isn't comma/string ends the clause
        else if Tok.Kind <> tkComma then
          Break;
      end;

      Inc(I);
    end;
  finally
    Lex.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Load one unit file, parse it, store its routines
// ---------------------------------------------------------------------------
procedure TUnitLoader.LoadOne(const FileName: string);
var
  FullPath : string;
  Source   : string;
  Lex      : TLexer;
  Par      : TParser;
  PNode    : TProgramNode;
  LU       : TLoadedUnit;
  // Nested uses in the imported file
  NestedUses : TStringList;
  NF         : string;
begin
  FullPath := ResolvePath(FileName);

  // Skip if already loaded (prevents circular imports)
  if AlreadyLoaded(FullPath) then Exit;

  // Check the file exists
  if not TFile.Exists(FullPath) then
  begin
    FErrors.Add('Unit not found: ' + FullPath);
    Exit;
  end;

  // Read source
  try
    Source := TFile.ReadAllText(FullPath, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      FErrors.Add('Cannot read unit ' + FileName + ': ' + E.Message);
      Exit;
    end;
  end;

  // Handle nested uses in the imported file
  NestedUses := ExtractUsesClause(Source);
  try
    for NF in NestedUses do
      LoadOne(NF);   // recursive — circular guard above catches loops
  finally
    NestedUses.Free;
  end;

  // Lex and parse
  try
    Lex := TLexer.Create(Source);
    try
      Lex.Tokenise;
      Par := TParser.Create(Lex.Tokens);
      try
        PNode := Par.Parse;
      finally
        Par.Free;
      end;
    finally
      Lex.Free;
    end;
  except
    on E: Exception do
    begin
      FErrors.Add('Parse error in unit ' + FileName + ': ' + E.Message);
      Exit;
    end;
  end;

  // Store
  LU := TLoadedUnit.Create(FullPath, Source, PNode);
  FLoaded.Add(LU);
end;

// ---------------------------------------------------------------------------
//  Public: load all units named in the main source's uses clause
// ---------------------------------------------------------------------------
procedure TUnitLoader.LoadUnits(const MainSource: string);
var
  UsesList : TStringList;
  FileName : string;
begin
  UsesList := ExtractUsesClause(MainSource);
  try
    for FileName in UsesList do
      LoadOne(FileName);
  finally
    UsesList.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Public: merge all loaded routines into the main program node
// ---------------------------------------------------------------------------
procedure TUnitLoader.MergeInto(Target: TProgramNode);
var
  LU : TLoadedUnit;
  R  : TRoutineDecl;
  I  : Integer;
begin
  // Walk loaded units in load order (dependencies first due to recursion)
  for LU in FLoaded do
  begin
    // Copy routine declarations into the target program.
    // We INSERT at the front so library routines are registered before
    // the main program's own routines (which may call them).
    // *** NOTE: We do NOT free the routines here — they stay owned by LU.PNode.
    //     The interpreter only holds a non-owning reference (TDictionary value).
    for I := LU.PNode.Routines.Count - 1 downto 0 do
    begin
      R := LU.PNode.Routines[I];
      // Add a reference copy — interpreter will look them up by name
      // We must clone the declaration or transfer ownership carefully.
      // Simplest safe approach: move ownership to Target.
      LU.PNode.Routines.Extract(R);   // remove WITHOUT freeing
      Target.Routines.Insert(0, R);   // insert at front of target
    end;

    // Also merge global var declarations from the library
    // (useful for library-level constants initialised in var blocks)
    for I := LU.PNode.Globals.Count - 1 downto 0 do
    begin
      var D := LU.PNode.Globals[I];
      LU.PNode.Globals.Extract(D);
      Target.Globals.Insert(0, D);
    end;
  end;
end;

function TUnitLoader.HasUnits: Boolean;
begin
  Result := FLoaded.Count > 0;
end;

end.
