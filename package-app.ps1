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

Write-Information "Making sure tmp files are clean for new package"
if (Test-Path ".\tmp_pkg") { Remove-Item -Recurse .\tmp_pkg }

$PkgApexPath = Get-ChildItem . -Attributes Directory -Exclude tmp_pkg, IntuneOut, TEMPLATE | Invoke-Fzf
if (-not $PkgApexPath) { Exit }
$PkgVersionPath = Get-ChildItem $PkgApexPath -Attributes Directory | Invoke-Fzf
if (-not $PkgVersionPath) { Exit }
$PkgOutName = "$(Split-Path $PkgApexPath -Leaf)-$(Split-Path $PkgVersionPath -Leaf)"

Write-Output "Moving $PkgVersionPath to .\tmp_pkg"
Copy-Item -Path $PkgVersionPath -Destination .\tmp_pkg -Recurse -Container
Write-Output "Decrypting secrets.sops.json and storing it as secrets.json"
sops.exe --config "$HOME\.sops.yaml" decrypt .\tmp_pkg\SupportFiles\secrets.sops.json > .\tmp_pkg\SupportFiles\secrets.json
Write-Output "Removing encrypted secrets.sops.json from final package"
Remove-Item .\tmp_pkg\SupportFiles\secrets.sops.json

# Package application if wanted
if (Read-YesNoChoice -Title "Package $PkgOutName as IntuneWin?" -Message "Yes or No?") {
    IntuneWinAppUtil -c (Resolve-Path tmp_pkg).Path -s Deploy-Application.exe -o "IntuneOut" -q
    Write-Output "Renaming Deploy-Application.intunewin to $PkgOutName.intunewin"
    Move-Item ".\IntuneOut\Deploy-Application.intunewin" ".\IntuneOut\$PkgOutName.intunewin" -Force
}

Write-Output "Cleaning tmp files"
Remove-Item -Recurse .\tmp_pkg