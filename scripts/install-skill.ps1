[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetRoot,

    [string]$SkillSource = (Join-Path (Split-Path -Parent $PSScriptRoot) 'skills\tz-rezultat-hz')
)

$ErrorActionPreference = 'Stop'
$skillName = 'tz-rezultat-hz'
$source = [System.IO.Path]::GetFullPath($SkillSource)
$targetRootPath = [System.IO.Path]::GetFullPath($TargetRoot)
$destination = Join-Path $targetRootPath $skillName
$stage = Join-Path $targetRootPath ('.' + $skillName + '.installing-' + [guid]::NewGuid().ToString('N'))

function Get-RelativeFiles([string]$Root) {
    $prefix = $Root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    return @(Get-ChildItem -LiteralPath $Root -File -Recurse | ForEach-Object {
        $_.FullName.Substring($prefix.Length).Replace('\', '/')
    } | Sort-Object)
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Skill source directory not found: $source"
}
foreach ($required in @('SKILL.md', 'bootstrap.ps1', 'bootstrap.py', 'LICENSE', 'THIRD-PARTY.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $required) -PathType Leaf)) {
        throw "Skill package is incomplete; required file is missing: $required"
    }
}
if (Test-Path -LiteralPath $destination) {
    throw "Installation refused: destination already exists and will not be overwritten: $destination"
}

if ($PSCmdlet.ShouldProcess($destination, 'Install standalone tz-rezultat-hz skill')) {
    try {
        New-Item -ItemType Directory -Force -Path $targetRootPath | Out-Null
        New-Item -ItemType Directory -Path $stage | Out-Null
        Copy-Item -Path (Join-Path $source '*') -Destination $stage -Recurse -Force

        $sourceFiles = Get-RelativeFiles $source
        $stagedFiles = Get-RelativeFiles $stage
        if (($sourceFiles -join [Environment]::NewLine) -cne ($stagedFiles -join [Environment]::NewLine)) {
            throw 'Staged package file list differs from the source package.'
        }
        foreach ($relative in $sourceFiles) {
            $sourceFile = Join-Path $source ($relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
            $stagedFile = Join-Path $stage ($relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
            if ((Get-Sha256 $sourceFile) -cne (Get-Sha256 $stagedFile)) {
                throw "Staged file hash mismatch: $relative"
            }
        }
        if (Test-Path -LiteralPath $destination) {
            throw "Installation refused: destination appeared during staging: $destination"
        }
        Move-Item -LiteralPath $stage -Destination $destination
        Write-Output "Installed: $destination"
        Write-Output ('Next: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $destination + '\bootstrap.ps1"')
        Write-Output 'The bootstrap command above only displays the component plan; run it with -Full only after reviewing and explicitly approving the downloads.'
    }
    catch {
        if (Test-Path -LiteralPath $stage) {
            Remove-Item -LiteralPath $stage -Recurse -Force
        }
        throw
    }
}
