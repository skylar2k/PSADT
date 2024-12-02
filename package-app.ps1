#Requires -modules PSFzf
Function Read-YesNoChoice {
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

$PkgApexPath = Get-ChildItem . -Attributes Directory -Exclude tmp_pkg, IntuneOut, TEMPLATE | Invoke-Fzf
if (-not $PkgApexPath) { Exit }
$PkgVersionPath = Get-ChildItem $PkgApexPath -Attributes Directory | Invoke-Fzf
if (-not $PkgVersionPath) { Exit }

Copy-Item -Path $PkgVersionPath -Destination .\tmp_pkg -Recurse -Container
sops.exe --config "~/.sops.yaml" decrypt .\tmp_pkg\SupportFiles\secrets.sops.json > .\tmp_pkg\SupportFiles\secrets.json
Remove-Item .\tmp_pkg\SupportFiles\secrets.sops.json

# Package application if wanted
if (Read-YesNoChoice -Title "Package to IntuneWin?" -Message "Yes or No?") {
    $PkgOutName = "$(Split-Path $PkgApexPath -Leaf)-$(Split-Path $PkgVersionPath -Leaf).intunewin"
    IntuneWinAppUtil -c (Resolve-Path tmp_pkg).Path -s Deploy-Application.exe -o "IntuneOut" -q
    Move-Item ".\IntuneOut\Deploy-Application.intunewin" ".\IntuneOut\$PkgOutName" -Force
}

Remove-Item -Recurse .\tmp_pkg