<#
.SYNOPSIS
    Builds consolidated SQL scripts for PostgreSQL scenarios.

.DESCRIPTION
    Generates one consolidated .sql file per scenario by concatenating
    all individual SQL files in alphabetical order.

.PARAMETER Scenario
    Optional scenario folder name.
    Example:
        ./build-scenarios.ps1
        ./build-scenarios.ps1 07_jsonb
#>

param(
    [string]$Scenario
)

# ------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path $ScriptRoot -Parent
$ScenariosRoot = Join-Path $ProjectRoot "scenarios"

# ------------------------------------------------------------------
# Utility
# ------------------------------------------------------------------

function Write-Info {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)

    Write-Host "   -> $Message"
}

# ------------------------------------------------------------------
# Build a single scenario
# ------------------------------------------------------------------

function Build-Scenario {

    param(
        [string]$ScenarioPath
    )

    $ScenarioName = Split-Path $ScenarioPath -Leaf
    $OutputFile = Join-Path $ScenarioPath "99_$ScenarioName.sql"

    Write-Info ""
    Write-Info "====================================================="
    Write-Info "Building: $ScenarioName"
    Write-Info "====================================================="

    $SqlFiles =
        Get-ChildItem $ScenarioPath -File -Filter "*.sql" |
        Where-Object {
            $_.Name -ne "99_$ScenarioName.sql"
        } |
        Sort-Object Name

    if ($SqlFiles.Count -eq 0) {

        Write-Host "No SQL files found."
        return
    }

    $Builder = New-Object System.Text.StringBuilder

    foreach ($File in $SqlFiles) {

        Write-Step $File.Name

        $null = $Builder.AppendLine("------------------------------------------------------------")
        $null = $Builder.AppendLine("-- Source: $($File.Name)")
        $null = $Builder.AppendLine("------------------------------------------------------------")
        $null = $Builder.AppendLine()

        $Content = Get-Content $File.FullName -Raw

        $null = $Builder.AppendLine($Content)
        $null = $Builder.AppendLine()
        $null = $Builder.AppendLine()
    }

    $Builder.ToString() |
        Set-Content `
            -Path $OutputFile `
            -Encoding utf8

    Write-Host ""
    Write-Host "Created: $OutputFile" -ForegroundColor Green
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------

if (!(Test-Path $ScenariosRoot)) {

    throw "Scenarios folder not found: $ScenariosRoot"
}

if ($Scenario) {

    $ScenarioPath = Join-Path $ScenariosRoot $Scenario

    if (!(Test-Path $ScenarioPath)) {

        throw "Scenario '$Scenario' not found."
    }

    Build-Scenario $ScenarioPath
}
else {

    $ScenarioFolders =
        Get-ChildItem $ScenariosRoot -Directory |
        Sort-Object Name

    foreach ($Folder in $ScenarioFolders) {

        Build-Scenario $Folder.FullName
    }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green