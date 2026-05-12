unit USQLite;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// Unauthorised copying, distribution or modification is prohibited.
// =============================================================================

// =============================================================================
//  USQLite.pas  —  SQLite3 database support for MiniDelphi
//
//  Uses dynamic loading of sqlite3.dll so no install is required.
//  Ship sqlite3.dll alongside MiniDelphi.exe and it just works.
//
//  Download sqlite3.dll from https://sqlite.org/download.html
//  (precompiled DLL for Windows — about 1MB)
//
//  MiniDelphi programs use these built-in functions:
//
//    DbOpen('mydata.db')           — open or create a database
//    DbExec('CREATE TABLE ...')    — run any SQL statement
//    DbQuery('SELECT ...')         — run SELECT, get formatted results
//    DbQueryValue('SELECT COUNT(*)') — get a single value
//    DbClose                       — close the database
//    DbLastError                   — last error message string
//    DbIsOpen                      — True if database is open
//
//  All DB state is global (one connection at a time) — appropriate
//  for a learning environment.
// =============================================================================

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes;

// ---------------------------------------------------------------------------
//  SQLite3 type aliases (matching sqlite3.h)
// ---------------------------------------------------------------------------
type
  TSQLiteDB   = Pointer;
  TSQLiteStmt = Pointer;

// ---------------------------------------------------------------------------
//  TMiniDB — the singleton database connection
// ---------------------------------------------------------------------------
type
  TMiniDB = class
  private
    FLib      : HMODULE;         // handle to sqlite3.dll
    FDB       : TSQLiteDB;       // current open database
    FLastError: string;          // last error message
    FFilename : string;          // currently open file

    // SQLite3 function pointers (loaded dynamically)
    sqlite3_open       : function(filename: PAnsiChar; var db: TSQLiteDB): Integer; cdecl;
    sqlite3_close      : function(db: TSQLiteDB): Integer; cdecl;
    sqlite3_exec       : function(db: TSQLiteDB; sql: PAnsiChar;
                                  callback: Pointer; arg: Pointer;
                                  var errmsg: PAnsiChar): Integer; cdecl;
    sqlite3_free       : procedure(ptr: Pointer); cdecl;
    sqlite3_errmsg     : function(db: TSQLiteDB): PAnsiChar; cdecl;
    sqlite3_prepare_v2 : function(db: TSQLiteDB; sql: PAnsiChar;
                                  nBytes: Integer; var stmt: TSQLiteStmt;
                                  var tail: PAnsiChar): Integer; cdecl;
    sqlite3_step       : function(stmt: TSQLiteStmt): Integer; cdecl;
    sqlite3_finalize   : function(stmt: TSQLiteStmt): Integer; cdecl;
    sqlite3_column_count: function(stmt: TSQLiteStmt): Integer; cdecl;
    sqlite3_column_name : function(stmt: TSQLiteStmt; col: Integer): PAnsiChar; cdecl;
    sqlite3_column_text : function(stmt: TSQLiteStmt; col: Integer): PAnsiChar; cdecl;
    sqlite3_column_type : function(stmt: TSQLiteStmt; col: Integer): Integer; cdecl;

    function  LoadLib: Boolean;
    procedure SetError(const Msg: string);

    const
      SQLITE_OK   = 0;
      SQLITE_ROW  = 100;
      SQLITE_DONE = 101;

  public
    constructor Create;
    destructor  Destroy; override;

    function  Open(const Filename: string): Boolean;
    procedure Close;
    function  Exec(const SQL: string): Boolean;
    function  Query(const SQL: string): string;
    function  QueryValue(const SQL: string): string;
    function  IsOpen: Boolean;

    property  LastError : string  read FLastError;
    property  Filename  : string  read FFilename;
    function  Available : Boolean;
  end;

// Global singleton — one database connection for MiniDelphi programs
var
  MiniDB : TMiniDB;

procedure InitMiniDB;
procedure FreeMiniDB;

// =============================================================================
implementation
// =============================================================================

procedure InitMiniDB;
begin
  if not Assigned(MiniDB) then
    MiniDB := TMiniDB.Create;
end;

procedure FreeMiniDB;
begin
  FreeAndNil(MiniDB);
end;

{ TMiniDB }

constructor TMiniDB.Create;
begin
  inherited;
  FLib       := 0;
  FDB        := nil;
  FLastError := '';
  FFilename  := '';
  LoadLib;
end;

destructor TMiniDB.Destroy;
begin
  Close;
  if FLib <> 0 then
    FreeLibrary(FLib);
  inherited;
end;

function TMiniDB.LoadLib: Boolean;

  function GetProc(const Name: string): Pointer;
  begin
    Result := GetProcAddress(FLib, PChar(Name));
  end;

begin
  Result := False;

  // Try the DLL in several locations
  FLib := LoadLibrary('sqlite3.dll');
  if FLib = 0 then
    FLib := LoadLibrary(PChar(ExtractFilePath(ParamStr(0)) + 'sqlite3.dll'));
  if FLib = 0 then
  begin
    FLastError := 'sqlite3.dll not found. Download from https://sqlite.org/download.html ' +
                  'and place it in the same folder as MiniDelphi.exe';
    Exit;
  end;

  // Load all the function pointers we need
  @sqlite3_open        := GetProc('sqlite3_open');
  @sqlite3_close       := GetProc('sqlite3_close');
  @sqlite3_exec        := GetProc('sqlite3_exec');
  @sqlite3_free        := GetProc('sqlite3_free');
  @sqlite3_errmsg      := GetProc('sqlite3_errmsg');
  @sqlite3_prepare_v2  := GetProc('sqlite3_prepare_v2');
  @sqlite3_step        := GetProc('sqlite3_step');
  @sqlite3_finalize    := GetProc('sqlite3_finalize');
  @sqlite3_column_count:= GetProc('sqlite3_column_count');
  @sqlite3_column_name := GetProc('sqlite3_column_name');
  @sqlite3_column_text := GetProc('sqlite3_column_text');
  @sqlite3_column_type := GetProc('sqlite3_column_type');

  // Verify critical functions loaded
  if not Assigned(@sqlite3_open) or not Assigned(@sqlite3_exec) then
  begin
    FLastError := 'sqlite3.dll is present but appears corrupt or wrong version.';
    FreeLibrary(FLib);
    FLib := 0;
    Exit;
  end;

  Result := True;
end;

procedure TMiniDB.SetError(const Msg: string);
begin
  FLastError := Msg;
end;

function TMiniDB.IsOpen: Boolean;
begin
  Result := Assigned(FDB);
end;

function TMiniDB.Open(const Filename: string): Boolean;
var
  RC : Integer;
begin
  Result := False;

  if FLib = 0 then
  begin
    SetError('SQLite DLL not available.');
    Exit;
  end;

  // Close any existing connection first
  Close;

  RC := sqlite3_open(PAnsiChar(AnsiString(Filename)), FDB);
  if RC <> SQLITE_OK then
  begin
    SetError('Cannot open database: ' + string(sqlite3_errmsg(FDB)));
    FDB := nil;
    Exit;
  end;

  FFilename  := Filename;
  FLastError := '';
  Result     := True;
end;

procedure TMiniDB.Close;
begin
  if Assigned(FDB) then
  begin
    sqlite3_close(FDB);
    FDB       := nil;
    FFilename := '';
  end;
end;

function TMiniDB.Exec(const SQL: string): Boolean;
var
  ErrMsg : PAnsiChar;
  RC     : Integer;
begin
  Result := False;

  if not IsOpen then
  begin
    SetError('No database open. Call DbOpen first.');
    Exit;
  end;

  ErrMsg := nil;
  RC     := sqlite3_exec(FDB, PAnsiChar(AnsiString(SQL)),
                         nil, nil, ErrMsg);
  if RC <> SQLITE_OK then
  begin
    if Assigned(ErrMsg) then
    begin
      SetError(string(ErrMsg));
      sqlite3_free(ErrMsg);
    end
    else
      SetError('SQL execution failed (code ' + IntToStr(RC) + ')');
    Exit;
  end;

  FLastError := '';
  Result     := True;
end;

function TMiniDB.Query(const SQL: string): string;
var
  Stmt     : TSQLiteStmt;
  Tail     : PAnsiChar;
  RC, Cols : Integer;
  I        : Integer;
  Row      : string;
  Header   : string;
  Lines    : TStringList;
  ColW     : array of Integer;
  ColName  : string;
  CellVal  : string;
begin
  Result := '';

  if not IsOpen then
  begin
    SetError('No database open. Call DbOpen first.');
    Exit;
  end;

  Tail := nil;
  RC   := sqlite3_prepare_v2(FDB, PAnsiChar(AnsiString(SQL)),
                              -1, Stmt, Tail);
  if RC <> SQLITE_OK then
  begin
    SetError('Query error: ' + string(sqlite3_errmsg(FDB)));
    Exit;
  end;

  Lines  := TStringList.Create;
  try
    Cols := sqlite3_column_count(Stmt);
    SetLength(ColW, Cols);

    // Collect column names and initial widths
    Header := '';
    for I := 0 to Cols - 1 do
    begin
      ColName := string(sqlite3_column_name(Stmt, I));
      ColW[I] := Length(ColName);
      if I > 0 then Header := Header + ' | ';
      Header := Header + ColName;
    end;

    // Fetch all rows, build each as a string
    while sqlite3_step(Stmt) = SQLITE_ROW do
    begin
      Row := '';
      for I := 0 to Cols - 1 do
      begin
        var CellPtr := sqlite3_column_text(Stmt, I);
        if Assigned(CellPtr) then
          CellVal := string(CellPtr)
        else
          CellVal := 'NULL';
        if I > 0 then Row := Row + ' | ';
        Row := Row + CellVal;
        if Length(CellVal) > ColW[I] then ColW[I] := Length(CellVal);
      end;
      Lines.Add(Row);
    end;

    sqlite3_finalize(Stmt);

    // Build formatted output
    var Sep := '';
    for I := 0 to Cols - 1 do
    begin
      if I > 0 then Sep := Sep + '-+-';
      Sep := Sep + StringOfChar('-', ColW[I]);
    end;

    Result := Header + #13#10 + Sep + #13#10;
    for Row in Lines do
      Result := Result + Row + #13#10;

    if Lines.Count = 1 then
      Result := Result + '(1 row)'
    else
      Result := Result + '(' + IntToStr(Lines.Count) + ' rows)';

    FLastError := '';
  finally
    Lines.Free;
  end;
end;

function TMiniDB.QueryValue(const SQL: string): string;
var
  Stmt : TSQLiteStmt;
  Tail : PAnsiChar;
  RC   : Integer;
  Ptr  : PAnsiChar;
begin
  Result := '';

  if not IsOpen then
  begin
    SetError('No database open. Call DbOpen first.');
    Exit;
  end;

  Tail := nil;
  RC   := sqlite3_prepare_v2(FDB, PAnsiChar(AnsiString(SQL)),
                              -1, Stmt, Tail);
  if RC <> SQLITE_OK then
  begin
    SetError('Query error: ' + string(sqlite3_errmsg(FDB)));
    Exit;
  end;

  if sqlite3_step(Stmt) = SQLITE_ROW then
  begin
    Ptr := sqlite3_column_text(Stmt, 0);
    if Assigned(Ptr) then Result := string(Ptr)
    else Result := 'NULL';
  end;

  sqlite3_finalize(Stmt);
  FLastError := '';
end;

function TMiniDB.Available: Boolean;
begin
  Result := FLib <> 0;
end;

end.
