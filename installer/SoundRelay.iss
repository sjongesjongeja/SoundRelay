; Script generated for Inno Setup 6
#define MyAppName "SoundRelay"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "SoundRelay Open Source"
#define MyAppURL "https://github.com/sjongesjongeja/SoundRelay"
#define MyAppExeName "SoundRelay.exe"

[Setup]
AppId={{E14D4C53-81D2-4E2F-A2F7-3B27EA902384}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=F:\audiorelay\bin
OutputBaseFilename=SoundRelay-Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "dutch"; MessagesFile: "compiler:Languages\Dutch.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "F:\audiorelay\dist\SoundRelay\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "F:\audiorelay\bin\SoundRelay.apk"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "F:\audiorelay\server\usb_stream.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autoprograms}\SoundRelay USB Modus"; Filename: "{app}\usb_stream.bat"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
