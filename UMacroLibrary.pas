unit UMacroLibrary;

// =============================================================================
// MiniDelphi Toy Compiler & Learning IDE
// Copyright (C) 2026 Nomidor Software, LLC.
// GPL v3 — see https://www.gnu.org/licenses/gpl-3.0.html
// =============================================================================

// =============================================================================
//  UMacroLibrary.pas  -  Curated starter library of office automation macros.
//
//  Each macro is a self-contained .mdp file with metadata in a header
//  comment block:
//
//      // @name        Human-readable macro name
//      // @description One-line summary shown in the macro list
//      // @category    Group it shows under
//
//  On first launch the Macro tab checks the user's macro folder and
//  seeds it with these starter macros if the folder is empty.
//  The user can then edit, delete, or extend them freely.
// =============================================================================

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections;

type
  TStarterMacro = record
    FileName : string;   // file name to save as (e.g. 'DailyBackup.mdp')
    Source   : string;   // the full macro source code
  end;

// Returns the curated list of starter macros to seed
function GetStarterMacros : TArray<TStarterMacro>;

// Seeds a folder with the starter macros (skipping any that already exist)
// Returns number of files written.
function SeedMacroFolder(const Folder: string) : Integer;

implementation

function MakeStarter(const FN, Src: string): TStarterMacro;
begin
  Result.FileName := FN;
  Result.Source   := Src;
end;

function GetStarterMacros : TArray<TStarterMacro>;
var
  L : TList<TStarterMacro>;
begin
  L := TList<TStarterMacro>.Create;
  try
    // ─────────────────────────────────────────────────────────────────────
    //  BACKUP & FILE MANAGEMENT
    // ─────────────────────────────────────────────────────────────────────

    L.Add(MakeStarter('DailyBackup.mdp',
      '// @name        Daily Documents Backup' + #13#10 +
      '// @description Mirrors your Documents folder to a backup drive' + #13#10 +
      '// @category    Backup' + #13#10 +
      '' + #13#10 +
      '// ============================================================' + #13#10 +
      '// DAILY DOCUMENTS BACKUP' + #13#10 +
      '//' + #13#10 +
      '// Uses Windows robocopy to mirror your Documents folder to a' + #13#10 +
      '// backup destination. /MIR makes the destination match exactly' + #13#10 +
      '// (files removed from source are removed from backup).' + #13#10 +
      '// ============================================================' + #13#10 +
      '' + #13#10 +
      'var' + #13#10 +
      '  src, dst : String;' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  src := GetEnvVar(''USERPROFILE'') + ''\Documents'';' + #13#10 +
      '  dst := ''D:\Backup\Documents'';' + #13#10 +
      '' + #13#10 +
      '  if not Confirm(''Backup '' + src + '' to '' + dst + ''?'') then' + #13#10 +
      '    exit;' + #13#10 +
      '' + #13#10 +
      '  writeln(''Starting backup...'');' + #13#10 +
      '  ShellWait(''robocopy "'' + src + ''" "'' + dst + ''" /MIR /R:1 /W:1'');' + #13#10 +
      '  writeln(''Backup complete.'');' + #13#10 +
      '  ShowInfoBox(''Backup finished.'' + Chr(13) +' + #13#10 +
      '              ''Source: '' + src + Chr(13) +' + #13#10 +
      '              ''Destination: '' + dst);' + #13#10 +
      'end.'));

    L.Add(MakeStarter('ArchiveOldFiles.mdp',
      '// @name        Archive Old Files' + #13#10 +
      '// @description Moves files older than N days into an Archive folder' + #13#10 +
      '// @category    Backup' + #13#10 +
      '' + #13#10 +
      '// ============================================================' + #13#10 +
      '// ARCHIVE OLD FILES' + #13#10 +
      '//' + #13#10 +
      '// Picks a source folder, then moves any file older than the' + #13#10 +
      '// chosen number of days into a sibling Archive folder.' + #13#10 +
      '// Uses robocopy /MOV /MINAGE for the heavy lifting.' + #13#10 +
      '// ============================================================' + #13#10 +
      '' + #13#10 +
      'var' + #13#10 +
      '  src, archive, days : String;' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  src := SelectDirectoryDialog;' + #13#10 +
      '  if src = '''' then exit;' + #13#10 +
      '' + #13#10 +
      '  days := InputBox(''Move files older than how many days?'',' + #13#10 +
      '                   ''Archive'', ''90'');' + #13#10 +
      '  if days = '''' then exit;' + #13#10 +
      '' + #13#10 +
      '  archive := src + ''\Archive'';' + #13#10 +
      '  writeln(''Archiving files older than '', days, '' days...'');' + #13#10 +
      '  writeln(''From: '', src);' + #13#10 +
      '  writeln(''To  : '', archive);' + #13#10 +
      '' + #13#10 +
      '  ShellWait(''robocopy "'' + src + ''" "'' + archive +' + #13#10 +
      '            ''" /MOV /MINAGE:'' + days + '' /R:0'');' + #13#10 +
      '' + #13#10 +
      '  ShowInfoBox(''Archive complete. Old files moved to:'' +' + #13#10 +
      '              Chr(13) + archive);' + #13#10 +
      'end.'));

    L.Add(MakeStarter('CleanDownloads.mdp',
      '// @name        Clean Downloads Folder' + #13#10 +
      '// @description Deletes Downloads files older than N days (with preview)' + #13#10 +
      '// @category    Backup' + #13#10 +
      '' + #13#10 +
      '// ============================================================' + #13#10 +
      '// CLEAN DOWNLOADS FOLDER' + #13#10 +
      '//' + #13#10 +
      '// Lists files in the Downloads folder older than N days, then' + #13#10 +
      '// asks for confirmation before deleting them.' + #13#10 +
      '// ============================================================' + #13#10 +
      '' + #13#10 +
      'var' + #13#10 +
      '  dl, days : String;' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  dl   := GetEnvVar(''USERPROFILE'') + ''\Downloads'';' + #13#10 +
      '  days := InputBox(''Delete Downloads files older than how many days?'',' + #13#10 +
      '                   ''Cleanup'', ''30'');' + #13#10 +
      '  if days = '''' then exit;' + #13#10 +
      '' + #13#10 +
      '  writeln(''Files that would be removed:'');' + #13#10 +
      '  ShellWait(''forfiles /P "'' + dl + ''" /D -'' + days +' + #13#10 +
      '            '' /C "cmd /c echo @path"'');' + #13#10 +
      '' + #13#10 +
      '  if Confirm(''Proceed with deletion?'') then' + #13#10 +
      '  begin' + #13#10 +
      '    ShellWait(''forfiles /P "'' + dl + ''" /D -'' + days +' + #13#10 +
      '              '' /C "cmd /c del @path"'');' + #13#10 +
      '    ShowInfoBox(''Old downloads cleaned.'');' + #13#10 +
      '  end' + #13#10 +
      '  else' + #13#10 +
      '    writeln(''Cancelled — nothing was deleted.'');' + #13#10 +
      'end.'));

    // ─────────────────────────────────────────────────────────────────────
    //  EMAIL & COMMUNICATION
    // ─────────────────────────────────────────────────────────────────────

    L.Add(MakeStarter('EmailDailyReport.mdp',
      '// @name        Email Daily Report' + #13#10 +
      '// @description Opens your mail client with a pre-filled daily status email' + #13#10 +
      '// @category    Email' + #13#10 +
      '' + #13#10 +
      '// ============================================================' + #13#10 +
      '// EMAIL DAILY REPORT' + #13#10 +
      '//' + #13#10 +
      '// Builds a mailto: URL with To/Subject/Body filled in, then' + #13#10 +
      '// hands off to the default mail client. The user reviews and' + #13#10 +
      '// hits Send themselves — no silent sending.' + #13#10 +
      '// ============================================================' + #13#10 +
      '' + #13#10 +
      'var' + #13#10 +
      '  recipient, subject, body, url : String;' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  recipient := ''boss@example.com'';' + #13#10 +
      '  subject   := ''Daily Status — '' + DateStr;' + #13#10 +
      '' + #13#10 +
      '  body := ''Hi,'' + Chr(13) + Chr(13) +' + #13#10 +
      '          ''Quick status for '' + DateStr + '':'' + Chr(13) + Chr(13) +' + #13#10 +
      '          ''  • '' + Chr(13) +' + #13#10 +
      '          ''  • '' + Chr(13) +' + #13#10 +
      '          ''  • '' + Chr(13) + Chr(13) +' + #13#10 +
      '          ''Thanks,'' + Chr(13);' + #13#10 +
      '' + #13#10 +
      '  // mailto: URL encoding — replace newlines with %0A, spaces with %20' + #13#10 +
      '  body := UrlEncode(body);' + #13#10 +
      '  subject := UrlEncode(subject);' + #13#10 +
      '' + #13#10 +
      '  url := ''mailto:'' + recipient +' + #13#10 +
      '         ''?subject='' + subject +' + #13#10 +
      '         ''&body='' + body;' + #13#10 +
      '' + #13#10 +
      '  Shell(url);' + #13#10 +
      '  writeln(''Mail client opened with daily report draft.'');' + #13#10 +
      'end.'));

    L.Add(MakeStarter('EmailFile.mdp',
      '// @name        Email a File' + #13#10 +
      '// @description Pick a file and open a draft email with it noted in the body' + #13#10 +
      '// @category    Email' + #13#10 +
      '' + #13#10 +
      '// ============================================================' + #13#10 +
      '// EMAIL A FILE' + #13#10 +
      '//' + #13#10 +
      '// Note: mailto: cannot attach files directly (security). This' + #13#10 +
      '// macro opens a draft with the filename in the body so you can' + #13#10 +
      '// drag-and-drop or attach it manually before sending.' + #13#10 +
      '// ============================================================' + #13#10 +
      '' + #13#10 +
      'var' + #13#10 +
      '  fname, recipient, subject, body, url : String;' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  fname := OpenFileDialog(''All Files|*.*'');' + #13#10 +
      '  if fname = '''' then exit;' + #13#10 +
      '' + #13#10 +
      '  recipient := InputBox(''Recipient email:'', ''Email'', '''');' + #13#10 +
      '  if recipient = '''' then exit;' + #13#10 +
      '' + #13#10 +
      '  subject := ''File: '' + ExtractFileName(fname);' + #13#10 +
      '  body    := ''Please find attached:'' + Chr(13) + Chr(13) +' + #13#10 +
      '             fname + Chr(13) + Chr(13) +' + #13#10 +
      '             ''(Attach the file before sending.)'';' + #13#10 +
      '' + #13#10 +
      '  url := ''mailto:'' + recipient +' + #13#10 +
      '         ''?subject='' + UrlEncode(subject) +' + #13#10 +
      '         ''&body='' + UrlEncode(body);' + #13#10 +
      '' + #13#10 +
      '  Shell(url);' + #13#10 +
      '  writeln(''Draft opened. File path is in the body — attach and send.'');' + #13#10 +
      'end.'));

    // ─────────────────────────────────────────────────────────────────────
    //  PRODUCTIVITY
    // ─────────────────────────────────────────────────────────────────────

    L.Add(MakeStarter('MorningRoutine.mdp',
      '// @name        Morning Routine' + #13#10 +
      '// @description Opens your usual morning apps and websites all at once' + #13#10 +
      '// @category    Productivity' + #13#10 +
      '' + #13#10 +
      '// ============================================================' + #13#10 +
      '// MORNING ROUTINE' + #13#10 +
      '//' + #13#10 +
      '// One-click startup: mail, calendar, news, todo list. Customise' + #13#10 +
      '// the URLs and app paths below to match your own workflow.' + #13#10 +
      '// ============================================================' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  writeln(''Good morning! Opening your routine...'');' + #13#10 +
      '' + #13#10 +
      '  // Open websites in default browser' + #13#10 +
      '  Shell(''https://mail.google.com'');' + #13#10 +
      '  Sleep(500);' + #13#10 +
      '' + #13#10 +
      '  Shell(''https://calendar.google.com'');' + #13#10 +
      '  Sleep(500);' + #13#10 +
      '' + #13#10 +
      '  Shell(''https://news.ycombinator.com'');' + #13#10 +
      '  Sleep(500);' + #13#10 +
      '' + #13#10 +
      '  // Launch local apps (uncomment and edit paths as needed)' + #13#10 +
      '  // Shell(''C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE'');' + #13#10 +
      '  // Shell(''C:\Program Files\Slack\slack.exe'');' + #13#10 +
      '' + #13#10 +
      '  writeln(''All set. Have a good day!'');' + #13#10 +
      'end.'));

    L.Add(MakeStarter('TimedBreakReminder.mdp',
      '// @name        Timed Break Reminder' + #13#10 +
      '// @description Pops a reminder every N minutes for the next M hours' + #13#10 +
      '// @category    Productivity' + #13#10 +
      '' + #13#10 +
      '// ============================================================' + #13#10 +
      '// TIMED BREAK REMINDER' + #13#10 +
      '//' + #13#10 +
      '// Sits in the background showing a popup every N minutes.' + #13#10 +
      '// Click Stop on the Macros toolbar to end it early.' + #13#10 +
      '// ============================================================' + #13#10 +
      '' + #13#10 +
      'var' + #13#10 +
      '  minutes, hours, count, total : Integer;' + #13#10 +
      '  mStr, hStr : String;' + #13#10 +
      '  i : Integer;' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  mStr := InputBox(''Remind me every how many minutes?'',' + #13#10 +
      '                   ''Break Reminder'', ''60'');' + #13#10 +
      '  hStr := InputBox(''For how many hours?'',' + #13#10 +
      '                   ''Break Reminder'', ''8'');' + #13#10 +
      '' + #13#10 +
      '  minutes := StrToInt(mStr);' + #13#10 +
      '  hours   := StrToInt(hStr);' + #13#10 +
      '  total   := (hours * 60) div minutes;' + #13#10 +
      '' + #13#10 +
      '  writeln(''Running '', total, '' reminders, '', minutes, '' min apart.'');' + #13#10 +
      '' + #13#10 +
      '  for i := 1 to total do' + #13#10 +
      '  begin' + #13#10 +
      '    Sleep(minutes * 60 * 1000);' + #13#10 +
      '    ShowInfoBox(''Time for a break! ('' + IntToStr(i) +' + #13#10 +
      '                '' of '' + IntToStr(total) + '')'');' + #13#10 +
      '  end;' + #13#10 +
      '' + #13#10 +
      '  ShowInfoBox(''Done. Good work today!'');' + #13#10 +
      'end.'));

    // ─────────────────────────────────────────────────────────────────────
    //  SYSTEM
    // ─────────────────────────────────────────────────────────────────────

    L.Add(MakeStarter('LockComputer.mdp',
      '// @name        Lock Computer' + #13#10 +
      '// @description Locks the workstation immediately' + #13#10 +
      '// @category    System' + #13#10 +
      '' + #13#10 +
      '// ============================================================' + #13#10 +
      '// LOCK COMPUTER' + #13#10 +
      '//' + #13#10 +
      '// Equivalent to Win+L. Useful as a hotkey target via Windows' + #13#10 +
      '// shortcut: create a shortcut to MiniDelphi.exe with' + #13#10 +
      '//    "--run-macro LockComputer"' + #13#10 +
      '// then assign a hotkey to that shortcut.' + #13#10 +
      '// ============================================================' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  Shell(''rundll32.exe user32.dll,LockWorkStation'');' + #13#10 +
      'end.'));

    L.Add(MakeStarter('OpenTaskManager.mdp',
      '// @name        Open Task Manager' + #13#10 +
      '// @description Launches Windows Task Manager' + #13#10 +
      '// @category    System' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  Shell(''taskmgr.exe'');' + #13#10 +
      'end.'));

    L.Add(MakeStarter('ShowDiskSpace.mdp',
      '// @name        Show Disk Space' + #13#10 +
      '// @description Reports free / total space on all drives' + #13#10 +
      '// @category    System' + #13#10 +
      '' + #13#10 +
      '// ============================================================' + #13#10 +
      '// SHOW DISK SPACE' + #13#10 +
      '//' + #13#10 +
      '// Shells out to wmic for a quick disk space summary.' + #13#10 +
      '// ============================================================' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  writeln(''Disk space summary:'');' + #13#10 +
      '  writeln('''');' + #13#10 +
      '  ShellWait(''wmic logicaldisk get DeviceID,Size,FreeSpace'');' + #13#10 +
      'end.'));

    // ─────────────────────────────────────────────────────────────────────
    //  REPORTS & FILES
    // ─────────────────────────────────────────────────────────────────────

    L.Add(MakeStarter('FolderInventory.mdp',
      '// @name        Folder Inventory Report' + #13#10 +
      '// @description Lists every file in a folder tree into a text report' + #13#10 +
      '// @category    Reports' + #13#10 +
      '' + #13#10 +
      '// ============================================================' + #13#10 +
      '// FOLDER INVENTORY REPORT' + #13#10 +
      '//' + #13#10 +
      '// Pick a folder, get a tree listing saved to your Desktop as' + #13#10 +
      '// Inventory_<date>.txt. Uses Windows dir /s under the hood.' + #13#10 +
      '// ============================================================' + #13#10 +
      '' + #13#10 +
      'var' + #13#10 +
      '  folder, report : String;' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  folder := SelectDirectoryDialog;' + #13#10 +
      '  if folder = '''' then exit;' + #13#10 +
      '' + #13#10 +
      '  report := GetDesktopPath + ''\Inventory_'' + DateStr + ''.txt'';' + #13#10 +
      '  writeln(''Generating inventory of: '', folder);' + #13#10 +
      '  writeln(''Saving to: '', report);' + #13#10 +
      '' + #13#10 +
      '  ShellWait(''cmd /c dir "'' + folder + ''" /s /b > "'' + report + ''"'');' + #13#10 +
      '' + #13#10 +
      '  if FileExists(report) then' + #13#10 +
      '  begin' + #13#10 +
      '    ShowInfoBox(''Report saved to:'' + Chr(13) + report);' + #13#10 +
      '    Shell(''notepad.exe "'' + report + ''"'');' + #13#10 +
      '  end' + #13#10 +
      '  else' + #13#10 +
      '    ShowErrorBox(''Report could not be created.'');' + #13#10 +
      'end.'));

    L.Add(MakeStarter('OpenLastDownload.mdp',
      '// @name        Open Last Download' + #13#10 +
      '// @description Opens the most recently downloaded file' + #13#10 +
      '// @category    Productivity' + #13#10 +
      '' + #13#10 +
      'var' + #13#10 +
      '  dl, latest : String;' + #13#10 +
      '' + #13#10 +
      'begin' + #13#10 +
      '  dl := GetEnvVar(''USERPROFILE'') + ''\Downloads'';' + #13#10 +
      '  // Ask Windows to list files in date order, take the first one' + #13#10 +
      '  ShellWait(''cmd /c for /f "delims=" %f in (''''dir "'' + dl +' + #13#10 +
      '            ''" /b /o-d /a-d'''') do @echo %f & goto :end > "%TEMP%\last.txt"'');' + #13#10 +
      '  latest := Trim(ReadFile(GetEnvVar(''TEMP'') + ''\last.txt''));' + #13#10 +
      '' + #13#10 +
      '  if latest <> '''' then' + #13#10 +
      '  begin' + #13#10 +
      '    writeln(''Opening: '', latest);' + #13#10 +
      '    Shell(dl + ''\'' + latest);' + #13#10 +
      '  end' + #13#10 +
      '  else' + #13#10 +
      '    ShowWarningBox(''No recent downloads found.'');' + #13#10 +
      'end.'));

    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

function SeedMacroFolder(const Folder: string): Integer;
var
  Starters : TArray<TStarterMacro>;
  M        : TStarterMacro;
  Path     : string;
begin
  Result := 0;
  if not TDirectory.Exists(Folder) then
    TDirectory.CreateDirectory(Folder);

  Starters := GetStarterMacros;
  for M in Starters do
  begin
    Path := TPath.Combine(Folder, M.FileName);
    if not TFile.Exists(Path) then
    begin
      TFile.WriteAllText(Path, M.Source, TEncoding.UTF8);
      Inc(Result);
    end;
  end;
end;

end.
