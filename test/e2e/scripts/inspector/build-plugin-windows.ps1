param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'

$PluginRepo = if ($env:PLUGIN_REPO) { $env:PLUGIN_REPO } else { 'https://github.com/status-im/status-qml-inspector.git' }
$PluginRef = if ($env:PLUGIN_REF) { $env:PLUGIN_REF } else { 'edbf498b167750d2d08aae8093de07339219a507' }

function Fail([string]$Message) {
    [Console]::Error.WriteLine("setup: $Message")
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail 'install git' }
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) { Fail 'install CMake' }

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) { Fail 'install Visual Studio 2022 with the C++ workload' }
$vs = & $vswhere -latest -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { Fail 'install Visual Studio 2022 with the C++ workload' }
$devCmd = Join-Path $vs 'Common7\Tools\VsDevCmd.bat'
cmd /c "`"$devCmd`" -no_logo -arch=x64 >nul && set" | ForEach-Object {
    if ($_ -match '^(.*?)=(.*)$' -and $Matches[1]) {
        [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
}

$out = (New-Item -ItemType Directory -Force -Path $OutDir).FullName
$qtCache = if ($env:QT_CACHE) { $env:QT_CACHE } else { Join-Path $env:LOCALAPPDATA 'status-e2e-qt' }
New-Item -ItemType Directory -Force -Path $qtCache | Out-Null

if ($env:QT_PREFIX) {
    $qt = (Resolve-Path $env:QT_PREFIX).Path
} else {
    $qt = Join-Path $qtCache '6.11.0\msvc2022_64'
    if (-not (Test-Path (Join-Path $qt 'lib\cmake\Qt6\Qt6Config.cmake'))) {
        $python = $env:SETUP_PYTHON
        if (-not $python) {
            $bin = Join-Path $env:USERPROFILE '.local\bin'
            $env:Path = "$bin;$env:Path"
            if (Get-Command uv -ErrorAction SilentlyContinue) {
                $python = (uv python find 3.14).Trim()
            }
        }
        if (-not $python) { Fail 'run scripts/setup-windows.ps1 first, or set SETUP_PYTHON' }
        $aqtVenv = Join-Path $qtCache 'aqt-venv'
        if (-not (Test-Path (Join-Path $aqtVenv 'Scripts\aqt.exe'))) {
            & $python -m venv $aqtVenv
            & (Join-Path $aqtVenv 'Scripts\python.exe') -m pip install --quiet aqtinstall
        }
        & (Join-Path $aqtVenv 'Scripts\aqt.exe') install-qt windows desktop 6.11.0 win64_msvc2022_64 -O $qtCache --timeout 3000
    }
}

$cleanup = $false
if ($env:PLUGIN_SRC) {
    $src = (Resolve-Path $env:PLUGIN_SRC).Path
} else {
    $src = Join-Path $env:TEMP ("qmlinspector-" + [guid]::NewGuid().ToString('n'))
    $cleanup = $true
    git clone --quiet $PluginRepo $src
    git -C $src checkout --quiet $PluginRef
}

try {
    cmake -S (Join-Path $src 'qt-plugin\generic-plugin') -B $out -G 'Visual Studio 17 2022' -A x64 `
        "-DCMAKE_PREFIX_PATH=$qt" '-DQMLINSPECTOR_QUICKWIDGETS=OFF'
    cmake --build $out --config Release
    $dll = Get-ChildItem -Path $out -Recurse -Filter 'qmlinspector.dll' |
        Where-Object { $_.FullName -match '\\Release\\' } |
        Select-Object -First 1
    if (-not $dll) {
        $dll = Get-ChildItem -Path $out -Recurse -Filter 'qmlinspector.dll' | Select-Object -First 1
    }
    if (-not $dll) { Fail "qmlinspector.dll was not built in $out" }
    $destDir = Join-Path $out 'plugins\generic'
    $dest = Join-Path $destDir 'qmlinspector.dll'
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    if ($dll.FullName -ne $dest) { Copy-Item $dll.FullName $dest -Force }
    Get-Item $dest | Format-List FullName, Length
} finally {
    if ($cleanup) { Remove-Item -Recurse -Force $src }
}