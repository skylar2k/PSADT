[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ##*===============================================
    #region VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = 'SMART Technologies'
    [String]$appName = 'SMART Notebook'
    [String]$appVersion = '24'
    [String]$appArch = 'x86'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '03/12/2024'
    [String]$appScriptAuthor = 'Skylar Johansen'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''


    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.10.2'
    [String]$deployAppScriptDate = '08/13/2024'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    #endregion END VARIABLE DECLARATION
    ##*===============================================
    $secrets = Get-Content "$dirSupportFiles\secrets.json" | ConvertFrom-Json

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* MARK: PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'
        ## <Perform Pre-Installation tasks here>
        [Hashtable]$TransformProperties = @{
            "DESKTOP_ICONS"          = "0"
            "ACTIVATE_LICENSE"       = "0"
            "CR_ENABLED"             = "0" # Error reporting
            "CUSTOMER_LOGGING"       = "0"
            "ENABLE_STPCS"           = "1"
            "INSTALL_SPU"            = "0"
            "ENABLE_EXPIRY_WARNINGS" = "0"
            "ENABLE_SLS_TRIAL"       = "0" # Don't let users start Notebook Plus trial
            "FULL_GALLERY"           = "1"
            "LAT_CONTENT"            = "1"
            "INSTALL_BOARD"          = "1"
            "INSTALL_INK"            = "1"
            "INSTALL_NOTEBOOK"       = "1"

            # Languages
            "EN_GB"                  = "1"
            "NB"                     = "1"
        }
        New-MsiTransform -MsiPath "$dirFiles\SMARTEducationSoftware.msi" -TransformProperties $TransformProperties

        ##*===============================================
        ##* MARK: INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'
        ## <Perform Installation tasks here>
        Execute-MSI -Action "Install" -Path "SMARTEducationSoftware.msi" -Transform "SMARTEducationSoftware.mst" -Parameters "/qn"


        ##*===============================================
        ##* MARK: POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'
        ## <Perform Post-Installation tasks here>
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* MARK: PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'
        ## <Perform Pre-Uninstallation tasks here>
        # Get array of applications that are actually installed
        $InstalledApps = @(
            "{2FA63536-1209-4B62-A043-E0E4B5DF5254}" # SMART Notebook
            "{87257486-5AF1-476C-99F4-C41F90251EEF}" # SMART Lesson Activity Toolkit
            "{34A051B4-86CC-4409-94D6-B149E9F36404}" # SMART Education Software
            "{84FE50F5-B0F3-4D18-8BE8-A4DEEE0C37AD}" # TechSmith Screen Capture Codec
            "{AE4A8476-F602-4FC0-A40D-336DC76DD7EE}" # SMART Norwegian Handwriting Resources
            "{B5D5D9DC-3361-43D7-ADED-916CC6E90A03}" # SMART English (United Kingdom) Handwriting Resources
            "{BFC4DA50-D610-4BFE-92ED-CCBE6D9D3273}" # SMART Gallery Essentials
            "{CE22E589-A241-4B0C-B99D-E08D660EC32F}" # SMART Product Drivers
            "{D0FFBAE6-0470-4EEB-A098-3C04063A6A31}" # SMART Ink
        ) | ForEach-Object { Get-InstalledApplication -ProductCode "$_" }

        ##*===============================================
        ##* MARK: UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'
        ## <Perform Uninstallation tasks here>
        $InstalledApps | ForEach-Object {
            Execute-MSI -Action "Uninstall" -Path $_.ProductCode
        }

        ##*===============================================
        ##* MARK: POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'
        ## <Perform Post-Uninstallation tasks here>
        $path = "$envCommonStartMenuPrograms\SMART Technologies\SMART Tools\SMART-avinstalleringsprogram.lnk"
        if (Test-Path $path) { Remove-File -Path $path }

    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* MARK: PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'
        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* MARK: REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'
        ## <Perform Repair tasks here>

        ##*===============================================
        ##* MARK: POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'
        ## <Perform Post-Repair tasks here>

    }

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
