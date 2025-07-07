# Requires -Modules @{ModuleName='Microsoft.PowerShell.Utility'; ModuleVersion='7.0.0.0'}

# ##########################################################################
# Import configuration variables from env file
# ##########################################################################
try {
    # Check if the env file exists
    if (-not (Test-Path -Path ".\env")) {
        Write-Warning "The 'env' file was not found in the current directory. Proceeding without importing environment variables."
    } else {
        Get-Content -Path ".\env" | ForEach-Object {
            # Skip comments and empty lines
            if ($_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$') {
                $parts = $_.Split('=', 2)
                if ($parts.Length -eq 2) {
                    $varName = $parts[0].Trim()
                    $varValue = $parts[1].Trim()
                    Set-Item -Path "Env:$varName" -Value $varValue
                    Write-Host "Imported environment variable: $varName=$varValue"
                }
            }
        }
    }
} catch {
    Write-Error "Failed to import variables from 'env' file: $($_.Exception.Message)"
}

# ##########################################################################
# Remote access variables (can be adapted)
# ##########################################################################
# set the default values for remote access ports
# ##########################################################################

$script:XRDP_PORT = $env:XRDP_PORT
if ([string]::IsNullOrEmpty($script:XRDP_PORT)) {
    $script:XRDP_PORT = 13389
}

$script:XVNC_DISPLAY = $env:XVNC_DISPLAY
if ([string]::IsNullOrEmpty($script:XVNC_DISPLAY)) {
    $script:XVNC_DISPLAY = 8
}

$script:XVNC_PORT = $env:XVNC_PORT
if ([string]::IsNullOrEmpty($script:XVNC_PORT)) {
    $script:XVNC_PORT = "590$($script:XVNC_DISPLAY)"
}

$script:XSSH_PORT = $env:XSSH_PORT
if ([string]::IsNullOrEmpty($script:XSSH_PORT)) {
    $script:XSSH_PORT = 20022
}

# ##########################################################################
# Variables (For menu choice - should not be changed)
# ##########################################################################
# The following variables contain the default and the possible choices
# for Desktop Environment, Remote Access, Kali Packages, Network, and build
# architecture
# ##########################################################################

$script:XDESKTOP_CHOICE = @("xfce", "mate", "kde", "e17", "gnome", "i3", "i3-gaps", "live", "lxde")
$script:XREMOTE_CHOICE = @("vnc", "rdp", "x2go")
$script:XKALI_CHOICE = @("arm", "core", "default", "everything", "firmware", "headless", "labs", "large", "nethunter")
$script:XNET_CHOICE = @("bridge", "host")
$script:XBUILD_CHOICE = @("amd64", "arm64")

# ##########################################################################
# menu function
# ##########################################################################
# Takes a string as parameter for the prompt and an array of choices.
# It will then prompt "Please select a xxx" and replace xxx with the first
# element of the array (in the above example "Please select a color")
# It then shows numbers starting from 1 and options you may chose
# ( 1 - blue, 2 - red in the example) and return the user's choice
# in the variable $choice (scope: script)
# ##########################################################################

function menu {
    param (
        [string]$PromptText,
        [array]$Choices
    )

    $script:choice = 0

    while ($true) {
        Write-Host "`nPlease select a $PromptText"
        for ($i = 0; $i -lt $Choices.Length; $i++) {
            Write-Host "$($i + 1) - $($Choices[$i])"
        }

        $inputChoice = Read-Host "Your choice -> "

        if ([int]::TryParse($inputChoice, [ref]$script:choice)) {
            if ($script:choice -ge 1 -and $script:choice -le $Choices.Length) {
                break
            }
        }
        Write-Host "Invalid choice. Please enter a number between 1 and $($Choices.Length)."
    }
}

# ##########################################################################
# Script starting point
# ##########################################################################

Write-Host "This script will create a custom Kali Linux Docker container for you"

# ##########################################
# ask the user what he/she wants to install
# we call the menu function with each of the
# above variables if not specified in .env
# ##########################################

$script:XDESKTOP_ENVIRONMENT = $env:XDESKTOP_ENVIRONMENT
if ([string]::IsNullOrEmpty($script:XDESKTOP_ENVIRONMENT)) {
    menu "Desktop Environment (only xfce for xrdp right now)" $script:XDESKTOP_CHOICE
    $script:XDESKTOP_ENVIRONMENT = $script:XDESKTOP_CHOICE[$script:choice - 1]
}

$script:XREMOTE_ACCESS = $env:XREMOTE_ACCESS
if ([string]::IsNullOrEmpty($script:XREMOTE_ACCESS)) {
    menu "Remote Access Option" $script:XREMOTE_CHOICE
    $script:XREMOTE_ACCESS = $script:XREMOTE_CHOICE[$script:choice - 1]
}

$script:XKALI_PKG = $env:XKALI_PKG
if ([string]::IsNullOrEmpty($script:XKALI_PKG)) {
    menu "Kali Package" $script:XKALI_CHOICE
    $script:XKALI_PKG = $script:XKALI_CHOICE[$script:choice - 1]
}

$script:XNETWORK = $env:XNETWORK
if ([string]::IsNullOrEmpty($script:XNETWORK)) {
    menu "Network" $script:XNET_CHOICE
    $script:XNETWORK = $script:XNET_CHOICE[$script:choice - 1]
}

$script:XBUILD_PLATFORM = $env:XBUILD_PLATFORM
if ([string]::IsNullOrEmpty($script:XBUILD_PLATFORM)) {
    menu "Build Architecture" $script:XBUILD_CHOICE
    $script:XBUILD_PLATFORM = $script:XBUILD_CHOICE[$script:choice - 1]
}

# ##########################################
# additional user config input:
# - Name for local custom Kali Docker image
# - Name for created container
# - Dir of host machine to mount
# - Dir to mount in container
# - Username for container user
# - Password for conatiner user (echo off)
# ##########################################

$script:DOCKERIMG = $env:DOCKERIMG
if ([string]::IsNullOrEmpty($script:DOCKERIMG)) {
    $script:DOCKERIMG = Read-Host "Enter desired local Docker image name (e.g. custom/kali-linux)"
    Write-Host ""
}

$script:CONTAINER = $env:CONTAINER
if ([string]::IsNullOrEmpty($script:CONTAINER)) {
    $script:CONTAINER = Read-Host "Enter desired local Docker container name (e.g. kali-linux)"
    Write-Host ""
}

$script:HOSTDIR = $env:HOSTDIR
if ([string]::IsNullOrEmpty($script:HOSTDIR)) {
    $script:HOSTDIR = Read-Host "Enter host directory to mount"
    Write-Host ""
}

$script:CONTAINERDIR = $env:CONTAINERDIR
if ([string]::IsNullOrEmpty($script:CONTAINERDIR)) {
    $script:CONTAINERDIR = Read-Host "Enter container directory to mount to"
    Write-Host ""
}

$script:USERNAME = $env:USERNAME
if ([string]::IsNullOrEmpty($script:USERNAME)) {
    $script:USERNAME = Read-Host "Enter desired username"
    Write-Host ""
}

$script:PASSWORD = $env:PASSWORD
if ([string]::IsNullOrEmpty($script:PASSWORD)) {
    # Read-Host -AsSecureString is for secure input, but the original script
    # explicitly states "password will show in Docker output" implying plaintext usage.
    # For a direct translation of 'stty -echo', we use a trick with P/Invoke or
    # prompt the user that it will be visible. Given the original comment,
    # simply using Read-Host is appropriate if the password is truly passed plaintext.
    $script:PASSWORD = Read-Host "Enter desired password (password will show in Docker output)"
    Write-Host ""
}

# ##########################################
# show a summary of the Installation choices
# and confirm choices
# ##########################################

Clear-Host
Write-Host "Configuration:`n"
Write-Host "Desktop environment:    $script:XDESKTOP_ENVIRONMENT"
Write-Host "Remote Access:          $script:XREMOTE_ACCESS"
Write-Host "Kali packages:          $script:XKALI_PKG"
Write-Host "Network:                $script:XNETWORK"
Write-Host "Build platform:         $script:XBUILD_PLATFORM"
Write-Host "Image name:             $script:DOCKERIMG"
Write-Host "Container name:         $script:CONTAINER"
Write-Host "Host dir mount:         $script:HOSTDIR"
Write-Host "Container dir mount:    $script:CONTAINERDIR"
Write-Host "Username:               $script:USERNAME"
Write-Host "Password                [redacted]"

Read-Host "`nHit enter to start building the container" | Out-Null

# ##########################################
# build the image
# ##########################################
# call docker build and pass on all
# the choices as build-arg to the Dockerfile
# where they will be interpreted
# ##########################################

# Construct the build arguments dynamically
$buildArgs = @(
    "--platform", "linux/$script:XBUILD_PLATFORM",
    "-t", $script:DOCKERIMG,
    "--build-arg", "DESKTOP_ENVIRONMENT=$script:XDESKTOP_ENVIRONMENT",
    "--build-arg", "REMOTE_ACCESS=$script:XREMOTE_ACCESS",
    "--build-arg", "KALI_PACKAGE=$script:XKALI_PKG",
    "--build-arg", "RDP_PORT=$script:XRDP_PORT",
    "--build-arg", "VNC_PORT=$script:XVNC_PORT",
    "--build-arg", "VNC_DISPLAY=$script:XVNC_DISPLAY",
    "--build-arg", "SSH_PORT=$script:XSSH_PORT",
    "--build-arg", "BUILD_ENV=$script:XBUILD_PLATFORM",
    "--build-arg", "HOSTDIR=$script:HOSTDIR",
    "--build-arg", "CONTAINERDIR=$script:CONTAINERDIR",
    "--build-arg", "UNAME=$script:USERNAME",
    "--build-arg", "UPASS=$script:PASSWORD",
    "." # Context path
)

Write-Host "Running: docker image build $buildArgs"
docker image build @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker image build failed. Exiting."
    exit 1
}

# ##########################################
# create the container
# ##########################################
# call docker create and pass on all
# the choices for network and ports that the
# user has made in the menu
# ##########################################

$createArgs = @(
    "--name", $script:CONTAINER,
    "--network", $script:XNETWORK,
    "--platform", "linux/$script:XBUILD_PLATFORM",
    "-p", "$($script:XRDP_PORT):$($script:XRDP_PORT)",
    "-p", "$($script:XVNC_PORT):$($script:XVNC_PORT)",
    "-p", "$($script:XSSH_PORT):$($script:XSSH_PORT)",
    "-t",
    "-v", "$($script:HOSTDIR):$($script:CONTAINERDIR)",
    $script:DOCKERIMG
)

Write-Host "Running: docker create $createArgs"
docker create @createArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker container creation failed. Exiting."
    exit 1
}

# ##########################################
# start the container
# ##########################################

Write-Host "Image ($script:DOCKERIMG) and container ($script:CONTAINER) build successful. $script:CONTAINER will now start."
docker start $script:CONTAINER

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker container failed to start. Exiting."
    exit 1
}

# ##########################################
# Clear environment variables from env file
# ##########################################
try {
    if (Test-Path -Path ".\env") {
        Get-Content -Path ".\env" | ForEach-Object {
            if ($_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$') {
                $varName = ($_ -split '=', 2)[0].Trim()
                Remove-Item -Path "Env:$varName" -ErrorAction SilentlyContinue
                Write-Host "Unset environment variable: $varName"
            }
        }
    }
} catch {
    Write-Warning "Failed to unset environment variables: $($_.Exception.Message)"
}