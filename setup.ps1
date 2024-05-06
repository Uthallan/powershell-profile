#!/usr/bin/env pwsh

# Set Invariant Culture for consistent behavior across all locales
#[Environment]::SetEnvironmentVariable('DOTNET_SYSTEM_GLOBALIZATION_INVARIANT', '1', 'Process')


# Ensure the script can run with elevated privileges
if ($IsWindows) {
    Write-Host "Operating system environment detected: Windows"
    # Check for Administrator privileges on Windows
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Please run this script as an Administrator!"
        break
    }
} elseif ($IsLinux) {
    Write-Host "Operating system environment detected: Linux"
    # Check for root privileges on Linux
    $userId = $(whoami)
    if ($userId -ne 'root') {
        Write-Warning "Script not running with sudo or as root!"
        
    }
} else {
    Write-Warning "Unsupported or unidentified operating system"
    break
}


# Continue with the script for configuration tasks


# Function to test internet connectivity
function Test-InternetConnection {
    try {
        $testConnection = Test-Connection -ComputerName www.google.com -Count 1 -ErrorAction Stop
        Write-Host "Internet connection test successful"
        return $true
    }
    catch {
        Write-Warning "Internet connection is required but not available. Please check your connection."
        return $false
    }
}

# Check for internet connectivity before proceeding
if (-not (Test-InternetConnection)) {
    break
}

# Profile creation or update
if (!(Test-Path -Path $PROFILE -PathType Leaf)) {
    try {
        # Determine appropriate profile path based on OS and PowerShell Edition
        $profilePath = ""
        $downloadUrl = "https://github.com/Uthallan/powershell-profile/raw/main/Microsoft.PowerShell_profile.ps1"
        
        if ($IsWindows) {
            if ($PSVersionTable.PSEdition -eq "Core") {
                $profilePath = "$env:USERPROFILE\Documents\Powershell"
            } elseif ($PSVersionTable.PSEdition -eq "Desktop") {
                $profilePath = "$env:USERPROFILE\Documents\WindowsPowerShell"
            }

            $outputFile = Join-Path -Path $profilePath -ChildPath "Microsoft.PowerShell_profile.ps1"
            Invoke-RestMethod -Uri $downloadUrl -OutFile $outputFile
            Write-Host "The profile @ [$outputFile] has been created."
            Write-Host "If you want to add any persistent components, please do so at [$profilePath/Profile.ps1] as there is an updater in the installed profile which uses the hash to update the profile and will lead to loss of changes"
        } elseif ($IsLinux) {
            $profilePath = "$env:HOME/.config/powershell"
            $outputFile = $profilePath + "/Microsoft.PowerShell_profile.ps1"
            Invoke-RestMethod -Uri $downloadUrl -OutFile $outputFile
            Write-Host "The profile @ [$outputFile] has been created."
            Write-Host "If you want to add any persistent components, please do so at [$profilePath/Profile.ps1] as there is an updater in the installed profile which uses the hash to update the profile and will lead to loss of changes"
        }

        # Create profile directories if they do not exist
        if (!(Test-Path -Path $profilePath)) {
            New-Item -Path $profilePath -ItemType "directory"
        }

        
        
        
    }
    catch {
        Write-Error "Failed to create or update the profile. Error: $_"
    }
} else {
    try {
        # Determine appropriate profile path based on OS and PowerShell Edition
        $profilePath = ""
        if ($IsWindows) {
            if ($PSVersionTable.PSEdition -eq "Core") {
                $profilePath = "$env:USERPROFILE\Documents\Powershell"
            } elseif ($PSVersionTable.PSEdition -eq "Desktop") {
                $profilePath = "$env:USERPROFILE\Documents\WindowsPowerShell"
            }
        } elseif ($IsLinux) {
            $profilePath = "$env:HOME/.config/powershell"
        }


        # Define the backup directory and create it if it doesn't exist
        $backupDir = Join-Path -Path $profilePath -ChildPath "pwshProfileBackups"
        if (-not (Test-Path -Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory
        }

        # Define the backup file path with a .bak extension
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $backupFilePath = Join-Path -Path $backupDir -ChildPath ("oldprofile_" + $timestamp + ".ps1.bak")

        # Move the old profile to the backup location
        Get-Item -Path $PROFILE | Move-Item -Destination $backupFilePath -Force

        # Download the new profile script
        $downloadUrl = "https://github.com/Uthallan/powershell-profile/raw/main/Microsoft.PowerShell_profile.ps1"
        Invoke-RestMethod -Uri $downloadUrl -OutFile $PROFILE

        Write-Host "The profile @ [$PROFILE] has been created. Old profile backed up to [$backupFilePath]."
        Write-Host "Please back up any persistent components of your old profile to [$profilePath\Profile.ps1] as there is an updater in the installed profile which uses the hash to update the profile and will lead to loss of changes"
    }
    catch {
        Write-Error "Failed to backup and update the profile. Error: $_"
    }
}



# # OMP Install
# if ($IsWindows) {
#     try {
#         winget install -e --accept-source-agreements --accept-package-agreements JanDeDobbeleer.OhMyPosh
#     }
#     catch {
#         Write-Error "Failed to install Oh My Posh. Error: $_"
#     }
# }


# Font Install
if ($IsWindows) {
try {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name

    if ($fontFamilies -notcontains "CaskaydiaCove NF") {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFileAsync((New-Object System.Uri("https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/CascadiaCode.zip")), ".\CascadiaCode.zip")
        
        while ($webClient.IsBusy) {
            Start-Sleep -Seconds 2
        }

        Expand-Archive -Path ".\CascadiaCode.zip" -DestinationPath ".\CascadiaCode" -Force
        $destination = (New-Object -ComObject Shell.Application).Namespace(0x14)
        Get-ChildItem -Path ".\CascadiaCode" -Recurse -Filter "*.ttf" | ForEach-Object {
            If (-not(Test-Path "C:\Windows\Fonts\$($_.Name)")) {        
                $destination.CopyHere($_.FullName, 0x10)
            }
        }

        Remove-Item -Path ".\CascadiaCode" -Recurse -Force
        Remove-Item -Path ".\CascadiaCode.zip" -Force
    }
}
catch {
    Write-Error "Failed to download or install the Cascadia Code font. Error: $_"
}
} elseif ($IsLinux) {
    Write-Host "Font install not implement for Linux. Skipping..."
}


# Final check and message to the user
if ($IsWindows) {
    if ((Test-Path -Path $PROFILE) -and (winget list --name "OhMyPosh" -e) -and ($fontFamilies -contains "CaskaydiaCove NF")) {
        Write-Host "Setup completed successfully. Please restart your PowerShell session to apply changes."
    } else {
        Write-Warning "Setup completed with errors. Please check the error messages above."
    }
} elseif ($IsLinux) {
    Write-Warning "Setup verification not fully implemented for Linux yet."
    if ((Test-Path -Path $PROFILE)) {
        Write-Host "Profile path verified. Please restart your PowerShell session to apply changes."
    } else {
        Write-Warning "Setup completed with errors. Please check the error messages above."
    }
    
}

# Choco install
# try {
#     if ($IsWindows) {
#         Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
#     } elseif ($IsLinux) {
#         Write-Host "Chocolatey installation not implemented for Linux. Skipping..."
#     }
# }
# catch {
#     Write-Error "Failed to install Chocolatey. Error: $_"
# }

# # Terminal Icons Install
# try {
#     if ($IsWindows) {
#         Install-Module -Name Terminal-Icons -Repository PSGallery -Force
#     } elseif ($IsLinux) {
#         Write-Host "Terminal-Icons installation not implemented for Linux yet. Skipping..."
#     }
# }
# catch {
#     Write-Error "Failed to install Terminal Icons module. Error: $_"
# }

# zoxide Install
try {
    if ($IsWindows) {
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installed successfully."
    } elseif ($IsLinux) {
        Write-Host "zoxide installation not implemented for Linux yet. Skipping..."
    }
}
catch {
    Write-Error "Failed to install zoxide. Error: $_"
}

