#Requires -modules PSFzf

$RunConfig = @{ Mode = ""; PkgName = ""; PkgVersion = ""; NeedSelection = $true }

function Read-YesNoChoice {
    Param (
        [Parameter(Mandatory = $true)][String]$Title,
        [Parameter(Mandatory = $true)][String]$Message,
        [Parameter(Mandatory = $false)][Int]$DefaultOption = 0
    )
	
    $No = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'No'
    $Yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Yes'
    $Options = [System.Management.Automation.Host.ChoiceDescription[]]($No, $Yes)
	
    return $host.ui.PromptForChoice($Title, $Message, $Options, $DefaultOption)
}

function Select-PackageAndVersion {
    param ([Parameter(Mandatory = $false)][Boolean]$SelectVersion = $true)

    $PkgApexPath = Get-ChildItem . -Attributes Directory -Exclude tmp_pkg, IntuneOut, TEMPLATES | Invoke-Fzf
    if (-not $PkgApexPath) { exit }
    $RunConfig.PkgName = Split-Path $PkgApexPath -Leaf
    if ($SelectVersion) {
        $PkgVersionPath = Get-ChildItem $PkgApexPath -Attributes Directory | Invoke-Fzf
        if (-not $PkgVersionPath) { exit }
        $RunConfig.PkgVersion = Split-Path $PkgVersionPath -Leaf
    }
}

function Get-OperationMode {
    $RunConfig.Mode = @("Repeat last run", "Package IntuneWin", "Package PSADT", "New Package") | Invoke-Fzf
}

function Package-PSADT {
    $PkgPath = "$($RunConfig.PkgName)\$($RunConfig.PkgVersion)"
    Write-Output "Packaging $PkgPath"
    Write-Output "Cleaning up previous tmp files"
    if (Test-Path ".\tmp_pkg") { Remove-Item -Recurse ".\tmp_pkg" -Force }
    Write-Output "Copying package to .\tmp_pkg"
    Copy-Item -Path "$PkgPath" -Destination ".\tmp_pkg" -Recurse -Container
    Write-Output "Decrypting secrets.sops.json and storing it as secrets.json"
    sops.exe --config "$HOME\.sops.yaml" decrypt ".\tmp_pkg\SupportFiles\secrets.sops.json" > ".\tmp_pkg\SupportFiles\secrets.json"
    Write-Output "Removing encrypted secrets.sops.json from package"
    Remove-Item ".\tmp_pkg\SupportFiles\secrets.sops.json"
    Write-Output "Package can be found in .\tmp_pkg"
    $RunConfig.NeedSelection = $false
}

function New-IntuneWin {
    Package-PSADT
    IntuneWinAppUtil.exe -c (Resolve-Path "tmp_pkg").Path -s Invoke-AppDeployToolkit.exe -o "IntuneOut" -q
    $PkgOutName = "$($RunConfig.PkgName)-$($RunConfig.PkgVersion).intunewin"
    Write-Output "Renaming Invoke-AppDeployToolkit.intunewin to $PkgOutName" 
    Move-Item ".\IntuneOut\Invoke-AppDeployToolkit.intunewin" ".\IntuneOut\$PkgOutName" -Force
    Write-Output "Cleaning tmp files"
    Remove-Item -Recurse ".\tmp_pkg" -Force
}

Get-OperationMode
if (-not $RunConfig.Mode) { Write-Output "No mode selected, exiting."; exit }
if ($RunConfig.Mode -eq "Repeat last run") { 
    if (-not (Test-Path "last-run.json")) { Write-Output "No last run, exiting."; exit }
    $RunConfig = Get-Content "last-run.json" | ConvertFrom-Json
    $RunConfig.NeedSelection = $false
}

switch ($RunConfig.Mode) {
    "Package IntuneWin" {
        if ($RunConfig.NeedSelection) { Select-PackageAndVersion }
        New-IntuneWin
    }
    "Package PSADT" {
        if ($RunConfig.NeedSelection) { Select-PackageAndVersion }
        Package-PSADT
    }
    "New Package" { 
        if (Read-YesNoChoice -Title "New Version for existing package?" -Message "Yes or No?") {
            Select-PackageAndVersion -SelectVersion $false
        }
        else { $RunConfig.PkgName = Read-Host "Package Name?" }
        $RunConfig.PkgVersion = Read-Host "Version number?"
        Copy-Item -Path "TEMPLATES\4.0.6" -Destination "$($RunConfig.PkgName)\$($RunConfig.PkgVersion)" -Recurse -Container
        Write-Output "Created version ($($RunConfig.PkgVersion)) for $($RunConfig.PkgName)"
    }
}

$RunConfig | ConvertTo-Json | Out-File "last-run.json"