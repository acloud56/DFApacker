using namespace KeePassLib
using namespace KeePassLib.Interfaces
using namespace KeePassLib.Keys
using namespace KeepassLib.Security
using namespace KeePassLib.Serialization
using namespace Microsoft.PowerShell.SecretManagement
using namespace System.Collections.Generic
using namespace System.Collections.ObjectModel
using namespace System.Management.Automation
using namespace System.Runtime.InteropServices
function Register-KeepassSecretVault {
    <#
    .SYNOPSIS
        Registers a Keepass Vault with the Secret Management engine
    .DESCRIPTION
        Enables you to register a keepass vault with the secret management engine, with more discoverable parameters and
        safety checks
    .EXAMPLE
        PS C:\> Register-KeepassSecretVault -Path $HOME/Desktop/MyVault.kdbx
        Explanation of what the example does
    #>

    [CmdletBinding(DefaultParameterSetName = 'UseMasterPassword')]
    param(
        #Path to your kdbx database file
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)][String]$Path,
        #Name of your secret management vault. Defaults to the base filename
        [String]$Name,
        #Path to your kdbx keyfile path if you use one. Only v1 keyfiles (2.44 and older) are currently supported
        [String]$KeyPath,
        #Prompt for a master password for the vault
        [Switch]$UseMasterPassword,
        #Use your Windows Login account as an authentication factor for the vault
        [Switch]$UseWindowsAccount,
        #Automatically create a keepass database with the specifications you provided
        [Parameter(ParameterSetName='Create')][Switch]$Create,
        #Specify the master password to use when automatically creating a vault
        [Parameter(ParameterSetName='Create')][SecureString]$MasterPassword,
        #Report key titles as full paths including folders. Useful if you want to view conflicting Keys
        [Switch]$ShowFullTitle,
        #Show Recycle Bin entries
        [Switch]$ShowRecycleBin,
        #Don't validate the vault operation upon registration. This is useful for pre-staging 
        #vaults or vault configurations in deployments.
        [Parameter(ParameterSetName='SkipValidate')][Switch]$SkipValidate
    )

    $ErrorActionPreference = 'Stop'
    if (-not ($SkipValidate -or $Create)) {
        $Path = Resolve-Path $Path
    }
    if (-not $Name) { $Name = ([IO.FileInfo]$Path).BaseName }
    if ($UseWindowsAccount -and -not ($PSEdition -eq 'Desktop' -or $IsWindows)) {
        throw [NotSupportedException]'-UseWindowsAccount parameter is only supported on Windows'
    }
    if (-not $UseMasterPassword -and -not $UseWindowsAccount -and -not $KeyPath) {
        throw [InvalidOperationException]'No authentication methods specified. You must specify at least one of: UseMasterPassword, UseWindowsAccount, or KeyPath'
    }
    if ($Create) {
        $ConnectKPDBParams = @{
            Path = $Path
            KeyPath = $KeyPath
            UseWindowsAccount = $UseWindowsAccount
            Create = $Create
            MasterPassword = $MasterPassword
        }
        $dbConnection = Connect-KeePassDatabase @ConnectKPDBParams
        if (-not $dbConnection) {throw 'Connect-KeePassDatabase was executed but a database connection was not returned. This should not happen.'}
    }

    #BUG: Workaround for https://github.com/PowerShell/SecretManagement/issues/103
    if (Get-Module SecretManagement.KeePass -ErrorAction SilentlyContinue -OutVariable KeePassModule) {
        $ModuleName = $KeePassModule.Path
    } else {
        $ModuleName = 'SecretManagement.KeePass'
    }

    Register-SecretVault -ModuleName $ModuleName -Name $Name -VaultParameters @{
        Path              = $Path
        UseMasterPassword = $UseMasterPassword.IsPresent
        UseWindowsAccount = $UseWindowsAccount.IsPresent
        KeyPath           = $KeyPath
        ShowFullTitle     = $ShowFullTitle.IsPresent
        ShowRecycleBin    = $ShowRecycleBin.IsPresent
    }

    if (-not (Get-SecretVault -Name $Name)) { throw 'Register-SecretVault did not return an error but the vault is not registered.' }
    #Create does the same validation
    if (-not $SkipValidate -and -not $Create) {
        if (-not (Test-SecretVault -VaultName $Name)) {
            Unregister-SecretVault -Name $Name -ErrorAction SilentlyContinue
            throw "$Name is an invalid vault configuration, removing. Consider using -SkipValidate if you wish to pre-load a configuration without testing it"
        }
    }

}
function Unlock-KeePassSecretVault {
<#
    .SYNOPSIS
    Enables the entry of a master password prior to vault activities for unattended scenarios.
    If registering a vault for the first time unattended, be sure to use the -SkipValidate parameter of Register-KeepassSecretVault
    .EXAMPLE
    Get-SecretVault 'MyKeepassVault' | Unlock-KeePassSecretVault -Password $MySecureString
    .EXAMPLE
    Unlock-KeePassSecretVault -Name 'MyKeepassVault' -Password $MySecureString
#>
    param (
        [Parameter(Mandatory)][SecureString]$Password,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][String]$Name
    )

    Write-PSFMessage -Level Warning 'DEPRECATED: This command has been deprecated. Please use the SecretManagement command Unlock-SecretVault instead.'
    Microsoft.PowerShell.SecretManagement\Unlock-SecretVault -Password $Password -Name $Name
}
function ConvertTo-ReadOnlyDictionary {
    <#
        .SYNOPSIS
        Converts a hashtable to a ReadOnlyDictionary[String,Object]. Needed for SecretInformation
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)][hashtable]$hashtable
    )
    process {
        $dictionary = [SortedDictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
        $hashtable.GetEnumerator().foreach{
            $dictionary[$_.Name] = $_.Value
        }
        [ReadOnlyDictionary[string,object]]::new($dictionary)
    }
}
function GetKeepassParams ([String]$VaultName, [Hashtable]$AdditionalParameters) {
    $KeepassParams = @{}
    if ($VaultName) { 
        $KeepassParams.KeePassConnection = (Get-Variable -Scope Script -Name "Vault_$VaultName").Value 
    }
    return $KeepassParams
}
function Test-DBChanged ($dbConnection) {
    [string]$currentDbFileHash = (Get-FileHash -Path $dbConnection.IOConnectionInfo.Path).Hash
    [byte[]]$dbHashBytes = $dbConnection.HashOfFileOnDisk

    #Convert to String
    [string]$dbHash = $dbHashBytes.foreach{[String]::Format('{0:X2}', $_)} -join ''


    #Return true or false
    $currentDbFileHash -ne $dbHash
}
function Unlock-SecureString ([SecureString]$SecureString) {
    <#
    .SYNOPSIS
    Compatibility function to convert a secure string to plain text
    .OUTPUT
    String
    #>
    if ($PSVersionTable.PSVersion -ge '6.0.0') {
        ConvertFrom-SecureString -AsPlainText -SecureString $SecureString
    } else {
        #Legacy Windows Powershell Workaround Method
        [PSCredential]::new('SecureString',$SecureString).GetNetworkCredential().Password
    }
}
function VaultError ([String]$Message) {
    <#
    .SYNOPSIS
    Takes a terminating error and first writes it as a non-terminating error to the user to better surface the issue.
    #>

    #FIXME: Use regular errors if https://github.com/PowerShell/SecretManagement/issues/102 is resolved
    Write-PSFMessage -Level Error "Vault ${VaultName}: $Message"
    throw "Vault ${VaultName}: $Message"
}

function Connect-KeePassDatabase {
    <#
    .SYNOPSIS
    Open a connection to a keepass database
    #>
    param (
        #Path to the Keepass database
        [Parameter(Mandatory)][String]$Path,
        #Prompt for a master password
        [Switch]$UseMasterPassword,
        #The master password to unlock the database
        [SecureString]$MasterPassword,
        #The path to the key file for the database
        [String]$KeyPath,
        #Whether to use a secure key stored via DPAPI in your windows profile
        [Switch]$UseWindowsAccount,
        #Create a new database at the specified path. Will error if a database does not exist at the specified path
        [Switch]$Create,
        #Allow clobbering an existing database
        [Switch]$AllowClobber
    )

    $DBCompositeKey = [CompositeKey]::new()

    if (-not $MasterPassword -and -not $KeyPath -and -not $UseWindowsAccount) {
        Write-PSFMessage -Level Verbose "No vault authentication mechanisms specified. Assuming you wanted to prompt for the Master Password"
        $UseMasterPassword = $true
    }

    if ($UseMasterPassword -and -not $MasterPassword) {
        $CredentialParams = @{
            Username = 'Keepass Master Password'
            Message = "Enter the Keepass Master password for: $Path"
        }
        #PS7+ Only
        if ($PSEdition -ne 'Desktop') {
            $CredentialParams.Title = 'Keepass Master Password'
        }
        $MasterPassword = (Get-Credential @CredentialParams).Password
    }

    #NOTE: Order in which the CompositeKey is created is important and must follow the order of : MasterKey, KeyFile, Windows Account
    if ($MasterPassword) {
        $DBCompositeKey.AddUserKey(
            [KcpPassword]::new(
                #Decode SecureString
                [Marshal]::PtrToStringUni([Marshal]::SecureStringToBSTR($MasterPassword))
            )
        )
    }

    if ($KeyPath) {

        if (-not (Test-Path $KeyPath)) {
            if ($Create) {
                #Create a new key
                [KcpKeyFile]::Create(
                    $KeyPath, 
                    $null
                )
            } else {
                #Will emit a path not found error
                Resolve-Path $KeyPath
            }
        } else {
            Write-PSFMessage -Level Verbose "A keepass key file was already found at $KeyPath. Reusing this key for safety. Please manually delete this key if you wish to use a new one"
        }

        $resolvedKeyPath = Resolve-Path $KeyPath
        # Assume UNC path if no drive present.
        if ($Null -eq $resolvedKeyPath.Drive) {
            $dbCompositeKey.AddUserKey(
                [KcpKeyFile]::new(
                    $resolvedKeyPath.ProviderPath, #Path to keyfile
                    $true #Error if it is a database file
                )
            )
        } else {
            $dbCompositeKey.AddUserKey(
                [KcpKeyFile]::new(
                    $resolvedKeyPath, #Path to keyfile
                    $true #Error if it is a database file
                )
            )
        }
    }

    if ($UseWindowsAccount) {
        if ($PSVersionTable.PSVersion -gt '5.99.99' -and -not $IsWindows) {
            throw [NotSupportedException]'The -UseWindowsAccount parameter is only supported on a Windows Platform'
        }
        $DBCompositeKey.AddUserKey([KcpUserAccount]::new())
    }

    $ParentPath = (Resolve-Path ($Path | Split-Path)).ProviderPath
    $DBFile = $Path | Split-Path -Leaf
    $resolvedPath = Join-Path -Path $ParentPath -ChildPath $DBFile

    $DBConnection = [PWDatabase]::new()
    $DBConnectionInfo = [IOConnectionInfo]::FromPath($resolvedPath)

    if ($Create) {
        if (-not $AllowClobber -and (Test-Path $resolvedPath)) {
            throw "-Create was specified but a database already exists at $resolvedPath. Please specify -AllowClobber to overwrite the database."
        }
        $DBConnection.New(
            $DBConnectionInfo,
            $DBCompositeKey
        )
        $DBConnection.Save($null)
    }

    #Establish the connection

    $DBConnection.Open(
        $DBConnectionInfo,
        $DBCompositeKey,
        $null #No status logger
    )
    if (-not $DBConnection.IsOpen) { throw "Unable to connect to the database at $resolvedPath. Please check you supplied proper credentials" }
    $DBConnection
}

function Get-Secret {
    [CmdletBinding()]
    param (
        [string]$Name,
        [Alias('Vault')][string]$VaultName,
        [Alias('VaultParameters')][hashtable]$AdditionalParameters = (Get-SecretVault -Name $VaultName).VaultParameters
    )
    if ($AdditionalParameters.Verbose) {$VerbosePreference = 'continue'}

    if (-not (Test-SecretVault -VaultName $vaultName -AdditionalParameters $AdditionalParameters)) {
        Write-PSFMessage -Level Error 'There appears to be an issue with the vault (Test-SecretVault returned false)'
        throw 'There appears to be an issue with the vault (Test-SecretVault returned false)'
    }

    if (-not $Name) { 
        Write-PSFMessage -Level Error 'You must specify a secret Name'
        throw 'You must specify a secret Name'
    }

    $KeepassParams = GetKeepassParams $VaultName $AdditionalParameters

    if ($Name) { $KeePassParams.Title = $Name }
    $keepassGetResult = Get-SecretInfo -Vault $vaultName -Filter $Name -AsKPPSObject

    if ($keepassGetResult.count -gt 1) {
        Write-PSFMessage -Level Error "Multiple ambiguous entries found for $Name, please remove the duplicate entry or specify the full path of the secret"
        throw "Multiple ambiguous entries found for $Name, please remove the duplicate entry or specify the full path of the secret"
    }
    $result = if (-not $keepassGetResult.Username) {
        $keepassGetResult.Password
    } else {
        [PSCredential]::new($KeepassGetResult.UserName, $KeepassGetResult.Password)
    }
    return $result
}

function Get-SecretInfo {
    [CmdletBinding()]
    param(
        [Alias('Name')][string]$Filter,
        [Alias('Vault')][string]$VaultName = (Get-SecretVault).VaultName,
        [Alias('VaultParameters')][hashtable]$AdditionalParameters = (Get-SecretVault -Name $VaultName).VaultParameters,
        [Switch]$AsKPPSObject
    )
    if ($AdditionalParameters.Verbose) {$VerbosePreference = 'continue'}

    if (-not (Test-SecretVault -VaultName $vaultName)) {
        Write-PSFMessage -Level Error 'There appears to be an issue with the vault (Test-SecretVault returned false)'
        return $false
    }

    $KeepassParams = GetKeepassParams -VaultName $VaultName -AdditionalParameters $AdditionalParameters
    $KeepassGetResult = Get-KPEntry @KeepassParams | ConvertTo-KPPSObject
    if (-not $AdditionalParameters.ShowRecycleBin) {
        $KeepassGetResult = $KeepassGetResult | Where-Object FullPath -notmatch '^[^/]+?/Recycle ?Bin$'
    }

    #TODO: Split this off into private function for testing
    function Get-KPSecretName ([PSCustomObject]$KPPSObject) {
        <#
        .SYNOPSIS
        Gets the secret name for the vault context, contingent on some parameters
        WARNING: Relies on external context $AdditionalParameters
        #>
        if ($AdditionalParameters.ShowFullTitle) {
            #Strip everything before the first /
            $i = $KPPSObject.FullPath.IndexOf('/')
            $prefix = if ($i -eq -1) {$null} else {
                $KPPSObject.FullPath.Substring($i+1)
            }
            #Output Prefix/Title
            if ($prefix) {
                return $prefix,$KPPSObject.Title -join '/'
            } else {
                return $KPPSObject.Title
            }
        } else {
            return $KPPSObject.Title
        }
    }

    if ($Filter) {
        $KeepassGetResult = $KeepassGetResult | Where-Object {
            (Get-KPSecretName $PSItem) -like $Filter
        }
    }

    #Used by internal commands like Get-Secret
    if ($AsKPPSObject) {
        return $KeepassGetResult
    }

    [Object[]]$secretInfoResult = $KeepassGetResult | Foreach-Object {
        if (-not $PSItem.Title) {
            Write-PSFMessage -Level Warning "Keepass Entry with blank title found at $($PSItem.FullPath). These are not currently supported and will be omitted"
            return
        }

        [ReadOnlyDictionary[String,Object]]$metadata = [ordered]@{
            UUID = $PSItem.uuid.ToHexString()
            Title = $PSItem.Title
            ParentGroup = $PSItem.ParentGroup
            Path = $PSItem.FullPath,$PSItem.Title -join '/'
            Notes = $PSItem.Notes
            URL = $PSItem.Url
            Tags = $PSItem.Tags -join ', '
            Created = $PSItem.CreationTime
            Accessed = $PSItem.LastAccessTimeUtc
            Modified = $PSItem.LastModifiedTimeUtc
            Moved = $PSItem.LocationChanged
            IconName = $PSItem.IconId
            UsageCount = $PSItem.UsageCount
            Expires = if ($Expires) {$PSItem.ExpireTime}
        } | ConvertTo-ReadOnlyDictionary

        #TODO: Find out why the fully qualified is required on Linux even though using Namespace is defined above
        [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
            (Get-KPSecretName $PSItem), #string name
            #TODO: Add logic to mark as securestring if there is no username
            [Microsoft.PowerShell.SecretManagement.SecretType]::PSCredential, #SecretType type
            $VaultName, #string vaultName
            $metadata #ReadOnlyDictionary[string,object] metadata
        )
    }

    [Object[]]$sortedInfoResult = $secretInfoResult | Sort-Object -Unique -Property Name
    if ($sortedInfoResult.count -lt $secretInfoResult.count) {
        $nonUniqueFilteredRecords = Compare-Object $sortedInfoResult $secretInfoResult -Property Name | Where-Object SideIndicator -eq '=>'
        Write-PSFMessage -Level Error "Vault ${VaultName}: Entries with non-unique titles were detected, the duplicates were filtered out. $(if (-not $additionalParameters.ShowFullTitle) {'Consider adding the ShowFullTitle VaultParameter to your vault registration'})"
        Write-PSFMessage -Level Error "Vault ${VaultName}: Filtered Non-Unique Titles: $($nonUniqueFilteredRecords.Name -join ', ')"
    }
    $sortedInfoResult
}
function Remove-Secret {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()][string]$Name,
        [Alias('Vault')][string]$VaultName,
        [Alias('VaultParameters')][hashtable]$AdditionalParameters = (Get-SecretVault -Name $VaultName).VaultParameters
    )
    if ($AdditionalParameters.Verbose) {$VerbosePreference = 'continue'}
    if (-not (Test-SecretVault -VaultName $vaultName)) {
        VaultError 'There appears to be an issue with the vault (Test-SecretVault returned false)'
        return $false
    }
    $KeepassParams = GetKeepassParams $VaultName $AdditionalParameters

    $GetKeePassResult = Get-SecretInfo -VaultName $VaultName -Name $Name -AsKPPSObject
    if ($GetKeePassResult.count -gt 1) {
        VaultError "There are multiple entries with the name $Name and Remove-Secret will not proceed for safety."
        return $false
    }
    if (-not $GetKeePassResult) {
        VaultError "No Keepass Entry named $Name found"
        return $false
    }

    Remove-KPEntry @KeepassParams -KeePassEntry $GetKeePassResult.KPEntry -ErrorAction stop -Confirm:$false

    return $true
}
function Set-Secret {
    [CmdletBinding()]
    param (
        [string]$Name,
        [object]$Secret,
        [Alias('Vault')][string]$VaultName,
        [Alias('VaultParameters')][hashtable]$AdditionalParameters = (Get-SecretVault -Name $VaultName).VaultParameters
    )
    if ($AdditionalParameters.Verbose) { $VerbosePreference = 'continue' }

    if (-not $Name) {
        Write-PSFMessage -Level Error ([NotSupportedException]'The -Name parameter is mandatory for the KeePass vault')
        return $false
    }
    if (-not (Test-SecretVault -VaultName $vaultName)) {
        Write-PSFMessage -Level Error 'There appears to be an issue with the vault (Test-SecretVault returned false)'
        return $false
    }
    $KeepassParams = GetKeepassParams $VaultName $AdditionalParameters

    
    
    switch ($Secret.GetType()) {
        ([String]) {
            $KeepassParams.Username = $null
            $KeepassParams.KeepassPassword = [ProtectedString]::New($true, $Secret)
            break
        }
        ([SecureString]) {
            $KeepassParams.Username = $null
            $KeepassParams.KeepassPassword = [ProtectedString]::New($true, (Unlock-SecureString $Secret))
            break
        }
        ([PSCredential]) {
            $KeepassParams.Username = $Secret.Username
            $KeepassParams.KeepassPassword = [ProtectedString]::New($true, $Secret.GetNetworkCredential().Password)
            break
        }
        default {
            Write-PSFMessage -Level Error ([NotImplementedException]'This vault provider only accepts string, securestring, and PSCredential secrets')
            return $false
        }
    }
    
    if (Get-SecretInfo -Name $Name -Vault $VaultName) {
        Write-PSFMessage "Updating Keepass Entry" -Target $Name -Tag Update
        
        try {
            # $KeepassEntry = Get-SecretInfo -Name $Name -Vault $VaultName -AsKPPSObject
            # Need to get the original KPEntry Object for modification
            $KeepassParamsGetKPEntry = GetKeepassParams $VaultName $AdditionalParameters
            # ToDo Sherlock: Got an array but need just one Object
            $KeepassResults = Get-KPEntry @KeepassParamsGetKPEntry -Title $Name
            # $fullPathes = $KeepassResults|Foreach-Object {
            #     $path=$_.ParentGroup.GetFullPath('/', $true)
            #     $title = $_.Strings.ReadSafe('Title')
            #     "Title= $title; Fullpath= $Path;"
            # }
            # Write-PSFMessage -level Host -Tag Sherlock "fullPathes=$fullPathes"
            if ($KeepassResults.count -gt 1){
                Write-PSFMessage -Level Error "Retrieved $($KeepassResults.count) Keepass-Entries, narrow down the criteria"
                return
            }
            $KeepassEntry = $KeepassResults #[1]
            # $KeepassEntry = Get-KPEntry -KeePassConnection $KeepassParams.KeepassConnection -Title $Title
            Write-PSFMessage "Found KeepassEntry=$KeepassEntry" -Level Debug
            # Write-PSFMessage "`$KeepassEntry.getType()=$($KeepassEntry.GetType())" -tag "Sherlock"
        }
        catch {
            Write-PSFMessage -Level Error "Fehler bei Get-KPEntry, $_"  
        }
        # Write-PSFMessage -Level Warning "Vault ${VaultName}: A secret with the title $Name already exists. This vault currently does not support overwriting secrets. Please remove the secret with Remove-Secret first."
        # return $false
       
        $KPEntry = Set-KPEntry @KeepassParams -Title $Name -PassThru -KeePassEntry $KeepassEntry -Confirm:$False
        
        # Write-PSFMessage -Level Warning "Vault ${VaultName}: A secret with the title $Name already exists. This vault currently does not support overwriting secrets. Please remove the secret with Remove-Secret first."
        # return $false
    }
    else {
        #Set default group
        #TODO: Support Creating Secrets with paths
        Write-PSFMessage "Adding Keepass Entry" -Target $Name -Tag Add
        $KeepassParams.KeePassGroup = (Get-Variable "VAULT_$VaultName").Value.RootGroup
        $KPEntry = Add-KPEntry @KeepassParams -Title $Name -PassThru
    }
    
    #Save the changes immediately
    #TODO: Consider making this optional as a vault parameter
    $KeepassParams.KeepassConnection.Save($null)

    return [Bool]($KPEntry)
}

function Test-SecretVault {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName,Mandatory)]
        [Alias('Vault')][Alias('Name')][string]$VaultName,

        #This intelligent default is here because if you call test-secretvault from other commands it doesn't populate like it does when called from SecretManagement
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('VaultParameters')][hashtable]$AdditionalParameters = (get-secretvault $VaultName).VaultParameters
    )
    if ($AdditionalParameters.Verbose) {$VerbosePreference = 'continue'}

    Write-PSFMessage -Level Verbose "SecretManagement: Testing Vault ${VaultName}"
    #TODO: Hash vault parameter settings and reset vault state if they change. May be a bug if user changes vault parameters in same session

    #Test if connection already open, no need to do further testing if so
    try {
        $DBConnection = (Get-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction Stop).Value
        if (-not $DBConnection.isOpen) {
            Write-PSFMessage -Level Error 'Connection closed, starting a new connection'
            return $false
        }
        if (Test-DBChanged $DBConnection) {
            $dbConnection.close()
            Write-PSFMessage -Level Error 'Database file on disk has changed, starting a new connection'
            return $false
        }
        Write-PSFMessage -Level Verbose "Vault ${VaultName}: Connection already open, using existing connection"
        return $dbConnection.isOpen
    } catch {
        Write-PSFMessage -Level Verbose "${VaultName}: $PSItem"
    }

    #Basic Sanity Checks
    if (-not $VaultName) {
        Write-PSFMessage -Level Error 'Keepass: You must specify a Vault Name to test'
        return $false
    }

    if (-not $AdditionalParameters.Path) {
        #TODO: Create a default vault if path isn't supplied
        #TODO: Add ThrowUser to throw outside of module scope
        Write-PSFMessage -Level Error 'You must specify the Path vault parameter as a path to your KeePass Database'
        return $false
    }

    if (-not (Test-Path $AdditionalParameters.Path)) {
        Write-PSFMessage -Level Error "Could not find the keepass database $($AdditionalParameters.Path). Please verify the file exists or re-register the vault"
        return $false
    }

    #3 Scenarios Supported: Master PW, Keyfile, PW + Keyfile
    $ConnectKPDBParams = @{
        Path = $AdditionalParameters.Path
        KeyPath = $AdditionalParameters.KeyPath
        UseWindowsAccount = $AdditionalParameters.UseWindowsAccount
        UseMasterPassword = $AdditionalParameters.UseMasterPassword
    }

    [SecureString]$vaultMasterPassword = Get-Variable -Name "Vault_${VaultName}_MasterPassword" -ValueOnly -ErrorAction SilentlyContinue
    if ($vaultMasterPassword) {
        Write-PSFMessage -Level Verbose "Cached Master Password Found for $VaultName"
        $ConnectKPDBParams.MasterPassword = $vaultMasterPassword
    }

    try {
        $DBConnection = Connect-KeePassDatabase @ConnectKPDBParams
    } catch {
        Write-PSFMessage -Level Error $PSItem
    }


    if ($DBConnection.IsOpen) {
        Set-Variable -Name "Vault_$VaultName" -Scope Script -Value $DBConnection
        return $DBConnection.IsOpen
    }

    #If we get this far something went wrong
    Write-PSFMessage -Level Error "Unable to open connection to the database"
    return $false

    # if (-not $AdditionalParameters.Keypath -or $AdditionalParameters.UseMasterKey) {

    # }
    # if (-not (Get-KeePassDatabaseConfiguration -DatabaseProfileName $VaultName)) {
    #     New-KeePassDatabaseConfiguration @KeePassDBConfigParams
    #     Write-PSFMessage -Level Verbose "Vault ${VaultName}: A PoshKeePass database configuration was not found but was created."
    #     return $true
    # }
    # try {
    #     Get-KeePassEntry -DatabaseProfileName $VaultName -MasterKey $VaultMasterKey -Title '__SECRETMANAGEMENT__TESTSECRET_SHOULDNOTEXIST' -ErrorAction Stop
    # } catch {
    #     Clear-Variable -Name "Vault_$VaultName" -Scope Script -ErrorAction SilentlyContinue
    #     throw $PSItem
    # }
}
function Unlock-SecretVault {
    param (
        [Parameter(Mandatory)][SecureString]$Password,
        [Parameter(Mandatory)][Alias('Vault')][Alias('Name')][String]$VaultName,
        [Alias('VaultParameters')][hashtable]$AdditionalParameters
    )

    Write-PSFMessage "Unlocking SecretVault $VaultName"
    $vault = Get-SecretVault -Name $VaultName -ErrorAction Stop
    $vaultName = $vault.Name
    if ($vault.ModuleName -ne 'SecretManagement.KeePass') {
        Write-PSFMessage -Level Error "$vaultName was found but is not a Keepass Vault."
        return $false
    }
    Set-Variable -Name "Vault_${vaultName}_MasterPassword" -Scope Script -Value $Password -Force
    #Force a reconnection
    Remove-Variable -Name "Vault_${vaultName}" -Scope Script -Force -ErrorAction SilentlyContinue
    if (-not (Test-SecretVault -Name $vaultName -AdditionalParameters $AdditionalParameters)) {
        Write-PSFMessage -Level Error "${vaultName}: Failed to unlock the vault"
        return $false
    }
    Write-PSFMessage "SecretVault $vault unlocked successfull"
    return $true
}
function Unregister-SecretVault {
    [CmdletBinding()]
    param(
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )
    if ($AdditionalParameters.Verbose) {$VerbosePreference = 'continue'}
    try {
        Remove-Variable -Name "Vault_$VaultName" -Scope Script -Force -ErrorAction Stop
    } catch [ItemNotFoundException] {
        Write-PSFMessage -Level Verbose "Vault ${VaultName}: Vault was not loaded at time of deregistration"
    }
}

