<#
    Author        = 'Jeff Hicks'
    CompanyName   = 'JDH Information Technology Solutions, Inc.'
    Copyright     = '(c) 2017-2022 JDH Information Technology Solutions, Inc.'
    ProjectUrl    = 'https://github.com/jdhitsolutions/PSScriptTools'
#>

Function ConvertTo-PSClass {
    [cmdletbinding()]
    [outputType([String])]
    Param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [object]$InputObject,
        [Parameter(Mandatory, HelpMessage = "Enter the name of your new class")]
        [ValidatePattern("^\w+$")]
        [string]$Name,
        [Parameter(HelpMessage = "Specify properties to include from the reference inputput object. The default is all properties.")]
        [string[]]$Properties,
        [Parameter(HelpMessage = "Specify properties to exclude from the reference inputput object.")]
        [string[]]$Exclude,
        [Parameter(HelpMessage = "Provide a brief description of the class. It will be inserted into the class definition.")]
        [string]$Description
    )
    Begin {
        Write-Verbose "Starting $($myinvocation.MyCommand)"
        #initialize a counter
        $c = 0
    } #begin

    Process {
        #only need a single instance of the object
        if ($c -eq 0) {
            Write-Verbose "Converting existing type $($InputObject.getType().Fullname)"
            #create a list to hold properties
            $prop = [system.collections.generic.list[object]]::new()

            #define the class here-string
            $myclass = @"

# This class is derived from $($InputObject.getType().Fullname)
# $Description
class $Name {
    #properties

"@

            #get the required properties
            if ($Properties) {
                ($InputObject.psobject.properties).Where({ $Properties -contains $_.name }) |
                Select-Object -Property Name, TypeNameOfValue |
                ForEach-Object {
                    Write-Verbose "Adding $($_.name)"
                    $prop.Add($_)
                } #forEach
            } #if Properties
            else {
                Write-Verbose "Adding all properties"
                $InputObject.psobject.properties | Select-Object -Property Name, TypeNameOfValue |
                ForEach-Object {
                    Write-Verbose "Adding $($_.name)"
                    $prop.Add($_)
                } #foreach
            } #else all

            if ($Exclude) {
                foreach ($item in $Exclude) {
                    Write-Verbose "Excluding $item"
                    #remove properties that are tagged as excluded from the list
                    [void]$prop.remove($($prop.where({ $_.name -like $item })))
                }
            }
            Write-Verbose "Processing $($prop.count) properties"
            foreach ($item in $prop) {
                #add the property definition name to the class
                #e.g. [string]$Name
                $myclass += "`t[{0}]`${1}`n" -f $item.TypeNameOfValue, $item.name
            }

            #add placeholder content to the class definition
            $myclass += @"

    # Methods can be inserted here.
    # Don't forget to use the RETURN key word unless the returntype is [void]
    <#
    [returntype] MethodName(<parameters>) {
        code
        return value
    }
    #>

    #constructor placeholder
    $Name() {
        #insert code here
    }

} #close class definition
"@

            #if running VS Code or the PowerShell ISE, copy the class to the clipboard
            #this code could be modified to insert the class into the current document
            if ($host.name -match "ISE|Visual Studio Code" ) {
                $myClass | Set-Clipboard
                $myClass
                Write-Host "The class definition has been copied to the clipboard." -ForegroundColor green
            }
            else {
                $myClass
            }
            $c++
        } #if first object
        else {
            $c++
            Write-Verbose "Skipping next object"
        }
    } #process
    End {
        Write-Verbose "Ending $($myinvocation.MyCommand)"
    } #end
}