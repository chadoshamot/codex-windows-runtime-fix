#Requires -Version 5.1

<#
.SYNOPSIS
    Repairs a failed cua_node runtime staging operation used by the
    OpenAI Codex desktop app on Windows.

.DESCRIPTION
    This script is intended as a workaround for a specific startup issue:

      - OpenAI.Codex is installed.
      - The bundled cua_node runtime is complete.
      - The application repeatedly creates incomplete .staging-* runtime
        directories.
      - The corresponding finalized runtime directory is missing or incomplete.

    The script:
      1. Stops running ChatGPT/Codex processes.
      2. Detects the installed OpenAI.Codex package.
      3. Verifies the bundled cua_node runtime.
      4. Detects the runtime ID from the newest staging directory.
      5. Checks whether the finalized runtime is already complete.
      6. Copies the bundled runtime using XCOPY /G when repair is required.
      7. Verifies file count, total size, and critical files.
      8. Launches the app.

.PRIVACY
    This script:
      - does NOT connect to the Internet;
      - does NOT collect telemetry;
      - does NOT read ChatGPT conversations;
      - does NOT read account credentials;
      - does NOT upload files;
      - does NOT delete existing runtimes or staging directories.

.NOTES
    Unofficial community workaround.
    Not affiliated with or endorsed by OpenAI.
#>

$ErrorActionPreference = "Stop"

function Write-Step {
    param(
        [string]$Number,
        [string]$Message
    )

    Write-Host ""
    Write-Host "[$Number] $Message" -ForegroundColor Yellow
}

function Stop-WithError {
    param([string]$Message)

    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Write-Host ""
    Write-Host "No runtime files were intentionally deleted." -ForegroundColor DarkGray
    exit 1
}

function Get-DirectoryStats {
    param([string]$Path)

    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction Stop)
    $size = ($files | Measure-Object -Property Length -Sum).Sum

    if ($null -eq $size) {
        $size = 0
    }

    return [PSCustomObject]@{
        Files = $files
        Count = $files.Count
        Size  = [Int64]$size
    }
}

Clear-Host

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "        Codex Windows Runtime Repair" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Unofficial community workaround"
Write-Host "No network access or telemetry is performed by this script."
Write-Host ""

try {

    # ---------------------------------------------------------
    # 1. Stop running processes
    # ---------------------------------------------------------

    Write-Step "1/8" "Stopping running ChatGPT/Codex processes..."

    Get-Process ChatGPT -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    Get-Process codex -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2

    Write-Host "OK" -ForegroundColor Green


    # ---------------------------------------------------------
    # 2. Detect installed package
    # ---------------------------------------------------------

    Write-Step "2/8" "Detecting installed OpenAI.Codex package..."

    $packages = @(Get-AppxPackage -Name OpenAI.Codex)

    if ($packages.Count -eq 0) {
        Stop-WithError "OpenAI.Codex is not installed for the current user."
    }

    if ($packages.Count -gt 1) {
        Stop-WithError "Multiple OpenAI.Codex packages were detected. Refusing to guess which package should be repaired."
    }

    $pkg = $packages[0]

    Write-Host "Installed version : $($pkg.Version)" -ForegroundColor Cyan

    # Deliberately avoid printing the complete local filesystem path.


    # ---------------------------------------------------------
    # 3. Verify bundled runtime
    # ---------------------------------------------------------

    Write-Step "3/8" "Checking bundled cua_node runtime..."

    $src = Join-Path $pkg.InstallLocation "app\resources\cua_node"

    if (!(Test-Path -LiteralPath $src -PathType Container)) {
        Stop-WithError "The installed package does not contain the expected cua_node runtime."
    }

    $sourceCriticalFiles = @(
        (Join-Path $src "bin\node.exe"),
        (Join-Path $src "bin\node_repl.exe"),
        (Join-Path $src "manifest.json")
    )

    foreach ($file in $sourceCriticalFiles) {
        if (!(Test-Path -LiteralPath $file -PathType Leaf)) {
            Stop-WithError "The bundled cua_node runtime is incomplete. Repair has been aborted."
        }
    }

    $srcStats = Get-DirectoryStats -Path $src

    Write-Host "Bundled files     : $($srcStats.Count)"
    Write-Host "Bundled size      : $([math]::Round($srcStats.Size / 1MB, 2)) MB"
    Write-Host "Critical files    : OK" -ForegroundColor Green


    # ---------------------------------------------------------
    # 4. Detect staging failure
    # ---------------------------------------------------------

    Write-Step "4/8" "Looking for failed runtime staging directories..."

    $runtimeRoot = Join-Path $env:LOCALAPPDATA "OpenAI\Codex\runtimes\cua_node"

    if (!(Test-Path -LiteralPath $runtimeRoot)) {
        Stop-WithError @"
The cua_node runtime directory does not exist.

Launch Codex/ChatGPT once and allow the failed startup attempt to finish,
then run this repair tool again.
"@
    }

    $stagingDirs = @(
        Get-ChildItem -LiteralPath $runtimeRoot -Force -Directory |
            Where-Object { $_.Name -like ".staging-*" } |
            Sort-Object LastWriteTime -Descending
    )

    if ($stagingDirs.Count -eq 0) {
        Stop-WithError @"
No .staging-* runtime directories were found.

This tool only repairs the known incomplete-runtime staging failure.
Your startup problem may have a different cause.
"@
    }

    $latestStaging = $stagingDirs[0]

    if ($latestStaging.Name -notmatch '^\.staging-([A-Za-z0-9]+)-[^\\]+$') {
        Stop-WithError "The newest staging directory has an unexpected name. Repair has been aborted."
    }

    $runtimeId = $matches[1]

    # Avoid printing user-specific paths.
    Write-Host "Runtime ID        : $runtimeId" -ForegroundColor Cyan
    Write-Host "Staging attempts  : $($stagingDirs.Count)"


    # ---------------------------------------------------------
    # 5. Check target runtime
    # ---------------------------------------------------------

    Write-Step "5/8" "Checking finalized runtime..."

    $dst = Join-Path $runtimeRoot $runtimeId

    $runtimeValid = $false

    if (Test-Path -LiteralPath $dst -PathType Container) {

        $dstStats = Get-DirectoryStats -Path $dst

        $criticalOK =
            (Test-Path -LiteralPath (Join-Path $dst "bin\node.exe")) -and
            (Test-Path -LiteralPath (Join-Path $dst "bin\node_repl.exe")) -and
            (Test-Path -LiteralPath (Join-Path $dst "manifest.json"))

        if (
            $criticalOK -and
            ($srcStats.Count -eq $dstStats.Count) -and
            ($srcStats.Size -eq $dstStats.Size)
        ) {
            $runtimeValid = $true
        }
    }

    if ($runtimeValid) {

        Write-Host "Runtime already matches bundled runtime." -ForegroundColor Green
        Write-Host "No copy operation is required."

    } else {

        Write-Host "Finalized runtime is missing or incomplete." -ForegroundColor Yellow


        # -----------------------------------------------------
        # 6. Repair
        # -----------------------------------------------------

        Write-Step "6/8" "Repairing runtime..."

        New-Item -ItemType Directory -Path $dst -Force | Out-Null

        Write-Host "Copying bundled runtime..."
        Write-Host ""

        & xcopy.exe "$src\*" "$dst\" /E /I /H /Y /G

        $xcopyExitCode = $LASTEXITCODE

        # XCOPY:
        # 0 = files copied successfully
        # 1 = no files found
        # 2 = Ctrl+C termination
        # 4 = initialization error
        # 5 = disk write error
        if ($xcopyExitCode -ne 0) {
            Stop-WithError "XCOPY failed with exit code $xcopyExitCode."
        }

        Write-Host ""
        Write-Host "Copy completed." -ForegroundColor Green
    }


    # ---------------------------------------------------------
    # 7. Verify result
    # ---------------------------------------------------------

    Write-Step "7/8" "Verifying repaired runtime..."

    if (!(Test-Path -LiteralPath $dst -PathType Container)) {
        Stop-WithError "The finalized runtime directory was not created."
    }

    $dstStats = Get-DirectoryStats -Path $dst

    $nodeOK = Test-Path -LiteralPath (Join-Path $dst "bin\node.exe")
    $nodeReplOK = Test-Path -LiteralPath (Join-Path $dst "bin\node_repl.exe")
    $manifestOK = Test-Path -LiteralPath (Join-Path $dst "manifest.json")

    $fileCountMatch = ($srcStats.Count -eq $dstStats.Count)
    $sizeMatch = ($srcStats.Size -eq $dstStats.Size)

    Write-Host ""
    Write-Host "Source files      : $($srcStats.Count)"
    Write-Host "Runtime files     : $($dstStats.Count)"
    Write-Host "File count match  : $fileCountMatch"

    Write-Host ""
    Write-Host "Source size       : $([math]::Round($srcStats.Size / 1MB, 2)) MB"
    Write-Host "Runtime size      : $([math]::Round($dstStats.Size / 1MB, 2)) MB"
    Write-Host "Size match        : $sizeMatch"

    Write-Host ""
    Write-Host "node.exe          : $nodeOK"
    Write-Host "node_repl.exe     : $nodeReplOK"
    Write-Host "manifest.json     : $manifestOK"

    if (
        !$fileCountMatch -or
        !$sizeMatch -or
        !$nodeOK -or
        !$nodeReplOK -or
        !$manifestOK
    ) {
        Stop-WithError "Runtime verification failed. The application will not be launched automatically."
    }

    Write-Host ""
    Write-Host "Runtime verification PASSED." -ForegroundColor Green


    # ---------------------------------------------------------
    # 8. Launch
    # ---------------------------------------------------------

    Write-Step "8/8" "Starting Codex/ChatGPT..."

    Start-Process "shell:AppsFolder\OpenAI.Codex_2p2nqsd0c76g0!App"

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "             Repair completed" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Codex/ChatGPT should now be starting."
    Write-Host ""

    Start-Sleep -Seconds 3
    exit 0

}
catch {

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "                 Repair failed" -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "No runtime directories were intentionally deleted."
    exit 1
}