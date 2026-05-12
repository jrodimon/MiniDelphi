unit UObjectRuntime;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  UObjectRuntime.pas  —  Object-oriented runtime for MiniDelphi
//
//  Implements:
//    • TObjectInstance   — a live object in memory (fields + class ref)
//    • TClassRegistry    — maps class names to TClassDecl + method resolution
//    • Method dispatch   — virtual/override, inheritance chain lookup
//    • Interface checking— is obj is IGreeter
//
//  How it works
//  ────────────
//  When MiniDelphi runs  dog := TDog.Create:
//    1. TClassRegistry finds TClassDecl for 'TDog'
//    2. Creates a TObjectInstance with ClassName='TDog'
//    3. Pre-populates all inherited fields with default values
//    4. Runs the constructor body (if any)
//    5. Returns a TValue of kind vkObject pointing to the instance
//
//  When MiniDelphi runs  dog.Speak:
//    1. Evaluates dog → TValue(vkObject, TObjectInstance)
//    2. Asks TClassRegistry to find method 'Speak' for class 'TDog'
//    3. Registry walks inheritance chain: TDog → TAnimal → TObject
//    4. Returns the most-derived TMethodDecl found
//    5. Interpreter executes its body with Self bound to the instance
// =============================================================================

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  UAST;

type
  // -------------------------------------------------------------------
  //  A live object instance — one per  TFoo.Create  call
  // -------------------------------------------------------------------
  TObjectInstance = class
  public
    ObjClass  : string;                        // 'TDog', 'TCat', etc.
    Fields    : TDictionary<string, Pointer>;  // field name → TValue pointer

    constructor Create(const AClassName: string);
    destructor  Destroy; override;
  end;

  // -------------------------------------------------------------------
  //  Method resolution result
  // -------------------------------------------------------------------
  TMethodLookup = record
    Found      : Boolean;
    Method     : TMethodDecl;
    OwnerClass : string;   // which class declared this method
  end;

  // -------------------------------------------------------------------
  //  The class registry — built from the parsed AST before running
  // -------------------------------------------------------------------
  TClassRegistry = class
  private
    // All registered classes and interfaces
    FClasses    : TDictionary<string, TClassDecl>;
    FInterfaces : TDictionary<string, TInterfaceDecl>;

  public
    constructor Create;
    destructor  Destroy; override;

    // Register a class or interface from the parsed AST
    procedure RegisterClass    (Decl: TClassDecl);
    procedure RegisterInterface(Decl: TInterfaceDecl);

    // Register all classes/interfaces from a parsed program
    procedure RegisterProgram  (Prog: TProgramNode);

    // Lookup
    function  FindClass    (const Name: string) : TClassDecl;
    function  FindInterface(const Name: string) : TInterfaceDecl;

    // Method resolution — walks inheritance chain
    function  ResolveMethod(const ClassName, MethodName: string) : TMethodLookup;

    // Field resolution — returns default type name or '' if not found
    function  ResolveField (const ClassName, FieldName: string;
                            out TypeName: string) : Boolean;

    // Interface conformance — does class implement interface?
    function  Implements(const ClassName, InterfaceName: string) : Boolean;

    // Inheritance — is A descended from B?
    function  IsDescendant(const AClass, BClass: string) : Boolean;

    // Get all fields for a class (including inherited), in order
    procedure CollectFields(const ClassName: string;
                            Fields: TObjectList<TFieldDecl>);

    // Get all methods visible on a class (including inherited)
    procedure CollectMethods(const ClassName: string;
                             Methods: TObjectList<TMethodDecl>);

    function  ClassExists    (const Name: string) : Boolean;
    function  InterfaceExists(const Name: string) : Boolean;
  end;

// Global registry — initialised before each program run
var
  ClassRegistry : TClassRegistry;

procedure InitClassRegistry;
procedure FreeClassRegistry;

// =============================================================================
implementation
// =============================================================================

{ TObjectInstance }

constructor TObjectInstance.Create(const AClassName: string);
begin
  inherited Create;
  ObjClass := AClassName;
  Fields    := TDictionary<string, Pointer>.Create;
end;

destructor TObjectInstance.Destroy;
begin
  // NOTE: Field values (TValue records) are owned by the interpreter's
  // environment — we only hold Pointers here, don't free them
  Fields.Free;
  inherited;
end;

{ TClassRegistry }

constructor TClassRegistry.Create;
begin
  inherited;
  FClasses    := TDictionary<string, TClassDecl>.Create;
  FInterfaces := TDictionary<string, TInterfaceDecl>.Create;
end;

destructor TClassRegistry.Destroy;
begin
  // Note: we do NOT own the TClassDecl/TInterfaceDecl nodes —
  // they belong to the TProgramNode AST.
  FClasses.Free;
  FInterfaces.Free;
  inherited;
end;

procedure TClassRegistry.RegisterClass(Decl: TClassDecl);
begin
  FClasses.AddOrSetValue(LowerCase(Decl.Name), Decl);
end;

procedure TClassRegistry.RegisterInterface(Decl: TInterfaceDecl);
begin
  FInterfaces.AddOrSetValue(LowerCase(Decl.Name), Decl);
end;

procedure TClassRegistry.RegisterProgram(Prog: TProgramNode);
var
  CD : TClassDecl;
  ID : TInterfaceDecl;
  TB : TTypeBlock;
begin
  // Register from type blocks
  for TB in Prog.TypeBlocks do
  begin
    for CD in TB.Classes    do RegisterClass(CD);
    for ID in TB.Interfaces do RegisterInterface(ID);
  end;
  // Also register from flat lists (filled by MergeInto)
  for CD in Prog.Classes    do RegisterClass(CD);
  for ID in Prog.Interfaces do RegisterInterface(ID);
end;

function TClassRegistry.FindClass(const Name: string): TClassDecl;
begin
  if not FClasses.TryGetValue(LowerCase(Name), Result) then
    Result := nil;
end;

function TClassRegistry.FindInterface(const Name: string): TInterfaceDecl;
begin
  if not FInterfaces.TryGetValue(LowerCase(Name), Result) then
    Result := nil;
end;

function TClassRegistry.ClassExists(const Name: string): Boolean;
begin
  Result := FClasses.ContainsKey(LowerCase(Name));
end;

function TClassRegistry.InterfaceExists(const Name: string): Boolean;
begin
  Result := FInterfaces.ContainsKey(LowerCase(Name));
end;

// ---------------------------------------------------------------------------
//  Walk the inheritance chain to find a method.
//  We start at ClassName and work up to parents until found or no parent.
// ---------------------------------------------------------------------------
function TClassRegistry.ResolveMethod(const ClassName,
  MethodName: string): TMethodLookup;
var
  Current : string;
  Decl    : TClassDecl;
  M       : TMethodDecl;
  MName   : string;
begin
  Result.Found      := False;
  Result.Method     := nil;
  Result.OwnerClass := '';

  Current := LowerCase(ClassName);
  MName   := LowerCase(MethodName);

  while Current <> '' do
  begin
    Decl := FindClass(Current);
    if not Assigned(Decl) then Break;

    // Search this class's methods
    for M in Decl.Methods do
      if LowerCase(M.Name) = MName then
      begin
        Result.Found      := True;
        Result.Method     := M;
        Result.OwnerClass := Decl.Name;
        Exit;
      end;

    // Move up to parent
    Current := LowerCase(Decl.ParentName);
  end;
end;

// ---------------------------------------------------------------------------
//  Find a field's type by walking the inheritance chain
// ---------------------------------------------------------------------------
function TClassRegistry.ResolveField(const ClassName, FieldName: string;
  out TypeName: string): Boolean;
var
  Current : string;
  Decl    : TClassDecl;
  F       : TFieldDecl;
  FName   : string;
begin
  Result   := False;
  TypeName := '';
  Current  := LowerCase(ClassName);
  FName    := LowerCase(FieldName);

  while Current <> '' do
  begin
    Decl := FindClass(Current);
    if not Assigned(Decl) then Break;

    for F in Decl.Fields do
      if LowerCase(F.Name) = FName then
      begin
        TypeName := F.TypeName;
        Result   := True;
        Exit;
      end;

    Current := LowerCase(Decl.ParentName);
  end;
end;

// ---------------------------------------------------------------------------
//  Check interface conformance
// ---------------------------------------------------------------------------
function TClassRegistry.Implements(const ClassName,
  InterfaceName: string): Boolean;
var
  Current : string;
  Decl    : TClassDecl;
  IName   : string;
begin
  Result  := False;
  Current := LowerCase(ClassName);
  IName   := LowerCase(InterfaceName);

  while Current <> '' do
  begin
    Decl := FindClass(Current);
    if not Assigned(Decl) then Break;
    if Decl.Interfaces.IndexOf(IName) >= 0 then
    begin
      Result := True;
      Exit;
    end;
    Current := LowerCase(Decl.ParentName);
  end;
end;

// ---------------------------------------------------------------------------
//  IsDescendant: is AClass the same as or a subclass of BClass?
// ---------------------------------------------------------------------------
function TClassRegistry.IsDescendant(const AClass, BClass: string): Boolean;
var
  Current : string;
  Decl    : TClassDecl;
begin
  Result  := False;
  Current := LowerCase(AClass);

  while Current <> '' do
  begin
    if Current = LowerCase(BClass) then begin Result := True; Exit; end;
    Decl := FindClass(Current);
    if not Assigned(Decl) then Break;
    Current := LowerCase(Decl.ParentName);
  end;
end;

// ---------------------------------------------------------------------------
//  Collect all fields for a class including inherited ones
// ---------------------------------------------------------------------------
procedure TClassRegistry.CollectFields(const ClassName: string;
  Fields: TObjectList<TFieldDecl>);
var
  Chain   : TStringList;
  Current : string;
  Decl    : TClassDecl;
  F       : TFieldDecl;
  I       : Integer;
begin
  // Build inheritance chain from root to leaf
  Chain   := TStringList.Create;
  Current := LowerCase(ClassName);
  try
    while Current <> '' do
    begin
      Chain.Insert(0, Current);   // insert at front = root first
      Decl := FindClass(Current);
      if not Assigned(Decl) then Break;
      Current := LowerCase(Decl.ParentName);
    end;

    // Now walk root → leaf, collecting fields
    for I := 0 to Chain.Count - 1 do
    begin
      Decl := FindClass(Chain[I]);
      if Assigned(Decl) then
        for F in Decl.Fields do
          Fields.Add(F);   // non-owning reference
    end;
  finally
    Chain.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Collect all methods visible on a class (most derived wins)
// ---------------------------------------------------------------------------
procedure TClassRegistry.CollectMethods(const ClassName: string;
  Methods: TObjectList<TMethodDecl>);
var
  Chain   : TStringList;
  Seen    : TStringList;
  Current : string;
  Decl    : TClassDecl;
  M       : TMethodDecl;
  I       : Integer;
begin
  Chain := TStringList.Create;
  Seen  := TStringList.Create;
  Current := LowerCase(ClassName);
  try
    while Current <> '' do
    begin
      Chain.Insert(0, Current);
      Decl := FindClass(Current);
      if not Assigned(Decl) then Break;
      Current := LowerCase(Decl.ParentName);
    end;

    // Walk leaf → root, most-derived first; skip already-seen names
    for I := Chain.Count - 1 downto 0 do
    begin
      Decl := FindClass(Chain[I]);
      if Assigned(Decl) then
        for M in Decl.Methods do
        begin
          var MN := LowerCase(M.Name);
          if Seen.IndexOf(MN) < 0 then
          begin
            Methods.Add(M);
            Seen.Add(MN);
          end;
        end;
    end;
  finally
    Chain.Free;
    Seen.Free;
  end;
end;

{ Global helpers }

procedure InitClassRegistry;
begin
  if not Assigned(ClassRegistry) then
    ClassRegistry := TClassRegistry.Create;
end;

procedure FreeClassRegistry;
begin
  FreeAndNil(ClassRegistry);
end;

end.
