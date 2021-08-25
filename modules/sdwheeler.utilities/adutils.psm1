#-------------------------------------------------------
#region AD Functions
function getuser {
    param( [string]$sam)
    $adprops = @('DistinguishedName','SamAccountName','UserPrincipalName','mail','DisplayName','GivenName','sn','Title','Department','telephoneNumber','MobilePhone','StreetAddress','City','State','PostalCode','Country','Manager','sbuxManagerNumber','extensionAttribute7','sbuxJobNumber','EmployeeNumber','sbuxLocalMarketEmployeeID','sbuxCostCenter','extensionAttribute1','employeeType','sbuxEmployeeStatus','extensionAttribute15','sbuxSourceSystem','extensionAttribute8','sbuxImmutableID','ObjectGUID','objectSid','Created','LastLogonDate','PasswordLastSet','LastBadPasswordAttempt','Enabled','LockedOut','PasswordExpired','PasswordNeverExpires','PasswordNotRequired','Description','otherLoginWorkstations','proxyAddresses')
    get-aduser $sam -prop * | Select-Object $adprops
  }
  function Get-XADUserPasswordExpirationDate {
    Param ([Parameter(Mandatory=$true,  Position=0,  ValueFromPipeline=$true, HelpMessage='Identity of the Account')]
    [Object] $accountIdentity)
    PROCESS {
      $accountObj = Get-ADUser $accountIdentity -properties PasswordExpired, PasswordNeverExpires, PasswordLastSet
      $accountObj
      if ($accountObj.PasswordExpired) {
        Write-Output ('Password of account: ' + $accountObj.Name + ' already expired!')
      } else {
        if ($accountObj.PasswordNeverExpires) {
          Write-Output ('Password of account: ' + $accountObj.Name + ' is set to never expires!')
        } else {
          $passwordSetDate = $accountObj.PasswordLastSet
          if ($null -eq $passwordSetDate) {
            Write-Output ('Password of account: ' + $accountObj.Name + ' has never been set!')
          }  else {
            $maxPasswordAgeTimeSpan = $null
            $dfl = (get-addomain).DomainMode
            if ($dfl -ge 3) {
              ## Greater than Windows2008 domain functional level
              $accountFGPP = Get-ADUserResultantPasswordPolicy $accountObj
              if ($null -ne $accountFGPP) {
                $maxPasswordAgeTimeSpan = $accountFGPP.MaxPasswordAge
              } else {
                $maxPasswordAgeTimeSpan = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
              }
            } else {
              $maxPasswordAgeTimeSpan = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
            }
            if ($null -eq $maxPasswordAgeTimeSpan -or $maxPasswordAgeTimeSpan.TotalMilliseconds -eq 0) {
              Write-Output ('MaxPasswordAge is not set for the domain or is set to zero!')
            } else {
              Write-Output ('Password of account: ' + $accountObj.SamAccountName + ' expires on: ' + ($passwordSetDate + $maxPasswordAgeTimeSpan))
            }
          }
        }
      }
    }
  }
  function phone {
    param([string[]]$names)
    $users = $names | ForEach-Object{ Get-ADUser -identity $_ -prop sAMAccountName,DisplayName,telephonenumber,EmailAddress,physicalDeliveryOfficeName,title,mobile,department }
    $users | Select-Object @{l='account';e={$_.sAMAccountName}},
    @{l='name';e={$_.DisplayName}},
    title,
    department,
    @{l='email';e={$_.EmailAddress}},
    @{l='phone';e={$_.telephonenumber}},
    @{l='mobile';e={$_.mobile}},
    @{l='office';e={$_.physicalDeliveryOfficeName}}
  }
  Function Get-LocalGroupMembership {
    <#
        .Synopsis
        Get the local group membership.

        .Description
        Get the local group membership.

        .Parameter ComputerName
        Name of the Computer to get group members. Default is "localhost".

        .Parameter GroupName
        Name of the GroupName to get members from. Default is "Administrators".

        .Example
        Get-LocalGroupMembership
        Description
        -----------
        Get the Administrators group membership for the localhost

        .Example
        Get-LocalGroupMembership -ComputerName SERVER01 -GroupName "Remote Desktop Users"
        Description
        -----------
        Get the membership for the the group "Remote Desktop Users" on the computer SERVER01

        .Example
        Get-LocalGroupMembership -ComputerName SERVER01,SERVER02 -GroupName "Administrators"
        Description
        -----------
        Get the membership for the the group "Administrators" on the computers SERVER01 and SERVER02

        .OUTPUTS
        PSCustomObject

        .INPUTS
        Array

        .Link
        N/A

        .Notes
        NAME:      Get-LocalGroupMembership
        AUTHOR:    Francois-Xavier Cat
        WEBSITE:   www.LazyWinAdmin.com
    #>
    [Cmdletbinding()]

    PARAM (
      [alias('DnsHostName','__SERVER','Computer','IPAddress')]
      [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
      [string[]]$ComputerName = $env:COMPUTERNAME,

      [string]$GroupName = 'Administrators'

    )
    BEGIN{
    }#BEGIN BLOCK

    PROCESS{
      foreach ($Computer in $ComputerName){
        TRY{
          $Everything_is_OK = $true

          # Testing the connection
          Write-Verbose -Message "$Computer - Testing connection..."
          Test-Connection -ComputerName $Computer -Count 1 -ErrorAction Stop |Out-Null

          # Get the members for the group and computer specified
          Write-Verbose -Message "$Computer - Querying..."
          $Group = [ADSI]"WinNT://$Computer/$GroupName,group"
          $Members = @($group.psbase.Invoke('Members'))
        }#TRY
        CATCH{
          $Everything_is_OK = $false
          Write-Warning -Message "Something went wrong on $Computer"
          Write-Verbose -Message "Error on $Computer"
        }#Catch

        IF($Everything_is_OK){
          # Format the Output
          Write-Verbose -Message "$Computer - Formatting Data"
          $members | ForEach-Object {
            $name = $_.GetType().InvokeMember('Name', 'GetProperty', $null, $_, $null)
            $class = $_.GetType().InvokeMember('Class', 'GetProperty', $null, $_, $null)
            $path = $_.GetType().InvokeMember('ADsPath', 'GetProperty', $null, $_, $null)

            # Find out if this is a local or domain object
            if ($path -like "*/$Computer/*"){
              $Type = 'Local'
            }
            else {$Type = 'Domain'
            }

            $Details = '' | Select-Object ComputerName,Account,Class,Group,Path,Type
            $Details.ComputerName = $Computer
            $Details.Account = $name
            $Details.Class = $class
            $Details.Group = $GroupName
            $details.Path = $path
            $details.Type = $type

            # Show the Output
            $Details
          }
        }#IF(Everything_is_OK)
      }#Foreach
    }#PROCESS BLOCK

    END{Write-Verbose -Message 'Script Done'}#END BLOCK
  }
  function get-aduserpic {
    param($samname)
    $user = Get-ADUser $samname -Properties thumbnailphoto
    $user.thumbnailphoto | Set-Content .\$samname.jpg -Encoding byte
  }
  function set-aduserpic {
    param($samname)
    $photo = [byte[]](Get-Content .\$samname.jpg -Encoding byte)
    Set-ADUser $samname -Replace @{thumbnailPhoto=$photo}
  }
  #endregion
