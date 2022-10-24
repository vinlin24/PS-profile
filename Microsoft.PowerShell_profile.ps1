<# ANSI Escape Sequences #>
$ESC = [char]27
$RESET = "$ESC[0m"
$DEFAULT = "$ESC[39m"
# All of these are bolded too
$BLACK = "$ESC[1;30m"
$RED = "$ESC[1;31m"
$GREEN = "$ESC[1;32m"
$YELLOW = "$ESC[1;33m"
$BLUE = "$ESC[1;34m"
$MAGENTA = "$ESC[1;35m"
$CYAN = "$ESC[1;36m"
$WHITE = "$ESC[1;37m"


<# Helper function for prompt #>
function Get-BranchState () {
    # Otherwise determine the color and symbols from the status
    # Use the same notation as VS Code in the bottom left corner:
    # '*' for modified, '+' for staged, '*+' for both, '!' for conflict
    $status = (git status) -join "`n" 2> $null

    # git error, probably not a repository
    if ($status -eq "") { return "" }

    # Parse for the other states; color priority:
    # red (conflict) > magenta (staged) > yellow (modified) > green (clean)
    $color = $BLACK
    $marks = ""

    # These can occur independently of each other
    # Check in reverse order of color priority so that highest takes precedence
    if ($status | Select-String "nothing to commit, working tree clean") {
        $color = $GREEN
    }
    if ($status | Select-String "(Changes not staged for commit|Untracked files):") {
        $color = $YELLOW
        $marks += "*"
    }
    if ($status | Select-String "Changes to be committed:") {
        $color = $MAGENTA
        $marks += "+"
    }
    if ($status | Select-String "fix conflicts") {
        $color = $RED
        $marks += "!"
    }

    # Get the HEAD SHA
    $SHA = (git rev-parse --short HEAD)

    # Get the branch name if possible
    $match = $status | Select-String "On branch (.+)"
    # Probably in detached HEAD mode, use the tag if applicable
    if ($null -eq $match) {
        $match = $status | Select-String "HEAD detached at (.+)"
        # Some other problem, I have no idea
        if ($null -eq $match) { return "" }
        $detachedState = "${RED}DETACHED${RESET} "
    }
    # If matched first time, uses the branch name
    # Otherwise, uses the tag name if available, else the SHA
    $branchName = $match.Matches.Groups[1].Value

    $branch = "${color}(${branchName}${marks})${RESET}"
    return " ${detachedState}${CYAN}${SHA}${RESET} ${branch}"
}

<# Override default shell prompt #>
function prompt {
    # Abbreviate the path part to use ~ for home and show at most two
    # layers deep from cwd, while still including ~ or the drive root.
    #
    # For example:
    # ~\...\classes\Fall 22
    # PS>
    #
    # With a venv active and git repository detected:
    # (.venv) ~\repos\counters c700bb7 (main)
    # └─(counters) PS>

    $cwd = "$(Get-Location)"
    $root = "$(Get-Item \)"
    if ($cwd -like "${HOME}*") {
        $root = $HOME
    }

    # Case 1: at the root
    if ($cwd -eq $root) {
        $cwdAbbrev = $root
    }

    # Case 2: parent is the root
    elseif ((Split-Path $cwd -Parent) -eq $root) {
        $cwdAbbrev = $cwd
    }

    # Case 3: grandparent is the root
    elseif ((Split-Path (Split-Path $cwd -Parent) -Parent) -eq $root) {
        $cwdAbbrev = $cwd
    }

    # Case 4: there are arbitrary layers between grandparent and root
    else {
        $leaf = Split-Path $cwd -Leaf
        $parent = Split-Path (Split-Path $cwd -Parent) -Leaf
        $parts = @("...", $parent, $leaf)
        $cwdAbbrev = $root
        foreach ($part in $parts) {
            $cwdAbbrev = Join-Path $cwdAbbrev $part
        }
    }

    # Finally replace home part of path with ~
    $cwdAbbrev = $cwdAbbrev -ireplace [regex]::Escape($HOME), "~"

    # Part on the second line
    $prompt = "PS> "
    $venv = $env:VIRTUAL_ENV
    # If a venv is activated, prefix prompt with name of origin directory
    if ($venv) {
        $venvDir = Split-Path (Split-Path $venv -Parent) -Leaf
        $prompt = "${GREEN}$([char]9492)$([char]9472)(${venvDir})${RESET} ${CYAN}${prompt}${RESET}"
    }
    else {
        $prompt = "${CYAN}${prompt}${RESET}"
    }

    # Final combined prompt
    "${BLUE}${cwdAbbrev}${RESET}$(Get-BranchState)`n${prompt}"
}

<# Colorized ls from https://github.com/joonro/Get-ChildItemColor #>
# Only run this in the console and not in the ISE
if (-Not (Test-Path Variable:PSise)) {
    try {
        Import-Module Get-ChildItemColor
    }
    catch {
        Write-Host "Module Get-ChildItemColor could not be loaded." -ForegroundColor Red
    }
    Remove-Item alias:ls -Force
    Set-Alias ll Get-ChildItemColor -option AllScope
    Set-Alias ls Get-ChildItemColorFormatWide -option AllScope
}

function ld { Get-ChildItemColor -Directory }
function lf { Get-ChildItemColor -File }

Remove-Item alias:pwd -Force
function pwd { "$(Get-Location)" }

<# No welcome text please #>
Clear-Host
