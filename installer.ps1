function Test-DeaduniebiAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-DeaduniebiScript {
    param([string]$Path, [switch]$AsAdmin)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return $false }
    $escapedPath = $Path.Replace('"', '\"')
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = 'powershell.exe'
    $start.Arguments = '-NoProfile -STA -ExecutionPolicy Bypass -File "' + $escapedPath + '"'
    $start.UseShellExecute = $true
    if ($AsAdmin) { $start.Verb = 'runas' }
    try {
        [System.Diagnostics.Process]::Start($start) | Out-Null
        return $true
    }
    catch { return $false }
}

$script:EntryPath = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { $null }
$script:StartupWarnings = New-Object System.Collections.Generic.List[string]

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    if (Restart-DeaduniebiScript -Path $script:EntryPath) { exit }
    Write-Error 'Deaduniebi Screen Share must run in STA mode. Start it with: powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\installer.ps1'
    exit 1
}

if (-not (Test-DeaduniebiAdministrator)) {
    if ($script:EntryPath -and (Restart-DeaduniebiScript -Path $script:EntryPath -AsAdmin)) { exit }
    $script:StartupWarnings.Add('Deaduniebi Screen Share is not running as administrator. Some tools may require admin permissions.') | Out-Null
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$AppName = 'Deaduniebi Screen Share'
$AppVersion = '1.0'

$ScriptRoot = if ($script:EntryPath) { Split-Path -Parent $script:EntryPath } else { $null }
$LocalAppDataRoot = if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { [System.IO.Path]::GetTempPath() } else { $env:LOCALAPPDATA }
$AppBaseRoot = if ($ScriptRoot -and -not $ScriptRoot.StartsWith([System.IO.Path]::GetTempPath().TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) { $ScriptRoot } else { Join-Path $LocalAppDataRoot 'Deaduniebi Screen Share' }
$AppRoot = Join-Path $AppBaseRoot 'deaduniebitools'
$ToolsRoot = $AppRoot
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'Deaduniebi Screen Share'

foreach ($dir in @($AppRoot, $ToolsRoot, $TempRoot)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

$ButtonStyleXaml = @'
<Style x:Key="FlatButtonStyle" TargetType="Button">
    <Setter Property="Foreground" Value="#EDEDED"/>
    <Setter Property="Background" Value="#1A1A1A"/>
    <Setter Property="BorderBrush" Value="#333333"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="FontSize" Value="12.5"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Padding" Value="14,0"/>
    <Setter Property="Template">
        <Setter.Value>
            <ControlTemplate TargetType="Button">
                <Border x:Name="Root" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="3" Padding="{TemplateBinding Padding}">
                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True">
                        <Setter TargetName="Root" Property="BorderBrush" Value="#FFFFFF"/>
                    </Trigger>
                    <Trigger Property="IsPressed" Value="True">
                        <Setter TargetName="Root" Property="Opacity" Value="0.7"/>
                    </Trigger>
                    <Trigger Property="IsEnabled" Value="False">
                        <Setter TargetName="Root" Property="Opacity" Value="0.4"/>
                    </Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate>
        </Setter.Value>
    </Setter>
</Style>
'@

$Categories = @(
    [ordered]@{ Key = 'orbdiff'; Label = 'OrbDiff'; Header = 'Tools developed by OrbDiff - github.com/orbdiff'; Description = 'Prefetch, BAM, USN, memory, process, USB, and string forensic tools.' },
    [ordered]@{ Key = 'spokwn'; Label = 'Spokwn'; Header = 'Tools developed by Spokwn - github.com/spokwn'; Description = 'BAM, journal, activities cache, services, process, and path parsers.' },
    [ordered]@{ Key = 'tonynoh'; Label = 'Tonynoh'; Header = 'Tools developed by Tonynoh - github.com/meowtonynoh'; Description = 'Meow resolver, Doomsday finder, client scanner, and import checker.' },
    [ordered]@{ Key = 'praiselily'; Label = 'PraiseLily'; Header = 'Tools developed by PraiseLily - github.com/praiselily'; Description = 'PowerShell hunting and alt detection tools.' },
    [ordered]@{ Key = 'redlotus'; Label = 'RedLotus'; Header = 'RedLotus tools by ItzIceHere and RedLotus contributors'; Description = 'Mod analysis, scheduled-task monitoring, and alternate-account checking tools.' },
    [ordered]@{ Key = 'detectac'; Label = 'DetectAC'; Header = 'Tools developed by DetectAC - detect.ac'; Description = 'Detect.ac Free Tools for Windows forensic review and artifact analysis.' },
    [ordered]@{ Key = 'scripts'; Label = 'Scripts'; Header = 'Useful PowerShell scripts for forensic analysis'; Description = 'Script actions launched in a visible console window.' },
    [ordered]@{ Key = 'nirsoft'; Label = 'NirSoft'; Header = 'NirSoft utilities - nirsoft.net'; Description = 'Portable Windows event, USB, registry, shellbag, jump list, and prefetch utilities.' },
    [ordered]@{ Key = 'ericzimmerman'; Label = 'EricZimmerman'; Header = 'Eric Zimmerman''s forensic tools - ericzimmerman.github.io'; Description = 'Amcache, event log, jump list, registry, shellbag, SRUM, MFT, and timeline tools.' },
    [ordered]@{ Key = 'others'; Label = 'Others'; Header = 'Various forensic tools from the community'; Description = 'Community tools, decompilers, hex editors, file search, Java scanners, and supporting analyzers.' },
    [ordered]@{ Key = 'dependencies'; Label = 'Dependencies'; Header = 'Required runtimes and dependencies'; Description = '.NET runtimes and Visual C++ Redistributable installers used by external tools.' },
    [ordered]@{ Key = 'credits'; Label = 'Credits'; Header = 'Authors of the tools and scripts used by this launcher'; Description = 'Every external tool keeps its original credit.' }
)

$DownloadTools = @(
    [ordered]@{ Name = 'Prefetch View++'; Description = 'Parses prefetch extracting file info'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/PrefetchView/releases/download/v1.6.7/pv++.exe') },
    [ordered]@{ Name = 'BAM Reveal'; Description = 'Parses BAM forensic artefact'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/BAMReveal/releases/latest/download/BAMReveal.exe') },
    [ordered]@{ Name = 'Amcache Parser'; Description = 'Parses AMCache with YARA + signatures'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/AmcacheParser/releases/latest/download/AmcacheParser.exe') },
    [ordered]@{ Name = 'Journal Parser'; Description = 'Parses NTFS USNJournal entries'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/JournalParser/releases/latest/download/JournalParser.exe') },
    [ordered]@{ Name = 'Check Deleted USN'; Description = 'Compares USN timestamp vs boot time'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/CheckDeletedUSN/releases/latest/download/CheckDeletedUSN.exe') },
    [ordered]@{ Name = 'Fileless'; Description = 'Detect fileless via eventlog + memdump'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/Fileless/releases/latest/download/fileless.exe') },
    [ordered]@{ Name = 'JAR Parser'; Description = 'Parses JAR prefetch, DcomLaunch strings, etc'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/JARParser/releases/latest/download/JARParser.exe') },
    [ordered]@{ Name = 'PF Trace'; Description = 'Rundll32/Regsvr32 prefetch analysis'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/PFTrace/releases/latest/download/PFTrace.exe') },
    [ordered]@{ Name = 'InjGen'; Description = 'Detects JNI/JVMTI memory injections'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/InjGen/releases/latest/download/InjGen.exe') },
    [ordered]@{ Name = 'DPS Analyzer'; Description = 'Analyzes DPS memory'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/DPS-Analyzer/releases/latest/download/dpsanalyzer.exe') },
    [ordered]@{ Name = 'USB Detector'; Description = 'Detects USB device history'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/USBDetector/releases/latest/download/USBDetector.exe') },
    [ordered]@{ Name = 'User Assist View'; Description = 'Parser UserAssist artifact'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/UserAssistView/releases/latest/download/UserAssistView.exe') },
    [ordered]@{ Name = 'Strings Parser'; Description = 'Strings + YARA + signatures scanner'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/StringsParser/releases/download/v1.2/stringsparser1.2b.exe') },
    [ordered]@{ Name = 'Bam Check Restart'; Description = 'Detect the date of creation of the BAM'; Category = 'orbdiff'; Kind = 'Download'; Links = @('https://github.com/Orbdiff/BAM-CheckRestart/releases/download/v2.0.2/BAMCheckRestart.exe') },
    [ordered]@{ Name = 'Activities Cache execution'; Description = 'Gets the execution of files using the activitiescache.db'; Category = 'spokwn'; Kind = 'Download'; Links = @('https://github.com/spokwn/ActivitiesCache-execution/releases/download/v0.6.5/ActivitiesCacheParser.exe') },
    [ordered]@{ Name = 'BAM Parser'; Description = 'Parses the BAM forensic artefact'; Category = 'spokwn'; Kind = 'Download'; Links = @('https://github.com/spokwn/BAM-parser/releases/download/v1.2.9/BAMParser.exe') },
    [ordered]@{ Name = 'Bam Deleted Keys'; Description = 'Gathers BAM deleted keys by comparing them with the hives keys.'; Category = 'spokwn'; Kind = 'Download'; Links = @('https://github.com/spokwn/BamDeletedKeys/releases/download/v1.0/BamDeletedKeys.exe') },
    [ordered]@{ Name = 'Journal Trace'; Description = 'Parses NTFS journal entries'; Category = 'spokwn'; Kind = 'Download'; Links = @('https://github.com/spokwn/JournalTrace/releases/download/1.2/JournalTrace.exe') },
    [ordered]@{ Name = 'Pca Svc Executed'; Description = 'Fork of service-execution'; Category = 'spokwn'; Kind = 'Download'; Links = @('https://github.com/spokwn/pcasvc-executed/releases/download/v0.8.7/PcaSvcExecuted.exe') },
    [ordered]@{ Name = 'Espouken Tool'; Description = 'A collection of tools'; Category = 'spokwn'; Kind = 'Download'; Links = @('https://github.com/spokwn/Tool/releases/download/v1.1.3/espouken.exe') },
    [ordered]@{ Name = 'Process Parser'; Description = 'Parses processes using xxstrings'; Category = 'spokwn'; Kind = 'Download'; Links = @('https://github.com/spokwn/process-parser/releases/download/v0.5.5/ProcessParser.exe') },
    [ordered]@{ Name = 'Paths Parser'; Description = 'Parses info about paths on a .txt'; Category = 'spokwn'; Kind = 'Download'; Links = @('https://github.com/spokwn/PathsParser/releases/download/v1.2/PathsParser.exe') },
    [ordered]@{ Name = 'Kernel Live Dump Tool'; Description = 'Captures live kernel memory dumps'; Category = 'spokwn'; Kind = 'Download'; Links = @('https://github.com/spokwn/KernelLiveDumpTool/releases/latest') },
    [ordered]@{ Name = 'Prefetch Parser'; Description = 'Parses Windows prefetch files'; Category = 'spokwn'; Kind = 'Download'; Links = @('https://github.com/spokwn/prefetch-parser/releases/latest') },
    [ordered]@{ Name = 'Meow Resolver'; Description = 'Detector and resolver for known bypasses'; Category = 'tonynoh'; Kind = 'Download'; Links = @('https://github.com/MeowTonynoh/MeowResolver/releases/download/v.1.1/MeowResolver.exe') },
    [ordered]@{ Name = 'Meow Doomsday Finder'; Description = 'Doomsday client finder'; Category = 'tonynoh'; Kind = 'Download'; Links = @('https://github.com/MeowTonynoh/MeowDoomsdayFucker/releases/download/V.1.5/MeowDoomsdayFucker.exe') },
    [ordered]@{ Name = 'Meow Client Scanner'; Description = 'Client scanner'; Category = 'tonynoh'; Kind = 'Download'; Links = @('https://github.com/MeowTonynoh/MeowClientFucker/releases/download/v1.0/MeowClientFucker.exe') },
    [ordered]@{ Name = 'Meow Imports Checker'; Description = 'File imports checker'; Category = 'tonynoh'; Kind = 'Download'; Links = @('https://github.com/MeowTonynoh/MeowImportsChecker/releases/download/MeowImportsChecker/MeowImportsChecker.exe') },
    [ordered]@{ Name = 'Meow Novoware Scanner'; Description = 'Detects Novoware cheat artifacts'; Category = 'tonynoh'; Kind = 'Download'; Links = @('https://github.com/MeowTonynoh/MeowNovowareFucker/releases/latest') },
    [ordered]@{ Name = 'PSHunter'; Description = 'Hunts suspicious PowerShell activity'; Category = 'praiselily'; Kind = 'Download'; Links = @('https://github.com/praiselily/PSHunter/releases/latest') },
    [ordered]@{ Name = 'AltDetector'; Description = 'Detects alternate account artifacts'; Category = 'praiselily'; Kind = 'Download'; Links = @('https://github.com/praiselily/AltDetector/releases/latest') },
    [ordered]@{ Name = 'RL ModAnalyzer'; Description = 'Analyzes mod files for cheat indicators'; Category = 'redlotus'; Kind = 'Download'; Links = @('https://github.com/ItzIceHere/RedLotus-Mod-Analyzer/releases/latest') },
    [ordered]@{ Name = 'RL TaskSentinel'; Description = 'Monitors scheduled tasks for anomalies'; Category = 'redlotus'; Kind = 'Download'; Links = @('https://github.com/ItzIceHere/RedLotus-Task-Sentinel/releases/latest') },
    [ordered]@{ Name = 'RL AltChecker'; Description = 'Checks for alternate account indicators'; Category = 'redlotus'; Kind = 'Download'; Links = @('https://github.com/ItzIceHere/RedLotusAltChecker/releases/latest') },
    [ordered]@{ Name = 'Amcache Parser++'; Description = 'High-performance Amcache parser with YARA + VirusTotal'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/AmcacheParser++.exe') },
    [ordered]@{ Name = 'Autoruns++'; Description = 'Autoruns alternative with USN monitoring and signature verification'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/Autoruns++.exe') },
    [ordered]@{ Name = 'Bam Parser++'; Description = 'BAM execution history with YARA engine and tamper detection'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/BamParser++.exe') },
    [ordered]@{ Name = 'Browser Downloads View++'; Description = 'Multi-browser download history with USN modification highlighting'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/BrowserDownloadsView++.exe') },
    [ordered]@{ Name = 'Browsing History View++'; Description = 'Multi-browser history with suspicious domain flagging + VT links'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/BrowsingHistoryView++.exe') },
    [ordered]@{ Name = 'Crashed File Viewer++'; Description = 'Unified view of Windows crash artifacts with USN highlighting'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/CrashedFileViewer++.exe') },
    [ordered]@{ Name = 'Journal Trace++'; Description = 'USN Journal analysis with bypass detections and filtering'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/JournalTrace++.exe') },
    [ordered]@{ Name = 'Kernel Live Dump++'; Description = 'Dumps Kernel/User-mode RAM with filterable string results'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/KernelLiveDump++.exe') },
    [ordered]@{ Name = 'MFT Explorer++'; Description = 'Defined $MFT view with suspicious ADS identification'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/MFTExplorer++.exe') },
    [ordered]@{ Name = 'Paths Parser++'; Description = 'Paths parser GUI with YARA support and a USN journal viewer'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/PathsParser++.exe') },
    [ordered]@{ Name = 'PowerShell Parser++'; Description = 'Scrapes PowerShell history artifacts with bypass detection'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/PowerShellParser++.exe') },
    [ordered]@{ Name = 'Saved Files Viewer++'; Description = 'Shows every file saved to disk with cross-referenced timestamps'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/SavedFilesViewer++.exe') },
    [ordered]@{ Name = 'SRUM Explorer++'; Description = 'Maps file paths and services from SRUM with YARA + USN tracking'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/SRUMExplorer++.exe') },
    [ordered]@{ Name = 'String Explorer++'; Description = 'Navigate an exe''s full string data, entropy, and VirusTotal integration'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/StringExplorer++.exe') },
    [ordered]@{ Name = 'USB Deview++'; Description = 'Aggregated USB device logs cross-referenced against DeviceHunt'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/USBDeview++.exe') },
    [ordered]@{ Name = 'Win Prefetch View++'; Description = 'WinPrefetchView with bypass detections and YARA rule support'; Category = 'detectac'; Kind = 'Download'; Links = @('https://github.com/detect-ac/Detect.ac-Free-Tools/releases/download/FreeTools/WinPrefetchView++.exe') },
    [ordered]@{ Name = 'Full Event Log View'; Description = 'View Windows event logs'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/fulleventlogview-x64.zip') },
    [ordered]@{ Name = 'Network Usage View'; Description = 'Monitor network usage'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/networkusageview-x64.zip') },
    [ordered]@{ Name = 'Browser Downloads View'; Description = 'View browser download history'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/browserdownloadsview-x64.zip') },
    [ordered]@{ Name = 'Alternate Stream View'; Description = 'View NTFS alternate data streams'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/alternatestreamview-x64.zip') },
    [ordered]@{ Name = 'USB Deview'; Description = 'Manage USB devices'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/usbdeview-x64.zip') },
    [ordered]@{ Name = 'Open Save Files View'; Description = 'View Open/Save dialog history'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/opensavefilesview-x64.zip') },
    [ordered]@{ Name = 'Executed Programs List'; Description = 'List executed programs'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/executedprogramslist.zip') },
    [ordered]@{ Name = 'Task Scheduler View'; Description = 'View scheduled tasks'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/taskschedulerview-x64.zip') },
    [ordered]@{ Name = 'Jump Lists View'; Description = 'View Windows Jump Lists'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/jumplistsview.zip') },
    [ordered]@{ Name = 'Win Prefetch View'; Description = 'View Windows Prefetch files'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/winprefetchview-x64.zip') },
    [ordered]@{ Name = 'Reg Scanner'; Description = 'Advanced Registry scanner'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/regscanner-x64.zip') },
    [ordered]@{ Name = 'ShellBags View'; Description = 'View ShellBags entries'; Category = 'nirsoft'; Kind = 'Download'; Links = @('https://www.nirsoft.net/utils/shellbagsview.zip') },
    [ordered]@{ Name = 'Computer Activity View'; Description = 'Timeline of computer activity events'; Category = 'nirsoft'; Kind = 'Link'; Links = @('https://www.nirsoft.net/utils/computer_activity_view.html') },
    [ordered]@{ Name = 'Amcache Parser EZ'; Description = 'Parse Amcache.hve'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/AmcacheParser.zip') },
    [ordered]@{ Name = 'bstrings'; Description = 'String extractor'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/bstrings.zip') },
    [ordered]@{ Name = 'EvtxECmd'; Description = 'Event log parser'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/EvtxECmd.zip') },
    [ordered]@{ Name = 'Jump List Explorer'; Description = 'Jump List explorer'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/JumpListExplorer.zip') },
    [ordered]@{ Name = 'JLECmd'; Description = 'Parses Jump List files from the command line'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/JLECmd.zip') },
    [ordered]@{ Name = 'MFTECmd'; Description = 'MFT parser'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/MFTECmd.zip') },
    [ordered]@{ Name = 'PECmd'; Description = 'Prefetch parser'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/PECmd.zip') },
    [ordered]@{ Name = 'Recent File Cache Parser'; Description = 'Parses RecentFileCache.bcf artifacts'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/RecentFileCacheParser.zip') },
    [ordered]@{ Name = 'Registry Explorer'; Description = 'Registry viewer'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/RegistryExplorer.zip') },
    [ordered]@{ Name = 'ShellBags Explorer'; Description = 'ShellBags viewer'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/ShellBagsExplorer.zip') },
    [ordered]@{ Name = 'SrumECmd'; Description = 'SRUM parser'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/SrumECmd.zip') },
    [ordered]@{ Name = 'Timeline Explorer'; Description = 'Timeline explorer'; Category = 'ericzimmerman'; Kind = 'Download'; Links = @('https://download.ericzimmermanstools.com/net9/TimelineExplorer.zip') },
    [ordered]@{ Name = 'Jarabel'; Description = 'Locate all .jar files (or most of them) on a computer'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/nay-cat/Jarabel/releases/download/light/Jarabel.Light.exe') },
    [ordered]@{ Name = 'Luyten'; Description = 'Open source Java decompiler GUI for Procyon'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/deathmarine/Luyten/releases/download/v0.5.4_Rebuilt_with_Latest_depenencies/luyten-0.5.4.exe') },
    [ordered]@{ Name = 'VM Aware'; Description = 'Advanced VM detection library and tool'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/NotRequiem/VMAware/releases/download/v2.8.0/vmaware.exe') },
    [ordered]@{ Name = 'NTFS Parser'; Description = 'Forensics tool for NTFS'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/thewhiteninja/ntfstool/releases/download/v1.7/ntfstool.x64.exe') },
    [ordered]@{ Name = 'Hayabusa'; Description = 'Threat hunting and fast forensics timeline generator'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/Yamato-Security/hayabusa/releases/download/v3.10.0/hayabusa-3.10.0-all-platforms.zip') },
    [ordered]@{ Name = 'Everything'; Description = 'Locate files and folders by name instantly'; Category = 'others'; Kind = 'Download'; Links = @('https://www.voidtools.com/Everything-1.4.1.1032.x64-Setup.exe') },
    [ordered]@{ Name = 'HxD'; Description = 'HxD hex editor'; Category = 'others'; Kind = 'Download'; Links = @('https://mh-nexus.de/downloads/HxDSetup.zip') },
    [ordered]@{ Name = 'DIE Engine'; Description = 'Detects file type, packer, and compiler information'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/horsicq/DIE-engine/releases') },
    [ordered]@{ Name = 'Velociraptor'; Description = 'Endpoint DFIR and threat hunting tool'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/Velocidex/velociraptor/releases/latest') },
    [ordered]@{ Name = 'P1AE Javaw'; Description = 'Javaw scanner'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/p1aegg/javaw/releases/download/v1.9/P1AE.Javaw.exe') },
    [ordered]@{ Name = 'Macro Scanner EXE'; Description = 'Lafferr macro scanner'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/Lafferrr/MacroScanner/releases/download/MS/MacroScanner.exe') },
    [ordered]@{ Name = 'String Checker'; Description = 'Lafferr strings checker'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/Lafferrr/SSTools/raw/refs/heads/main/SSTools/Strings/LaffersStringsChecker.exe') },
    [ordered]@{ Name = 'Java Library Analyzer'; Description = 'Lafferr Java library analyzer'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/Lafferrr/SSTools/raw/refs/heads/main/SSTools/JavaLibraryAnalyzer/JavaLibraryAnalyzer.exe', 'https://github.com/Lafferrr/SSTools/raw/refs/heads/main/SSTools/JavaLibraryAnalyzer/library_baseline.bin', 'https://github.com/Lafferrr/SSTools/raw/refs/heads/main/SSTools/JavaLibraryAnalyzer/natives_baseline.bin') },
    [ordered]@{ Name = 'PJ Cheat Scanner Lite'; Description = 'String checker'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/gorbgallin/Pj-sCheatScannerLite/releases/download/1.1/PjCheatScannerLite.exe', 'https://github.com/gorbgallin/Pj-sCheatScannerLite/releases/download/1.1/cheat_strings.txt') },
    [ordered]@{ Name = 'System Informer'; Description = 'Process viewer'; Category = 'others'; Kind = 'Download'; Links = @('https://github.com/winsiderss/si-builds/releases/download/4.0.26115.206/systeminformer-build-canary-setup.exe') },
    [ordered]@{ Name = 'NET 8.0'; Description = 'Install .NET 8.0 runtime'; Category = 'dependencies'; Kind = 'Download'; Links = @('https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/sdk-8.0.423-windows-x64-installer') },
    [ordered]@{ Name = 'NET 9.0'; Description = 'Install .NET 9.0 runtime'; Category = 'dependencies'; Kind = 'Download'; Links = @('https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/9.0.11/windowsdesktop-runtime-9.0.11-win-x64.exe') },
    [ordered]@{ Name = 'NET 10.0'; Description = 'Install .NET 10.0 runtime'; Category = 'dependencies'; Kind = 'Download'; Links = @('https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/10.0.10/windowsdesktop-runtime-10.0.10-win-x64.exe') },
    [ordered]@{ Name = 'VSRedist'; Description = 'Install Visual C++ Redistributable'; Category = 'dependencies'; Kind = 'Download'; Links = @('https://aka.ms/vc14/vc_redist.x64.exe') }
)

$psPrefix = 'Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; Invoke-Expression (Invoke-RestMethod '

$ScriptActions = @(
    [ordered]@{ Name = 'Running Processes'; Description = 'Lists all running processes'; Category = 'scripts'; Kind = 'Script'; Command = 'Get-Process | Sort-Object CPU -Descending | Format-Table Name,ID,CPU,WorkingSet -AutoSize' },
    [ordered]@{ Name = 'Services Checker'; Description = 'Runs NiccBlahh ServiceChecker'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/NiccBlahh/ServiceChecker/refs/heads/main/ServiceChecker.ps1'')') },
    [ordered]@{ Name = 'Zeezy Services'; Description = 'Runs zeezyexe services checker'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/zeezyexe/services-checker/refs/heads/main/zeezyservices.psl'')') },
    [ordered]@{ Name = 'Doomsday Finder'; Description = 'Runs zedoonvm1 DoomsDayDetector script'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/zedoonvm1/powershell-scripts/refs/heads/main/DoomsDayDetector.ps1'')') },
    [ordered]@{ Name = 'All In One'; Description = 'Runs Enr1c0o all-in-one screenshare script'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/Enr1c0o/Powershell-Scripts/refs/heads/main/All-in-one.ps1'')') },
    [ordered]@{ Name = 'P1ae''s Mod Analyzer'; Description = 'Runs p1aegg mod analyzer'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/p1aegg/powershell/refs/heads/main/modanalyzer.ps1'')') },
    [ordered]@{ Name = 'JAR Parser Script'; Description = 'Parses JAR files'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/l4rpsucks/Scripts/refs/heads/main/JARParser.ps1'')') },
    [ordered]@{ Name = 'Fileless Bypass Detection'; Description = 'Detects fileless bypass techniques'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/l4rpsucks/Scripts/refs/heads/main/FilelessBypassDetection.ps1'')') },
    [ordered]@{ Name = 'Macro Scanner'; Description = 'Scans for mouse software macros'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/zeezyexe/macro-scanner/refs/heads/main/catchmacro.ps1'')') },
    [ordered]@{ Name = 'ClassLoader Dump'; Description = 'Dumps ClassLoader data'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/p1aegg/powershell/refs/heads/main/ClassLoaderDump.ps1'')') },
    [ordered]@{ Name = 'Yarp''s Mod Analyzer'; Description = 'Runs the mod analyzer command'; Category = 'scripts'; Kind = 'Script'; RunMode = 'Cmd'; Command = 'powershell Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass && powershell Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/p1aegg/powershell/refs/heads/main/modanalyzer.ps1)' },
    [ordered]@{ Name = 'Meow Mod Analyzer'; Description = 'Runs MeowTonynoh mod analyzer'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/MeowTonynoh/MeowModAnalyzer/main/MeowModAnalyzer.ps1'')') },
    [ordered]@{ Name = 'Prefetch Integrity Analyzer'; Description = 'Analyzes prefetch integrity (RedLotus)'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/bacanoicua/Screenshare/main/RedLotusPrefetchIntegrityAnalyzer.ps1'')') },
    [ordered]@{ Name = 'Lily Services'; Description = 'Runs PraiseLily services checker'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/Lafferrr/SSTools/refs/heads/main/LilysServices'')') },
    [ordered]@{ Name = 'Lily Services Enabler'; Description = 'Runs services enabler'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/Lafferrr/SSTools/refs/heads/main/LilysServicesEnabler'')') },
    [ordered]@{ Name = 'Hotspot Logs'; Description = 'Checks hotspot and tethering logs'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/praiselily/WeHateFakers/refs/heads/main/HotspotLogs.ps1'')') },
    [ordered]@{ Name = 'Harddisk Converter'; Description = 'Converts hard disk identifiers for review'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/HarddiskConverter.ps1'')') },
    [ordered]@{ Name = 'PraiseLily Services'; Description = 'Lists and analyzes running services'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/Services.ps1'')') },
    [ordered]@{ Name = 'DQRKIS Checker'; Description = 'Runs cheesecatlol DQRKIS artifact checker'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/cheesecatlol/DQRKIS-FUCKER/refs/heads/main/DqrkisFucker.ps1'')') },
    [ordered]@{ Name = 'MacroDetector'; Description = 'Detects macro and clicker software traces'; Category = 'scripts'; Kind = 'Script'; Command = ($psPrefix + '''https://raw.githubusercontent.com/NiccBlahh/MacroDetector/refs/heads/main/MacroDetector.ps1'')') }
)

$Credits = @(
    [ordered]@{ Name = 'p1ae'; Role = 'Original SSTool application structure.'; Source = 'README.md, resource.rc, main.cpp, splash.cpp' },
    [ordered]@{ Name = 'p1aegg'; Role = 'PowerShell scripts, mod analyzer, ClassLoader Dump, and P1AE Javaw.'; Source = 'webview_manager.cpp, web/index.html' },
    [ordered]@{ Name = 'OrbDiff'; Role = 'OrbDiff forensic tools.'; Source = 'github.com/Orbdiff' },
    [ordered]@{ Name = 'Spokwn'; Role = 'Spokwn forensic tools.'; Source = 'github.com/spokwn' },
    [ordered]@{ Name = 'Tonynoh / MeowTonynoh'; Role = 'Meow resolver, Doomsday, client, imports, and mod analyzer tools.'; Source = 'github.com/MeowTonynoh' },
    [ordered]@{ Name = 'DetectAC'; Role = 'Detect.ac Free Tools suite.'; Source = 'detect.ac, github.com/detect-ac' },
    [ordered]@{ Name = 'NirSoft'; Role = 'NirSoft Windows forensic and system utilities.'; Source = 'nirsoft.net' },
    [ordered]@{ Name = 'Eric Zimmerman'; Role = 'Eric Zimmerman forensic tools.'; Source = 'ericzimmerman.github.io' },
    [ordered]@{ Name = 'NiccBlahh'; Role = 'ServiceChecker and MacroDetector scripts.'; Source = 'github.com/NiccBlahh' },
    [ordered]@{ Name = 'zeezyexe'; Role = 'Services checker and macro scanner scripts.'; Source = 'github.com/zeezyexe' },
    [ordered]@{ Name = 'zedoonvm1'; Role = 'DoomsDayDetector PowerShell script.'; Source = 'github.com/zedoonvm1/powershell-scripts' },
    [ordered]@{ Name = 'Enr1c0o'; Role = 'All-in-one PowerShell screenshare script.'; Source = 'github.com/Enr1c0o/Powershell-Scripts' },
    [ordered]@{ Name = 'l4rpsucks'; Role = 'JARParser and FilelessBypassDetection scripts.'; Source = 'github.com/l4rpsucks/Scripts' },
    [ordered]@{ Name = 'YarpLetapStan'; Role = 'Yarp''s Mod Analyzer script.'; Source = 'github.com/YarpLetapStan/PowershellScripts' },
    [ordered]@{ Name = 'bacanoicua / RedLotus'; Role = 'RedLotus prefetch integrity analyzer script.'; Source = 'github.com/bacanoicua/Screenshare' },
    [ordered]@{ Name = 'Lafferrr / PraiseLily'; Role = 'Macro Scanner, Strings Checker, Java Library Analyzer, Lily Services.'; Source = 'github.com/Lafferrr/SSTools' },
    [ordered]@{ Name = 'praiselily'; Role = 'PSHunter, AltDetector, hotspot logs, services, and harddisk converter.'; Source = 'github.com/praiselily' },
    [ordered]@{ Name = 'ItzIceHere / RedLotus'; Role = 'RedLotus Mod Analyzer, Task Sentinel, and AltChecker.'; Source = 'github.com/ItzIceHere' },
    [ordered]@{ Name = 'cheesecatlol'; Role = 'DQRKIS checker.'; Source = 'github.com/cheesecatlol' },
    [ordered]@{ Name = 'nay-cat'; Role = 'Jarabel.'; Source = 'github.com/nay-cat/Jarabel' },
    [ordered]@{ Name = 'deathmarine / Procyon'; Role = 'Luyten Java decompiler GUI.'; Source = 'github.com/deathmarine/Luyten' },
    [ordered]@{ Name = 'NotRequiem'; Role = 'VM Aware.'; Source = 'github.com/NotRequiem/VMAware' },
    [ordered]@{ Name = 'thewhiteninja'; Role = 'NTFS Parser.'; Source = 'github.com/thewhiteninja/ntfstool' },
    [ordered]@{ Name = 'Yamato-Security'; Role = 'Hayabusa.'; Source = 'github.com/Yamato-Security/hayabusa' },
    [ordered]@{ Name = 'horsicq'; Role = 'DIE Engine.'; Source = 'github.com/horsicq/DIE-engine' },
    [ordered]@{ Name = 'Velocidex'; Role = 'Velociraptor.'; Source = 'github.com/Velocidex/velociraptor' },
    [ordered]@{ Name = 'voidtools'; Role = 'Everything file search.'; Source = 'voidtools.com' },
    [ordered]@{ Name = 'MH-Nexus'; Role = 'HxD hex editor.'; Source = 'mh-nexus.de' },
    [ordered]@{ Name = 'gorbgallin'; Role = 'PJ Cheat Scanner Lite.'; Source = 'github.com/gorbgallin' },
    [ordered]@{ Name = 'winsiderss'; Role = 'System Informer builds.'; Source = 'github.com/winsiderss/si-builds' },
    [ordered]@{ Name = 'Microsoft'; Role = '.NET runtimes, Visual C++ Redistributable, and WPF.'; Source = 'microsoft.com, dotnet.microsoft.com, aka.ms' }
)

function Show-DeaduniebiDialog {
    param(
        [string]$Title = 'Deaduniebi Screen Share',
        [string]$Message = '',
        [string]$Kind = 'Info',
        [string]$Details = '',
        [string]$CopyText = ''
    )

    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = 'No message was provided.' }

    [xml]$dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Deaduniebi Screen Share" Width="560" Height="400"
        WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="NoResize"
        Background="#0A0A0A" ShowInTaskbar="False" Topmost="True"
        UseLayoutRounding="True" SnapsToDevicePixels="True" FontFamily="Segoe UI">
    <Window.Resources>$ButtonStyleXaml</Window.Resources>
    <Border BorderBrush="#2A2A2A" BorderThickness="1" Padding="22">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <Grid Grid.Row="0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel>
                    <TextBlock x:Name="DialogKindText" Text="MESSAGE" FontSize="11" FontWeight="Bold" Foreground="#8A8A8A"/>
                    <TextBlock x:Name="DialogTitleText" Text="Deaduniebi Screen Share" FontSize="18" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,4,0,0" TextWrapping="Wrap"/>
                </StackPanel>
                <Button x:Name="DialogCloseButton" Grid.Column="1" Content="X" Width="32" Height="30" Style="{StaticResource FlatButtonStyle}" Padding="0"/>
            </Grid>
            <StackPanel Grid.Row="1" Margin="0,20,0,16">
                <Border Background="#121212" BorderBrush="#262626" BorderThickness="1" CornerRadius="3" Padding="14">
                    <TextBlock x:Name="DialogMessageText" Foreground="#D6D6D6" FontSize="13" TextWrapping="Wrap"/>
                </Border>
                <Border x:Name="DialogDetailsBorder" Background="#0F0F0F" BorderBrush="#262626" BorderThickness="1" CornerRadius="3" Padding="12" Margin="0,12,0,0">
                    <TextBox x:Name="DialogDetailsBox" Height="120" Background="Transparent" Foreground="#BDBDBD" BorderThickness="0" FontFamily="Consolas" FontSize="11" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
                </Border>
            </StackPanel>
            <Grid Grid.Row="2">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="140"/>
                    <ColumnDefinition Width="10"/>
                    <ColumnDefinition Width="100"/>
                </Grid.ColumnDefinitions>
                <Button x:Name="DialogCopyButton" Grid.Column="1" Content="Copy Details" Height="36" Style="{StaticResource FlatButtonStyle}"/>
                <Button x:Name="DialogOkButton" Grid.Column="3" Content="OK" Height="36" Style="{StaticResource FlatButtonStyle}" Background="#FFFFFF" Foreground="#000000" BorderBrush="#FFFFFF"/>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

    try {
        $dialogReader = New-Object System.Xml.XmlNodeReader $dialogXaml
        $dialogWindow = [Windows.Markup.XamlReader]::Load($dialogReader)
        $dialogWindow.Add_MouseLeftButtonDown({ try { $dialogWindow.DragMove() } catch {} })

        $dialogWindow.FindName('DialogTitleText').Text = $Title
        $dialogWindow.FindName('DialogMessageText').Text = $Message
        $dialogWindow.FindName('DialogKindText').Text = $Kind.ToUpperInvariant()
        $detailsBorder = $dialogWindow.FindName('DialogDetailsBorder')
        $copyButton = $dialogWindow.FindName('DialogCopyButton')

        $copyPayload = if (-not [string]::IsNullOrWhiteSpace($CopyText)) { $CopyText } elseif (-not [string]::IsNullOrWhiteSpace($Details)) { $Details } else { $Message }

        if ([string]::IsNullOrWhiteSpace($Details)) {
            $detailsBorder.Visibility = 'Collapsed'
            if ($Kind -ne 'Error') { $copyButton.Visibility = 'Collapsed' }
        }
        else {
            $dialogWindow.FindName('DialogDetailsBox').Text = $Details
        }

        $copyButton.Add_Click({
            try {
                [System.Windows.Clipboard]::SetText($copyPayload)
                $copyButton.Content = 'Copied'
            }
            catch { $copyButton.Content = 'Copy Failed' }
        }.GetNewClosure())

        $dialogWindow.FindName('DialogOkButton').Add_Click({ $dialogWindow.Close() })
        $dialogWindow.FindName('DialogCloseButton').Add_Click({ $dialogWindow.Close() })
        $dialogWindow.ShowDialog() | Out-Null
    }
    catch {
        [System.Windows.MessageBox]::Show($Message, $Title, 'OK', 'Information') | Out-Null
    }
}

function Show-DeaduniebiTermsDialog {
    [xml]$termsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Deaduniebi Screen Share Terms" Width="560" Height="440"
        WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="NoResize"
        Background="#0A0A0A" ShowInTaskbar="False" Topmost="True"
        UseLayoutRounding="True" SnapsToDevicePixels="True" FontFamily="Segoe UI">
    <Window.Resources>$ButtonStyleXaml</Window.Resources>
    <Border BorderBrush="#2A2A2A" BorderThickness="1" Padding="26">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <StackPanel>
                <TextBlock Text="Deaduniebi Screen Share" FontSize="22" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                <TextBlock Text="Read and accept before continuing" FontSize="12" Foreground="#8A8A8A" Margin="0,4,0,0"/>
            </StackPanel>
            <Border Grid.Row="1" Margin="0,22,0,20" Background="#121212" BorderBrush="#262626" BorderThickness="1" CornerRadius="3" Padding="18">
                <StackPanel>
                    <TextBlock TextWrapping="Wrap" Foreground="#D6D6D6" FontSize="13" Text="Deaduniebi Screen Share is a launcher for legitimate screenshare and forensic review workflows. Use it only on systems where you have permission."/>
                    <TextBlock TextWrapping="Wrap" Foreground="#D6D6D6" FontSize="13" Margin="0,12,0,0" Text="External programs and scripts are created by their own developers. Their original credits are kept and no ownership is claimed."/>
                    <TextBlock TextWrapping="Wrap" Foreground="#D6D6D6" FontSize="13" Margin="0,12,0,0" Text="Downloaded tools are saved in the deaduniebitools folder. Some tools may require administrator permission or their own runtimes."/>
                    <TextBlock TextWrapping="Wrap" Foreground="#FFFFFF" FontSize="13" FontWeight="SemiBold" Margin="0,16,0,0" Text="Click Accept if you understand and agree."/>
                </StackPanel>
            </Border>
            <Grid Grid.Row="2">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="10"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Button x:Name="TermsCancelButton" Content="Cancel" Height="40" Style="{StaticResource FlatButtonStyle}"/>
                <Button x:Name="TermsAcceptButton" Grid.Column="2" Content="Accept &amp; Continue" Height="40" Style="{StaticResource FlatButtonStyle}" Background="#FFFFFF" Foreground="#000000" BorderBrush="#FFFFFF"/>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

    try {
        $termsReader = New-Object System.Xml.XmlNodeReader $termsXaml
        $termsWindow = [Windows.Markup.XamlReader]::Load($termsReader)
        $termsWindow.Add_MouseLeftButtonDown({ try { $termsWindow.DragMove() } catch {} })
        $script:TermsAccepted = $false
        $termsWindow.FindName('TermsAcceptButton').Add_Click({ $script:TermsAccepted = $true; $termsWindow.Close() })
        $termsWindow.FindName('TermsCancelButton').Add_Click({ $script:TermsAccepted = $false; $termsWindow.Close() })
        $termsWindow.ShowDialog() | Out-Null
        return [bool]$script:TermsAccepted
    }
    catch {
        Show-DeaduniebiDialog -Title 'Deaduniebi Screen Share - Startup Error' -Message 'The terms window could not be displayed.' -Kind 'Error' -Details $_.Exception.Message
        return $false
    }
}

if (-not (Show-DeaduniebiTermsDialog)) { exit }

[xml]$splashXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Deaduniebi Screen Share" Width="520" Height="220"
        WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="NoResize"
        Background="#0A0A0A" ShowInTaskbar="False" Topmost="True" FontFamily="Segoe UI">
    <Border BorderBrush="#2A2A2A" BorderThickness="1" Padding="28">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock Text="DEADUNIEBI SCREEN SHARE" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
            <TextBlock x:Name="SplashStatusText" Grid.Row="1" Text="Starting" FontSize="13" Foreground="#8A8A8A" VerticalAlignment="Center"/>
            <ProgressBar x:Name="SplashBar" Grid.Row="2" Height="6" Minimum="0" Maximum="100" Value="10" Foreground="#FFFFFF" Background="#1E1E1E" BorderThickness="0"/>
        </Grid>
    </Border>
</Window>
"@

try {
    $splashReader = New-Object System.Xml.XmlNodeReader $splashXaml
    $SplashWindow = [Windows.Markup.XamlReader]::Load($splashReader)
    $SplashStatusText = $SplashWindow.FindName('SplashStatusText')
    $SplashBar = $SplashWindow.FindName('SplashBar')
    $SplashWindow.Show()
    $SplashWindow.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}
catch { $SplashWindow = $null }

function Update-Splash {
    param([string]$Text, [double]$Progress)
    if (-not $SplashWindow) { return }
    $SplashStatusText.Text = $Text
    $SplashBar.Value = $Progress
    $SplashWindow.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

Update-Splash -Text 'Loading interface' -Progress 25

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Deaduniebi Screen Share" Width="1280" Height="820" MinWidth="1040" MinHeight="680"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip" WindowStyle="None"
        Background="#0A0A0A" UseLayoutRounding="True" SnapsToDevicePixels="True" FontFamily="Segoe UI">
    <Window.Resources>$ButtonStyleXaml</Window.Resources>
    <Border BorderBrush="#2A2A2A" BorderThickness="1">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="56"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="54"/>
            </Grid.RowDefinitions>

            <Border x:Name="HeaderBar" Grid.Row="0" Background="#0F0F0F" BorderBrush="#222222" BorderThickness="0,0,0,1">
                <Grid Margin="18,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        
                        <TextBlock Text="Deaduniebi Screen Share" FontSize="15" FontWeight="SemiBold" Foreground="#FFFFFF" VerticalAlignment="Center"/>
                    </StackPanel>
                    <Border Grid.Column="1" Height="34" MaxWidth="480" Margin="24,0" Background="#151515" BorderBrush="#2A2A2A" BorderThickness="1" CornerRadius="3" Padding="12,0">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="SearchBox" Background="Transparent" BorderThickness="0" Foreground="#FFFFFF" CaretBrush="#FFFFFF" FontSize="13" VerticalContentAlignment="Center"/>
                            <Button x:Name="ClearSearchButton" Grid.Column="1" Content="Clear" Height="24" Padding="8,0" FontSize="11" Style="{StaticResource FlatButtonStyle}" Visibility="Collapsed"/>
                        </Grid>
                    </Border>
                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="MinButton" Content="_" Width="34" Height="30" Padding="0" Style="{StaticResource FlatButtonStyle}"/>
                        <Button x:Name="CloseButton" Content="X" Width="34" Height="30" Padding="0" Margin="8,0,0,0" Style="{StaticResource FlatButtonStyle}"/>
                    </StackPanel>
                </Grid>
            </Border>

            <Border Grid.Row="1" Background="#0D0D0D" BorderBrush="#222222" BorderThickness="0,0,0,1" Padding="18,12,18,6">
                <WrapPanel x:Name="CategoryButtonPanel"/>
            </Border>

            <Grid Grid.Row="2" Margin="20">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="20"/>
                    <ColumnDefinition Width="290"/>
                </Grid.ColumnDefinitions>

                <Grid Grid.Column="0">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Margin="0,0,0,14">
                        <TextBlock x:Name="SelectedCategoryText" Text="OrbDiff" FontSize="24" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock x:Name="SelectedCategoryDescription" Foreground="#BDBDBD" FontSize="13" Margin="0,6,0,0" TextWrapping="Wrap"/>
                        <TextBlock x:Name="CategoryHeaderText" Foreground="#6E6E6E" FontSize="12" Margin="0,4,0,0" TextWrapping="Wrap"/>
                        <TextBlock x:Name="SearchHintText" Foreground="#6E6E6E" FontSize="12" Margin="0,4,0,0" TextWrapping="Wrap"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                        <StackPanel x:Name="ToolListPanel" Margin="0,0,10,0"/>
                    </ScrollViewer>
                </Grid>

                <Border Grid.Column="2" Background="#111111" BorderBrush="#262626" BorderThickness="1" CornerRadius="3" Padding="18" VerticalAlignment="Top">
                    <StackPanel>
                        <TextBlock Text="STATUS" FontSize="11" FontWeight="Bold" Foreground="#6E6E6E"/>
                        <TextBlock x:Name="StateText" Text="READY" FontSize="26" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,6,0,0"/>
                        <TextBlock x:Name="StatusText" Text="Ready" FontSize="13" Foreground="#D6D6D6" Margin="0,6,0,0" TextWrapping="Wrap"/>
                        <TextBlock x:Name="SubStatusText" Text="Pick a category above." FontSize="12" Foreground="#8A8A8A" Margin="0,4,0,0" TextWrapping="Wrap"/>
                        <Border Height="1" Background="#262626" Margin="0,16"/>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Step" Foreground="#6E6E6E" FontSize="12"/>
                            <TextBlock x:Name="StepText" Grid.Column="1" Text="Waiting" Foreground="#FFFFFF" FontSize="12" FontWeight="SemiBold"/>
                        </Grid>
                        <Grid Margin="0,8,0,0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Progress" Foreground="#6E6E6E" FontSize="12"/>
                            <TextBlock x:Name="ProgressLabel" Grid.Column="1" Text="0%" Foreground="#FFFFFF" FontSize="12" FontWeight="SemiBold"/>
                        </Grid>
                        <Grid Margin="0,8,0,0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Items" Foreground="#6E6E6E" FontSize="12"/>
                            <TextBlock x:Name="ToolCountText" Grid.Column="1" Text="0" Foreground="#FFFFFF" FontSize="12" FontWeight="SemiBold"/>
                        </Grid>
                        <ProgressBar x:Name="MainProgressBar" Height="4" Margin="0,16,0,0" Minimum="0" Maximum="100" Value="0" Foreground="#FFFFFF" Background="#222222" BorderThickness="0"/>
                        <Button x:Name="DownloadAllButton" Content="Download All" Height="38" Margin="0,20,0,0" Style="{StaticResource FlatButtonStyle}" Background="#FFFFFF" Foreground="#000000" BorderBrush="#FFFFFF"/>
                        <Button x:Name="CancelDownloadButton" Content="Cancel Download" Height="38" Margin="0,8,0,0" Style="{StaticResource FlatButtonStyle}" IsEnabled="False"/>
                    </StackPanel>
                </Border>
            </Grid>

            <Border Grid.Row="3" Background="#0F0F0F" BorderBrush="#222222" BorderThickness="0,1,0,0">
                <Grid Margin="20,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="OpenToolsFolderButton" Content="Open Folder" Width="112" Height="32" Style="{StaticResource FlatButtonStyle}"/>
                        <Button x:Name="ClearToolsButton" Content="Clear Tools" Width="112" Height="32" Margin="8,0,0,0" Style="{StaticResource FlatButtonStyle}"/>
                        <Button x:Name="SettingsButton" Content="Settings" Width="112" Height="32" Margin="8,0,0,0" Style="{StaticResource FlatButtonStyle}"/>
                    </StackPanel>
                    <TextBlock x:Name="VersionText" Grid.Column="2" Foreground="#6E6E6E" FontSize="12" VerticalAlignment="Center"/>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$HeaderBar = $window.FindName('HeaderBar')
$CloseButton = $window.FindName('CloseButton')
$MinButton = $window.FindName('MinButton')
$CategoryButtonPanel = $window.FindName('CategoryButtonPanel')
$ToolListPanel = $window.FindName('ToolListPanel')
$StatusText = $window.FindName('StatusText')
$SubStatusText = $window.FindName('SubStatusText')
$StateText = $window.FindName('StateText')
$CategoryHeaderText = $window.FindName('CategoryHeaderText')
$SelectedCategoryText = $window.FindName('SelectedCategoryText')
$SelectedCategoryDescription = $window.FindName('SelectedCategoryDescription')
$SearchBox = $window.FindName('SearchBox')
$ClearSearchButton = $window.FindName('ClearSearchButton')
$SearchHintText = $window.FindName('SearchHintText')
$DownloadAllButton = $window.FindName('DownloadAllButton')
$CancelDownloadButton = $window.FindName('CancelDownloadButton')
$OpenToolsFolderButton = $window.FindName('OpenToolsFolderButton')
$ClearToolsButton = $window.FindName('ClearToolsButton')
$SettingsButton = $window.FindName('SettingsButton')
$StepText = $window.FindName('StepText')
$ProgressLabel = $window.FindName('ProgressLabel')
$ToolCountText = $window.FindName('ToolCountText')
$MainProgressBar = $window.FindName('MainProgressBar')
$VersionText = $window.FindName('VersionText')

$VersionText.Text = "Version $AppVersion"

$script:CurrentCategory = 'orbdiff'
$script:CategoryButtons = @{}
$script:CardProgressBars = @{}
$script:CardButtons = @{}
$script:DownloadQueue = New-Object System.Collections.Queue
$script:CurrentWorker = $null
$script:ActiveDownloadJob = $null
$script:SearchIndex = $null
$script:SearchRenderTimer = $null
$script:SuppressSearchTextChanged = $false
$script:BrushConverter = New-Object System.Windows.Media.BrushConverter
$script:Settings = [ordered]@{
    AutoLaunchDownloads = $true
    RunScriptsAsAdmin = $true
    OpenFolderWhenNoLaunchable = $true
    DetailedErrorPopups = $true
}

function Get-Brush {
    param([string]$Color)
    return $script:BrushConverter.ConvertFromString($Color)
}

function Refresh-Ui {
    if ($window) { $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background) }
}

function Set-ButtonTone {
    param($Button, [string]$Tone)
    if ($Tone -eq 'primary') {
        $Button.Background = Get-Brush '#FFFFFF'
        $Button.Foreground = Get-Brush '#000000'
        $Button.BorderBrush = Get-Brush '#FFFFFF'
    }
    else {
        $Button.Background = Get-Brush '#1A1A1A'
        $Button.Foreground = Get-Brush '#EDEDED'
        $Button.BorderBrush = Get-Brush '#333333'
    }
}

function Set-ProgressAnimated {
    param([double]$Value, [int]$DurationMs = 180)
    if ($Value -lt 0) { $Value = 0 }
    if ($Value -gt 100) { $Value = 100 }
    $MainProgressBar.IsIndeterminate = $false
    $animation = New-Object System.Windows.Media.Animation.DoubleAnimation
    $animation.To = $Value
    $animation.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds($DurationMs))
    $MainProgressBar.BeginAnimation([System.Windows.Controls.ProgressBar]::ValueProperty, $animation)
}

function Set-UiState {
    param([string]$Title, [string]$SubTitle, [string]$Chip, [string]$Step, [double]$Progress = 0)
    $StatusText.Text = $Title
    $SubStatusText.Text = $SubTitle
    $StateText.Text = $Chip.ToUpperInvariant()
    $StepText.Text = $Step
    $ProgressLabel.Text = ('{0}%' -f [int]$Progress)
    Set-ProgressAnimated -Value $Progress
    Refresh-Ui
}

function Show-ErrorDetails {
    param([string]$Title, [string]$Action, [string]$ToolName, [string]$Message, [string]$Url, [string]$Path, [string]$Extra)

    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = 'Unknown error.' }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Action: $Action") | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($ToolName)) { $lines.Add("Tool: $ToolName") | Out-Null }
    $lines.Add("Error: $Message") | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($Url)) { $lines.Add("URL: $Url") | Out-Null }
    if (-not [string]::IsNullOrWhiteSpace($Path)) { $lines.Add("Path: $Path") | Out-Null }
    if (-not [string]::IsNullOrWhiteSpace($Extra)) { $lines.Add("Details: $Extra") | Out-Null }

    $detail = ($lines -join "`r`n")
    Set-UiState -Title 'Error' -SubTitle $Message -Chip 'Error' -Step $Action -Progress 0
    $detailsToShow = $detail
    if (-not [bool]$script:Settings.DetailedErrorPopups) { $detailsToShow = '' }
    Show-DeaduniebiDialog -Title $Title -Message $Message -Kind 'Error' -Details $detailsToShow -CopyText $detail
}

function Show-DeaduniebiSettings {
    [xml]$settingsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Deaduniebi Screen Share Settings" Width="540" Height="430"
        WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="NoResize"
        Background="#0A0A0A" ShowInTaskbar="False" Topmost="True"
        UseLayoutRounding="True" SnapsToDevicePixels="True" FontFamily="Segoe UI">
    <Window.Resources>$ButtonStyleXaml</Window.Resources>
    <Border BorderBrush="#2A2A2A" BorderThickness="1" Padding="24">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel>
                    <TextBlock Text="Settings" FontSize="22" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                    <TextBlock Text="Options for this session" FontSize="12" Foreground="#8A8A8A" Margin="0,4,0,0"/>
                </StackPanel>
                <Button x:Name="SettingsCloseButton" Grid.Column="1" Content="X" Width="32" Height="30" Padding="0" Style="{StaticResource FlatButtonStyle}"/>
            </Grid>
            <StackPanel Grid.Row="1" Margin="0,22,0,16">
                <Border Background="#121212" BorderBrush="#262626" BorderThickness="1" CornerRadius="3" Padding="16">
                    <StackPanel>
                        <CheckBox x:Name="AutoLaunchCheck" Content="Launch tools after download" Foreground="#D6D6D6" FontSize="13" Margin="0,0,0,14"/>
                        <CheckBox x:Name="AdminScriptsCheck" Content="Run scripts as administrator" Foreground="#D6D6D6" FontSize="13" Margin="0,0,0,14"/>
                        <CheckBox x:Name="OpenFolderNoLaunchCheck" Content="Open tool folder if no launchable file is found" Foreground="#D6D6D6" FontSize="13" Margin="0,0,0,14"/>
                        <CheckBox x:Name="DetailedErrorsCheck" Content="Show detailed error popups" Foreground="#D6D6D6" FontSize="13"/>
                    </StackPanel>
                </Border>
                <TextBlock Text="Settings apply to this run only. No config file is written, so installer.ps1 stays standalone." Foreground="#6E6E6E" FontSize="12" TextWrapping="Wrap" Margin="0,12,0,0"/>
            </StackPanel>
            <Grid Grid.Row="2">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="110"/>
                    <ColumnDefinition Width="10"/>
                    <ColumnDefinition Width="110"/>
                </Grid.ColumnDefinitions>
                <Button x:Name="DefaultsButton" Content="Defaults" Width="110" Height="38" HorizontalAlignment="Left" Style="{StaticResource FlatButtonStyle}"/>
                <Button x:Name="CancelSettingsButton" Grid.Column="1" Content="Cancel" Height="38" Style="{StaticResource FlatButtonStyle}"/>
                <Button x:Name="SaveSettingsButton" Grid.Column="3" Content="Save" Height="38" Style="{StaticResource FlatButtonStyle}" Background="#FFFFFF" Foreground="#000000" BorderBrush="#FFFFFF"/>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

    try {
        $settingsReader = New-Object System.Xml.XmlNodeReader $settingsXaml
        $settingsWindow = [Windows.Markup.XamlReader]::Load($settingsReader)
        $settingsWindow.Add_MouseLeftButtonDown({ try { $settingsWindow.DragMove() } catch {} })

        $autoLaunchCheck = $settingsWindow.FindName('AutoLaunchCheck')
        $adminScriptsCheck = $settingsWindow.FindName('AdminScriptsCheck')
        $openFolderNoLaunchCheck = $settingsWindow.FindName('OpenFolderNoLaunchCheck')
        $detailedErrorsCheck = $settingsWindow.FindName('DetailedErrorsCheck')

        $autoLaunchCheck.IsChecked = [bool]$script:Settings.AutoLaunchDownloads
        $adminScriptsCheck.IsChecked = [bool]$script:Settings.RunScriptsAsAdmin
        $openFolderNoLaunchCheck.IsChecked = [bool]$script:Settings.OpenFolderWhenNoLaunchable
        $detailedErrorsCheck.IsChecked = [bool]$script:Settings.DetailedErrorPopups

        $settingsWindow.FindName('DefaultsButton').Add_Click({
            $autoLaunchCheck.IsChecked = $true
            $adminScriptsCheck.IsChecked = $true
            $openFolderNoLaunchCheck.IsChecked = $true
            $detailedErrorsCheck.IsChecked = $true
        })

        $settingsWindow.FindName('SaveSettingsButton').Add_Click({
            $script:Settings.AutoLaunchDownloads = [bool]$autoLaunchCheck.IsChecked
            $script:Settings.RunScriptsAsAdmin = [bool]$adminScriptsCheck.IsChecked
            $script:Settings.OpenFolderWhenNoLaunchable = [bool]$openFolderNoLaunchCheck.IsChecked
            $script:Settings.DetailedErrorPopups = [bool]$detailedErrorsCheck.IsChecked
            $settingsWindow.Close()
            Set-UiState -Title 'Settings saved' -SubTitle 'Session settings were updated.' -Chip 'Ready' -Step 'Settings' -Progress 0
        })

        $settingsWindow.FindName('CancelSettingsButton').Add_Click({ $settingsWindow.Close() })
        $settingsWindow.FindName('SettingsCloseButton').Add_Click({ $settingsWindow.Close() })
        $settingsWindow.ShowDialog() | Out-Null
    }
    catch {
        Show-DeaduniebiDialog -Title 'Deaduniebi Screen Share - Settings Error' -Message 'Could not open settings.' -Kind 'Error' -Details $_.Exception.Message
    }
}

function Get-SafeFileName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return 'download' }
    $invalid = [Regex]::Escape((-join [System.IO.Path]::GetInvalidFileNameChars()))
    $safe = [Regex]::Replace($Name, "[$invalid]", '_').Trim()
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'download' }
    return $safe
}

function Get-UrlFileName {
    param([string]$Url)
    try {
        $uri = [Uri]$Url
        $name = [System.IO.Path]::GetFileName($uri.LocalPath)
        if (-not [string]::IsNullOrWhiteSpace($name)) { return (Get-SafeFileName ([Uri]::UnescapeDataString($name))) }
    }
    catch {}
    return 'download'
}

function Get-NormalExtension {
    param([string]$FileName)
    $ext = [System.IO.Path]::GetExtension($FileName)
    if ([string]::IsNullOrWhiteSpace($ext)) { return $null }
    $known = @('.exe', '.zip', '.msi', '.ps1', '.cmd', '.bat', '.txt', '.bin', '.dll', '.json')
    if ($known -contains $ext.ToLowerInvariant()) { return $ext }
    return $null
}

function Get-PrimaryFileName {
    param($Tool)
    $firstUrlName = Get-UrlFileName (@($Tool.Links)[0])
    $ext = Get-NormalExtension $firstUrlName
    if ([string]::IsNullOrWhiteSpace($ext)) { $ext = '.exe' }
    return (Get-SafeFileName $Tool.Name) + $ext
}

function Get-ToolFolder {
    param($Tool, [switch]$Create)
    $folder = Join-Path $ToolsRoot (Get-SafeFileName $Tool.Name)
    if ($Create -and -not (Test-Path -LiteralPath $folder)) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }
    return $folder
}

function Get-SecondaryFileName {
    param([string]$Url, [int]$Index)
    $name = Get-UrlFileName $Url
    if ($name -eq 'download') { $name = 'download_' + $Index + '.bin' }
    return $name
}

function Get-DownloadTargets {
    param($Tool)
    $destDir = Get-ToolFolder -Tool $Tool -Create
    $links = @($Tool.Links)
    $targets = @()
    for ($i = 0; $i -lt $links.Count; $i++) {
        if ($i -eq 0) { $fileName = Get-PrimaryFileName $Tool }
        else { $fileName = Get-SecondaryFileName -Url $links[$i] -Index ($i + 1) }
        $targets += [pscustomobject]@{
            Url = [string]$links[$i]
            Path = (Join-Path $destDir $fileName)
            Directory = $destDir
            FileName = $fileName
            Index = ($i + 1)
            Total = $links.Count
        }
    }
    return $targets
}

function Get-ItemKey {
    param($Item)
    return ($Item.Category + '::' + $Item.Name)
}

function Get-CategoryItemCount {
    param([string]$Key)
    if ($Key -eq 'scripts') { return $ScriptActions.Count }
    if ($Key -eq 'credits') { return $Credits.Count }
    return @($DownloadTools | Where-Object { $_.Category -eq $Key }).Count
}

function Get-SearchQuery {
    if ($SearchBox -and -not [string]::IsNullOrWhiteSpace($SearchBox.Text)) { return $SearchBox.Text.Trim() }
    return ''
}

function Initialize-SearchIndex {
    if ($script:SearchIndex -ne $null) { return }
    $items = @()
    $items += @($DownloadTools)
    $items += @($ScriptActions)
    $index = New-Object System.Collections.Generic.List[object]
    foreach ($item in $items) {
        $category = $Categories | Where-Object { $_.Key -eq $item.Category } | Select-Object -First 1
        $parts = New-Object System.Collections.Generic.List[string]
        $parts.Add([string]$item.Name) | Out-Null
        $parts.Add([string]$item.Description) | Out-Null
        $parts.Add([string]$item.Category) | Out-Null
        if ($category) {
            $parts.Add([string]$category.Label) | Out-Null
            $parts.Add([string]$category.Header) | Out-Null
        }
        $parts.Add((@($item.Links) -join ' ')) | Out-Null
        $index.Add([pscustomobject]@{
            Item = $item
            Name = [string]$item.Name
            NameLower = ([string]$item.Name).ToLowerInvariant()
            Blob = ($parts -join ' ').ToLowerInvariant()
        }) | Out-Null
    }
    $script:SearchIndex = $index
}

function Get-SearchItems {
    param([string]$Query)
    Initialize-SearchIndex
    $terms = @($Query.ToLowerInvariant() -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($terms.Count -eq 0) { return @() }
    $queryLower = $Query.ToLowerInvariant()

    $found = @($script:SearchIndex | Where-Object {
        $entry = $_
        $ok = $true
        foreach ($term in $terms) {
            if ($entry.Blob.IndexOf($term, [System.StringComparison]::Ordinal) -lt 0) { $ok = $false; break }
        }
        $ok
    })

    return @($found | Sort-Object @{ Expression = {
        if ($_.NameLower.StartsWith($queryLower, [System.StringComparison]::Ordinal)) { 0 }
        elseif ($_.NameLower.IndexOf($queryLower, [System.StringComparison]::Ordinal) -ge 0) { 1 }
        else { 2 }
    }}, Name | ForEach-Object { $_.Item })
}

function Get-SelectedItems {
    $query = Get-SearchQuery
    if (-not [string]::IsNullOrWhiteSpace($query)) { return @(Get-SearchItems -Query $query) }
    if ($script:CurrentCategory -eq 'scripts') { return @($ScriptActions | Sort-Object Name) }
    if ($script:CurrentCategory -eq 'credits') { return @($Credits) }
    $items = @($DownloadTools | Where-Object { $_.Category -eq $script:CurrentCategory })
    if ($script:CurrentCategory -ne 'dependencies') { $items = @($items | Sort-Object Name) }
    return $items
}

function Update-SearchChrome {
    $query = Get-SearchQuery
    if ([string]::IsNullOrWhiteSpace($query)) { $ClearSearchButton.Visibility = 'Collapsed' }
    else { $ClearSearchButton.Visibility = 'Visible' }
}

function Request-SearchRender {
    Update-SearchChrome
    if (-not $script:SearchRenderTimer) {
        $script:SearchRenderTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:SearchRenderTimer.Interval = [TimeSpan]::FromMilliseconds(230)
        $script:SearchRenderTimer.Add_Tick({
            $script:SearchRenderTimer.Stop()
            Render-CurrentCategory
        })
    }
    $script:SearchRenderTimer.Stop()
    $script:SearchRenderTimer.Start()
}

function Clear-SearchBox {
    $script:SuppressSearchTextChanged = $true
    $SearchBox.Text = ''
    $script:SuppressSearchTextChanged = $false
    if ($script:SearchRenderTimer) { $script:SearchRenderTimer.Stop() }
    Update-SearchChrome
    Render-CurrentCategory
    $SearchBox.Focus() | Out-Null
}

function Update-CategoryButtons {
    foreach ($category in $Categories) {
        $key = $category.Key
        if (-not $script:CategoryButtons.ContainsKey($key)) { continue }
        $button = $script:CategoryButtons[$key]
        $button.Content = "$($category.Label) ($(Get-CategoryItemCount -Key $key))"
        if ($key -eq $script:CurrentCategory -and [string]::IsNullOrWhiteSpace((Get-SearchQuery))) { Set-ButtonTone -Button $button -Tone 'primary' }
        else { Set-ButtonTone -Button $button -Tone 'secondary' }
    }
}

function New-TextBlock {
    param([string]$Text, [double]$Size = 12, [string]$Color = '#D6D6D6', [string]$Weight = 'Normal')
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = $Size
    $tb.Foreground = Get-Brush $Color
    $tb.FontWeight = $Weight
    $tb.TextWrapping = 'Wrap'
    return $tb
}

function New-RowBorder {
    $border = New-Object System.Windows.Controls.Border
    $border.Background = Get-Brush '#131313'
    $border.BorderBrush = Get-Brush '#262626'
    $border.BorderThickness = New-Object System.Windows.Thickness 1
    $border.CornerRadius = New-Object System.Windows.CornerRadius 3
    $border.Margin = New-Object System.Windows.Thickness 0,0,0,6
    return $border
}

function Get-ItemActionLabel {
    param($Item)
    if ($Item.Kind -eq 'Script') { return 'Run' }
    if ($Item.Kind -eq 'Link') { return 'Open' }
    $primaryPath = Join-Path (Get-ToolFolder -Tool $Item) (Get-PrimaryFileName $Item)
    if (Test-Path -LiteralPath $primaryPath) { return 'Launch' }
    return 'Download'
}

function New-ToolRow {
    param($Item)
    $border = New-RowBorder

    $grid = New-Object System.Windows.Controls.Grid
    $colMain = New-Object System.Windows.Controls.ColumnDefinition
    $colMain.Width = New-Object System.Windows.GridLength 1,([System.Windows.GridUnitType]::Star)
    $colAction = New-Object System.Windows.Controls.ColumnDefinition
    $colAction.Width = [System.Windows.GridLength]::Auto
    $grid.ColumnDefinitions.Add($colMain) | Out-Null
    $grid.ColumnDefinitions.Add($colAction) | Out-Null
    $rowMain = New-Object System.Windows.Controls.RowDefinition
    $rowMain.Height = [System.Windows.GridLength]::Auto
    $rowBar = New-Object System.Windows.Controls.RowDefinition
    $rowBar.Height = New-Object System.Windows.GridLength 3
    $grid.RowDefinitions.Add($rowMain) | Out-Null
    $grid.RowDefinitions.Add($rowBar) | Out-Null

    $text = New-Object System.Windows.Controls.StackPanel
    $text.Margin = New-Object System.Windows.Thickness 16,12,12,12
    $text.Children.Add((New-TextBlock -Text $Item.Name -Size 14 -Color '#FFFFFF' -Weight 'SemiBold')) | Out-Null
    $desc = New-TextBlock -Text $Item.Description -Size 12 -Color '#8A8A8A'
    $desc.Margin = New-Object System.Windows.Thickness 0,3,0,0
    $text.Children.Add($desc) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($text, 0)
    $grid.Children.Add($text) | Out-Null

    $action = New-Object System.Windows.Controls.Button
    $action.Style = $window.Resources['FlatButtonStyle']
    $action.Width = 110
    $action.Height = 32
    $action.Margin = New-Object System.Windows.Thickness 0,0,14,0
    $action.VerticalAlignment = 'Center'
    $action.Content = Get-ItemActionLabel -Item $Item
    Set-ButtonTone -Button $action -Tone 'secondary'
    [System.Windows.Controls.Grid]::SetColumn($action, 1)
    $grid.Children.Add($action) | Out-Null

    $progress = New-Object System.Windows.Controls.ProgressBar
    $progress.Minimum = 0
    $progress.Maximum = 100
    $progress.Value = 0
    $progress.Height = 3
    $progress.Foreground = Get-Brush '#FFFFFF'
    $progress.Background = Get-Brush '#1E1E1E'
    $progress.BorderThickness = New-Object System.Windows.Thickness 0
    [System.Windows.Controls.Grid]::SetRow($progress, 1)
    [System.Windows.Controls.Grid]::SetColumnSpan($progress, 2)
    $grid.Children.Add($progress) | Out-Null

    $key = Get-ItemKey $Item
    $script:CardProgressBars[$key] = $progress
    $script:CardButtons[$key] = $action

    if ($Item.Kind -eq 'Script' -or $Item.Kind -eq 'Link') { $progress.Visibility = 'Hidden' }
    elseif ($action.Content -eq 'Launch') { $progress.Value = 100 }

    $itemForClick = $Item
    $action.Add_Click({ Invoke-ItemAction -Item $itemForClick }.GetNewClosure())
    $border.Child = $grid
    return $border
}

function New-CreditRow {
    param($Credit)
    $border = New-RowBorder
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = New-Object System.Windows.Thickness 16,12,16,12
    $stack.Children.Add((New-TextBlock -Text $Credit.Name -Size 14 -Color '#FFFFFF' -Weight 'SemiBold')) | Out-Null
    $role = New-TextBlock -Text $Credit.Role -Size 12 -Color '#BDBDBD'
    $role.Margin = New-Object System.Windows.Thickness 0,4,0,0
    $stack.Children.Add($role) | Out-Null
    $source = New-TextBlock -Text $Credit.Source -Size 11 -Color '#6E6E6E'
    $source.Margin = New-Object System.Windows.Thickness 0,4,0,0
    $stack.Children.Add($source) | Out-Null
    $border.Child = $stack
    return $border
}

function Render-CurrentCategory {
    $ToolListPanel.Children.Clear()
    $script:CardProgressBars.Clear()
    $script:CardButtons.Clear()

    $query = Get-SearchQuery
    $searchActive = -not [string]::IsNullOrWhiteSpace($query)
    $items = @(Get-SelectedItems)
    $isCredits = $false

    if ($searchActive) {
        $SelectedCategoryText.Text = 'Search Results'
        $SelectedCategoryDescription.Text = "Matches for '$query' across every category."
        $CategoryHeaderText.Text = 'Search covers tool names, categories, descriptions, authors, and source links.'
        $SearchHintText.Text = "Showing $($items.Count) match(es). Clear the search to return to the category."
        $ToolCountText.Text = $items.Count.ToString()
        $showDownload = (@($items | Where-Object { $_.Kind -eq 'Download' }).Count -gt 0)
    }
    else {
        $category = $Categories | Where-Object { $_.Key -eq $script:CurrentCategory } | Select-Object -First 1
        if (-not $category) { return }
        $SelectedCategoryText.Text = $category.Label
        $SelectedCategoryDescription.Text = $category.Description
        $CategoryHeaderText.Text = $category.Header
        $SearchHintText.Text = 'Search by tool name, artifact, or author.'
        $ToolCountText.Text = (Get-CategoryItemCount -Key $category.Key).ToString()
        $isCredits = ($category.Key -eq 'credits')
        $showDownload = -not ($category.Key -eq 'scripts' -or $isCredits)
    }

    if ($showDownload) {
        $DownloadAllButton.Visibility = 'Visible'
        $CancelDownloadButton.Visibility = 'Visible'
    }
    else {
        $DownloadAllButton.Visibility = 'Collapsed'
        $CancelDownloadButton.Visibility = 'Collapsed'
    }

    if ($items.Count -eq 0) {
        $emptyMessage = if ($searchActive) { "No tools matched '$query'." } else { 'No items in this category.' }
        $ToolListPanel.Children.Add((New-TextBlock -Text $emptyMessage -Size 14 -Color '#8A8A8A')) | Out-Null
    }
    elseif ($isCredits) {
        foreach ($credit in $items) { $ToolListPanel.Children.Add((New-CreditRow -Credit $credit)) | Out-Null }
    }
    else {
        foreach ($item in $items) { $ToolListPanel.Children.Add((New-ToolRow -Item $item)) | Out-Null }
    }

    Update-CategoryButtons
    Refresh-Ui
}

function Switch-Category {
    param([string]$Key)
    $script:CurrentCategory = $Key
    if (-not [string]::IsNullOrWhiteSpace($SearchBox.Text)) {
        $script:SuppressSearchTextChanged = $true
        $SearchBox.Text = ''
        $script:SuppressSearchTextChanged = $false
        if ($script:SearchRenderTimer) { $script:SearchRenderTimer.Stop() }
        Update-SearchChrome
    }
    Render-CurrentCategory
    Set-UiState -Title 'Ready' -SubTitle "Showing $($SelectedCategoryText.Text)." -Chip 'Ready' -Step 'Waiting' -Progress 0
}

function Add-CategoryButton {
    param($Category)
    $button = New-Object System.Windows.Controls.Button
    $button.Style = $window.Resources['FlatButtonStyle']
    $button.Height = 32
    $button.Margin = New-Object System.Windows.Thickness 0,0,6,6
    $button.Content = $Category.Label
    $button.ToolTip = $Category.Header
    Set-ButtonTone -Button $button -Tone 'secondary'
    $key = $Category.Key
    $button.Add_Click({ Switch-Category -Key $key }.GetNewClosure())
    $CategoryButtonPanel.Children.Add($button) | Out-Null
    $script:CategoryButtons[$Category.Key] = $button
}

function Set-CardDownloading {
    param($Job)
    $key = $Job.Category + '::' + $Job.Name
    if ($script:CardProgressBars.ContainsKey($key)) { $script:CardProgressBars[$key].IsIndeterminate = $true }
    if ($script:CardButtons.ContainsKey($key)) { $script:CardButtons[$key].Content = 'Working' }
}

function Set-CardComplete {
    param($Job, [bool]$Success)
    $key = $Job.Category + '::' + $Job.Name
    if ($script:CardProgressBars.ContainsKey($key)) {
        $bar = $script:CardProgressBars[$key]
        $bar.IsIndeterminate = $false
        $bar.Value = if ($Success) { 100 } else { 0 }
    }
    if ($script:CardButtons.ContainsKey($key)) {
        $script:CardButtons[$key].Content = if ($Success) { 'Launch' } else { 'Retry' }
    }
}

function New-DownloadJob {
    param($Tool, [bool]$Batch)
    $targets = @(Get-DownloadTargets -Tool $Tool)
    $toolDir = Get-ToolFolder -Tool $Tool -Create
    $primaryPath = $null
    $isZip = $false
    if ($targets.Count -gt 0) {
        $primaryPath = [string]$targets[0].Path
        $isZip = ([System.IO.Path]::GetExtension($primaryPath).ToLowerInvariant() -eq '.zip')
    }
    return [pscustomobject]@{
        Name = [string]$Tool.Name
        Description = [string]$Tool.Description
        Category = [string]$Tool.Category
        Batch = [bool]$Batch
        Directory = $toolDir
        Targets = $targets
        PrimaryPath = $primaryPath
        IsZip = $isZip
    }
}

function Start-NextDownload {
    if ($script:CurrentWorker -ne $null) { return }
    if ($script:DownloadQueue.Count -eq 0) {
        $CancelDownloadButton.IsEnabled = $false
        return
    }

    $job = $script:DownloadQueue.Dequeue()
    $script:ActiveDownloadJob = $job
    $CancelDownloadButton.IsEnabled = $true
    Set-CardDownloading -Job $job
    Set-UiState -Title 'Downloading tool' -SubTitle "Downloading $($job.Name)." -Chip 'Downloading' -Step $job.Name -Progress 0
    $MainProgressBar.IsIndeterminate = $true
    $ProgressLabel.Text = '...'

    try {
        $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $runspace.ApartmentState = 'STA'
        $runspace.ThreadOptions = 'ReuseThread'
        $runspace.Open()
        $runspace.SessionStateProxy.SetVariable('downloadJob', $job)

        $powerShell = [powershell]::Create()
        $powerShell.Runspace = $runspace
        $null = $powerShell.AddScript({
            $jobArg = $downloadJob
            $result = [pscustomobject]@{
                Job = $jobArg
                Success = $false
                Cancelled = $false
                Error = $null
                ErrorType = $null
                ErrorUrl = $null
                ErrorPath = $null
                PrimaryPath = $jobArg.PrimaryPath
                IsZip = $jobArg.IsZip
                Directory = $jobArg.Directory
                LaunchPath = $null
                DownloadedPaths = @()
            }

            function Resolve-DownloadTarget {
                param($Target)
                $url = [string]$Target.Url
                $resolved = [pscustomobject]@{ Url = $url; FileName = [string]$Target.FileName; Path = [string]$Target.Path }
                $apiUrl = $null
                $apiRequired = $true
                if ($url -match 'github\.com/([^/]+)/([^/]+)/releases/latest/?$') {
                    $apiUrl = "https://api.github.com/repos/$($Matches[1])/$($Matches[2])/releases/latest"
                }
                elseif ($url -match 'github\.com/([^/]+)/([^/]+)/releases/?$') {
                    $apiUrl = "https://api.github.com/repos/$($Matches[1])/$($Matches[2])/releases/latest"
                }
                elseif ($url -match 'github\.com/([^/]+)/([^/]+)/releases/tag/(.+)$') {
                    $tag = [Uri]::EscapeDataString(([Uri]::UnescapeDataString($Matches[3])).TrimEnd('/'))
                    $apiUrl = "https://api.github.com/repos/$($Matches[1])/$($Matches[2])/releases/tags/$tag"
                }
                elseif ($url -match 'github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)$') {
                    $tag = [Uri]::EscapeDataString(([Uri]::UnescapeDataString($Matches[3])).TrimEnd('/'))
                    $apiUrl = "https://api.github.com/repos/$($Matches[1])/$($Matches[2])/releases/tags/$tag"
                    $apiRequired = $false
                }

                if ($apiUrl) {
                    try {
                        $release = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'Deaduniebi Screen Share' } -ErrorAction Stop
                        $asset = $release.assets |
                            Where-Object { $_.name -match '\.(exe|zip|msi|cmd|bat)$' } |
                            Sort-Object @{ Expression = {
                                switch ([System.IO.Path]::GetExtension($_.name).ToLowerInvariant()) {
                                    '.exe' { 0 }
                                    '.msi' { 1 }
                                    '.zip' { 2 }
                                    '.cmd' { 3 }
                                    '.bat' { 4 }
                                    default { 9 }
                                }
                            }}, name |
                            Select-Object -First 1
                        if (-not $asset) {
                            if ($apiRequired) { throw "No downloadable GitHub release asset was found at $apiUrl." }
                        }
                        else {
                            $resolved.Url = [string]$asset.browser_download_url
                            $resolved.FileName = [string]$asset.name
                            $resolved.Path = Join-Path ([string]$Target.Directory) ([string]$asset.name)
                        }
                    }
                    catch {
                        if ($apiRequired) { throw }
                    }
                }
                return $resolved
            }

            function Save-UrlToFile {
                param([string]$Uri, [string]$OutFile)
                $outDir = Split-Path -Parent $OutFile
                if (-not (Test-Path -LiteralPath $outDir)) {
                    New-Item -Path $outDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                }
                $tempFile = "$OutFile.download"
                if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue }
                $client = New-Object System.Net.WebClient
                $client.Headers.Add('User-Agent', 'Deaduniebi Screen Share')
                try {
                    $client.DownloadFile($Uri, $tempFile)
                    if (Test-Path -LiteralPath $OutFile) { Remove-Item -LiteralPath $OutFile -Force -ErrorAction Stop }
                    Move-Item -LiteralPath $tempFile -Destination $OutFile -Force -ErrorAction Stop
                }
                finally {
                    $client.Dispose()
                    if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue }
                }
            }

            function Find-Launchable {
                param([string]$Directory, [string]$PreferredPath)
                if ($PreferredPath -and (Test-Path -LiteralPath $PreferredPath)) {
                    if (@('.exe', '.msi', '.cmd', '.bat') -contains [System.IO.Path]::GetExtension($PreferredPath).ToLowerInvariant()) {
                        return $PreferredPath
                    }
                }
                $launchable = Get-ChildItem -Path $Directory -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { @('.exe', '.msi', '.cmd', '.bat') -contains $_.Extension.ToLowerInvariant() } |
                    Sort-Object @{ Expression = {
                        switch ($_.Extension.ToLowerInvariant()) {
                            '.exe' { 0 }
                            '.msi' { 1 }
                            '.cmd' { 2 }
                            '.bat' { 3 }
                            default { 9 }
                        }
                    }}, FullName |
                    Select-Object -First 1
                if ($launchable) { return $launchable.FullName }
                return $null
            }

            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                if (-not (Test-Path -LiteralPath $jobArg.Directory)) {
                    New-Item -Path $jobArg.Directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
                }

                foreach ($target in $jobArg.Targets) {
                    $result.ErrorUrl = $target.Url
                    $result.ErrorPath = $target.Path

                    $resolvedTarget = Resolve-DownloadTarget -Target $target
                    $target.Url = $resolvedTarget.Url
                    $target.FileName = $resolvedTarget.FileName
                    $target.Path = $resolvedTarget.Path
                    $result.ErrorUrl = $resolvedTarget.Url
                    $result.ErrorPath = $resolvedTarget.Path

                    if ($target.Index -eq 1) {
                        $result.PrimaryPath = $resolvedTarget.Path
                        $result.IsZip = ([System.IO.Path]::GetExtension($resolvedTarget.Path).ToLowerInvariant() -eq '.zip')
                    }

                    if (-not (Test-Path -LiteralPath $resolvedTarget.Path)) {
                        Save-UrlToFile -Uri $resolvedTarget.Url -OutFile $resolvedTarget.Path
                    }
                    $result.DownloadedPaths += [string]$resolvedTarget.Path
                }

                if ($result.PrimaryPath -and ([System.IO.Path]::GetExtension($result.PrimaryPath).ToLowerInvariant() -eq '.zip')) {
                    Expand-Archive -Path $result.PrimaryPath -DestinationPath $jobArg.Directory -Force -ErrorAction Stop
                }

                $result.LaunchPath = Find-Launchable -Directory $jobArg.Directory -PreferredPath $result.PrimaryPath
                $result.Success = $true
                $result
            }
            catch {
                $result.Error = $_.Exception.Message
                if ($_.Exception) { $result.ErrorType = $_.Exception.GetType().FullName }
                $result
            }
        })

        $handle = $powerShell.BeginInvoke()
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(250)

        $script:CurrentWorker = [pscustomobject]@{
            PowerShell = $powerShell
            Runspace = $runspace
            Handle = $handle
            Timer = $timer
            Job = $job
            CancelRequested = $false
        }

        $timer.Add_Tick({
            if (-not $script:CurrentWorker) { return }
            if (-not $script:CurrentWorker.Handle.IsCompleted) { return }

            $workerState = $script:CurrentWorker
            $workerState.Timer.Stop()
            $result = $null
            $wasCancelled = [bool]$workerState.CancelRequested
            $wj = $workerState.Job

            try {
                if ($wasCancelled) {
                    $result = [pscustomobject]@{ Job = $wj; Success = $false; Cancelled = $true; Error = $null; ErrorType = $null; ErrorUrl = $null; ErrorPath = $wj.Directory; PrimaryPath = $wj.PrimaryPath; IsZip = $wj.IsZip; Directory = $wj.Directory; LaunchPath = $null; DownloadedPaths = @() }
                }
                else {
                    $output = $workerState.PowerShell.EndInvoke($workerState.Handle)
                    if ($output -and $output.Count -gt 0) { $result = $output[$output.Count - 1] }
                    if (-not $result) {
                        $result = [pscustomobject]@{ Job = $wj; Success = $false; Cancelled = $false; Error = 'The download worker finished without a result.'; ErrorType = 'MissingResult'; ErrorUrl = $null; ErrorPath = $wj.Directory; PrimaryPath = $wj.PrimaryPath; IsZip = $wj.IsZip; Directory = $wj.Directory; LaunchPath = $null; DownloadedPaths = @() }
                    }
                }
            }
            catch {
                $result = [pscustomobject]@{ Job = $wj; Success = $false; Cancelled = $wasCancelled; Error = $_.Exception.Message; ErrorType = $_.Exception.GetType().FullName; ErrorUrl = $null; ErrorPath = $wj.Directory; PrimaryPath = $wj.PrimaryPath; IsZip = $wj.IsZip; Directory = $wj.Directory; LaunchPath = $null; DownloadedPaths = @() }
            }
            finally {
                try { $workerState.PowerShell.Dispose() } catch {}
                try { $workerState.Runspace.Close() } catch {}
                try { $workerState.Runspace.Dispose() } catch {}
            }

            $jobDone = $result.Job
            $script:CurrentWorker = $null
            $script:ActiveDownloadJob = $null
            $MainProgressBar.IsIndeterminate = $false
            $CancelDownloadButton.IsEnabled = $false

            if (-not $jobDone) {
                Set-UiState -Title 'Download stopped' -SubTitle 'The download ended without a job result.' -Chip 'Error' -Step 'Stopped' -Progress 0
                Start-NextDownload
                return
            }

            if ($result.Cancelled) {
                Set-CardComplete -Job $jobDone -Success $false
                Set-UiState -Title 'Download cancelled' -SubTitle "$($jobDone.Name) was cancelled." -Chip 'Cancelled' -Step 'Cancelled' -Progress 0
            }
            elseif ($result.Success) {
                Set-CardComplete -Job $jobDone -Success $true
                Set-UiState -Title 'Download complete' -SubTitle "$($jobDone.Name) saved successfully." -Chip 'Ready' -Step 'Completed' -Progress 100
                if (-not $jobDone.Batch -and $result.LaunchPath -and [bool]$script:Settings.AutoLaunchDownloads) {
                    Start-DownloadedTool -Path $result.LaunchPath -Name $jobDone.Name -Directory $result.Directory
                }
                elseif (-not $jobDone.Batch -and $result.LaunchPath) {
                    Set-UiState -Title 'Downloaded' -SubTitle "$($jobDone.Name) was saved. Auto-launch is disabled." -Chip 'Ready' -Step 'Downloaded' -Progress 100
                }
                elseif (-not $jobDone.Batch -and $result.Directory) {
                    Set-UiState -Title 'Downloaded' -SubTitle "$($jobDone.Name) was saved, but no launchable file was found." -Chip 'Ready' -Step 'Open folder' -Progress 100
                    if ([bool]$script:Settings.OpenFolderWhenNoLaunchable) {
                        Start-Process 'explorer.exe' -ArgumentList $result.Directory
                    }
                }
            }
            else {
                $message = if ($result.Error) { $result.Error } else { 'Unknown download error.' }
                Set-CardComplete -Job $jobDone -Success $false
                Set-UiState -Title 'Download failed' -SubTitle $message -Chip 'Error' -Step 'Failed' -Progress 0
                Show-ErrorDetails -Title 'Deaduniebi Screen Share - Download Error' -Action 'Download' -ToolName $jobDone.Name -Message $message -Url $result.ErrorUrl -Path $result.ErrorPath -Extra $result.ErrorType
            }

            Start-NextDownload
        })

        $timer.Start()
    }
    catch {
        $script:CurrentWorker = $null
        $script:ActiveDownloadJob = $null
        $MainProgressBar.IsIndeterminate = $false
        $CancelDownloadButton.IsEnabled = $false
        Set-CardComplete -Job $job -Success $false
        Set-UiState -Title 'Download failed' -SubTitle $_.Exception.Message -Chip 'Error' -Step 'Failed' -Progress 0
        Show-ErrorDetails -Title 'Deaduniebi Screen Share - Download Error' -Action 'Start download worker' -ToolName $job.Name -Message $_.Exception.Message -Url '' -Path $job.Directory -Extra $_.Exception.GetType().FullName
        Start-NextDownload
    }
}

function Queue-Download {
    param($Tool, [bool]$Batch)
    try {
        $job = New-DownloadJob -Tool $Tool -Batch $Batch
        $script:DownloadQueue.Enqueue($job)
        Start-NextDownload
    }
    catch {
        Set-UiState -Title 'Queue failed' -SubTitle $_.Exception.Message -Chip 'Error' -Step 'Failed' -Progress 0
        Show-ErrorDetails -Title 'Deaduniebi Screen Share - Queue Error' -Action 'Queue download' -ToolName $Tool.Name -Message $_.Exception.Message -Url '' -Path $ToolsRoot -Extra $_.Exception.GetType().FullName
    }
}

function Start-DownloadedTool {
    param([string]$Path, [string]$Name, [string]$Directory)
    try {
        if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
        if ([string]::IsNullOrWhiteSpace($Directory)) { $Directory = Split-Path -Parent $Path }
        $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        if ($extension -eq '.cmd' -or $extension -eq '.bat') {
            $psi.FileName = 'cmd.exe'
            $psi.Arguments = '/k "' + $Path + '"'
        }
        else { $psi.FileName = $Path }
        $psi.WorkingDirectory = $Directory
        $psi.UseShellExecute = $true
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        Set-UiState -Title 'Tool launched' -SubTitle "$Name launched successfully." -Chip 'Ready' -Step 'Launched' -Progress 100
    }
    catch {
        Set-UiState -Title 'Launch failed' -SubTitle $_.Exception.Message -Chip 'Error' -Step 'Failed' -Progress 0
        Show-ErrorDetails -Title 'Deaduniebi Screen Share - Launch Error' -Action 'Launch downloaded tool' -ToolName $Name -Message $_.Exception.Message -Url '' -Path $Path -Extra $_.Exception.GetType().FullName
    }
}

function Start-ScriptAction {
    param($ScriptItem)
    $ps1Path = $null
    try {
        $runMode = ''
        if ($ScriptItem -and $ScriptItem.Contains('RunMode')) { $runMode = [string]$ScriptItem.RunMode }
        if ($runMode -eq 'Cmd') {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'cmd.exe'
            $psi.Arguments = '/k title Deaduniebi Screen Share & ' + [string]$ScriptItem.Command
            $psi.UseShellExecute = $true
            if ([bool]$script:Settings.RunScriptsAsAdmin) { $psi.Verb = 'runas' }
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            Set-UiState -Title 'Script launched' -SubTitle "$($ScriptItem.Name) opened in a command window." -Chip 'Running' -Step $ScriptItem.Name -Progress 100
            return
        }

        if (-not (Test-Path -LiteralPath $TempRoot)) { New-Item -Path $TempRoot -ItemType Directory -Force | Out-Null }
        $fileName = 'Deaduniebi_script_' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss_fff') + '.ps1'
        $ps1Path = Join-Path $TempRoot $fileName
        $header = "`$Host.UI.RawUI.WindowTitle = 'Deaduniebi Screen Share - $($ScriptItem.Name -replace "'", "''")'`r`n"
        $body = $header + $ScriptItem.Command + "`r`n"
        $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
        [System.IO.File]::WriteAllText($ps1Path, $body, $utf8NoBom)

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'cmd.exe'
        $psi.Arguments = '/k title Deaduniebi Screen Share & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $ps1Path + '"'
        $psi.UseShellExecute = $true
        if ([bool]$script:Settings.RunScriptsAsAdmin) { $psi.Verb = 'runas' }
        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($proc) {
            $proc.EnableRaisingEvents = $true
            Register-ObjectEvent -InputObject $proc -EventName Exited -Action {
                Remove-Item -LiteralPath $Event.MessageData -Force -ErrorAction SilentlyContinue
            } -MessageData $ps1Path | Out-Null
        }
        Set-UiState -Title 'Script launched' -SubTitle "$($ScriptItem.Name) opened in a console window." -Chip 'Running' -Step $ScriptItem.Name -Progress 100
    }
    catch {
        Set-UiState -Title 'Script failed' -SubTitle $_.Exception.Message -Chip 'Error' -Step 'Failed' -Progress 0
        Show-ErrorDetails -Title 'Deaduniebi Screen Share - Script Error' -Action 'Run script' -ToolName $ScriptItem.Name -Message $_.Exception.Message -Url '' -Path $ps1Path -Extra $_.Exception.GetType().FullName
    }
}

function Invoke-ItemAction {
    param($Item)
    if ($Item.Kind -eq 'Script') {
        Start-ScriptAction -ScriptItem $Item
        return
    }
    if ($Item.Kind -eq 'Link') {
        $url = @($Item.Links)[0]
        try {
            Start-Process $url
            Set-UiState -Title 'Opened link' -SubTitle "$($Item.Name) opened in your browser." -Chip 'Ready' -Step 'Browser' -Progress 0
        }
        catch {
            Show-ErrorDetails -Title 'Deaduniebi Screen Share - Link Error' -Action 'Open link' -ToolName $Item.Name -Message $_.Exception.Message -Url $url -Path '' -Extra $_.Exception.GetType().FullName
        }
        return
    }
    Queue-Download -Tool $Item -Batch:$false
}

function Download-AllCurrentCategory {
    if ([string]::IsNullOrWhiteSpace((Get-SearchQuery)) -and ($script:CurrentCategory -eq 'scripts' -or $script:CurrentCategory -eq 'credits')) { return }
    $items = @(Get-SelectedItems | Where-Object { $_.Kind -eq 'Download' })
    foreach ($item in $items) { Queue-Download -Tool $item -Batch:$true }
}

function Cancel-CurrentDownload {
    $script:DownloadQueue.Clear()
    if ($script:CurrentWorker -ne $null) {
        $script:CurrentWorker.CancelRequested = $true
        try { $script:CurrentWorker.PowerShell.Stop() } catch {}
        $CancelDownloadButton.IsEnabled = $false
    }
}

function Open-ToolsFolder {
    try {
        if (-not (Test-Path -LiteralPath $ToolsRoot)) { New-Item -Path $ToolsRoot -ItemType Directory -Force | Out-Null }
        Start-Process 'explorer.exe' -ArgumentList $ToolsRoot
    }
    catch {
        Show-ErrorDetails -Title 'Deaduniebi Screen Share - Folder Error' -Action 'Open tools folder' -ToolName '' -Message $_.Exception.Message -Url '' -Path $ToolsRoot -Extra $_.Exception.GetType().FullName
    }
}

function Clear-DeaduniebiTools {
    try {
        Cancel-CurrentDownload
        $script:CurrentWorker = $null
        $script:ActiveDownloadJob = $null

        if (-not (Test-Path -LiteralPath $ToolsRoot)) { New-Item -Path $ToolsRoot -ItemType Directory -Force | Out-Null }

        $items = @(Get-ChildItem -LiteralPath $ToolsRoot -Force -ErrorAction SilentlyContinue)
        foreach ($item in $items) { Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop }

        if (Test-Path -LiteralPath $TempRoot) {
            Get-ChildItem -LiteralPath $TempRoot -Filter 'Deaduniebi_script_*.ps1' -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }

        Set-UiState -Title 'Tools cleared' -SubTitle "Removed $($items.Count) item(s) from the deaduniebitools folder." -Chip 'Ready' -Step 'Cleared' -Progress 0
        Render-CurrentCategory
        Show-DeaduniebiDialog -Title 'Deaduniebi Screen Share - Tools Cleared' -Message 'All downloaded tools were removed from the deaduniebitools folder.' -Kind 'Info'
    }
    catch {
        Set-UiState -Title 'Clear failed' -SubTitle $_.Exception.Message -Chip 'Error' -Step 'Failed' -Progress 0
        Show-ErrorDetails -Title 'Deaduniebi Screen Share - Clear Tools Error' -Action 'Clear tools folder' -ToolName '' -Message $_.Exception.Message -Url '' -Path $ToolsRoot -Extra $_.Exception.GetType().FullName
    }
}

foreach ($category in $Categories) { Add-CategoryButton -Category $category }

$HeaderBar.Add_MouseLeftButtonDown({ try { $window.DragMove() } catch {} })
$CloseButton.Add_Click({ $window.Close() })
$MinButton.Add_Click({ $window.WindowState = 'Minimized' })
$DownloadAllButton.Add_Click({ Download-AllCurrentCategory })
$CancelDownloadButton.Add_Click({ Cancel-CurrentDownload })
$OpenToolsFolderButton.Add_Click({ Open-ToolsFolder })
$ClearToolsButton.Add_Click({ Clear-DeaduniebiTools })
$SettingsButton.Add_Click({ Show-DeaduniebiSettings })
$SearchBox.Add_TextChanged({
    if (-not [bool]$script:SuppressSearchTextChanged) { Request-SearchRender }
})
$ClearSearchButton.Add_Click({ Clear-SearchBox })

$window.Add_PreviewKeyDown({
    param($sender, $e)
    if ($e.Key -eq 'Escape') {
        if (-not [string]::IsNullOrWhiteSpace($SearchBox.Text) -and $SearchBox.IsKeyboardFocusWithin) {
            Clear-SearchBox
            $e.Handled = $true
            return
        }
        if ($script:CurrentWorker -ne $null) { Cancel-CurrentDownload }
        $e.Handled = $true
    }
})

Update-Splash -Text 'Indexing tools' -Progress 70

Render-CurrentCategory
Set-UiState -Title 'Ready' -SubTitle 'Pick a category above.' -Chip 'Ready' -Step 'Waiting' -Progress 0

foreach ($warning in $script:StartupWarnings) { $SubStatusText.Text = $warning }

Update-Splash -Text 'Ready' -Progress 100
Start-Sleep -Milliseconds 200
if ($SplashWindow) { $SplashWindow.Close() }

$window.ShowDialog() | Out-Null
