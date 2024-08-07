<#
.SYNOPSIS
Sets the location for the Azure resource group for the current azd environment.

.DESCRIPTION
The `Set-ResourceGroupLocation` function prompts the user to enter a location for the Azure resource group. If a default location is provided, the user can press ENTER to use the default value. The function validates the entered location against a list of available Azure regions and sets the environment variable for the resource group location if the entered location is valid.

.PARAMETER envVarName
The name of the environment variable to set for the resource group location.

.PARAMETER resourceAlias
A descriptive alias for the type of resources being set (e.g., "Vision", "Document Intelligence").

.PARAMETER availableRegions
An array of available Azure regions to validate the entered location against. This can be retrieved using the `az account list-locations` command.

.PARAMETER defaultLocation
The default location to use if the user does not provide a new location.

.EXAMPLE
Set-ResourceGroupLocation -envVarName "RESOURCE_GROUP_LOCATION" -resourceAlias "resource group" -availableRegions $availableRegions -defaultLocation $defaultLocation

This example sets the location for the resource group using the provided environment variable name, location alias, available regions, and default location.

.NOTES
- The function will prompt the user to enter a location if the default location is not set.
- The function will loop until a valid Azure region is entered.
- The function sets the specified environment variable to the valid location entered by the user.
#>
function Set-ResourceGroupLocation {
    param (
        [string]$envVarName,
        [string]$resourceAlias,
        [string]$accountKind,
        [string[]]$availableRegions,
        [string]$defaultLocation
    )

    while ($true) {
        # Check if the default location is already set
        if ($defaultLocation) {
            $location = Read-Host "Please enter the location for your $resourceAlias resources (or press ENTER to use the default value: $defaultLocation)"
                     
            # Use the current value if the user presses ENTER
            if ([string]::IsNullOrWhiteSpace($location)) {
                $location = $defaultLocation
            }
        }
        else {
            # Default location is not set
            $location = Read-Host "Please enter the location for your $resourceAlias resources"
        }          

        # Check if the entered location is valid
        if ($availableRegions -contains $location) {
            # Check if the relevant resource kind is available in the selected region
            $result = az cognitiveservices account list-skus --kind $accountKind --location $location | ConvertFrom-Json
            # The relevant resource kind is not available in the selected region
            if ($result.Length -eq 0) {
                # List which locations are available
                $json = az cognitiveservices account list-skus --kind $accountKind | ConvertFrom-Json
                $filteredJson = $json | Where-Object { $_.kind -eq $accountKind -and $_.tier -ne 'Free' }
                $sortedJson = $filteredJson | Sort-Object locations
                            
                Write-Host "$resourceAlias resources are not available in the selected region." -ForegroundColor Red
                Write-Host "Available regions for $resourceAlias resources are:`n$($sortedJson.locations)" -ForegroundColor Yellow
            }
            # The relevant resource kind is available in the selected region
            else {
                azd env set $envVarName $location
                break
            }    
        }
        # Entered location is not a valid Azure region
        else {
            Write-Host "Invalid Azure region: $location. Please check for typos." -ForegroundColor Red
            Write-Host "Available regions are:`n$availableRegions" -ForegroundColor Yellow
        }
    }
}
<#
.SYNOPSIS
Prompts the user for confirmation before an action is performed, returning $true or $false as applicable.

.DESCRIPTION
The `Get-Confirmation` function prompts the user to respond to a y/n prompt. The user can press ENTER to use the default value of Y. The function validates the response and loops until a valid response of y, n, or ENTER is received.

.PARAMETER message
The message to be displayed when prompting for a response. As the only parameter, you can either just put the message or specify the -message parameter followed by the message.

.EXAMPLE
Get-Confirmation "Would you like to do the thing? (Y/n)"

This example prompts the user and returns $true or $false depending on the response from the user.

.NOTES
- The function will prompt the user respond with either a y, n, or pressing ENTER.
- The function will loop until a response is received.
- The function returns $true or $false depending on the response received. If ENTER or y is received, $true is returned. Otherwise, $false is returned.
#>
function Get-Confirmation {
    param (
        [Parameter(Mandatory=$true)]
        [string]$message
    )
    while ($true) {
        $confirmation = Read-Host $message
        # $true
        if ([string]::IsNullOrWhiteSpace($confirmation) -or $confirmation -eq 'y' ) {
            return $true
        }
        # $false
        elseif ($confirmation -eq 'n') {
            return $false
        }
        # Invalid entry
        else {
            Write-Host "Invalid selection. Please enter y or n." -ForegroundColor Yellow
        }
    }
}

Write-Host "Running pre-provision script..." -ForegroundColor Cyan

# Get object ID of the current user if the env var is not already set
if (-not $env:YOUR_OBJECT_ID) {
    $UserObjectId = az ad signed-in-user show --query id -o tsv
    if (-not $UserObjectId) {
        Write-Host "Unable to obtain your Entra ID user object ID." -ForegroundColor Red
        $UserObjectId = Read-Host "Please enter your Object ID and press ENTER"
    }
    else {
        # $CorrectObjectId = Read-Host "Is this your Object ID? $UserObjectId (y/n)"
        if (-not (Get-Confirmation "Is this your Object ID? $UserObjectId (Y/n)")) {
            $UserObjectId = Read-Host "Please enter your Object ID and press ENTER"
        }
    }
    azd env set YOUR_OBJECT_ID $UserObjectId
}

# Set the resource group name for the multi-service account (always deployed)
$MultiResourceGroup = "multi-${env:AZURE_ENV_NAME}-rg"
azd env set MULTI_RESOURCE_GROUP $MultiResourceGroup

# List of available Azure regions
Write-Host "Getting a list of available Azure regions..."
$availableRegions = az account list-locations --query "[].name" -o tsv | Sort-Object

# Ensure the DEFAULT_LOCATION environment variable is set
if (-not $env:DEFAULT_LOCATION) {
    # Check if AZURE_LOCATION environment variable (as part of 'azd up')
    if ($env:AZURE_LOCATION) {
        $defaultLocation = Read-Host "Please enter the default location for your resources (or press ENTER to use the Azure location value: $($env:AZURE_LOCATION))"
       
        # Use the AZURE_LOCATION value if the user presses ENTER
        if ([string]::IsNullOrWhiteSpace($defaultLocation)) {
            $defaultLocation = $env:AZURE_LOCATION
        }
    }
    else {
        # Azure location is not set
        $defaultLocation = Read-Host "Please enter the default location for your resources"
    }
       
    # Check if the entered location is valid
    if (-not($availableRegions -contains $defaultLocation)) {
        Write-Host "Invalid Azure region: $defaultLocation. Please check for typos." -ForegroundColor Red
        Write-Host "Available regions are:`n$availableRegions" -ForegroundColor Yellow
        # Ask the user to enter the location again
        $defaultLocation = Read-Host "Please enter a valid default location for your resources"
    }
    # Set the DEFAULT_LOCATION environment variable
    azd env set DEFAULT_LOCATION $defaultLocation
}
else {
    # If DEFAULT_LOCATION environment variable is set, store it in a variable
    $defaultLocation = $env:DEFAULT_LOCATION
}

# Provision all demos or ask the user which demos to provision
# $ProvisionAllDemos = Read-Host "Provision all demos? (y/n)"
if (Get-Confirmation "Provision all demos? (Y/n)") {
    # Intro
    azd env set INTRO_DEMO "true"
    if (-not $env:INTRO_RESOURCE_GROUP) {
        # Ensure the INTRO_RESOURCE_GROUP environment variable is set
        $IntroResourceGroup = "intro-${env:AZURE_ENV_NAME}-rg"
        azd env set INTRO_RESOURCE_GROUP $IntroResourceGroup
    }

    # Vision
    azd env set VISION_DEMO "true"
    if (-not $env:VISION_RESOURCE_GROUP) {
        # Ensure the VISION_RESOURCE_GROUP environment variable is set
        $VisionResourceGroup = "vision-${env:AZURE_ENV_NAME}-rg"
        azd env set VISION_RESOURCE_GROUP $VisionResourceGroup
              
        # Ensure the VISION_LOCATION environment variable is set
        if (-not $env:VISION_LOCATION) {
            Set-ResourceGroupLocation -envVarName "VISION_LOCATION" -resourceAlias "Vision" -accountKind "ComputerVision" -availableRegions $availableRegions -defaultLocation $defaultLocation
        }
    }

    # Language
    azd env set LANGUAGE_DEMO "true"
    # Ensure the LANGUAGE_RESOURCE_GROUP environment variable is set
    if (-not $env:LANGUAGE_RESOURCE_GROUP) {
        $LanguageResourceGroup = "language-${env:AZURE_ENV_NAME}-rg"
        azd env set LANGUAGE_RESOURCE_GROUP $LanguageResourceGroup
    }

    # OpenAI
    azd env set OPENAI_DEMO "true"
    if (-not $env:OPENAI_RESOURCE_GROUP) {
        # Ensure the OPENAI_RESOURCE_GROUP environment variable is set
        $OpenAIResourceGroup = "aoai-${env:AZURE_ENV_NAME}-rg"
        azd env set OPENAI_RESOURCE_GROUP $OpenAIResourceGroup
              
        # Ensure the AOAI_LOCATION environment variable is set
        if (-not $env:AOAI_LOCATION) {
            Set-ResourceGroupLocation -envVarName "AOAI_LOCATION" -resourceAlias "Azure OpenAI" -accountKind "OpenAI" -availableRegions $availableRegions -defaultLocation $defaultLocation
        }
    }

    # Search
    azd env set SEARCH_DEMO "true"
    # Ensure the SEARCH_RESOURCE_GROUP environment variable is set
    if (-not $env:SEARCH_RESOURCE_GROUP) {
        $SearchResourceGroup = "search-${env:AZURE_ENV_NAME}-rg"
        azd env set SEARCH_RESOURCE_GROUP $SearchResourceGroup
    }
       
    # Doc Intel
    azd env set DOCINTEL_DEMO "true"
    # Ensure the DOCINTEL_RESOURCE_GROUP environment variable is set
    if (-not $env:DOCINTEL_RESOURCE_GROUP) {
        $DocIntelResourceGroup = "docintel-${env:AZURE_ENV_NAME}-rg"
        azd env set DOCINTEL_RESOURCE_GROUP $DocIntelResourceGroup

        # Ensure the DOCINTEL_LOCATION environment variable is set
        if (-not $env:DOCINTEL_LOCATION) {
            Set-ResourceGroupLocation -envVarName "DOCINTEL_LOCATION" -resourceAlias "Document Intelligence" -accountKind "FormRecognizer" -availableRegions $availableRegions -defaultLocation $defaultLocation
        }
    }
}
else {
    # Provision only the selected demos

    # Ensure the INTRO_DEMO environment variable is set
    # $IntroDemo = Read-Host "Provision Intro Demo? (y/n)"
    if (Get-Confirmation "Provision Intro Demo? (Y/n)") {
        azd env set INTRO_DEMO "true"
        if (-not $env:INTRO_RESOURCE_GROUP) {
            # Ensure the INTRO_RESOURCE_GROUP environment variable is set
            $IntroResourceGroup = "intro-${env:AZURE_ENV_NAME}-rg"
            azd env set INTRO_RESOURCE_GROUP $IntroResourceGroup
        }
    }
    else {
        azd env set INTRO_DEMO "false"
    }

    # Ensure the VISION_DEMO environment variable is set
    # $VisionDemo = Read-Host "Provision Vision Demo? (y/n)"
    if (Get-Confirmation "Provision Vision Demo? (Y/n)") {
        azd env set VISION_DEMO "true"
        if (-not $env:VISION_RESOURCE_GROUP) {
            # Ensure the VISION_RESOURCE_GROUP environment variable is set
            $VisionResourceGroup = "vision-${env:AZURE_ENV_NAME}-rg"
            azd env set VISION_RESOURCE_GROUP $VisionResourceGroup

            # Ensure the VISION_LOCATION environment variable is set
            if (-not $env:VISION_LOCATION) {
                Set-ResourceGroupLocation -envVarName "VISION_LOCATION" -resourceAlias "Vision" -accountKind "ComputerVision" -availableRegions $availableRegions -defaultLocation $defaultLocation
            }
        }
    }
    else {
        azd env set VISION_DEMO "false"
    }

    # Ensure the LANGUAGE_DEMO environment variable is set
    # $LanguageDemo = Read-Host "Provision Language Demo? (y/n)"
    if (Get-Confirmation "Provision Language Demo? (Y/n)") {
        azd env set LANGUAGE_DEMO "true"
        # Ensure the LANGUAGE_RESOURCE_GROUP environment variable is set
        if (-not $env:LANGUAGE_RESOURCE_GROUP) {
            $LanguageResourceGroup = "language-${env:AZURE_ENV_NAME}-rg"
            azd env set LANGUAGE_RESOURCE_GROUP $LanguageResourceGroup
        }
    }
    else {
        azd env set LANGUAGE_DEMO "false"
    }

    # Ensure the OPENAI_DEMO environment variable is set
    # $OpenAIDemo = Read-Host "Provision Azure OpenAI Demo? (y/n)"
    if (Get-Confirmation "Provision Azure OpenAI Demo? (Y/n)") {
        azd env set OPENAI_DEMO "true"
        if (-not $env:OPENAI_RESOURCE_GROUP) {
            # Ensure the OPENAI_RESOURCE_GROUP environment variable is set
            $OpenAIResourceGroup = "aoai-${env:AZURE_ENV_NAME}-rg"
            azd env set OPENAI_RESOURCE_GROUP $OpenAIResourceGroup

            # Ensure the AOAI_LOCATION environment variable is set
            if (-not $env:AOAI_LOCATION) {
                Set-ResourceGroupLocation -envVarName "AOAI_LOCATION" -resourceAlias "Azure OpenAI" -accountKind "OpenAI" -availableRegions $availableRegions -defaultLocation $defaultLocation
            }
        }
    }
    else {
        azd env set OPENAI_DEMO "false"
    }

    # Ensure the SEARCH_DEMO environment variable is set
    # $SearchDemo = Read-Host "Provision Search Demo? (y/n)"
    if (Get-Confirmation "Provision Search Demo? (Y/n)") {
        azd env set SEARCH_DEMO "true"
        # Ensure the SEARCH_RESOURCE_GROUP environment variable is set
        if (-not $env:SEARCH_RESOURCE_GROUP) {
            $SearchResourceGroup = "search-${env:AZURE_ENV_NAME}-rg"
            azd env set SEARCH_RESOURCE_GROUP $SearchResourceGroup
        }
    }
    else {
        azd env set SEARCH_DEMO "false"
    }

    # Ensure the DOCINTEL_DEMO environment variable is set
    # $DocIntelDemo = Read-Host "Provision Document Intelligence Demo? (y/n)"
    if (Get-Confirmation "Provision Document Intelligence Demo? (Y/n)") {
        azd env set DOCINTEL_DEMO "true"
        # Ensure the DOCINTEL_RESOURCE_GROUP environment variable is set
        if (-not $env:DOCINTEL_RESOURCE_GROUP) {
            $DocIntelResourceGroup = "docintel-${env:AZURE_ENV_NAME}-rg"
            azd env set DOCINTEL_RESOURCE_GROUP $DocIntelResourceGroup

            # Ensure the DOCINTEL_LOCATION environment variable is set
            if (-not $env:DOCINTEL_LOCATION) {
                Set-ResourceGroupLocation -envVarName "DOCINTEL_LOCATION" -resourceAlias "Document Intelligence" -accountKind "FormRecognizer" -availableRegions $availableRegions -defaultLocation $defaultLocation
            }
        }
    }
    else {
        azd env set DOCINTEL_DEMO "false"
    }
}
Write-Host "Pre-provision script complete." -ForegroundColor Green
