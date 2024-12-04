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
    [String]$appVendor = 'Microsoft'
    [String]$appName = 'DOTNET Runetime'
    [String]$appVersion = '4.8.1'
    [String]$appArch = 'x64'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '04/12/2024'
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
    $release = Get-ItemPropertyValue -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release
    switch ($release) {
        { $_ -ge 533320 } { $version = '4.8.1 or later'; break }
        { $_ -ge 528040 } { $version = '4.8'; break }
        { $_ -ge 461808 } { $version = '4.7.2'; break }
        { $_ -ge 461308 } { $version = '4.7.1'; break }
        { $_ -ge 460798 } { $version = '4.7'; break }
        { $_ -ge 394802 } { $version = '4.6.2'; break }
        { $_ -ge 394254 } { $version = '4.6.1'; break }
        { $_ -ge 393295 } { $version = '4.6'; break }
        { $_ -ge 379893 } { $version = '4.5.2'; break }
        { $_ -ge 378675 } { $version = '4.5.1'; break }
        { $_ -ge 378389 } { $version = '4.5'; break }
        default { $version = $null; break }
    }

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* MARK: PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'
        ## <Perform Pre-Installation tasks here>
        # Don't do anything if version 4.8.1 or later is installed
        if ($version -eq "4.8.1 or later") { Exit-Script -ExitCode $mainExitCode }

        ##*===============================================
        ##* MARK: INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'
        ## <Perform Installation tasks here>
        Execute-Process -Path "NDP481-x86-x64-AllOS-ENU.exe" -Parameters "/q /norestart"

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

        ##*===============================================
        ##* MARK: UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'
        ## <Perform Uninstallation tasks here>
        if ($version -eq "4.8.1 or later") {
            Execute-Process -Path "NDP481-x86-x64-AllOS-ENU.exe" -Parameters "/uninstall /q /norestart"
        }

        ##*===============================================
        ##* MARK: POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'
        ## <Perform Post-Uninstallation tasks here>

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
