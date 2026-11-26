# Starts the nodes of docker-compose.waku.yml on Windows without Docker: the
# Linux node binary runs under WSL1, which shares the network with Windows.
# Writes assets/local-waku-fleets-config.json, as scan_waku_fleet.py does on Linux.
param(
    [string]$WorkDir = (Join-Path $env:TEMP 'status-e2e-waku'),
    [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'
$Distro = 'status-e2e-waku'
$RootfsUrl = 'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-amd64.tar.gz'
$RootfsSha256 = 'e77b6f10c2590cef872b33ee9f635a0e3fd1f57fb074c0e52b5c7f56147a0c86'

$Repo = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$Compose = Join-Path $Repo 'docker-compose.waku.yml'

function Fail([string]$Message) {
    [Console]::Error.WriteLine("waku fleet: $Message")
    exit 1
}

function Fetch([string]$Url, [string]$Sha256, [string]$File) {
    if ((Test-Path $File) -and ((Get-FileHash $File -Algorithm SHA256).Hash -eq $Sha256)) { return }
    curl.exe -sSfL --retry 5 --retry-all-errors -o $File $Url
    if ($LASTEXITCODE -ne 0) { Fail "cannot download $Url" }
    if ((Get-FileHash $File -Algorithm SHA256).Hash -ne $Sha256) { Fail "wrong checksum of $File" }
}

if (-not (Test-Path $Compose)) { Fail "missing $Compose" }
if (-not (Get-Command $Python -ErrorAction SilentlyContinue)) { Fail "no $Python to run the fleet scripts with" }
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { Fail 'enable the Windows Subsystem for Linux' }

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
& $Python (Join-Path $PSScriptRoot 'lib\waku_fleet_scripts.py') $Compose $WorkDir --wsl
if ($LASTEXITCODE -ne 0) { Fail 'cannot turn the compose file into node scripts' }
$tag = (Get-Content (Join-Path $WorkDir 'tag.txt')).Trim()
$name = "waku-$tag-amd64-linux.tar.gz"
$sha256 = Get-Content (Join-Path $PSScriptRoot 'lib\waku-node.sha256') |
    ForEach-Object { $hash, $file = $_ -split '\s+', 2; if ($file -eq $name) { $hash } }
if (-not $sha256) { Fail "add the checksum of $name to lib\waku-node.sha256" }
Fetch $RootfsUrl $RootfsSha256 (Join-Path $WorkDir 'rootfs.tar.gz')
Fetch "https://github.com/logos-messaging/logos-delivery/releases/download/$tag/$name" $sha256 (Join-Path $WorkDir 'waku.tar.gz')
$services = Get-Content (Join-Path $WorkDir 'services.txt') | Where-Object { $_ }

# wsl.exe prints UTF-16.
$known = (wsl.exe --list --quiet) -replace "`0", '' | ForEach-Object { $_.Trim() }
if ($known -contains $Distro) {
    wsl.exe --terminate $Distro | Out-Null
    wsl.exe --unregister $Distro | Out-Null
}
$distroDir = Join-Path $WorkDir 'distro'
New-Item -ItemType Directory -Force -Path $distroDir | Out-Null
wsl.exe --import $Distro $distroDir (Join-Path $WorkDir 'rootfs.tar.gz') --version 1
if ($LASTEXITCODE -ne 0) { Fail 'cannot import the Linux distribution into WSL1' }

Push-Location $WorkDir
try {
    wsl.exe -d $Distro -- bash ./install.sh
    if ($LASTEXITCODE -ne 0) { Fail 'cannot install the node in WSL' }
} finally {
    Pop-Location
}

# Started through WMI: a child of this script would stop with the CI step that runs it.
foreach ($service in $services) {
    $created = Invoke-CimMethod -ClassName Win32_Process -MethodName Create `
        -Arguments @{ CommandLine = "wsl.exe -d $Distro -- bash /opt/waku/$service.sh" }
    if ($created.ReturnValue -ne 0) { Fail "cannot start $service (WMI error $($created.ReturnValue))" }
    [Console]::Error.WriteLine("waku fleet: started $service")
}

& $Python (Join-Path $PSScriptRoot 'scan_waku_fleet.py') --no-docker --output (Join-Path $Repo 'assets\local-waku-fleets-config.json')
if ($LASTEXITCODE -ne 0) { Fail 'the nodes did not come up; see /tmp/*.log in the WSL distribution' }
