#---------------------------------------------------------------------
# Configures a build envrionment for nim-status-client on windows.
#---------------------------------------------------------------------

# Helpers
function Install-Scoop {
    if ((Get-Command scoop -ErrorAction SilentlyContinue) -ne $null) {
        Write-Host "Scoop already installed!"
    } else {
        Write-Host "Installing Scoop package manager..."
        Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
    }
}

# Throw error on native command failure, which is not the default behavior.
# $PSNativeCommandUseErrorActionPreference works only in PowerShell 7.4.
function run {
    $cmd = $args[0]
    $cmdArgs = @($args | Select-Object -Skip 1)
    & $cmd @cmdArgs
    if ($LASTEXITCODE -ne 0) {
        throw "ERROR: Exit code $LASTEXITCODE for command: '$cmd $cmdArgs'"
    }
}


function Scoop-Install([string]$package, [string]$version) {
    $appName = ($package -split '/')[-1]
    $fullName = "$package@$version"

    if (Test-Path "C:\ProgramData\scoop\apps\$appName\$version") {
        Write-Host "Already installed: $fullName"
        run scoop list $appName
    } else {
        Write-Host "Installing: $fullName"
        run scoop install --global "$fullName"
    }
}

# nimble is unpacked into a directory with no `nim` beside it: a nim there would shadow the pin.
# WARNING: Remember to update PATH in ci/Jenkinsfile.windows.
$NimbleVersion = '0.24.1'
$NimbleSha256  = '3afab31eea536f7256ed93769c0fd071e4f909fc9c3431fc0350405a785cdcb1'
$NimbleDir     = 'C:\nimble'

function Install-Nimble {
    if (Test-Path "$NimbleDir\nimble.exe") {
        Write-Host "Already installed: nimble $NimbleVersion"
        return
    }
    Write-Host "Installing nimble $NimbleVersion"
    $zip = "$env:TEMP\nimble-windows_x64.zip"
    $url = "https://github.com/nim-lang/nimble/releases/download/v$NimbleVersion/nimble-windows_x64.zip"
    (New-Object System.Net.WebClient).DownloadFile($url, $zip)
    $hash = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
    if ($hash -ne $NimbleSha256) {
        throw "ERROR: nimble checksum mismatch: got $hash, want $NimbleSha256"
    }
    New-Item -ItemType Directory -Force -Path $NimbleDir | Out-Null
    Expand-Archive -Force -Path $zip -DestinationPath $NimbleDir
    Remove-Item $zip
}

# nimble 0.24.1's architecture probe can fail and silently fetch the win32 Nim
# (fixed upstream after 0.24.1, nimble PR #1862): Seed-Nim materialises the pin
# and swaps an i386 store entry for the x64 zip. Remove it once a release carries #1862.
$NimX64Sha256 = @{
    '2.2.10' = 'fe0686a9b298e5b13d0a983df37e002a8c6320f8b16cc45a51d15cf4046a109f'
}

function Repair-Nim-Arch([string]$entry, [string]$pin) {
    if (-not $NimX64Sha256.ContainsKey($pin)) {
        throw "ERROR: nimble fetched a non-amd64 Nim $pin and this script has no x64 checksum for that version; add it to `$NimX64Sha256"
    }
    $zip = "$env:TEMP\nim-${pin}_x64.zip"
    $url = "https://nim-lang.org/download/nim-${pin}_x64.zip"
    Write-Host "Replacing it with the x64 build from $url"
    (New-Object System.Net.WebClient).DownloadFile($url, $zip)
    $hash = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
    if ($hash -ne $NimX64Sha256[$pin]) {
        throw "ERROR: Nim x64 zip checksum mismatch: got $hash, want $($NimX64Sha256[$pin])"
    }
    $tmp = "$env:TEMP\nim-${pin}_x64"
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    Expand-Archive -Path $zip -DestinationPath $tmp
    Remove-Item $zip
    Get-ChildItem $entry | Where-Object { $_.Name -ne 'nimblemeta.json' } |
        Remove-Item -Recurse -Force
    Get-ChildItem "$tmp\nim-$pin" | Move-Item -Destination $entry
    Remove-Item -Recurse -Force $tmp
}

function Seed-Nim {
    $manifest = Join-Path $PSScriptRoot '..\nim_status_client.nimble'
    $m = Select-String -Path $manifest -Pattern 'requires\s+"nim\s*==\s*([^"\s]+)"' | Select-Object -First 1
    if (-not $m) { throw "ERROR: no 'requires `"nim == X`"' line in $manifest" }
    $pin = $m.Matches[0].Groups[1].Value
    $mingw = 'C:\ProgramData\scoop\apps\mingw-winlibs\current\bin'
    if (-not (Test-Path "$mingw\gcc.exe")) {
        throw "ERROR: gcc not found at $mingw; nimble's architecture probe needs it"
    }
    $env:PATH = "$mingw;$NimbleDir;$env:PATH"
    $proj = Join-Path $env:TEMP 'status-nim-seed'
    New-Item -ItemType Directory -Force -Path $proj | Out-Null
    Set-Content -Path "$proj\seed.nimble" -Value @"
version = "0.0.0"
author = "status-desktop setup"
description = "materialises the Nim pinned by nim_status_client.nimble"
license = "MIT"
requires "nim == $pin"
"@
    Push-Location $proj
    try {
        Write-Host "Materialising Nim $pin into nimble's store"
        run "$NimbleDir\nimble.exe" setup
        # Own scope with 'Continue': PowerShell 5.1 turns a native command's
        # redirected stderr into a terminating error under 'Stop'.
        $entry = & {
            $ErrorActionPreference = 'Continue'
            & "$NimbleDir\nimble.exe" path nim 2>$null
        } | Where-Object { $_ -match "nim-$([regex]::Escape($pin))-" } | Select-Object -First 1
        if (-not $entry) { throw "ERROR: nimble setup did not materialise Nim $pin" }
        $nimExe = "$entry\bin\nim.exe"
        $ver = if (Test-Path $nimExe) { & $nimExe -v | Select-Object -First 1 } else { "no nim.exe in $entry" }
        Write-Host $ver
        if (-not (Test-Path $nimExe) -or ($ver -notmatch 'amd64')) {
            Repair-Nim-Arch $entry $pin
            $ver = & "$entry\bin\nim.exe" -v | Select-Object -First 1
            Write-Host $ver
            if ($ver -notmatch 'amd64') { throw "ERROR: still not an amd64 Nim after the swap: $ver" }
        }
    } finally {
        Pop-Location
        Remove-Item -Recurse -Force $proj -ErrorAction SilentlyContinue
    }
}

# Install Git and other dependencies
function Install-Dependencies {
    Write-Host "Installing dependencies..."
    if (!(scoop bucket list | Where { $_.Name -eq "extras" })) {
        run scoop bucket add extras
    }
    if (!(scoop bucket list | Where { $_.Name -eq "status" })) {
        run scoop bucket add status "https://github.com/status-im/infra-scoop-bucket.git"
    }
    run scoop update
    # Trying to 'hold' git breaks due to how hosts are bootstrapped.
    run scoop install --global git 7zip innounp dos2unix findutils wget rcedit
    # Old versions can cause weird Scoop install errors.
    run scoop update --global 7zip innounp
    # WARNING: Remember to update PATH in ci/Jenkinsfile.windows.
    Scoop-Install 'status/go'            '1.24.7'
    Scoop-Install 'status/cmake'         '3.31.6'
    Scoop-Install 'status/python'        '3.13.5'
    Scoop-Install 'status/mingw-winlibs' '15.2.0-13.0.0-r5'
    Scoop-Install 'status/vcredist2022'  '14.44.35211.0'
    Scoop-Install 'status/protobuf'      '36.0'
    Scoop-Install 'status/openssl-lts'   '3.0.19'
    Scoop-Install 'status/inno-setup'    '6.7.0'
    Scoop-Install 'status/msys2'         '2025-12-13'
    Scoop-Install 'status/llvm'          '22.1.8'
    Scoop-Install 'status/openjdk25'     '25.0.2-10'
}

function Install-MSYS2-Packages {
    Write-Host "Installing MSYS2 MinGW64 packages..."
    $msys2Bash = "C:\ProgramData\scoop\apps\msys2\current\usr\bin\bash.exe"
    $packages = "mingw-w64-x86_64-rust mingw-w64-x86_64-postgresql mingw-w64-x86_64-pkgconf"
    & $msys2Bash -lc "pacman -S --noconfirm --needed $packages"
}

function Install-Qt-SDK {
    Write-Host "Installing Qt $QtVersion SDK..."
    run pip install aqtinstall
    run aqt install-qt -O "C:\Qt" windows desktop $QtVersion win64_msvc2022_64 -m all
}

# Install Microsoft Visual C++ Build Tools 17.13.35
function Install-VC-BuildTools {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $buildToolsPath = if (Test-Path $vswhere) {
        & $vswhere `
            -products Microsoft.VisualStudio.Product.BuildTools `
            -latest `
            -requires Microsoft.VisualStudio.Workload.VCTools `
            -property installationPath
    }
    # Installer fails with exit code 1 if Build Tools already present.
    if ($buildToolsPath) {
        Write-Host "Visual Studio Build Tools already installed."
        Return
    }

    $VCBuildToolsUrl = "https://aka.ms/vs/17/release/vs_BuildTools.exe"
    $VCBuildToolsExe = "$HOME\Downloads\vs_BuildTools.exe"

    Write-Host "Downloading Microsoft Visual C++ Build Tools..."
    (New-Object System.Net.WebClient).DownloadFile($VCBuildToolsUrl, $VCBuildToolsExe)

    Write-Host "Installing Microsoft Visual C++ Build Tools..."
    $VCBuildToolsArgs = $(
        "--installPath", "C:\BuildTools",
        "--quiet", "--wait", "--norestart", "--nocache",
        "--add", "Microsoft.VisualStudio.Workload.MSBuildTools",
        "--add", "Microsoft.VisualStudio.Workload.VCTools",
        "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "--add", "Microsoft.VisualStudio.Component.VC.Redist.14.Latest",
        "--add", "Microsoft.VisualStudio.Component.Windows10SDK.10240",
        "--add", "Microsoft.VisualStudio.Component.Windows10SDK.14393",
        "--add", "Microsoft.VisualStudio.Component.Windows81SDK",
        "--add", "Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Win81",
        "--add", "Microsoft.VisualStudio.ComponentGroup.UWP.VC.v141.BuildTools"
    )
    $process = Start-Process -Wait -PassThru -FilePath $VCBuildToolsExe -ArgumentList $VCBuildToolsArgs
    if ($process.ExitCode -ne 0) {
        throw "ERROR: Build tools installation failed wit exit code: $($process.ExitCode)"
    }
}

function Show-Success-Message {
    Write-Host @"

SUCCESS!

Before you attempt to build nim-status-client you'll need a few environment variables set:

export QTDIR="/c/Qt/$QtVersion/msvc2022_64"
export Qt5_DIR="/c/Qt/$QtVersion/msvc2022_64"
export VCINSTALLDIR="/c/BuildTools/VC"

You might also have to include the following paths in your `$PATH:

export PATH=`"$env:USERPROFILE/go/bin:`$PATH`"
export PATH=`"/c/BuildTools/MSBuild/Current/Bin:`$PATH`"
export PATH=`"/c/BuildTools/VC/Tools/MSVC/14.44.35207/bin:`$PATH`"
export PATH=`"/c/ProgramData/scoop/apps/openssl-lts/current/bin:`$PATH`"
export PATH=`"/c/ProgramData/scoop/apps/inno-setup/current:`$PATH`"
export PATH=`"/c/ProgramData/scoop/apps/openjdk25/25.0.2-10/bin:`$PATH`"
export PATH=`"/c/nimble:`$PATH`"
"@
}

#---------------------------------------------------------------------

# Stop the script after first error
$ErrorActionPreference = 'Stop'
# Version of Qt SDK available form aqt
$QtVersion = "6.11.0"

# Don't run when sourcing script
If ($MyInvocation.InvocationName -ne ".") {
    Install-Scoop
    Install-Dependencies
    Install-Nimble
    Seed-Nim
    Install-MSYS2-Packages
    Install-Qt-SDK
    Install-VC-BuildTools
    Show-Success-Message
}

#---------------------------------------------------------------------
