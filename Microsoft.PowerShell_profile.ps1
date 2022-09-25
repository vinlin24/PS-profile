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

<# Helper subroutine for Open-CodeWorkspace #>
function _prompt_dir_choice {
    param (
        [Parameter(Mandatory = $true)]
        [System.Object[]] $RepoList
    )
    $count = 0
    $choiceDescs = @(
        $RepoList | ForEach-Object {
            "&${count}: $($_.Name)"
            $count++
        }
    )
    $choices = [System.Management.Automation.Host.ChoiceDescription[]] $choiceDescs
    # Prompt user input
    $choice = $Host.UI.PromptForChoice(
        "'$Name' matched $count directories",
        "Pick the one you meant to open (or ^C to cancel):",
        $choices,
        0
    )
    # Resolve choice
    return $RepoList[$choice].FullName
}

<# Open one of my repos as a workspace or directory #>
function Open-CodeWorkspace {
    param (
        [Parameter()]
        [string] $Name,
        [Parameter()]
        [switch] $New
    )

    # Assume the repos folder isn't gonna move lmao
    $reposDirPath = Join-Path $HOME "repos"
    $repos = @(Get-ChildItem $reposDirPath -Directory)
    # Search for folders within these special folders too
    $repos += @(Get-ChildItem "$reposDirPath\dump" -Directory)
    $repos += @(Get-ChildItem "$reposDirPath\forks" -Directory)

    $repoList = @($repos | Where-Object { $_.Name -like "*$Name*" })
    # If no arg was supplied, let the final else catch it
    if ($Name -eq "") {
        $repoList = $null
        $New = $false
    }

    # If such a repository exists:
    if ($repoList.Length -gt 0) {
        # If the name matched multiple results, prompt user to choose
        if ($repoList.Length -gt 1) {
            $repoPath = _prompt_dir_choice $repoList
        }
        else {
            $repopath = $repoList[0].FullName
        }

        $workspaceFile = Get-ChildItem $repoPath "*.code-workspace"
        # I only save one code-workspace per repo but who knows
        if ($workspaceFile -is [array]) {
            $workspaceFile = $workspaceFile[0]
            Start-Process $workspaceFile.PSPath
        }
        # No code-workspace file at all, code.exe the directory:
        elseif ($null -eq $workspaceFile) {
            code $repoPath
        }
        # Invoke the code-workspace file
        else {
            Start-Process $workspaceFile.PSPath
        }
        # Close terminal upon opening VS Code
        exit
    }

    # Otherwise if -New is used, make the repository:
    elseif ($New) {
        $newRepoPath = Join-Path $reposDirPath $Name
        # git init <directory> makes the directory automatically
        # "-b main" to specify starting branch as "main" instead of "master"
        git init -b main $newRepoPath
        code $newRepoPath
        # Close terminal upon opening VS Code
        exit
    }

    # Otherwise list the names of existing repos:
    else {
        Write-Host "No repository found in $reposDirPath with a name like '$Name'." -ForegroundColor Red
        Write-Host "The full list of directories at this location is:" -ForegroundColor Yellow
        foreach ($repo in $repos) {
            # If the repo is in the special directories, skip them
            # Since they'll be handled below
            $dirName = $repo.Parent.Name
            if ($dirName -eq "forks" -or $dirName -eq "dump") {
                continue
            }
            Write-Host $repo.Name
            # List the subdirectories of these special directories
            if ($repo.Name -eq "forks" -or $repo.Name -eq "dump") {
                Get-ChildItem $repo.FullName -Directory | ForEach-Object {
                    Write-Host "  $($_.Name)"
                }
            }
        }
    }
}

Set-Alias -Name "workspace" -Value "Open-CodeWorkspace"

<# Open this file's containing directory in VS Code #>
function Open-ThisProfile {
    code (Split-Path $profile -Parent)
    exit
}

Set-Alias -Name "profile" -Value "Open-ThisProfile"

<# Update pip to latest version #>
function Update-PipVersion {
    python -m pip install --upgrade pip
}

Set-Alias -Name "updatepip" -Value "Update-PipVersion"

<# Remove all __pycache__ directories and contents #>
function Remove-AllPycache {
    Get-ChildItem . __pycache__ -Directory -Recurse | Remove-Item -Recurse
}

Set-Alias -Name "pycache" -Value "Remove-AllPycache"

<# Reinstall the virtual environment in current directory #>
function Reset-VirtualEnv {
    param (
        [Parameter()]
        [string] $Name = ".venv"
    )

    # Validate path
    if (!(Test-Path $Name)) {
        Write-Host "Could not find a file named $Name, aborted." -ForegroundColor Red
        return
    }

    # Try to deactivate, then delete
    try { deactivate } catch {}
    Remove-Item $Name -Recurse
    Write-Host "Removed $Name" -ForegroundColor Yellow

    # Recreate venv
    Write-Host "Creating new virtual environment $Name..." -NoNewline -ForegroundColor Yellow
    python -m venv $Name
    Write-Host "Done." -ForegroundColor Green

    # Activate venv
    & "$Name\Scripts\Activate.ps1"

    # Update pip
    Update-PipVersion

    # Reinstall dependencies, if found
    if (Test-Path "requirements.txt") {
        pip install -r requirements.txt
        Write-Host "Installed dependencies from requirements.txt." -ForegroundColor Yellow
    }
    else {
        Write-Host "WARNING: Could not find a requirements.txt in current directory." -ForegroundColor Yellow
    }
}

Set-Alias -Name "resetvenv" -Value "Reset-VirtualEnv"

<# Shortcut for getting source path of an executable #>
function Get-Source {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Command,
        [Parameter()]
        [switch] $Open
    )
    $source = (Get-Command $Command).Source
    if ($Open) {
        if ($source -and (Test-Path $source)) {
            Invoke-Item (Split-Path $source -Parent)
        }
        else {
            Write-Host "Cannot open directory of '$source'." -ForegroundColor Red
        }
    }
    else {
        return $source
    }
}

Set-Alias -Name "src" -Value "Get-Source"

<# Shortcut for git commit --amend #>
function Edit-PreviousCommit {
    # Optional message to pass to -m option
    # If not included, use --no-edit switch
    param (
        [Parameter()]
        [string] $Message
    )
    if ($Message -eq "") {
        git commit --amend --no-edit
    }
    elseif ($Message.Length -le 50) {
        git commit --amend -m $Message
    }
    # Disallow messages longer than 50 characters
    else {
        $excess = $Message.Length - 50
        Write-Host "Your message should be <= 50 characters in length. It is currently $excess characters too long. Aborted." -ForegroundColor Red
    }
}

Set-Alias -Name "amend" -Value "Edit-PreviousCommit"

<# Alias for using specific Python interpreter instead of Python on PATH #>
$PYTHON_DIR = "$env:LOCALAPPDATA\Programs\Python"
# Get the version part of the directory, like "39" for Python 3.9
$PYTHON_VERS = @(Get-ChildItem $PYTHON_DIR | ForEach-Object { $_.Name -replace "Python", "" })
# Example: py39 for Python 3.9 interpreter
foreach ($ver in $PYTHON_VERS) {
    Set-Alias -Name "py$ver" -Value "$PYTHON_DIR\Python$ver\python.exe"
}

<# Shortcut for opening Git hook files since they're hidden in VS Code #>
function Open-GitHook {
    param (
        [Parameter()]
        [string] $Name
    )
    $hooksPath = ".\.git\hooks"
    # Not a repository or the .git folder is in a bad state
    if (!(Test-Path $hooksPath)) {
        Write-Host "Directory is not a repository or missing the .git/hooks directory, aborted." -ForegroundColor Red
        return
    }
    # No argument: open the whole folder
    if ($Name -eq "") {
        code $hooksPath
        return
    }
    # Otherwise open up the first file whose name is -like the input name
    $hooks = Get-ChildItem $hooksPath
    foreach ($file in $hooks) {
        if ($file.Name -like "*$Name*") {
            code $file.FullName
            return
        }
    }
    # No name -like it
    Write-Host "Could not find a hook with a filename name similar to '$Name', aborted." -ForegroundColor Red
}

Set-Alias -Name "hook" -Value "Open-GitHook"

# No welcome text please
Clear-Host
Write-Host (Get-Location).ToString()
