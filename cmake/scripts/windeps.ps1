# MIT License
# Copyright (c) 2023 SineStriker

# Description: This script calls `qmcorecmd` to deploy dependencies on Windows.

param()

function Show-Usage {
    $scriptName = Split-Path $MyInvocation.ScriptName -Leaf
    Write-Host "Usage: $scriptName -i <dir> -m <path>"
    Write-Host "                --plugindir <plugin_dir> --libdir <lib_dir> --qmldir <qml_dir>"
    Write-Host "               [--qmake <qmake_path>] [--extra <extra_path>]..."
    Write-Host "               [--qml <qml_module>]... [--plugin <plugin>]... [--copy <src> <dest>]..."
    Write-Host "               [-@ <file>]... [-L <path>]..."
    Write-Host "               [-f] [-s] [-V] [-h]"
}

# Check debug version of a dll
function Check-Debug {
    param([string]$FilePath)
    
    # Return $true if it's a debug version that should be skipped
    if ($FilePath.EndsWith(".pdb")) { return $true }
    if ($FilePath.EndsWith(".dll.debug")) { return $true }
    if ($FilePath.EndsWith("d.dll")) {
        $prefix = $FilePath.Substring(0, $FilePath.Length - 5)
        if (Test-Path "$prefix.dll") {
            return $true
        }
    }
    return $false
}

# Add plugin if not already found
function Add-Plugin {
    param([string]$PluginPath)
    
    $pluginName = Split-Path $PluginPath -Leaf
    
    if ($pluginName -notin $script:FoundPlugins) {
        $script:FoundPlugins += $pluginName
        $script:DeployArgs += "-c"
        $script:DeployArgs += $PluginPath
        $script:DeployArgs += $script:DestinationDir
    }
}

# Search plugins
function Search-Plugin {
    param(
        [string]$Category,
        [string]$Name,
        [array]$PluginPaths
    )
    
    foreach ($path in $PluginPaths) {
        if ($path) {
            $searchPattern = Join-Path $path "$Category\$Name.dll"
            $matchingFiles = Get-ChildItem -Path $searchPattern -ErrorAction SilentlyContinue
            
            # Process each matching file
            foreach ($pluginFile in $matchingFiles) {
                $isDebug = Check-Debug -FilePath $pluginFile.FullName
                if (-not $isDebug) {
                    Add-Plugin -PluginPath $pluginFile.FullName
                }
            }
        }
    }
}

# Copy or add to a deployment command
function Handle-QmlFile {
    param([string]$FilePath)
    
    $FilePath = $FilePath -replace '/', '\'
    
    # Ignore debug files
    if (Check-Debug -FilePath $FilePath) {
        return
    }
    
    # Compute relative path and target
    $relPath = $FilePath -replace [regex]::Escape($QmlPath + "\"), ""
    $target = Join-Path $QmlDir $relPath
    $fileDir = Split-Path $FilePath -Parent
    $relDirPath = $fileDir -replace [regex]::Escape($QmlPath + "\"), ""
    $targetDir = Join-Path $QmlDir $relDirPath
    
    # Handle binary files differently
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if ($extension -eq ".dll" -or $extension -eq ".exe") {
        $script:DeployArgs += "-c"
        $script:DeployArgs += $FilePath
        $script:DeployArgs += $targetDir
    } else {
        # Copy non-binary files directly
        if (-not (Test-Path $target)) {
            $targetParent = Split-Path $target -Parent
            if (-not (Test-Path $targetParent)) {
                New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            }
        }
        try {
            Copy-Item $FilePath $target -Force | Out-Null
        }
        catch {
            Write-Warning "Failed to copy $FilePath to $target : $_"
        }
    }
}

# Search QML directory
function Search-QmlDir {
    param([string]$QmlRelPath)
    
    $fullPath = Join-Path $QmlPath $QmlRelPath
    
    if (Test-Path $fullPath -PathType Container) {
        # Directory
        Get-ChildItem -Path $fullPath -Recurse -File | ForEach-Object {
            Handle-QmlFile -FilePath $_.FullName
        }
    } elseif (Test-Path $fullPath -PathType Leaf) {
        # File
        Handle-QmlFile -FilePath $fullPath
    }
}

# Initialize arguments
$InputDir = ""
$PluginDir = ""
$LibDir = ""
$QmlDir = ""
$QmakePath = ""
$CorecmdPath = ""
$Verbose = ""
$Files = @()
$ExtraPluginPaths = @()
$Plugins = @()
$PluginCount = 0
$QmlRelPaths = @()
$DeployArgs = @()

# Parse command line
$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        "-i" {
            $InputDir = $args[$i + 1]
            $i += 2
        }
        "-m" {
            $CorecmdPath = $args[$i + 1]
            $i += 2
        }
        "--plugindir" {
            $PluginDir = $args[$i + 1]
            $i += 2
        }
        "--libdir" {
            $LibDir = $args[$i + 1]
            $i += 2
        }
        "--qmldir" {
            $QmlDir = $args[$i + 1]
            $i += 2
        }
        "--qmake" {
            $QmakePath = $args[$i + 1]
            $i += 2
        }
        "--extra" {
            $ExtraPluginPaths += $args[$i + 1]
            $i += 2
        }
        "--plugin" {
            $PluginCount++
            $Plugins += $args[$i + 1]
            $i += 2
        }
        "--qml" {
            $QmlRelPaths += $args[$i + 1]
            $i += 2
        }
        "--copy" {
            $DeployArgs += "-c"
            $DeployArgs += $args[$i + 1]
            $DeployArgs += $args[$i + 2]
            $i += 3
        }
        "-f" {
            $DeployArgs += "-f"
            $i++
        }
        "-s" {
            $DeployArgs += "-s"
            $i++
        }
        "-V" {
            $Verbose = "-V"
            $i++
        }
        "-h" {
            Show-Usage
            exit 0
        }
        "-@" {
            $DeployArgs += "-@"
            $DeployArgs += $args[$i + 1]
            $i += 2
        }
        "-L" {
            $DeployArgs += "-L"
            $DeployArgs += $args[$i + 1]
            $i += 2
        }
        default {
            $i++
        }
    }
}

# Check required arguments
if (-not $InputDir) {
    throw "Error: Missing required argument 'INPUT_DIR'"
}
if (-not $PluginDir) {
    throw "Error: Missing required argument 'PLUGIN_DIR'"
}
if (-not $LibDir) {
    throw "Error: Missing required argument 'LIB_DIR'"
}
if (-not $QmlDir) {
    throw "Error: Missing required argument 'QML_DIR'"
}
if (-not $CorecmdPath) {
    throw "Error: Missing required argument 'CORECMD_PATH'"
}

# Normalize paths (replace forward slashes with backslashes)
$InputDir = $InputDir -replace '/', '\'
$PluginDir = $PluginDir -replace '/', '\'
$LibDir = $LibDir -replace '/', '\'
$QmlDir = $QmlDir -replace '/', '\'
$CorecmdPath = $CorecmdPath -replace '/', '\'

# Get Qt plugin and QML paths
$PluginPaths = @()
$QmlPath = ""
if ($QmakePath) {
    try {
        $QmakePluginPath = & $QmakePath -query QT_INSTALL_PLUGINS
        $PluginPaths += $QmakePluginPath
        $QmlPath = (& $QmakePath -query QT_INSTALL_QML) -replace '/', '\'
        
        # Add Qt bin directory
        $QtBinPath = & $QmakePath -query QT_INSTALL_BINS
        $DeployArgs += "-L"
        $DeployArgs += $QtBinPath
    }
    catch {
        Write-Warning "Failed to query qmake paths: $_"
    }
}

# Add extra plugin searching paths
$PluginPaths += $ExtraPluginPaths

# Ensure that the QML search path is not empty when QML related path is specified
if ($QmlRelPaths.Count -gt 0 -and -not $QmlPath) {
    throw "Error: qmake path must be specified when QML paths are provided"
}

# Search for .exe and .dll files in input directory
Get-ChildItem -Path $InputDir -Recurse -Include "*.exe", "*.dll" | ForEach-Object {
    $Files += $_.FullName
}

# Process plugins
$script:FoundPlugins = @()
$script:DestinationDir = ""

foreach ($pluginPath in $Plugins) {
    # Check format
    if ($pluginPath -notmatch '^[^/]+/[^/]+$') {
        throw "Error: Invalid plugin format '$pluginPath'. Expected format: <category>/<name>"
    }
    
    # Extract category and name
    $parts = $pluginPath -split '/'
    $category = $parts[0]
    $name = $parts[1]
    
    # Calculate destination directory
    $script:DestinationDir = ($PluginDir + "\" + $category) -replace '/', '\'
    
    # Search for the plugin
    $script:FoundPlugins = @()
    Search-Plugin -Category $category -Name $name -PluginPaths $PluginPaths
    
    if ($script:FoundPlugins.Count -eq 0) {
        throw "Error: Plugin '$pluginPath' not found in any search paths."
    }
}

# Process QML directories
if ($QmlRelPaths.Count -gt 0) {
    foreach ($qmlRelPath in $QmlRelPaths) {
        if ($qmlRelPath) {
            Search-QmlDir -QmlRelPath $qmlRelPath
        }
    }
}

# Build and execute the deploy command
$FinalDeployArgs = @("deploy") + $Files + $DeployArgs + "-o" + $LibDir
if ($Verbose -eq "-V") {
    $FinalDeployArgs += $Verbose
}

$DeployCmd = "$CorecmdPath " + ($FinalDeployArgs -join ' ')
if ($Verbose -eq "-V") {
    Write-Host "Executing: $DeployCmd"
}

# Execute the command
try {
    $exitCode = 0
    & $CorecmdPath @FinalDeployArgs
    if ($LASTEXITCODE -ne 0) {
        $exitCode = $LASTEXITCODE
    }
} catch {
    throw "Failed to execute deploy command: $_"
}

exit $exitCode