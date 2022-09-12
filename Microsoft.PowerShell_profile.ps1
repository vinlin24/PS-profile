<# Override default shell prompt #>
function prompt { "PS> " }

<# Helper function for writing status based on last exit code #>
function Write-CompletionStatus {
    if ($?) {
        Write-Host "Done." -ForegroundColor Green
    }
    else {
        Write-Host "Failed." -ForegroundColor Red
    }
}

<# Helper function for activating the given virtual environment #>
function Open-PythonVenv {
    param (
        [Parameter()]
        [string]$Path
    )
    Write-Host "Activating Python virtual environment $Path..." -NoNewline -ForegroundColor Yellow
    $activatePath = Join-Path -Path $Path -ChildPath "\Scripts\Activate.ps1"
    try { & $activatePath }
    finally { Write-CompletionStatus }
}

<# Activate Python virtual environment, creating it if necessary #>
function Start-PythonVenv {
    param (
        [Parameter()]
        [string]$Name = ".venv"
    )

    # Find the virtual environment in current and parent directories
    # Don't bother recursing through child directories because that could
    # take too long depending on where this is run

    # Current directory
    $targetDir = (Get-Location)
    $testPath = Join-Path -Path $targetDir -ChildPath $Name
    # Already exists, just activate it instantly
    if (Test-Path $testPath) {
        Open-PythonVenv -Path $testPath
        return
    }

    # Otherwise search through parent directories
    $targetDir = (Split-Path -Path $targetDir -Parent)

    # The result is the empty string "" when we pop the root
    while ($targetDir) {
        $testPath = Join-Path -Path $targetDir -ChildPath $Name
        # Already exists, ask for confirmation
        if (Test-Path $testPath) {
            Write-Host "Found a virtual environment in a parent directory $targetDir. Is this the one you wanted? (y/N) " -NoNewline -ForegroundColor Yellow
            $confirmation = Read-Host
            if ($confirmation -ne "y") {
                Write-Host "Did not activate $Name." -ForegroundColor Red
                return
            }
            Open-PythonVenv -Path $testPath
            return
        }
        # Pop the current directory off $targetDir
        $targetDir = (Split-Path -Path $targetDir -Parent)
    }

    # Doesn't exist yet, ask if caller wants to create it
    Write-Host "Could not find a virtual environment named $Name in current and parent directories. Would you like to create one here? (y/N) " -NoNewline -ForegroundColor Yellow
    $confirmation = Read-Host
    if ($confirmation -ne "y") {
        Write-Host "Did not create $Name." -ForegroundColor Red
        return
    }

    # Create the virtual environment
    Write-Host "Creating Python virtual environment $Name in current directory..." -NoNewline -ForegroundColor Yellow
    try { python -m venv $Name }
    finally { Write-CompletionStatus }
    
    # Activate the new virtual environment
    $newVenvPath = Join-Path -Path (Get-Location) -ChildPath $Name
    Open-PythonVenv -Path $newVenvPath
}

Set-Alias -Name "venv" -Value "Start-PythonVenv"

<# Get the list of verbs in a separate window #>
function Get-VerbsGridView {
    Get-Verb | Out-GridView
}

Set-Alias -Name "verbs" -Value "Get-VerbsGridView"

<# Helper function for Start-ProjectDir #>
function New-ItemAndMsg {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,
        [Parameter(Mandatory = $true, Position = 1)]
        [bool]$Quiet,
        [Parameter()]
        [switch]$Directory
    )
    if (Test-Path $Path) {
        if (-Not $Quiet) {
            Write-Host "SKIPPED: $Path already exists"
        }
        return
    }
    if ($Directory) {
        New-item -Path $Path -ItemType Directory | Out-Null
    }
    else {
        New-Item -Path $Path | Out-Null
    }
    if (-Not $Quiet) {
        Write-Host "SUCCESS: Created $Path"
    }
}

<# Initialize a barebones project directory #>
function Start-ProjectDir {
    param (
        # Complexity of template:
        # 0 - no dirs; 1 - src only; 2 - src, test; 3 - src, test, dist, build
        [ValidateRange(0, 3)]
        [Parameter(Position = 0)]
        [int]$Complexity = 0,
        # Create and activate venv and include requirements.txt
        [Parameter()]
        [switch]$PythonTemplate,
        # Suppress creation messages
        [Parameter()]
        [switch]$Quiet
    )

    Write-Host "Creating project directory template..." -ForegroundColor Yellow

    New-ItemAndMsg ".\.gitignore" $Quiet
    New-ItemAndMsg ".\README.md" $Quiet
    if ($Complexity -ge 1) {
        New-ItemAndMsg ".\src" $Quiet -Directory
    }
    if ($Complexity -ge 2) {
        New-ItemAndMsg ".\test" $Quiet -Directory
    }
    if ($Complexity -ge 3) {
        New-ItemAndMsg ".\dist" $Quiet -Directory
        New-ItemAndMsg ".\build" $Quiet -Directory
    }

    if ($PythonTemplate) {
        Write-Host "Opted to include Python essentials..." -ForegroundColor Yellow
        New-ItemAndMsg ".\requirements.txt" $Quiet
        Start-PythonVenv
    }

    Write-Host "Finished creating project directory template." -ForegroundColor Green
}

Set-Alias -Name "init" -Value "Start-ProjectDir"

# Display current working directory on startup
Clear-Host
Write-Host (Get-Location).ToString()
