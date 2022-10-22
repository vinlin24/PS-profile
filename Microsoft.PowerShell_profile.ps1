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
    $branch = git rev-parse --abbrev-ref HEAD

    # Non-existent repo
    if (!$?) { return "" }

    # We're probably in detached HEAD state, so return the SHA
    if ($branch -eq "HEAD") {
        $branch = git rev-parse --short HEAD
        return " ${RED}(${branch})${RESET}"
    }

    # Otherwise determine the color and symbols from the status
    # Use the same notation as VS Code in the bottom left corner:
    # '*' for modified, '+' for staged, and '*+' for both
    $status = git status  # For some reason this can be an array

    $ANY = "[\s\S]*"

    switch -Regex ($status -join "") {
        "${ANY}nothing to commit, working tree clean" {
            return " ${GREEN}(${branch})${RESET}"
        }
        "${ANY}Changes to be committed:${ANY}(Changes not staged for commit|Untracked files):${ANY}" {
            return " ${MAGENTA}(${branch}*+)${RESET}"
        }
        "${ANY}Changes to be committed:${ANY}" {
            return " ${MAGENTA}(${branch}+)${RESET}"
        }
        "${ANY}(Changes not staged for commit|Untracked files):${ANY}" {
            return " ${YELLOW}(${branch}*)${RESET}"
        }
        "${ANY}fix conflicts${ANY}" {
            return " ${RED}(${branch}!)${RESET}"
        }
    }

    # Shouldn't happen but who knows, at least I'll get a color
    return " ${CYAN}(${branch}?)${RESET}"
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

function pwd { "$(Get-Location)" }
Remove-Item alias:pwd -Force

<# No welcome text please #>
Clear-Host
