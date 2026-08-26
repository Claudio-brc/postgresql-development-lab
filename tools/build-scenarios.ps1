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
        ./build-scenarios.ps1 06_jsonb
#>

param(
    [string]$Scenario
)

# ------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------

$ScriptRoot    = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot   = Split-Path $ScriptRoot -Parent
$ScenariosRoot = Join-Path $ProjectRoot "scenarios"
$InstallRoot   = Join-Path $ProjectRoot "install"

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
    $OutputFile = Join-Path $InstallRoot "$ScenarioName.sql"

    Write-Info ""
    Write-Info "====================================================="
    Write-Info "Building: $ScenarioName"
    Write-Info "====================================================="

    $SqlFiles =
        Get-ChildItem $ScenarioPath -File -Filter "*.sql" |
        Sort-Object Name

    if ($SqlFiles.Count -eq 0) {

        Write-Host "No SQL files found."
        return
    }

    $Builder = New-Object System.Text.StringBuilder
	
	$null = $Builder.AppendLine("------------------------------------------------------------")
    $null = $Builder.AppendLine("-- PostgreSQL Development Lab")
    $null = $Builder.AppendLine("-- Scenario: $ScenarioName")
    $null = $Builder.AppendLine("--")
    $null = $Builder.AppendLine("-- AUTO-GENERATED FILE")
    $null = $Builder.AppendLine("-- DO NOT EDIT MANUALLY")
    $null = $Builder.AppendLine("------------------------------------------------------------")
    $null = $Builder.AppendLine()

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

if (!(Test-Path $InstallRoot)) {
    New-Item -ItemType Directory -Path $InstallRoot | Out-Null
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
