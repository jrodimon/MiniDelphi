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
//    Top-2:    palette — Pointer | Label | Button | Edit
//    Left:     list of .mdfrm files in current project
//    Centre:   design surface (a TPanel sized to FormDef.Width/Height)
//    Right:    Object Inspector — two-column property grid
//
//  Interaction
//  ───────────
//    Pointer mode (default):
//      Click empty space    → select the form
//      Click control        → select it
//      Drag selected ctrl   → move it
//      Delete key           → remove selected control
//      Arrow keys           → nudge selected control by 1px
//
//    Palette tool selected (Label/Button/Edit):
//      Click anywhere on surface → place a new control of that type
//      After placing, mode reverts to Pointer
//
//  Phase 2 hooks (already in place)
//    - TControlDef/TFormDef use property bags → new props are zero-cost
//    - Selection is a list (multi-select ready)
//    - Z-order is preserved in file order
//    - RunFormDef builds a real TForm at runtime
//    - Event handler names are stored as strings; Phase 2 will look them up
//
//  Public API for menu / interpreter integration
//    DoNew, DoOpen, DoSave, DoSaveAs
//    LoadFormFile(path)
//    RunFormDef(formDef)  — Phase 1: shows the form read-only
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

  // ---------------------------------------------------------------------------
  //  TPanel doesn't publish OnKeyDown so we publish it here in a subclass.
  //  Used for the design surface so arrow keys / Delete can be captured.
  // ---------------------------------------------------------------------------
  TKeyAwarePanel = class(TPanel)
  published
    property OnKeyDown;
    property OnKeyUp;
    property OnKeyPress;
  end;

  // ---------------------------------------------------------------------------
  //  TFormBuilderTab — main class
  // ---------------------------------------------------------------------------
  TFormBuilderTab = class
  private
    FParent       : TWinControl;

    // Model
    FFormDef      : TFormDef;
    FCurrentFile  : string;             // path of currently loaded .mdfrm ('' = unsaved)
    FModified     : Boolean;
    FSelection    : TList<TControlDef>; // Phase 1 holds 0 or 1
    FTool         : TPaletteTool;
    FProjectFolder: string;             // tracked from outside, used as InitialDir

    // Drag tracking
    FDragging     : Boolean;
    FDragStartX   : Integer;
    FDragStartY   : Integer;
    FDragCtrlX    : Integer;
    FDragCtrlY    : Integer;

    // UI
    FOuter        : TPanel;
    FToolbar      : TPanel;
    FPalette      : TPanel;
    FBtnNew       : TButton;
    FBtnOpen      : TButton;
    FBtnSave      : TButton;
    FBtnSaveAs    : TButton;
    FBtnDelete    : TButton;
    FLabelStatus  : TLabel;

    FBtnTPointer  : TButton;
    FBtnTLabel    : TButton;
    FBtnTButton   : TButton;
    FBtnTEdit     : TButton;

    FLeftPanel    : TPanel;
    FFileList     : TListBox;
    FLabelFiles   : TLabel;
    FSplitterL    : TSplitter;

    FRightPanel   : TPanel;
    FLabelInsp    : TLabel;
    FInspector    : TStringGrid;
    FSplitterR    : TSplitter;

    FCanvasPanel  : TPanel;             // background that hosts FDesignSurface
    FDesignSurface: TKeyAwarePanel;     // the form being designed
    FCanvasInfo   : TLabel;             // small text above the canvas

    // We track which VCL control is which TControlDef via a parallel list
    FCtrlMap      : TDictionary<TWinControl, TControlDef>;

    procedure BuildUI;
    procedure ApplyTheme;
    procedure RefreshFromModel;       // rebuild the design surface from FFormDef
    procedure RefreshInspector;
    procedure RefreshFileList;
    procedure RebuildDesignSurface;
    procedure SetTool(T: TPaletteTool);
    procedure SetModified(V: Boolean);
    procedure SelectControl(C: TControlDef);
    procedure UpdateStatus;
    function  AddSelectionMarkers(Ctrl: TWinControl) : Boolean;

    // Convert a control kind name to its info row
    function  KindInfoByName(const TypeName: string) : TControlKindInfo;
    function  KindInfoByTool(T: TPaletteTool) : TControlKindInfo;

    // VCL factory — used by both the designer and the runtime
    function  BuildVCLControlForDesign(Parent: TWinControl; CD: TControlDef) : TWinControl;
    function  BuildVCLControlForRuntime(Parent: TWinControl; CD: TControlDef) : TControl;

    // Event handlers
    procedure OnBtnNew      (Sender: TObject);
    procedure OnBtnOpen     (Sender: TObject);
    procedure OnBtnSave     (Sender: TObject);
    procedure OnBtnSaveAs   (Sender: TObject);
    procedure OnBtnDelete   (Sender: TObject);
    procedure OnPaletteClick(Sender: TObject);

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

    // External hooks
    procedure SetProjectFolder(const Folder: string);
    procedure LoadFormFile(const Path: string);

    // Phase 1 minimal runtime
    procedure RunFormDef(FD: TFormDef);
    procedure RunFormFile(const Path: string);

    // Public file operations — main form's File menu can call these
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

const
  DARK    = $00252526;
  DARKER  = $001E1E1E;
  GREEN   = $0056D364;

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

// ═══════════════════════════════════════════════════════════════════════════
//  THEME
//
//  Note: the design surface (FDesignSurface) is intentionally NOT themed.
//  It's meant to look like a real Windows form regardless of the IDE's
//  theme — i.e., always clBtnFace with raised bevel. The canvas around
//  it does follow the theme.
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormBuilderTab.ApplyTheme;
begin
  if Assigned(FOuter)         then Theme.ApplyPanelBg(FOuter);
  if Assigned(FToolbar)       then Theme.ApplyPanelToolbar(FToolbar);
  if Assigned(FPalette)       then Theme.ApplyPanelToolbar(FPalette);
  if Assigned(FLabelStatus)   then Theme.ApplyLabel(FLabelStatus, 'normal');

  if Assigned(FLeftPanel)     then Theme.ApplyPanelAlt(FLeftPanel);
  if Assigned(FLabelFiles)    then Theme.ApplyLabel(FLabelFiles, 'header');
  if Assigned(FFileList)      then Theme.ApplyListBox(FFileList);

  if Assigned(FRightPanel)    then Theme.ApplyPanelAlt(FRightPanel);
  if Assigned(FLabelInsp)     then Theme.ApplyLabel(FLabelInsp, 'header');
  if Assigned(FInspector)     then Theme.ApplyStringGrid(FInspector);

  if Assigned(FCanvasPanel)   then Theme.ApplyPanelBg(FCanvasPanel);
  if Assigned(FCanvasInfo)    then Theme.ApplyLabel(FCanvasInfo, 'accent');

  // FDesignSurface stays in light "form" colors regardless of theme
end;

// ═══════════════════════════════════════════════════════════════════════════
//  UI CONSTRUCTION
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormBuilderTab.BuildUI;
const
  BW = 80;
  BH = 28;
  PAD = 5;

  procedure MakeBtn(var B: TButton; Parent: TWinControl;
                    const Cap: string; var X: Integer;
                    Handler: TNotifyEvent; W: Integer = BW;
                    const Hint: string = '');
  begin
    B := TButton.Create(Parent);
    B.Parent  := Parent;
    B.Caption := Cap;
    B.Left    := X;  B.Top := PAD;
    B.Width   := W;  B.Height := BH;
    B.OnClick := Handler;
    if Hint <> '' then
    begin
      B.Hint     := Hint;
      B.ShowHint := True;
    end;
    Inc(X, W + PAD);
  end;

var X : Integer;
begin
  if FParent = nil then
    raise Exception.Create('TFormBuilderTab requires a non-nil parent');

  FOuter            := TPanel.Create(FParent);
  FOuter.Parent     := FParent;
  FOuter.Align      := alClient;
  FOuter.BevelOuter := bvNone;
  FOuter.Color      := DARKER;

  // ── Top toolbar ────────────────────────────────────────────────────────
  FToolbar            := TPanel.Create(FOuter);
  FToolbar.Parent     := FOuter;
  FToolbar.Align      := alTop;
  FToolbar.Height     := BH + PAD * 2;
  FToolbar.BevelOuter := bvNone;
  FToolbar.Color      := $00303030;

  X := PAD;
  MakeBtn(FBtnNew,    FToolbar, 'New',     X, OnBtnNew,    BW, 'New form');
  MakeBtn(FBtnOpen,   FToolbar, 'Open',    X, OnBtnOpen,   BW, 'Open .mdfrm file');
  MakeBtn(FBtnSave,   FToolbar, 'Save',    X, OnBtnSave,   BW, 'Save form');
  MakeBtn(FBtnSaveAs, FToolbar, 'Save As', X, OnBtnSaveAs, BW, 'Save form as...');
  MakeBtn(FBtnDelete, FToolbar, 'Delete',  X, OnBtnDelete, BW, 'Delete selected control (or press Del)');

  FLabelStatus            := TLabel.Create(FToolbar);
  FLabelStatus.Parent     := FToolbar;
  FLabelStatus.Left       := X + PAD * 2;
  FLabelStatus.Top        := PAD + 6;
  FLabelStatus.Width      := 600;
  FLabelStatus.Font.Color := clWhite;

  // ── Palette ────────────────────────────────────────────────────────────
  FPalette            := TPanel.Create(FOuter);
  FPalette.Parent     := FOuter;
  FPalette.Align      := alTop;
  FPalette.Height     := BH + PAD * 2;
  FPalette.BevelOuter := bvNone;
  FPalette.Color      := $00404040;

  X := PAD;
  FBtnTPointer := TButton.Create(FPalette);
  FBtnTPointer.Parent  := FPalette;
  FBtnTPointer.Caption := 'Pointer';
  FBtnTPointer.Left := X; FBtnTPointer.Top := PAD;
  FBtnTPointer.Width := BW; FBtnTPointer.Height := BH;
  FBtnTPointer.OnClick := OnPaletteClick;
  FBtnTPointer.Tag := Ord(ptPointer);
  Inc(X, BW + PAD * 2);

  FBtnTLabel := TButton.Create(FPalette);
  FBtnTLabel.Parent  := FPalette;
  FBtnTLabel.Caption := 'Label';
  FBtnTLabel.Left := X; FBtnTLabel.Top := PAD;
  FBtnTLabel.Width := BW; FBtnTLabel.Height := BH;
  FBtnTLabel.OnClick := OnPaletteClick;
  FBtnTLabel.Tag := Ord(ptLabel);
  Inc(X, BW + PAD);

  FBtnTButton := TButton.Create(FPalette);
  FBtnTButton.Parent  := FPalette;
  FBtnTButton.Caption := 'Button';
  FBtnTButton.Left := X; FBtnTButton.Top := PAD;
  FBtnTButton.Width := BW; FBtnTButton.Height := BH;
  FBtnTButton.OnClick := OnPaletteClick;
  FBtnTButton.Tag := Ord(ptButton);
  Inc(X, BW + PAD);

  FBtnTEdit := TButton.Create(FPalette);
  FBtnTEdit.Parent  := FPalette;
  FBtnTEdit.Caption := 'Edit';
  FBtnTEdit.Left := X; FBtnTEdit.Top := PAD;
  FBtnTEdit.Width := BW; FBtnTEdit.Height := BH;
  FBtnTEdit.OnClick := OnPaletteClick;
  FBtnTEdit.Tag := Ord(ptEdit);

  // ── Left: file list ────────────────────────────────────────────────────
  FLeftPanel            := TPanel.Create(FOuter);
  FLeftPanel.Parent     := FOuter;
  FLeftPanel.Align      := alLeft;
  FLeftPanel.Width      := 200;
  FLeftPanel.BevelOuter := bvNone;
  FLeftPanel.Color      := DARK;

  FLabelFiles            := TLabel.Create(FLeftPanel);
  FLabelFiles.Parent     := FLeftPanel;
  FLabelFiles.Align      := alTop;
  FLabelFiles.Height     := 22;
  FLabelFiles.Caption    := '  Forms in Project';
  FLabelFiles.Font.Style := [fsBold];
  FLabelFiles.Font.Color := clWhite;

  FFileList              := TListBox.Create(FLeftPanel);
  FFileList.Parent       := FLeftPanel;
  FFileList.Align        := alClient;
  FFileList.Color        := clWindow;
  FFileList.Font.Color   := clBlack;
  FFileList.Font.Name    := 'Segoe UI';
  FFileList.Font.Size    := 9;
  FFileList.OnDblClick   := OnFileListDblClick;

  FSplitterL := TSplitter.Create(FOuter);
  FSplitterL.Parent := FOuter;
  FSplitterL.Align  := alLeft;
  FSplitterL.Width  := 4;

  // ── Right: object inspector ────────────────────────────────────────────
  FRightPanel            := TPanel.Create(FOuter);
  FRightPanel.Parent     := FOuter;
  FRightPanel.Align      := alRight;
  FRightPanel.Width      := 260;
  FRightPanel.BevelOuter := bvNone;
  FRightPanel.Color      := DARK;

  FLabelInsp            := TLabel.Create(FRightPanel);
  FLabelInsp.Parent     := FRightPanel;
  FLabelInsp.Align      := alTop;
  FLabelInsp.Height     := 22;
  FLabelInsp.Caption    := '  Object Inspector';
  FLabelInsp.Font.Style := [fsBold];
  FLabelInsp.Font.Color := clWhite;

  FInspector                  := TStringGrid.Create(FRightPanel);
  FInspector.Parent           := FRightPanel;
  FInspector.Align            := alClient;
  FInspector.ColCount         := 2;
  FInspector.RowCount         := 2;
  FInspector.FixedRows        := 1;
  FInspector.FixedCols        := 0;
  FInspector.DefaultRowHeight := 20;
  FInspector.Options          := [goFixedHorzLine, goFixedVertLine,
                                  goHorzLine, goVertLine, goEditing,
                                  goAlwaysShowEditor];
  FInspector.Cells[0, 0] := 'Property';
  FInspector.Cells[1, 0] := 'Value';
  FInspector.ColWidths[0] := 100;
  FInspector.ColWidths[1] := 140;
  FInspector.Color        := clWindow;
  FInspector.Font.Color   := clBlack;
  FInspector.Font.Name    := 'Segoe UI';
  FInspector.Font.Size    := 9;
  FInspector.FixedColor   := clBtnFace;
  FInspector.OnSetEditText := OnInspectorSetEditText;

  FSplitterR := TSplitter.Create(FOuter);
  FSplitterR.Parent := FOuter;
  FSplitterR.Align  := alRight;
  FSplitterR.Width  := 4;

  // ── Centre: canvas with design surface ─────────────────────────────────
  FCanvasPanel             := TPanel.Create(FOuter);
  FCanvasPanel.Parent      := FOuter;
  FCanvasPanel.Align       := alClient;
  FCanvasPanel.BevelOuter  := bvNone;
  FCanvasPanel.Color       := DARKER;

  FCanvasInfo            := TLabel.Create(FCanvasPanel);
  FCanvasInfo.Parent     := FCanvasPanel;
  FCanvasInfo.Align      := alTop;
  FCanvasInfo.Height     := 20;
  FCanvasInfo.Caption    := '  Design surface — click on the form to select it, or click a control';
  FCanvasInfo.Font.Color := GREEN;

  // Design surface lives at a fixed position inside the canvas
  FDesignSurface             := TKeyAwarePanel.Create(FCanvasPanel);
  FDesignSurface.Parent      := FCanvasPanel;
  FDesignSurface.Left        := 20;
  FDesignSurface.Top         := 30;
  FDesignSurface.Width       := FFormDef.GetWidth;
  FDesignSurface.Height      := FFormDef.GetHeight;
  FDesignSurface.BevelOuter  := bvRaised;
  FDesignSurface.Color       := clBtnFace;
  FDesignSurface.Caption     := '';
  FDesignSurface.TabStop     := True;
  FDesignSurface.OnMouseDown := OnSurfaceMouseDown;
  FDesignSurface.OnMouseMove := OnSurfaceMouseMove;
  FDesignSurface.OnMouseUp   := OnSurfaceMouseUp;
  FDesignSurface.OnKeyDown   := OnSurfaceKeyDown;
end;

// ═══════════════════════════════════════════════════════════════════════════
//  STATUS / SELECTION / TOOL
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormBuilderTab.UpdateStatus;
var
  S    : string;
  Tool : string;
begin
  case FTool of
    ptPointer : Tool := 'Pointer';
    ptLabel   : Tool := 'Label  (click surface to place)';
    ptButton  : Tool := 'Button (click surface to place)';
    ptEdit    : Tool := 'Edit   (click surface to place)';
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
  UpdateStatus;
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
  // Trigger a redraw to update selection markers
  FDesignSurface.Invalidate;
  for var Ctrl in FCtrlMap.Keys do
    Ctrl.Invalidate;
  UpdateStatus;
end;

function TFormBuilderTab.KindInfoByName(const TypeName: string): TControlKindInfo;
var I : Integer;
begin
  for I := 0 to High(CONTROL_KINDS) do
    if SameText(CONTROL_KINDS[I].TypeName, TypeName) then
      Exit(CONTROL_KINDS[I]);
  // Default to Label if unknown
  Result := CONTROL_KINDS[0];
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

// ═══════════════════════════════════════════════════════════════════════════
//  REFRESH — rebuild VCL controls from model
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
  // Drop all currently mapped controls (they're parented to FDesignSurface)
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

  // Recreate from model
  for C in FFormDef.Controls do
  begin
    W := BuildVCLControlForDesign(FDesignSurface, C);
    if Assigned(W) then
      FCtrlMap.Add(W, C);
  end;
end;

// ---------------------------------------------------------------------------
//  Factory: build a VCL control for the DESIGN surface
//
//  At design time everything is rendered as a TPanel (so we can handle
//  mouse events uniformly even for TLabel which doesn't accept them).
//  The panel mimics the look of the real control via Caption + style.
// ---------------------------------------------------------------------------
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

  // Style differs per control type so it looks like the real thing
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

// ---------------------------------------------------------------------------
//  Factory: build a VCL control for the RUNTIME form
//
//  Used by RunFormDef to produce a real, live TForm at run time.
// ---------------------------------------------------------------------------
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
    // Phase 2 hook: this is where we'd assign B.OnClick to call the
    // interpreter routine whose name is stored in CD.GetOnClick.
    // For Phase 1, the button is inert (no handler attached).
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
      // Build a stable ordered key list — common props first, then the rest
      if ExtraNameRow then
      begin
        Keys.Add('Name');
        Keys.Add('Type');
      end
      else
        Keys.Add('Name');     // form name

      // Well-known properties in order
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

      // Append any other props in the bag that aren't already listed
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
    // Form itself
    ShowProps('Form', FFormDef.PropList, False, FFormDef.Name, '');
  end;
end;

// ---------------------------------------------------------------------------
//  Inspector edit committed
// ---------------------------------------------------------------------------
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

  // Are we editing the form, or a selected control?
  if FSelection.Count = 1 then
  begin
    C := FSelection[0];

    if SameText(Key, 'Type') then
    begin
      // Don't allow type changes via inspector — too disruptive
      RefreshInspector;
      Exit;
    end;

    if SameText(Key, 'Name') then
    begin
      NewName := Trim(Value);
      if NewName = C.Name then Exit;
      if not IsValidIdentifier(NewName) then
      begin
        ShowMessage('Name must be a valid identifier (letters, digits, underscore; no leading digit).');
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
      // Empty is allowed (no handler). Non-empty must be a valid identifier
      // because Phase 2 will look this up in the interpreter's routine table.
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
    SelectControl(FFormDef.FindControl(C.Name));   // re-select after rebuild
  end
  else
  begin
    // Form-level edits
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
//  FILE LIST (left pane)
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
  if Pos('(', S) = 1 then Exit;       // placeholder line
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

procedure TFormBuilderTab.OnPaletteClick(Sender: TObject);
begin
  SetTool(TPaletteTool((Sender as TButton).Tag));
end;

// ═══════════════════════════════════════════════════════════════════════════
//  PUBLIC FILE OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════

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
    // Place a new control here
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

  // Pointer mode + click on bare surface = select the form
  SelectControl(nil);
end;

procedure TFormBuilderTab.OnSurfaceMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
  // (Phase 2: marquee selection, hover hints)
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
    VK_LEFT :
      begin
        C.SetLeft(C.GetLeft - 1);
        Key := 0;
      end;
    VK_RIGHT :
      begin
        C.SetLeft(C.GetLeft + 1);
        Key := 0;
      end;
    VK_UP :
      begin
        C.SetTop(C.GetTop - 1);
        Key := 0;
      end;
    VK_DOWN :
      begin
        C.SetTop(C.GetTop + 1);
        Key := 0;
      end;
  else
    Exit;
  end;

  // Move the corresponding VCL control without rebuilding (smoother)
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

// ---------------------------------------------------------------------------
//  Click on a placed control
// ---------------------------------------------------------------------------
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
//
//  Build a real TForm from the def and show it modally. Buttons are inert,
//  Edits are editable, Labels are read-only. The form has a working close
//  button so the user can dismiss it.
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

// ═══════════════════════════════════════════════════════════════════════════
//  Stub: selection markers placeholder (Phase 2 implementation point)
// ═══════════════════════════════════════════════════════════════════════════

function TFormBuilderTab.AddSelectionMarkers(Ctrl: TWinControl): Boolean;
begin
  // Phase 2: draw resize handles around the selected control.
  // For Phase 1 we just rely on the inspector to show which one is selected.
  Result := False;
end;

end.
