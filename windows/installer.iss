[Setup]
AppName=TVMate Pro
AppVersion=1.0.2
AppPublisher=TVMate
AppPublisherURL=https://tvmate.app
DefaultDirName={autopf}\TVMate Pro
DefaultGroupName=TVMate Pro
OutputDir=..\..\build-output\desktop
OutputBaseFilename=TVMate-Pro-Setup
Compression=lzma2/ultra64
SolidCompression=yes
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\tvmatepro.exe,0
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs
Source: "..\..\tvmateproappicon.ico"; DestDir: "{app}"; DestName: "tvmatepro.ico"; Flags: ignoreversion

[Icons]
Name: "{group}\TVMate Pro"; Filename: "{app}\tvmatepro.exe"; IconFilename: "{app}\tvmatepro.ico"
Name: "{autodesktop}\TVMate Pro"; Filename: "{app}\tvmatepro.exe"; IconFilename: "{app}\tvmatepro.ico"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"
Name: "startup"; Description: "Run TVMate Pro when Windows starts"; GroupDescription: "System:"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "TVMatePro"; ValueData: """{app}\tvmatepro.exe"""; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{app}\tvmatepro.exe"; Description: "Launch TVMate Pro"; Flags: nowait postinstall skipifsilent
