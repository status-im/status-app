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

# Install Protobuf tool necessary to generate status-go files.
function Install-Protobuf-Go {
    $ProtocGenVersion = "v1.34.1"
    $ProtocGenZIP = "protoc-gen-go.$ProtocGenVersion.windows.amd64.zip"
    $ProtocGenURL = "https://github.com/protocolbuffers/protobuf-go/releases/download/$ProtocGenVersion/$ProtocGenZIP"
    $ProtocGenSHA256 = "403a619c4698fe5c4162c7f855803de3e8d8e0c187d7d51cbeb8d599f7a5a073"
    (New-Object System.Net.WebClient).DownloadFile($ProtocGenURL, "$env:USERPROFILE\$ProtocGenZIP")
    $ProtocGenRealSHA256 = (Get-Filehash -algorithm SHA256 "$env:USERPROFILE\$ProtocGenZIP").Hash
    if ($ProtocGenRealSHA256 -ne $ProtocGenSHA256) {
        throw "SHA256 hash does not match for $ProtocGenZIP !"
    }
    New-Item "$env:USERPROFILE\go\bin" -ItemType Directory -ea 0
    7z x -o="$env:USERPROFILE\go\bin" -y "$env:USERPROFILE\$ProtocGenZIP"
}

function Scoop-Install([string]$package, [string]$version) {
    $appName = ($package -split '/')[-1]
    $fullName = "$package@$version"

    if (Test-Path "C:\ProgramData\scoop\apps\$appName\$version") {
        Write-Host "Already installed: $fullName"
        scoop list $appName
    } else {
        Write-Host "Installing: $fullName"
        scoop install --global "$fullName"
    }
}

# Install Git and other dependencies
function Install-Dependencies {
    Write-Host "Installing dependencies..."
    if (!(scoop bucket list | Where { $_.Name -eq "extras" })) {
        scoop bucket add extras
    }
    if (!(scoop bucket list | Where { $_.Name -eq "status" })) {
        scoop bucket add status https://github.com/status-im/infra-scoop-bucket.git
    }
    scoop update
    # Trying to 'hold' git breaks due to how hosts are bootstrapped.
    scoop install --global git 7zip innounp dos2unix findutils wget rcedit
    # Old versions can cause weird Scoop install errors.
    scoop update --global 7zip innounp
    # WARNING: Remember to update PATH in ci/Jenkinsfile.windows.
    Scoop-Install 'status/go'            '1.24.7'
    Scoop-Install 'status/nim'           '2.2.6'
    Scoop-Install 'status/cmake'         '3.31.6'
    Scoop-Install 'status/python'        '3.13.5'
    Scoop-Install 'status/mingw-winlibs' '15.2.0-13.0.0-r5'
    Scoop-Install 'status/vcredist2022'  '14.44.35211.0'
    Scoop-Install 'status/protobuf'      '3.20.1'
    Scoop-Install 'status/openssl-lts'   '3.0.19'
    Scoop-Install 'status/inno-setup'    '6.7.0'
    Scoop-Install 'status/msys2'         '2025-12-13'
}

function Install-MSYS2-Packages {
    Write-Host "Installing MSYS2 MinGW64 packages..."
    $msys2Bash = "C:\ProgramData\scoop\apps\msys2\current\usr\bin\bash.exe"
    $packages = "mingw-w64-x86_64-rust mingw-w64-x86_64-postgresql"
    & $msys2Bash -lc "pacman -S --noconfirm --needed $packages"
}

function Install-Qt-SDK {
    Write-Host "Installing Qt $QtVersion SDK..."
    pip install aqtinstall
    aqt install-qt -O "C:\Qt" windows desktop $QtVersion win64_msvc2022_64 -m all
}

# Install Microsoft Visual C++ Build Tools 17.13.35
function Install-VC-BuildTools {
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
    Start-Process -Wait -PassThru -FilePath $VCBuildToolsExe -ArgumentList $VCBuildToolsArgs
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
"@
}

#---------------------------------------------------------------------

# Stop the script after first error
$ErrorActionPreference = 'Stop'
# Version of Qt SDK available form aqt
$QtVersion = "6.9.2"

# Don't run when sourcing script
If ($MyInvocation.InvocationName -ne ".") {
    Install-Scoop
    Install-Dependencies
    Install-MSYS2-Packages
    Install-Protobuf-Go
    Install-Qt-SDK
    Install-VC-BuildTools
    Show-Success-Message
}

#---------------------------------------------------------------------
