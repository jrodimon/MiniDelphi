unit UFormBuilderTab;

// =============================================================================
// Copyright (c) 2026 Nomidor Software, LLC.
// All rights reserved.
//
// MiniDelphi Toy Compiler & Learning IDE
// =============================================================================

// =============================================================================
//  UFormBuilderTab.pas  —  Visual form designer tab
//
//  Layout
//  ──────
//    Top:      toolbar — New / Open / Save / Save As / Delete
//    Left:     list of .mdfrm files in current project
//    Center-L: vertical palette (Pointer / Label / Button / Edit)
//    Center:   design surface
//    Right:    Object Inspector
//
//  Skinned by VCL Styles (via UTheme). No per-control color code.
// =============================================================================

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.IOUtils,
  System.Generics.Collections,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Graphics, Vcl.Grids, Vcl.ComCtrls, Vcl.Dialogs, Vcl.Menus,
  System.UITypes,
  UFormDef, UTheme;

const
  MDFRM_FILTER = 'MiniDelphi Form|*.mdfrm|All Files|*.*';
  MDFRM_EXT    = 'mdfrm';

type
  TPaletteTool = (ptPointer, ptLabel, ptButton, ptEdit);

  // TPanel that publishes OnKeyDown — needed so we can capture
  // Delete and arrow keys on the design surface.
  TKeyAwarePanel = class(TPanel)
  published
    property OnKeyDown;
    property OnKeyUp;
    property OnKeyPress;
  end;

  TFormBuilderTab = class
  private
    FParent       : TWinControl;

    FFormDef      : TFormDef;
    FCurrentFile  : string;
    FModified     : Boolean;
    FSelection    : TList<TControlDef>;
    FTool         : TPaletteTool;
    FProjectFolder: string;

    FDragging     : Boolean;
    FDragStartX   : Integer;
    FDragStartY   : Integer;
    FDragCtrlX    : Integer;
    FDragCtrlY    : Integer;

    // UI
    FOuter        : TPanel;
    FToolbar      : TPanel;
    FBtnNew       : TButton;
    FBtnOpen      : TButton;
    FBtnSave      : TButton;
    FBtnSaveAs    : TButton;
    FBtnDelete    : TButton;
    FLabelStatus  : TLabel;

    FLeftPanel    : TPanel;
    FFileList     : TListBox;
    FLabelFiles   : TLabel;
    FSplitterL    : TSplitter;

    FPalettePanel : TPanel;
    FLabelPalette : TLabel;
    FPaletteList  : TListBox;
    FSplitterP    : TSplitter;

    FRightPanel   : TPanel;
    FLabelInsp    : TLabel;
    FInspector    : TStringGrid;
    FSplitterR    : TSplitter;

    FCanvasPanel  : TPanel;
    FDesignSurface: TKeyAwarePanel;
    FCanvasInfo   : TLabel;

    FCtrlMap      : TDictionary<TWinControl, TControlDef>;

    procedure BuildUI;
    procedure ApplyTheme;
    procedure RefreshFromModel;
    procedure RefreshInspector;
    procedure RefreshFileList;
    procedure RebuildDesignSurface;
    procedure SetTool(T: TPaletteTool);
    procedure SetModified(V: Boolean);
    procedure SelectControl(C: TControlDef);
    procedure UpdateStatus;
    procedure SyncPaletteSelection;

    function  KindInfoByTool(T: TPaletteTool) : TControlKindInfo;

    function  BuildVCLControlForDesign(Parent: TWinControl; CD: TControlDef) : TWinControl;
    function  BuildVCLControlForRuntime(Parent: TWinControl; CD: TControlDef) : TControl;

    procedure OnBtnNew      (Sender: TObject);
    procedure OnBtnOpen     (Sender: TObject);
    procedure OnBtnSave     (Sender: TObject);
    procedure OnBtnSaveAs   (Sender: TObject);
    procedure OnBtnDelete   (Sender: TObject);
    procedure OnPaletteSelect(Sender: TObject);

    procedure OnFileListDblClick(Sender: TObject);
    procedure OnSurfaceMouseDown(Sender: TObject; Button: TMouseButton;
                                 Shift: TShiftState; X, Y: Integer);
    procedure OnSurfaceMouseMove(Sender: TObject; Shift: TShiftState;
                                 X, Y: Integer);
    procedure OnSurfaceMouseUp  (Sender: TObject; Button: TMouseButton;
                                 Shift: TShiftState; X, Y: Integer);
    procedure OnSurfaceKeyDown  (Sender: TObject; var Key: Word;
                                 Shift: TShiftState);

    procedure OnDesignedCtrlMouseDown(Sender: TObject; Button: TMouseButton;
                                      Shift: TShiftState; X, Y: Integer);
    procedure OnDesignedCtrlMouseMove(Sender: TObject; Shift: TShiftState;
                                      X, Y: Integer);
    procedure OnDesignedCtrlMouseUp  (Sender: TObject; Button: TMouseButton;
                                      Shift: TShiftState; X, Y: Integer);

    procedure OnInspectorSetEditText(Sender: TObject; ACol, ARow: Integer;
                                     const Value: string);
  public
    constructor Create(AParent: TWinControl);
    destructor  Destroy; override;

    procedure SetProjectFolder(const Folder: string);
    procedure LoadFormFile(const Path: string);

    procedure RunFormDef(FD: TFormDef);
    procedure RunFormFile(const Path: string);

    procedure DoNew;
    procedure DoOpen;
    procedure DoSave;
    procedure DoSaveAs;

    property CurrentFile : string read FCurrentFile;
    property Modified    : Boolean read FModified;
    property FormDef     : TFormDef read FFormDef;
  end;

// =============================================================================
implementation
// =============================================================================

// ═══════════════════════════════════════════════════════════════════════════
//  Constructor / Destructor
// ═══════════════════════════════════════════════════════════════════════════

constructor TFormBuilderTab.Create(AParent: TWinControl);
begin
  inherited Create;
  FParent      := AParent;
  FFormDef     := TFormDef.Create;
  FSelection   := TList<TControlDef>.Create;
  FCtrlMap     := TDictionary<TWinControl, TControlDef>.Create;
  FTool        := ptPointer;
  FCurrentFile := '';
  FModified    := False;
  FDragging    := False;
  FProjectFolder := '';

  BuildUI;
  RefreshFromModel;
  UpdateStatus;
  SyncPaletteSelection;

  ApplyTheme;
  Theme.Subscribe(ApplyTheme);
end;

destructor TFormBuilderTab.Destroy;
begin
  Theme.Unsubscribe(ApplyTheme);
  FCtrlMap.Free;
  FSelection.Free;
  FFormDef.Free;
  inherited;
end;

procedure TFormBuilderTab.ApplyTheme;
begin
  // VCL Styles repaints everything. No per-control work needed.
end;

// ═══════════════════════════════════════════════════════════════════════════
//  UI CONSTRUCTION
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormBuilderTab.BuildUI;
const
  BW  = 88;
  BH  = 30;
  PAD = 8;

  procedure MakeBtn(var B: TButton; Parent: TWinControl;
                    const Cap: string; var X: Integer;
                    Handler: TNotifyEvent; const Hint: string = '');
  begin
    B := TButton.Create(Parent);
    B.Parent  := Parent;
    B.Caption := Cap;
    B.Left    := X;  B.Top := PAD;
    B.Width   := BW; B.Height := BH;
    B.OnClick := Handler;
    if Hint <> '' then
    begin
      B.Hint := Hint;
      B.ShowHint := True;
    end;
    Inc(X, BW + PAD);
  end;

var X : Integer;
begin
  if FParent = nil then
    raise Exception.Create('TFormBuilderTab requires a non-nil parent');

  FOuter            := TPanel.Create(FParent);
  FOuter.Parent     := FParent;
  FOuter.Align      := alClient;
  FOuter.BevelOuter := bvNone;

  // ── Top toolbar ────────────────────────────────────────────────────────
  FToolbar            := TPanel.Create(FOuter);
  FToolbar.Parent     := FOuter;
  FToolbar.Align      := alTop;
  FToolbar.Height     := BH + PAD * 2;
  FToolbar.BevelOuter := bvNone;

  X := PAD;
  MakeBtn(FBtnNew,    FToolbar, 'New',     X, OnBtnNew,    'New form');
  MakeBtn(FBtnOpen,   FToolbar, 'Open',    X, OnBtnOpen,   'Open .mdfrm');
  MakeBtn(FBtnSave,   FToolbar, 'Save',    X, OnBtnSave,   'Save form');
  MakeBtn(FBtnSaveAs, FToolbar, 'Save As', X, OnBtnSaveAs, 'Save form as...');
  MakeBtn(FBtnDelete, FToolbar, 'Delete',  X, OnBtnDelete, 'Delete selected control (or press Del)');

  FLabelStatus            := TLabel.Create(FToolbar);
  FLabelStatus.Parent     := FToolbar;
  FLabelStatus.Left       := X + PAD * 2;
  FLabelStatus.Top        := PAD + 8;
  FLabelStatus.Width      := 700;

  // ── Left: file list ────────────────────────────────────────────────────
  FLeftPanel            := TPanel.Create(FOuter);
  FLeftPanel.Parent     := FOuter;
  FLeftPanel.Align      := alLeft;
  FLeftPanel.Width      := 180;
  FLeftPanel.BevelOuter := bvNone;

  FLabelFiles            := TLabel.Create(FLeftPanel);
  FLabelFiles.Parent     := FLeftPanel;
  FLabelFiles.Align      := alTop;
  FLabelFiles.Height     := 28;
  FLabelFiles.Caption    := '   Forms in Project';
  FLabelFiles.Font.Style := [fsBold];

  FFileList              := TListBox.Create(FLeftPanel);
  FFileList.Parent       := FLeftPanel;
  FFileList.Align        := alClient;
  FFileList.OnDblClick   := OnFileListDblClick;

  FSplitterL := TSplitter.Create(FOuter);
  FSplitterL.Parent := FOuter;
  FSplitterL.Align  := alLeft;
  FSplitterL.Width  := 4;

  // ── Palette (between file list and canvas) ─────────────────────────────
  FPalettePanel            := TPanel.Create(FOuter);
  FPalettePanel.Parent     := FOuter;
  FPalettePanel.Align      := alLeft;
  FPalettePanel.Width      := 140;
  FPalettePanel.BevelOuter := bvNone;

  FLabelPalette            := TLabel.Create(FPalettePanel);
  FLabelPalette.Parent     := FPalettePanel;
  FLabelPalette.Align      := alTop;
  FLabelPalette.Height     := 28;
  FLabelPalette.Caption    := '   Palette';
  FLabelPalette.Font.Style := [fsBold];

  FPaletteList              := TListBox.Create(FPalettePanel);
  FPaletteList.Parent       := FPalettePanel;
  FPaletteList.Align        := alClient;
  FPaletteList.Items.Add('Pointer');
  FPaletteList.Items.Add('Label');
  FPaletteList.Items.Add('Button');
  FPaletteList.Items.Add('Edit');
  FPaletteList.ItemIndex    := 0;
  FPaletteList.OnClick      := OnPaletteSelect;

  FSplitterP := TSplitter.Create(FOuter);
  FSplitterP.Parent := FOuter;
  FSplitterP.Align  := alLeft;
  FSplitterP.Width  := 4;

  // ── Right: object inspector ────────────────────────────────────────────
  FRightPanel            := TPanel.Create(FOuter);
  FRightPanel.Parent     := FOuter;
  FRightPanel.Align      := alRight;
  FRightPanel.Width      := 280;
  FRightPanel.BevelOuter := bvNone;

  FLabelInsp            := TLabel.Create(FRightPanel);
  FLabelInsp.Parent     := FRightPanel;
  FLabelInsp.Align      := alTop;
  FLabelInsp.Height     := 28;
  FLabelInsp.Caption    := '   Object Inspector';
  FLabelInsp.Font.Style := [fsBold];

  FInspector                  := TStringGrid.Create(FRightPanel);
  FInspector.Parent           := FRightPanel;
  FInspector.Align            := alClient;
  FInspector.ColCount         := 2;
  FInspector.RowCount         := 2;
  FInspector.FixedRows        := 1;
  FInspector.FixedCols        := 0;
  FInspector.DefaultRowHeight := 22;
  FInspector.Options          := [goFixedHorzLine, goFixedVertLine,
                                  goHorzLine, goVertLine, goEditing,
                                  goAlwaysShowEditor];
  FInspector.Cells[0, 0] := 'Property';
  FInspector.Cells[1, 0] := 'Value';
  FInspector.ColWidths[0] := 110;
  FInspector.ColWidths[1] := 160;
  FInspector.OnSetEditText := OnInspectorSetEditText;

  FSplitterR := TSplitter.Create(FOuter);
  FSplitterR.Parent := FOuter;
  FSplitterR.Align  := alRight;
  FSplitterR.Width  := 4;

  // ── Center: canvas ─────────────────────────────────────────────────────
  FCanvasPanel             := TPanel.Create(FOuter);
  FCanvasPanel.Parent      := FOuter;
  FCanvasPanel.Align       := alClient;
  FCanvasPanel.BevelOuter  := bvNone;

  FCanvasInfo            := TLabel.Create(FCanvasPanel);
  FCanvasInfo.Parent     := FCanvasPanel;
  FCanvasInfo.Align      := alTop;
  FCanvasInfo.Height     := 26;
  FCanvasInfo.Caption    := '   Click a palette tool, then click the form to place a control';

  // Design surface — light "form" look regardless of theme (it represents
  // a real Windows form preview).
  FDesignSurface             := TKeyAwarePanel.Create(FCanvasPanel);
  FDesignSurface.Parent      := FCanvasPanel;
  FDesignSurface.Left        := 24;
  FDesignSurface.Top         := 34;
  FDesignSurface.Width       := FFormDef.GetWidth;
  FDesignSurface.Height      := FFormDef.GetHeight;
  FDesignSurface.BevelOuter  := bvRaised;
  FDesignSurface.Color       := clBtnFace;
  FDesignSurface.ParentBackground := False;
  FDesignSurface.StyleElements   := [];
  FDesignSurface.Caption     := '';
  FDesignSurface.TabStop     := True;
  FDesignSurface.OnMouseDown := OnSurfaceMouseDown;
  FDesignSurface.OnMouseMove := OnSurfaceMouseMove;
  FDesignSurface.OnMouseUp   := OnSurfaceMouseUp;
  FDesignSurface.OnKeyDown   := OnSurfaceKeyDown;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  STATUS / TOOL SELECTION
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormBuilderTab.UpdateStatus;
var
  S    : string;
  Tool : string;
begin
  case FTool of
    ptPointer : Tool := 'Pointer';
    ptLabel   : Tool := 'Label (click form to place)';
    ptButton  : Tool := 'Button (click form to place)';
    ptEdit    : Tool := 'Edit (click form to place)';
  end;

  if FCurrentFile = '' then
    S := 'Untitled.mdfrm'
  else
    S := ExtractFileName(FCurrentFile);
  if FModified then S := '* ' + S;
  S := S + '    |    Tool: ' + Tool;
  if FSelection.Count = 1 then
    S := S + '    |    Selected: ' + FSelection[0].Name;
  FLabelStatus.Caption := S;
end;

procedure TFormBuilderTab.SetTool(T: TPaletteTool);
begin
  FTool := T;
  SyncPaletteSelection;
  UpdateStatus;
end;

procedure TFormBuilderTab.SyncPaletteSelection;
begin
  if Assigned(FPaletteList) then
    FPaletteList.ItemIndex := Ord(FTool);
end;

procedure TFormBuilderTab.SetModified(V: Boolean);
begin
  FModified := V;
  UpdateStatus;
end;

procedure TFormBuilderTab.SelectControl(C: TControlDef);
begin
  FSelection.Clear;
  if C <> nil then
    FSelection.Add(C);
  RefreshInspector;
  FDesignSurface.Invalidate;
  for var Ctrl in FCtrlMap.Keys do
    Ctrl.Invalidate;
  UpdateStatus;
end;

function TFormBuilderTab.KindInfoByTool(T: TPaletteTool): TControlKindInfo;
begin
  case T of
    ptLabel  : Result := CONTROL_KINDS[0];
    ptButton : Result := CONTROL_KINDS[1];
    ptEdit   : Result := CONTROL_KINDS[2];
  else
    Result := CONTROL_KINDS[0];
  end;
end;

procedure TFormBuilderTab.OnPaletteSelect(Sender: TObject);
begin
  case FPaletteList.ItemIndex of
    0 : FTool := ptPointer;
    1 : FTool := ptLabel;
    2 : FTool := ptButton;
    3 : FTool := ptEdit;
  end;
  UpdateStatus;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  REFRESH
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormBuilderTab.RefreshFromModel;
begin
  FDesignSurface.Width  := FFormDef.GetWidth;
  FDesignSurface.Height := FFormDef.GetHeight;
  FDesignSurface.Caption := FFormDef.GetCaption;
  RebuildDesignSurface;
  RefreshInspector;
end;

procedure TFormBuilderTab.RebuildDesignSurface;
var
  C   : TControlDef;
  W   : TWinControl;
  Lst : TList<TWinControl>;
begin
  Lst := TList<TWinControl>.Create;
  try
    for W in FCtrlMap.Keys do
      Lst.Add(W);
    for W in Lst do
      W.Free;
  finally
    Lst.Free;
  end;
  FCtrlMap.Clear;

  for C in FFormDef.Controls do
  begin
    W := BuildVCLControlForDesign(FDesignSurface, C);
    if Assigned(W) then
      FCtrlMap.Add(W, C);
  end;
end;

function TFormBuilderTab.BuildVCLControlForDesign(Parent: TWinControl;
  CD: TControlDef): TWinControl;
var
  P : TPanel;
begin
  P            := TPanel.Create(Parent);
  P.Parent     := Parent;
  P.Left       := CD.GetLeft;
  P.Top        := CD.GetTop;
  P.Width      := CD.GetWidth;
  P.Height     := CD.GetHeight;
  P.BevelOuter := bvNone;
  P.OnMouseDown := OnDesignedCtrlMouseDown;
  P.OnMouseMove := OnDesignedCtrlMouseMove;
  P.OnMouseUp   := OnDesignedCtrlMouseUp;
  P.ParentBackground := False;
  P.StyleElements   := [];

  if SameText(CD.ControlType, 'Button') then
  begin
    P.Caption := CD.GetCaption;
    P.Color   := clBtnFace;
    P.BevelOuter := bvRaised;
  end
  else if SameText(CD.ControlType, 'Label') then
  begin
    P.Caption := CD.GetCaption;
    P.Color   := clBtnFace;
  end
  else if SameText(CD.ControlType, 'Edit') then
  begin
    P.Caption := CD.GetText;
    P.Color   := clWindow;
    P.BevelOuter := bvLowered;
  end
  else
  begin
    P.Caption := '?' + CD.ControlType + '?';
    P.Color   := clRed;
  end;

  Result := P;
end;

function TFormBuilderTab.BuildVCLControlForRuntime(Parent: TWinControl;
  CD: TControlDef): TControl;
var
  L : TLabel;
  B : TButton;
  E : TEdit;
begin
  if SameText(CD.ControlType, 'Label') then
  begin
    L := TLabel.Create(Parent);
    L.Parent  := Parent;
    L.Left    := CD.GetLeft;
    L.Top     := CD.GetTop;
    L.Width   := CD.GetWidth;
    L.Height  := CD.GetHeight;
    L.Caption := CD.GetCaption;
    L.Name    := CD.Name;
    Result := L;
  end
  else if SameText(CD.ControlType, 'Button') then
  begin
    B := TButton.Create(Parent);
    B.Parent  := Parent;
    B.Left    := CD.GetLeft;
    B.Top     := CD.GetTop;
    B.Width   := CD.GetWidth;
    B.Height  := CD.GetHeight;
    B.Caption := CD.GetCaption;
    B.Name    := CD.Name;
    Result := B;
  end
  else if SameText(CD.ControlType, 'Edit') then
  begin
    E := TEdit.Create(Parent);
    E.Parent := Parent;
    E.Left   := CD.GetLeft;
    E.Top    := CD.GetTop;
    E.Width  := CD.GetWidth;
    E.Height := CD.GetHeight;
    E.Text   := CD.GetText;
    E.Name   := CD.Name;
    Result := E;
  end
  else
    Result := nil;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  OBJECT INSPECTOR
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormBuilderTab.RefreshInspector;

  procedure ShowProps(Title: string; PropBag: TStringList; ExtraNameRow: Boolean;
                      const CtrlName, CtrlType: string);
  var
    I       : Integer;
    Row     : Integer;
    Keys    : TStringList;
    K       : string;
  begin
    FInspector.Cells[0, 0] := 'Property';
    FInspector.Cells[1, 0] := 'Value';

    Keys := TStringList.Create;
    try
      if ExtraNameRow then
      begin
        Keys.Add('Name');
        Keys.Add('Type');
      end
      else
        Keys.Add('Name');

      if not ExtraNameRow then
      begin
        Keys.Add('Caption');
        Keys.Add('Width');
        Keys.Add('Height');
      end
      else
      begin
        Keys.Add('Left');
        Keys.Add('Top');
        Keys.Add('Width');
        Keys.Add('Height');
        if SameText(CtrlType, 'Edit') then
          Keys.Add('Text')
        else
          Keys.Add('Caption');
        Keys.Add('OnClick');
      end;

      for I := 0 to PropBag.Count - 1 do
      begin
        K := PropBag.Names[I];
        if (K <> '') and (Keys.IndexOf(K) < 0) then
          Keys.Add(K);
      end;

      FInspector.RowCount := Keys.Count + 1;
      for I := 0 to Keys.Count - 1 do
      begin
        Row := I + 1;
        K   := Keys[I];
        FInspector.Cells[0, Row] := K;

        if SameText(K, 'Name') then
        begin
          if ExtraNameRow then
            FInspector.Cells[1, Row] := CtrlName
          else
            FInspector.Cells[1, Row] := FFormDef.Name;
        end
        else if SameText(K, 'Type') then
          FInspector.Cells[1, Row] := CtrlType
        else
          FInspector.Cells[1, Row] := PropBag.Values[K];
      end;
    finally
      Keys.Free;
    end;
  end;

var
  C : TControlDef;
begin
  if FSelection.Count = 1 then
  begin
    C := FSelection[0];
    ShowProps('Control', C.PropList, True, C.Name, C.ControlType);
  end
  else
  begin
    ShowProps('Form', FFormDef.PropList, False, FFormDef.Name, '');
  end;
end;

procedure TFormBuilderTab.OnInspectorSetEditText(Sender: TObject;
  ACol, ARow: Integer; const Value: string);
var
  Key  : string;
  C    : TControlDef;
  NewName : string;
begin
  if (ACol <> 1) or (ARow < 1) then Exit;
  Key := FInspector.Cells[0, ARow];
  if Key = '' then Exit;

  if FSelection.Count = 1 then
  begin
    C := FSelection[0];

    if SameText(Key, 'Type') then
    begin
      RefreshInspector;
      Exit;
    end;

    if SameText(Key, 'Name') then
    begin
      NewName := Trim(Value);
      if NewName = C.Name then Exit;
      if not IsValidIdentifier(NewName) then
      begin
        ShowMessage('Name must be a valid identifier.');
        RefreshInspector;
        Exit;
      end;
      if FFormDef.FindControl(NewName) <> nil then
      begin
        ShowMessage('That name is already used on this form.');
        RefreshInspector;
        Exit;
      end;
      C.Name := NewName;
      SetModified(True);
      UpdateStatus;
      Exit;
    end;

    if SameText(Key, 'OnClick') then
    begin
      if (Value <> '') and (not IsValidIdentifier(Trim(Value))) then
      begin
        ShowMessage('Handler name must be a valid identifier or empty.');
        RefreshInspector;
        Exit;
      end;
      C.Props[Key] := Trim(Value);
      SetModified(True);
      Exit;
    end;

    C.Props[Key] := Value;
    SetModified(True);
    RebuildDesignSurface;
    SelectControl(FFormDef.FindControl(C.Name));
  end
  else
  begin
    if SameText(Key, 'Name') then
    begin
      NewName := Trim(Value);
      if not IsValidIdentifier(NewName) then
      begin
        ShowMessage('Form name must be a valid identifier.');
        RefreshInspector;
        Exit;
      end;
      FFormDef.SetName(NewName);
      SetModified(True);
      UpdateStatus;
      Exit;
    end;

    FFormDef.Props[Key] := Value;

    if SameText(Key, 'Width') or SameText(Key, 'Height') or
       SameText(Key, 'Caption') then
    begin
      FDesignSurface.Width   := FFormDef.GetWidth;
      FDesignSurface.Height  := FFormDef.GetHeight;
      FDesignSurface.Caption := FFormDef.GetCaption;
    end;
    SetModified(True);
  end;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  FILE LIST
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormBuilderTab.SetProjectFolder(const Folder: string);
begin
  FProjectFolder := Folder;
  RefreshFileList;
end;

procedure TFormBuilderTab.RefreshFileList;
var
  Files : TArray<string>;
  F     : string;
begin
  FFileList.Items.BeginUpdate;
  try
    FFileList.Items.Clear;
    if (FProjectFolder <> '') and TDirectory.Exists(FProjectFolder) then
    begin
      Files := TDirectory.GetFiles(FProjectFolder, '*.mdfrm');
      for F in Files do
        FFileList.Items.Add(ExtractFileName(F));
    end;
    if FFileList.Items.Count = 0 then
      FFileList.Items.Add('(no forms yet — click New)');
  finally
    FFileList.Items.EndUpdate;
  end;
end;

procedure TFormBuilderTab.OnFileListDblClick(Sender: TObject);
var
  S    : string;
  Path : string;
begin
  if FFileList.ItemIndex < 0 then Exit;
  S := FFileList.Items[FFileList.ItemIndex];
  if Pos('(', S) = 1 then Exit;
  if FProjectFolder = '' then Exit;
  Path := IncludeTrailingPathDelimiter(FProjectFolder) + S;
  if TFile.Exists(Path) then
    LoadFormFile(Path);
end;

// ═══════════════════════════════════════════════════════════════════════════
//  TOOLBAR HANDLERS
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormBuilderTab.OnBtnNew(Sender: TObject);
begin
  DoNew;
end;

procedure TFormBuilderTab.OnBtnOpen(Sender: TObject);
begin
  DoOpen;
end;

procedure TFormBuilderTab.OnBtnSave(Sender: TObject);
begin
  DoSave;
end;

procedure TFormBuilderTab.OnBtnSaveAs(Sender: TObject);
begin
  DoSaveAs;
end;

procedure TFormBuilderTab.OnBtnDelete(Sender: TObject);
begin
  if FSelection.Count = 0 then Exit;
  FFormDef.RemoveControl(FSelection[0]);
  FSelection.Clear;
  SetModified(True);
  RebuildDesignSurface;
  RefreshInspector;
end;

procedure TFormBuilderTab.DoNew;
begin
  if FModified and (MessageDlg(
    'Discard unsaved form?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;

  FFormDef.Clear;
  FCurrentFile := '';
  FSelection.Clear;
  SetModified(False);
  RefreshFromModel;
end;

procedure TFormBuilderTab.DoOpen;
var Dlg : TOpenDialog;
begin
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Filter     := MDFRM_FILTER;
    Dlg.DefaultExt := MDFRM_EXT;
    Dlg.Options    := [ofFileMustExist];
    if FProjectFolder <> '' then
      Dlg.InitialDir := FProjectFolder;
    if Dlg.Execute then
      LoadFormFile(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TFormBuilderTab.DoSave;
begin
  if FCurrentFile = '' then
    DoSaveAs
  else
  begin
    FFormDef.SaveToFile(FCurrentFile);
    SetModified(False);
    RefreshFileList;
  end;
end;

procedure TFormBuilderTab.DoSaveAs;
var Dlg : TSaveDialog;
begin
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Filter     := MDFRM_FILTER;
    Dlg.DefaultExt := MDFRM_EXT;
    if FProjectFolder <> '' then
      Dlg.InitialDir := FProjectFolder;
    if FFormDef.Name <> '' then
      Dlg.FileName := FFormDef.Name + '.' + MDFRM_EXT;
    if Dlg.Execute then
    begin
      FFormDef.SaveToFile(Dlg.FileName);
      FCurrentFile := Dlg.FileName;
      SetModified(False);
      RefreshFileList;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TFormBuilderTab.LoadFormFile(const Path: string);
begin
  if not TFile.Exists(Path) then
  begin
    ShowMessage('File not found: ' + Path);
    Exit;
  end;
  FFormDef.LoadFromFile(Path);
  FCurrentFile := Path;
  FSelection.Clear;
  SetModified(False);
  RefreshFromModel;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  DESIGN SURFACE — mouse / keyboard
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormBuilderTab.OnSurfaceMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  CD       : TControlDef;
  KindInfo : TControlKindInfo;
begin
  FDesignSurface.SetFocus;

  if FTool <> ptPointer then
  begin
    KindInfo := KindInfoByTool(FTool);
    CD := FFormDef.AddControl(KindInfo);
    CD.SetLeft(X);
    CD.SetTop(Y);
    SetTool(ptPointer);
    SetModified(True);
    RebuildDesignSurface;
    SelectControl(FFormDef.FindControl(CD.Name));
    Exit;
  end;

  SelectControl(nil);
end;

procedure TFormBuilderTab.OnSurfaceMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
end;

procedure TFormBuilderTab.OnSurfaceMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDragging := False;
end;

procedure TFormBuilderTab.OnSurfaceKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  C : TControlDef;
  W : TWinControl;
begin
  if FSelection.Count = 0 then Exit;
  C := FSelection[0];

  case Key of
    VK_DELETE :
      begin
        OnBtnDelete(Sender);
        Key := 0;
      end;
    VK_LEFT  : begin C.SetLeft(C.GetLeft - 1); Key := 0; end;
    VK_RIGHT : begin C.SetLeft(C.GetLeft + 1); Key := 0; end;
    VK_UP    : begin C.SetTop (C.GetTop  - 1); Key := 0; end;
    VK_DOWN  : begin C.SetTop (C.GetTop  + 1); Key := 0; end;
  else
    Exit;
  end;

  for W in FCtrlMap.Keys do
    if FCtrlMap[W] = C then
    begin
      W.Left := C.GetLeft;
      W.Top  := C.GetTop;
      Break;
    end;

  SetModified(True);
  RefreshInspector;
end;

procedure TFormBuilderTab.OnDesignedCtrlMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  W : TWinControl;
  C : TControlDef;
begin
  if not (Sender is TWinControl) then Exit;
  W := TWinControl(Sender);
  if not FCtrlMap.TryGetValue(W, C) then Exit;

  if FTool <> ptPointer then
  begin
    SelectControl(C);
    Exit;
  end;

  SelectControl(C);

  if Button = mbLeft then
  begin
    FDragging   := True;
    FDragStartX := X;
    FDragStartY := Y;
    FDragCtrlX  := W.Left;
    FDragCtrlY  := W.Top;
  end;
end;

procedure TFormBuilderTab.OnDesignedCtrlMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  W : TWinControl;
  C : TControlDef;
begin
  if not FDragging then Exit;
  if not (Sender is TWinControl) then Exit;
  W := TWinControl(Sender);
  if not FCtrlMap.TryGetValue(W, C) then Exit;

  W.Left := FDragCtrlX + (X - FDragStartX);
  W.Top  := FDragCtrlY + (Y - FDragStartY);
  C.SetLeft(W.Left);
  C.SetTop (W.Top);
  SetModified(True);
  RefreshInspector;
end;

procedure TFormBuilderTab.OnDesignedCtrlMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDragging := False;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  RUNTIME (Phase 1 minimal)
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormBuilderTab.RunFormDef(FD: TFormDef);
var
  F : TForm;
  C : TControlDef;
begin
  if FD = nil then Exit;

  F := TForm.CreateNew(nil);
  try
    F.Caption  := FD.GetCaption;
    F.Width    := FD.GetWidth;
    F.Height   := FD.GetHeight;
    F.Position := poScreenCenter;
    F.BorderStyle := bsSingle;

    for C in FD.Controls do
      BuildVCLControlForRuntime(F, C);

    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure TFormBuilderTab.RunFormFile(const Path: string);
var FD : TFormDef;
begin
  if not TFile.Exists(Path) then
  begin
    ShowMessage('Form file not found: ' + Path);
    Exit;
  end;
  FD := TFormDef.Create;
  try
    FD.LoadFromFile(Path);
    RunFormDef(FD);
  finally
    FD.Free;
  end;
end;

end.
