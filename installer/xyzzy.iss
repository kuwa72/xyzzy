; xyzzy Inno Setup installer
; Usage: iscc /DAppVersion=0.2.6.3 /DAppArch=amd64 /DSourceDir=path\to\files xyzzy.iss

#ifndef AppVersion
  #define AppVersion "0.0.0.0"
#endif
#ifndef AppArch
  #define AppArch "amd64"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\install"
#endif

[Setup]
AppName=xyzzy
AppVersion={#AppVersion}
AppPublisher=xyzzy contributors
AppPublisherURL=https://github.com/snmsts/xyzzy
DefaultDirName={autopf}\xyzzy
DefaultGroupName=xyzzy
OutputBaseFilename=xyzzy-{#AppVersion}-{#AppArch}-setup
OutputDir=..\build
Compression=lzma2
SolidCompression=yes
#if AppArch == "arm64"
ArchitecturesAllowed=arm64 x64compatible
ArchitecturesInstallIn64BitMode=arm64 x64compatible
#elif AppArch == "amd64"
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
PrivilegesRequired=lowest
LicenseFile={#SourceDir}\docs\LICENSE
WizardStyle=modern
UninstallDisplayIcon={app}\xyzzy.exe
ChangesEnvironment=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "addtopath"; Description: "Add xyzzy to PATH"; GroupDescription: "Environment:"; Flags: unchecked
Name: "shellcontext"; Description: "Add ""Open with xyzzy"" to context menu"; GroupDescription: "Shell integration:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\xyzzy.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\xyzzycli.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\xyzzyenv.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\Browser.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\TreeView.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\etc\*"; DestDir: "{app}\etc"; Flags: ignoreversion recursesubdirs
Source: "{#SourceDir}\lisp\*"; DestDir: "{app}\lisp"; Flags: ignoreversion recursesubdirs
Source: "{#SourceDir}\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\xyzzy"; Filename: "{app}\xyzzy.exe"
Name: "{group}\{cm:UninstallProgram,xyzzy}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\xyzzy"; Filename: "{app}\xyzzy.exe"; Tasks: desktopicon

[Registry]
; "Open with xyzzy" context menu for all files
Root: HKCU; Subkey: "Software\Classes\*\shell\xyzzy"; ValueType: string; ValueName: ""; ValueData: "Open with xyzzy"; Tasks: shellcontext; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\*\shell\xyzzy"; ValueType: string; ValueName: "Icon"; ValueData: """{app}\xyzzy.exe"""; Tasks: shellcontext
Root: HKCU; Subkey: "Software\Classes\*\shell\xyzzy\command"; ValueType: string; ValueName: ""; ValueData: """{app}\xyzzycli.exe"" ""%1"""; Tasks: shellcontext

[UninstallDelete]
; Remove runtime-generated files
Type: files; Name: "{app}\xyzzy.wxp"
Type: files; Name: "{app}\xyzzy.BUG"

[Code]
// PATH management
const
  EnvironmentKey = 'Environment';

procedure AddToPath(Dir: String);
var
  Path: String;
begin
  if not RegQueryStringValue(HKCU, EnvironmentKey, 'Path', Path) then
    Path := '';
  if Pos(Uppercase(Dir), Uppercase(Path)) = 0 then
  begin
    if Path <> '' then
      Path := Path + ';';
    Path := Path + Dir;
    RegWriteStringValue(HKCU, EnvironmentKey, 'Path', Path);
  end;
end;

procedure RemoveFromPath(Dir: String);
var
  Path, UpperDir: String;
  P: Integer;
begin
  if not RegQueryStringValue(HKCU, EnvironmentKey, 'Path', Path) then
    exit;
  UpperDir := Uppercase(Dir);
  P := Pos(UpperDir, Uppercase(Path));
  if P > 0 then
  begin
    Delete(Path, P, Length(Dir));
    if (P <= Length(Path)) and (Path[P] = ';') then
      Delete(Path, P, 1)
    else if (P > 1) and (Path[P - 1] = ';') then
      Delete(Path, P - 1, 1);
    RegWriteStringValue(HKCU, EnvironmentKey, 'Path', Path);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if WizardIsTaskSelected('addtopath') then
      AddToPath(ExpandConstant('{app}'));
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    RemoveFromPath(ExpandConstant('{app}'));
end;
