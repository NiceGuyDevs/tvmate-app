#define MyAppVersion GetDateTimeString('yyyy.mm.dd_HH.nn', '', '')

[Setup]
AppName=TvMatePro
AppVersion={#MyAppVersion}
DefaultDirName={pf}\TvMatePro
DefaultGroupName=TvMatePro
OutputDir=.
OutputBaseFilename=TvMatePro_{#MyAppVersion}
Compression=lzma
SolidCompression=yes
SetupIconFile=icon.ico
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\TvMatePro"; Filename: "{app}\tvmatepro.exe"
Name: "{commondesktop}\TvMatePro"; Filename: "{app}\tvmatepro.exe"

[Run]
Filename: "{app}\tvmatepro.exe"; Description: "Launch TvMatePro"; Flags: nowait postinstall skipifsilent