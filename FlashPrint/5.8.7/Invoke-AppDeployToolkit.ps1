[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType = 'Install',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [System.String]$DeployMode = 'Interactive',

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$AllowRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)


##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # App variables.
    AppVendor                   = 'FlashForge'
    AppName                     = 'FlashPrint 5'
    AppVersion                  = '5.8.7'
    AppArch                     = 'x64'
    AppLang                     = 'EN'
    AppRevision                 = '01'
    AppSuccessExitCodes         = @(0)
    AppRebootExitCodes          = @(1641, 3010)
    AppScriptVersion            = '1.0.0'
    AppScriptDate               = '10-12-2024'
    AppScriptAuthor             = 'Skylar Johansen'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName                 = ''
    InstallTitle                = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptVersion      = '4.0.3'
    DeployAppScriptParameters   = $PSBoundParameters

    # Script parameters.
    DeploymentType              = $DeploymentType
    DeployMode                  = $DeployMode
    AllowRebootPassThru         = $AllowRebootPassThru
    TerminalServerMode          = $TerminalServerMode
    DisableLogging              = $DisableLogging
}

$global:secrets = $null

function Install-ADTDeployment {
    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"
    $installPath = "$envProgramFiles\FlashForge\FlashPrint 5\"
    New-ADTFolder "$envProgramFiles\FlashForge"

    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType
    Expand-Archive "$($adtSession.DirFiles)\flashprint.zip" -DestinationPath "$installPath" -Force
    $CertSig = Get-AuthenticodeSignature "$installPath\driver\win7\FlashForge_3D_Printer.cat"
    $CertStore = Get-Item -Path "Cert:\LocalMachine\TrustedPublisher"
    $CertStore.Open("ReadWrite")
    $CertStore.Add($CertSig.SignerCertificate)
    $CertStore.Close()
    pnputil.exe /add-driver "$installPath\driver\win7\FlashForge_3D_Printer.inf" /install

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut("$envCommonStartMenuPrograms\$appName.lnk")
    $shortcut.TargetPath = "$installPath\FlashPrint.exe"
    $shortcut.IconLocation = "$installPath\FlashPrint.exe"
    $shortcut.WorkingDirectory = "$env:HomeDrive\$env:HomePath"
    $shortcut.Save()
    Set-ADTRegistryKey -Key "HKLM\SOFTWARE\MRFK\$appVendor\$appName\$appVersion"

}

function Uninstall-ADTDeployment {
    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"
    $installPath = "$envProgramFiles\FlashForge\FlashPrint 5\"
    Show-ADTInstallationWelcome -CloseProcesses "flashprint" -Silent

    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType
    pnputil.exe /delete-driver "$installPath\driver\win7\FlashForge_3D_Printer.inf" /uninstall
    Remove-ADTFolder -Path "$installPath"

    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"
    Remove-ADTFile -Path "$envCommonStartMenuPrograms\$appName.lnk"
    Remove-ADTRegistryKey -Key "HKLM\SOFTWARE\MRFK\$appVendor\$appName\$appVersion"

}

function Repair-ADTDeployment {
    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try {
    $moduleName = if ([System.IO.File]::Exists("$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1")) {
        Get-ChildItem -LiteralPath $PSScriptRoot\PSAppDeployToolkit -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
        "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
    }
    else {
        'PSAppDeployToolkit'
    }
    Import-Module -FullyQualifiedName @{ ModuleName = $moduleName; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.0.3' } -Force
    try {
        $adtSession = Open-ADTSession -SessionState $ExecutionContext.SessionState @adtSession -PassThru
        $secrets = Get-Content "$($adtSession.dirSupportFiles)\secrets.json" | ConvertFrom-Json
    }
    catch {
        Remove-Module -Name PSAppDeployToolkit* -Force
        throw
    }
}
catch {
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

try {
    if ([System.IO.File]::Exists("$PSScriptRoot\PSAppDeployToolkit.Extensions\PSAppDeployToolkit.Extensions.psd1")) {
        Get-ChildItem -LiteralPath $PSScriptRoot\PSAppDeployToolkit.Extensions -Recurse -File | Unblock-File
        Import-Module -FullyQualifiedName @{ ModuleName = "$PSScriptRoot\PSAppDeployToolkit.Extensions\PSAppDeployToolkit.Extensions.psd1"; Guid = '55276a4c-9fbb-49a4-8481-159113757c39'; ModuleVersion = '4.0.3' } -Force
    }
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch {
    Write-ADTLogEntry -Message ($mainErrorMessage = Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3
    Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop | Out-Null
    Close-ADTSession -ExitCode 60001
}
finally {
    Remove-Module -Name PSAppDeployToolkit* -Force
}
