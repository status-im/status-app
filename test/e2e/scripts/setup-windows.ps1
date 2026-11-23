param(
    [Parameter(Position = 0)]
    [string]$PluginsDir
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

function Fail([string]$Message) {
    [Console]::Error.WriteLine("setup: $Message")
    exit 1
}

function Ensure-Uv {
    $bin = Join-Path $env:USERPROFILE '.local\bin'
    $env:Path = "$bin;$env:Path"
    if (Get-Command uv -ErrorAction SilentlyContinue) { return }
    irm https://astral.sh/uv/install.ps1 | iex
    $env:Path = "$bin;$env:Path"
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { Fail 'uv was not installed' }
}

function Is-Squish([string]$Path) {
    if ($Path -match 'squish') { return $true }
    return (& $Path -c 'import sys; print(sys.base_prefix)') -match 'squish'
}

function Get-Python314 {
    foreach ($candidate in @(
            $(if (Get-Command py -ErrorAction SilentlyContinue) { try { (py -3.14 -c 'import sys; print(sys.executable)').Trim() } catch { $null } }),
            $(if (Get-Command python3.14 -ErrorAction SilentlyContinue) { (Get-Command python3.14).Source })
        )) {
        if (-not $candidate -or -not (Test-Path $candidate) -or (Is-Squish $candidate)) { continue }
        if ((& $candidate -c 'import sys; print("%d.%d" % sys.version_info[:2])') -eq '3.14') {
            return $candidate
        }
    }
    Ensure-Uv
    uv python install 3.14
    $found = (uv python find 3.14).Trim()
    if (-not $found -or (Is-Squish $found)) { Fail "Python 3.14 is not usable: $found" }
    return $found
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail 'install git' }
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) { Fail 'install CMake' }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) { Fail 'install Visual Studio 2022 with the C++ workload' }
$vs = & $vswhere -products * -latest -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { Fail 'install Visual Studio 2022 with the C++ workload' }

$python = Get-Python314
$out = if ($env:SETUP_PLUGIN_OUT) { $env:SETUP_PLUGIN_OUT } else { Join-Path $env:LOCALAPPDATA 'status-e2e-qt\qmlinspector' }
$env:SETUP_PYTHON = $python
& (Join-Path $PSScriptRoot 'inspector\build-plugin-windows.ps1') $out

Ensure-Uv
if (Test-Path (Join-Path $Root '.venv')) { Remove-Item -Recurse -Force (Join-Path $Root '.venv') }
uv venv --python $python .venv
uv pip install --python .\.venv\Scripts\python.exe -r requirements.txt

$plugins = if ($PluginsDir) { $PluginsDir } else { Join-Path $out 'plugins' }
& .\.venv\Scripts\python.exe .\scripts\lib\record_plugins.py $plugins

$dotenv = Join-Path $Root '.env'
$example = Join-Path $Root '.env.example'
if (-not (Test-Path $dotenv)) {
    Copy-Item $example $dotenv
    [Console]::Error.WriteLine('setup: created .env from .env.example')
}
foreach ($key in @('E2E_LOCAL_WAKU_FLEET', 'WALLET_TEST_USER_SEED')) {
    if (-not (Select-String -Path $dotenv -Pattern "^${key}=" -Quiet)) {
        [Console]::Error.WriteLine("setup: add ${key}= to .env")
    }
}
if (-not (Select-String -Path $dotenv -Pattern '^WALLET_TEST_USER_SEED=.+$' -Quiet)) {
    [Console]::Error.WriteLine('setup: set WALLET_TEST_USER_SEED in .env (Jenkins credential wallet-test-user-seed)')
}

$skipWaku = $env:E2E_SKIP_WAKU_FLEET -eq '1'
if (-not $skipWaku -and (Get-Command docker -ErrorAction SilentlyContinue)) {
    try { docker info *> $null } catch { $skipWaku = $true }
}
if ($skipWaku) {
    [Console]::Error.WriteLine('setup: skipping local Waku fleet')
} elseif (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('setup: docker not found, skipping Waku fleet')
} else {
    $repo = Split-Path $Root -Parent | Split-Path -Parent
    $project = if ($env:E2E_WAKU_COMPOSE_PROJECT) { $env:E2E_WAKU_COMPOSE_PROJECT } else { 'status-app' }
    $compose = Join-Path $repo 'docker-compose.waku.yml'
    if (-not (Test-Path $compose)) { Fail "missing $compose" }
    [Console]::Error.WriteLine("setup: starting Waku fleet (project=$project)")
    docker compose -p $project -f $compose up -d --build --remove-orphans
    Push-Location $repo
    try {
        & (Join-Path $Root '.venv\Scripts\python.exe') (Join-Path $repo 'test\e2e\scripts\scan_waku_fleet.py') --project $project
    } finally {
        Pop-Location
    }
}

Write-Output "setup: activate with: .\.venv\Scripts\Activate.ps1"
Write-Output "setup: INSPECTOR_PLUGINS=$plugins"