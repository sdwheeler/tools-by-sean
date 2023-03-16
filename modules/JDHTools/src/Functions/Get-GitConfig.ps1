<#
    Author        = 'Jeff Hicks'
    CompanyName   = 'JDH Information Technology Solutions, Inc.'
    Copyright     = '(c) 2017-2022 JDH Information Technology Solutions, Inc.'
    ProjectUrl    = 'https://gist.github.com/jdhitsolutions/2883df22ca7bb1492802f74545af7736'
#>

Function Get-GitConfig {

 <#
.SYNOPSIS
    Get git configuration settings
.DESCRIPTION
    Git stores configurations settings in a simple text file format. Fortunately, this file is structured and predictable. This command will process git configuration information into PowerShell friendly output.
.PARAMETER Scope
    Possible values are Global,Local or System
.PARAMETER Path
    Enter the path to a .gitconfig file. You can use shell paths like ~\.gitconfig
.EXAMPLE
PS C:\> Get-GitConfig

Scope  Category  Name         Setting
-----  --------  ----         -------
global filter    lfs          git-lfs clean -- %f
global filter    lfs          git-lfs smudge -- %f
global filter    lfs          true
global user      name         Art Deco
global user      email        artd@company.com
global gui       recentrepo   C:/Scripts/Gen2Tools
global gui       recentrepo   C:/Scripts/PSVirtualBox
global gui       recentrepo   C:/Scripts/FormatFunctions
global core      editor       powershell_ise.exe
global core      autocrlf     true
global core      excludesfile ~/.gitignore
global push      default      simple
global color     ui           true
global alias     logd         log --oneline --graph --decorate
global alias     last         log -1 HEAD
global alias     pushdev      !git checkout master && git merge dev && git push && git checkout dev
global alias     st           status
global alias     fp           !git fetch && git pull
global merge     tool         kdiff3
global mergetool kdiff3       'C:/Program Files/KDiff3/kdiff3.exe' $BASE $LOCAL $REMOTE -o $MERGED

Getting global configuration settings

.EXAMPLE
PS C:\> Get-GitConfig -scope system | where category -eq 'filter'

Scope  Category Name Setting
-----  -------- ---- -------
system filter   lfs  git-lfs clean -- %f
system filter   lfs  git-lfs smudge -- %f
system filter   lfs  git-lfs filter-process
system filter   lfs  true

Get system configuration and only git filters.
.EXAMPLE
PS S:\PSScriptTools> Get-GitConfig local

Scope Category Name                    Setting
----- -------- ----                    -------
local core     repositoryformatversion 0
local core     filemode                false
local core     bare                    false
local core     logallrefupdates        true
local core     symlinks                false
local core     ignorecase              true
local remote   origin                  https://github.com/jdhitsolutions/PSScriptTools.git
local remote   origin                  +refs/heads/*:refs/remotes/origin/*
local branch   master                  origin
local branch   master                  refs/heads/master

Get the git configuration from a local repository.

.EXAMPLE
PS C:\> Get-GitConfig -path ~\.gitconfig | format-table -groupby category -property Name,Setting

Get settings from a configuration file and present in a grouped, formatted table.

.INPUTS
    none
.OUTPUTS
    [gitConfig]
.NOTES
    The command assumes you have git installed. Otherwise, why would you be using this?

    Learn more about PowerShell: http://jdhitsolutions.com/blog/essential-powershell-resources/

    Last updated: 1 February, 2019
.LINK
    git
#>

    [CmdletBinding(DefaultParameterSetName = "default")]
    [OutputType("gitConfig")]
    [Alias("ggc")]

    Param (
        [Parameter(Position = 0, ParameterSetName = "default")]
        [ValidateSet("Global", "System", "Local")]
        [string[]]$Scope = "Global",
        [Parameter(ParameterSetName = "file")]
        #the path to a .gitconfig file which must be specified if scope if File
        [ValidateScript( {Test-Path $_})]
        [Alias("config")]
        [string]$Path
    )

    Begin {
        Write-Verbose "Starting $($myinvocation.MyCommand)"
        if ($path) {
            #convert path value to a complete file system path
            $Path = Convert-Path -Path $path
        }

        #internal helper function
        function _process {
            [cmdletbinding()]
            Param(
                [scriptblock]$scriptblock,
                [string]$Scope
            )

            Write-Verbose "Invoking $($scriptblock.tostring())"
            #invoke the scriptblock and save the text output
            $data = Invoke-Command -scriptblock $scriptblock

            #split each line of the config on the = sign
            #and add to the hashtable
            foreach ($line in $data) {
                $split = $line.split("=")
                #split the first element again to get the category and name
                $sub = $split[0].split(".")
                [PSCustomObject]@{
                    PSTypeName   = 'gitConfig'
                    Scope        = $scope
                    Category     = $sub[0]
                    Name         = $sub[1]
                    Setting      = $split[1]
                    Username     = $env:username
                    Computername = $env:COMPUTERNAME
                }
            } #foreach line
        } # _process
    } #begin

    Process {

        if ($PSCmdlet.ParameterSetName -eq 'file') {
            Write-Verbose "Getting config from $path"
            $get = [scriptblock]::Create("git config --file $path --list")
            #call the helper function
            _process -scriptblock $get -scope "File"
        }
        else {
            foreach ($item in $Scope) {
                Write-Verbose "Getting $item config"
                #the git command is case sensitive so make the scope lower case
                $item = $item.tolower()

                #create a scriptblock to run git config
                $get = [scriptblock]::Create("git config --$item --list")

                #call the helper function
                _process -scriptblock $get -Scope $item
            } #foreach scope
        } #else
    } #process

    End {
        Write-Verbose "Ending $($myinvocation.MyCommand)"
    } #end

} #end Get-GitConfig

#define a default set of properties to the custom gitConfig type
Update-TypeData -TypeName 'gitConfig' -DefaultDisplayPropertySet 'Scope', 'Category', 'Name', 'Setting' -force
#define some alias properties that might be more 'git-like'
Update-TypeData -TypeName 'gitConfig' -MemberType AliasProperty -MemberName 'Value' -Value 'Setting' -force
Update-TypeData -TypeName 'gitConfig' -MemberType AliasProperty -MemberName 'Section' -Value 'Category' -force
#add a custom property
Update-TypeData -TypeName 'gitConfig' -MemberType ScriptProperty -MemberName gitVersion -value {git --version} -force