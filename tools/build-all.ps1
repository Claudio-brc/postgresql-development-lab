<#
.SYNOPSIS
    Builds the master installation script.

.DESCRIPTION
    Concatenates all schema scripts and generated scenario scripts into a
    single installation file.

.PARAMETER OutputFile
    Name of the generated installation script.

.EXAMPLE
    .\build-install.ps1
#>

param (
    [string]$OutputFile = "postgresql-development-lab.sql"
)

$ScriptRoot    = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot   = Split-Path -Parent $ScriptRoot
$SchemaRoot    = Join-Path $ProjectRoot "schema"
$InstallRoot   = Join-Path $ProjectRoot "install"
$MasterScript  = Join-Path $InstallRoot $OutputFile

function Write-Info {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)

    Write-Host "  + $Message"
}

#
# Validate directories
#

if (!(Test-Path $SchemaRoot)) {
    throw "Schema directory not found: $SchemaRoot"
}

if (!(Test-Path $InstallRoot)) {
    throw "Install directory not found: $InstallRoot"
}

#
# Get files
#

$SchemaFiles = Get-ChildItem $SchemaRoot -File -Filter "*.sql" |
    Sort-Object Name

$ScenarioFiles = Get-ChildItem $InstallRoot -File -Filter "*.sql" |
    Where-Object {
        $_.Name -ne $OutputFile
    } |
    Sort-Object Name

if ($SchemaFiles.Count -eq 0) {
    throw "No schema files found."
}

if ($ScenarioFiles.Count -eq 0) {
    throw "No generated scenario files found."
}

#
# Build master script
#

Write-Info "Building master installation script..."

$Builder = New-Object System.Text.StringBuilder

$null = $Builder.AppendLine("------------------------------------------------------------")
$null = $Builder.AppendLine("-- PostgreSQL Development Lab")
$null = $Builder.AppendLine("--")
$null = $Builder.AppendLine("-- Master installation script")
$null = $Builder.AppendLine("--")
$null = $Builder.AppendLine("-- AUTO-GENERATED FILE")
$null = $Builder.AppendLine("-- DO NOT EDIT MANUALLY")
$null = $Builder.AppendLine("------------------------------------------------------------")
$null = $Builder.AppendLine()

#
# Schema
#

foreach ($File in $SchemaFiles) {

    Write-Step $File.Name

    $null = $Builder.AppendLine("------------------------------------------------------------")
    $null = $Builder.AppendLine("-- Schema: $($File.BaseName)")
    $null = $Builder.AppendLine("------------------------------------------------------------")
    $null = $Builder.AppendLine()

    $null = $Builder.AppendLine((Get-Content $File.FullName -Raw))
    $null = $Builder.AppendLine()
}

#
# Scenarios
#

foreach ($File in $ScenarioFiles) {

    Write-Step $File.Name

    $null = $Builder.AppendLine("------------------------------------------------------------")
    $null = $Builder.AppendLine("-- Scenario: $($File.BaseName)")
    $null = $Builder.AppendLine("------------------------------------------------------------")
    $null = $Builder.AppendLine()

    $null = $Builder.AppendLine((Get-Content $File.FullName -Raw))
    $null = $Builder.AppendLine()
}

#
# Write output
#

Set-Content `
    -Path $MasterScript `
    -Value $Builder.ToString()

Write-Host ""
Write-Host "Generated: $MasterScript" -ForegroundColor Green
Write-Host "Done." -ForegroundColor Green