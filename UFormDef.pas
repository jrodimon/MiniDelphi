unit UFormDef;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// =============================================================================

// =============================================================================
//  UFormDef.pas  —  Form definition model
//
//  A form is a TFormDef containing a list of TControlDef. Both have an
//  extensible property bag (TStringList of Key=Value strings) so we can
//  add new properties in later phases without changing the parser.
//
//  Well-known property keys:
//
//    Form-level:  Caption, Width, Height, OnShow (Phase 2), OnClose (Phase 2)
//    Control:     Left, Top, Width, Height, Caption, Text,
//                 OnClick (Phase 2), OnChange (Phase 2)
//
//  Storage format (.mdfrm) is INI with one section per control plus
//  a [Form] section. Z-order is the order in which controls appear
//  in the file.
//
//  Example:
//
//      [Form]
//      Name=GreetingForm
//      Caption=Greeting
//      Width=400
//      Height=200
//
//      [Control:Label1]
//      Type=Label
//      Left=20
//      Top=20
//      Caption=Enter your name:
//
//      [Control:EditName]
//      Type=Edit
//      Left=20
//      Top=50
//      Width=300
//      Text=
//
//      [Control:BtnGreet]
//      Type=Button
//      Left=20
//      Top=90
//      Width=100
//      Height=30
//      Caption=Greet me!
//      OnClick=OnGreetClick
// =============================================================================

interface

uses
  System.SysUtils, System.Classes, System.IniFiles, System.IOUtils,
  System.Generics.Collections;

type
  // ---------------------------------------------------------------------------
  //  Control kinds known to Phase 1.  Adding a new kind in Phase 2 means
  //  adding to TControlKind, the CONTROL_KINDS table, and the runtime
  //  factory in the form builder unit.
  // ---------------------------------------------------------------------------
  TControlKind = (ckLabel, ckButton, ckEdit);

  TControlKindInfo = record
    Kind         : TControlKind;
    TypeName     : string;        // 'Label', 'Button', 'Edit' — case-sensitive
    DefaultWidth : Integer;
    DefaultHeight: Integer;
    DefaultCaption : string;
  end;

  // ---------------------------------------------------------------------------
  //  A single control on a form.  Properties are stored as Key=Value pairs
  //  in the property bag so we can extend without breaking storage.
  //
  //  Convenience accessors are provided for the most common properties.
  // ---------------------------------------------------------------------------
  TControlDef = class
  private
    FProps : TStringList;
    function  GetProp(const Key: string): string;
    procedure SetProp(const Key, Value: string);
    function  GetIntProp(const Key: string; Def: Integer): Integer;
    procedure SetIntProp(const Key: string; Value: Integer);
  public
    Name        : string;          // unique within form, must be a valid identifier
    ControlType : string;          // 'Label' / 'Button' / 'Edit'

    constructor Create;
    destructor  Destroy; override;

    // Property bag access (use these for new/exotic properties)
    property Props[const Key: string] : string read GetProp write SetProp;

    // Convenience accessors for common properties
    function  GetLeft   : Integer;
    procedure SetLeft   (V: Integer);
    function  GetTop    : Integer;
    procedure SetTop    (V: Integer);
    function  GetWidth  : Integer;
    procedure SetWidth  (V: Integer);
    function  GetHeight : Integer;
    procedure SetHeight (V: Integer);
    function  GetCaption: string;
    procedure SetCaption(const V: string);
    function  GetText   : string;
    procedure SetText   (const V: string);
    function  GetOnClick: string;
    procedure SetOnClick(const V: string);

    // Raw access for the object inspector
    function  PropList : TStringList;
  end;

  // ---------------------------------------------------------------------------
  //  Whole form definition.
  // ---------------------------------------------------------------------------
  TFormDef = class
  private
    FProps    : TStringList;
    FControls : TObjectList<TControlDef>;
    function  GetProp(const Key: string): string;
    procedure SetProp(const Key, Value: string);
  public
    constructor Create;
    destructor  Destroy; override;

    // Form-level properties
    function  Name    : string;
    procedure SetName(const V: string);
    function  GetCaption: string;
    procedure SetCaption(const V: string);
    function  GetWidth  : Integer;
    procedure SetWidth  (V: Integer);
    function  GetHeight : Integer;
    procedure SetHeight (V: Integer);

    property Props[const Key: string] : string read GetProp write SetProp;
    function  PropList : TStringList;

    // Controls
    property Controls : TObjectList<TControlDef> read FControls;
    function  AddControl(Kind: TControlKindInfo) : TControlDef;
    function  FindControl(const AName: string) : TControlDef;
    procedure RemoveControl(C: TControlDef);
    function  GenerateUniqueName(const BaseName: string) : string;

    // I/O
    procedure LoadFromFile(const Path: string);
    procedure SaveToFile  (const Path: string);
    procedure Clear;
  end;

const
  CONTROL_KINDS : array[0..2] of TControlKindInfo = (
    (Kind: ckLabel;  TypeName: 'Label';
     DefaultWidth: 80;  DefaultHeight: 20; DefaultCaption: 'Label'),

    (Kind: ckButton; TypeName: 'Button';
     DefaultWidth: 90; DefaultHeight: 30; DefaultCaption: 'Button'),

    (Kind: ckEdit;   TypeName: 'Edit';
     DefaultWidth: 150; DefaultHeight: 24; DefaultCaption: '')
  );

// Validators / utilities (exposed so the form builder can reuse them)
function IsValidIdentifier(const S: string) : Boolean;

// =============================================================================
implementation
// =============================================================================

function IsValidIdentifier(const S: string) : Boolean;
var I : Integer;
begin
  Result := False;
  if S = '' then Exit;
  if not CharInSet(S[1], ['A'..'Z', 'a'..'z', '_']) then Exit;
  for I := 2 to Length(S) do
    if not CharInSet(S[I], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Exit;
  Result := True;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  TControlDef
// ═══════════════════════════════════════════════════════════════════════════

constructor TControlDef.Create;
begin
  inherited Create;
  FProps := TStringList.Create;
  FProps.CaseSensitive := False;
end;

destructor TControlDef.Destroy;
begin
  FProps.Free;
  inherited;
end;

function TControlDef.GetProp(const Key: string): string;
begin
  Result := FProps.Values[Key];
end;

procedure TControlDef.SetProp(const Key, Value: string);
begin
  if Value = '' then
    FProps.Values[Key] := ''     // keep the key but blank — visible in inspector
  else
    FProps.Values[Key] := Value;
end;

function TControlDef.GetIntProp(const Key: string; Def: Integer): Integer;
begin
  Result := StrToIntDef(FProps.Values[Key], Def);
end;

procedure TControlDef.SetIntProp(const Key: string; Value: Integer);
begin
  FProps.Values[Key] := IntToStr(Value);
end;

function TControlDef.GetLeft   : Integer; begin Result := GetIntProp('Left',   0);   end;
procedure TControlDef.SetLeft   (V: Integer); begin SetIntProp('Left',   V); end;
function TControlDef.GetTop    : Integer; begin Result := GetIntProp('Top',    0);   end;
procedure TControlDef.SetTop    (V: Integer); begin SetIntProp('Top',    V); end;
function TControlDef.GetWidth  : Integer; begin Result := GetIntProp('Width',  80);  end;
procedure TControlDef.SetWidth  (V: Integer); begin SetIntProp('Width',  V); end;
function TControlDef.GetHeight : Integer; begin Result := GetIntProp('Height', 24);  end;
procedure TControlDef.SetHeight (V: Integer); begin SetIntProp('Height', V); end;
function TControlDef.GetCaption: string;  begin Result := FProps.Values['Caption']; end;
procedure TControlDef.SetCaption(const V: string); begin FProps.Values['Caption'] := V; end;
function TControlDef.GetText   : string;  begin Result := FProps.Values['Text']; end;
procedure TControlDef.SetText   (const V: string); begin FProps.Values['Text'] := V; end;
function TControlDef.GetOnClick: string;  begin Result := FProps.Values['OnClick']; end;
procedure TControlDef.SetOnClick(const V: string); begin FProps.Values['OnClick'] := V; end;

function TControlDef.PropList: TStringList;
begin
  Result := FProps;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  TFormDef
// ═══════════════════════════════════════════════════════════════════════════

constructor TFormDef.Create;
begin
  inherited Create;
  FProps    := TStringList.Create;
  FProps.CaseSensitive := False;
  FControls := TObjectList<TControlDef>.Create(True);   // owns its items

  // Default form properties
  SetName('Form1');
  SetCaption('Form1');
  SetWidth(400);
  SetHeight(300);
end;

destructor TFormDef.Destroy;
begin
  FControls.Free;
  FProps.Free;
  inherited;
end;

procedure TFormDef.Clear;
begin
  FControls.Clear;
  FProps.Clear;
  SetName('Form1');
  SetCaption('Form1');
  SetWidth(400);
  SetHeight(300);
end;

function TFormDef.GetProp(const Key: string): string;
begin
  Result := FProps.Values[Key];
end;

procedure TFormDef.SetProp(const Key, Value: string);
begin
  FProps.Values[Key] := Value;
end;

function TFormDef.Name    : string;  begin Result := FProps.Values['Name']; end;
procedure TFormDef.SetName(const V: string); begin FProps.Values['Name'] := V; end;
function TFormDef.GetCaption: string;  begin Result := FProps.Values['Caption']; end;
procedure TFormDef.SetCaption(const V: string); begin FProps.Values['Caption'] := V; end;
function TFormDef.GetWidth  : Integer; begin Result := StrToIntDef(FProps.Values['Width'],  400); end;
procedure TFormDef.SetWidth  (V: Integer); begin FProps.Values['Width']  := IntToStr(V); end;
function TFormDef.GetHeight : Integer; begin Result := StrToIntDef(FProps.Values['Height'], 300); end;
procedure TFormDef.SetHeight (V: Integer); begin FProps.Values['Height'] := IntToStr(V); end;

function TFormDef.PropList : TStringList;
begin
  Result := FProps;
end;

function TFormDef.FindControl(const AName: string): TControlDef;
var C : TControlDef;
begin
  for C in FControls do
    if SameText(C.Name, AName) then
      Exit(C);
  Result := nil;
end;

function TFormDef.GenerateUniqueName(const BaseName: string): string;
var
  N    : Integer;
  Cand : string;
begin
  N := 1;
  repeat
    Cand := BaseName + IntToStr(N);
    if FindControl(Cand) = nil then
      Exit(Cand);
    Inc(N);
  until N > 9999;
  Result := BaseName + 'X';
end;

function TFormDef.AddControl(Kind: TControlKindInfo): TControlDef;
begin
  Result := TControlDef.Create;
  Result.ControlType := Kind.TypeName;
  Result.Name        := GenerateUniqueName(Kind.TypeName);
  Result.SetLeft(20);
  Result.SetTop(20 + FControls.Count * 10);    // cascade a little
  Result.SetWidth (Kind.DefaultWidth);
  Result.SetHeight(Kind.DefaultHeight);
  case Kind.Kind of
    ckLabel, ckButton : Result.SetCaption(Kind.DefaultCaption);
    ckEdit            : Result.SetText('');
  end;
  FControls.Add(Result);
end;

procedure TFormDef.RemoveControl(C: TControlDef);
var Idx : Integer;
begin
  Idx := FControls.IndexOf(C);
  if Idx >= 0 then
    FControls.Delete(Idx);
end;

// ---------------------------------------------------------------------------
//  Persistence
// ---------------------------------------------------------------------------
procedure TFormDef.LoadFromFile(const Path: string);
var
  Ini      : TIniFile;
  Sections : TStringList;
  S        : string;
  I, J     : Integer;
  CName    : string;
  Keys     : TStringList;
  C        : TControlDef;
begin
  Clear;

  Ini := TIniFile.Create(Path);
  Sections := TStringList.Create;
  Keys     := TStringList.Create;
  try
    Ini.ReadSections(Sections);

    // Form-level properties
    if Sections.IndexOf('Form') >= 0 then
    begin
      Keys.Clear;
      Ini.ReadSection('Form', Keys);
      for J := 0 to Keys.Count - 1 do
        FProps.Values[Keys[J]] := Ini.ReadString('Form', Keys[J], '');
    end;

    // Each control lives in [Control:Name] section. Iterate in source order
    // so z-order matches file order.
    for I := 0 to Sections.Count - 1 do
    begin
      S := Sections[I];
      if Pos('Control:', S) = 1 then
      begin
        CName := Copy(S, 9, MaxInt);
        if Trim(CName) = '' then Continue;
        C := TControlDef.Create;
        C.Name := CName;

        Keys.Clear;
        Ini.ReadSection(S, Keys);
        for J := 0 to Keys.Count - 1 do
        begin
          if SameText(Keys[J], 'Type') then
            C.ControlType := Ini.ReadString(S, 'Type', '')
          else
            C.Props[Keys[J]] := Ini.ReadString(S, Keys[J], '');
        end;
        FControls.Add(C);
      end;
    end;
  finally
    Keys.Free;
    Sections.Free;
    Ini.Free;
  end;
end;

procedure TFormDef.SaveToFile(const Path: string);
var
  Ini      : TIniFile;
  I, J     : Integer;
  C        : TControlDef;
  SectName : string;
  KeyName  : string;
begin
  // Wipe target first so removed controls don't leave orphan sections
  if TFile.Exists(Path) then
    TFile.Delete(Path);

  Ini := TIniFile.Create(Path);
  try
    // Form section
    for J := 0 to FProps.Count - 1 do
    begin
      KeyName := FProps.Names[J];
      if KeyName <> '' then
        Ini.WriteString('Form', KeyName, FProps.ValueFromIndex[J]);
    end;

    // Each control
    for I := 0 to FControls.Count - 1 do
    begin
      C        := FControls[I];
      SectName := 'Control:' + C.Name;
      Ini.WriteString(SectName, 'Type', C.ControlType);
      for J := 0 to C.PropList.Count - 1 do
      begin
        KeyName := C.PropList.Names[J];
        if KeyName <> '' then
          Ini.WriteString(SectName, KeyName, C.PropList.ValueFromIndex[J]);
      end;
    end;
  finally
    Ini.Free;
  end;
end;

end.
