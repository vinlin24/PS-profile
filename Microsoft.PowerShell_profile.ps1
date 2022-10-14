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
function Get-BranchName () {
    $branch = git rev-parse --abbrev-ref HEAD

    # Non-existent repo
    if (!$?) { return "" }

    # Determine the color from the status
    $status = git status -s
    if ($status.Length -gt 0) {
        $branchColor = $YELLOW
    }
    else {
        $branchColor = $GREEN
    }

    # We're probably in detached HEAD state, so return the SHA
    if ($branch -eq "HEAD") {
        $branch = git rev-parse --short HEAD
        return " ${RED}(${branch})${RESET}"
    }
    # We're on an actual branch, so return it
    else {
        return " ${branchColor}(${branch})${RESET}"
    }
}

<# Override default shell prompt #>
function prompt {
    # Abbreviate the path part to use ~ for home and show at most two
    # layers deep from cwd, while still including ~ or the drive root.
    # For example:
    # ~\...\classes\Fall 22 PS>

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
    # Final prompt
    "${BLUE}${cwdAbbrev}${RESET}$(Get-BranchName) ${CYAN}PS>${RESET} "
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

<# No welcome text please #>
Clear-Host
