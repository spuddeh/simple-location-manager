#requires -Version 7
<#
.SYNOPSIS
    One-time backfill of historical GitHub Releases for Simple Location Manager and its presets.

.DESCRIPTION
    Creates a GitHub Release for each already-published historical version using the zips in
    _release_archive/. These releases are GitHub-only: each carries an invisible
    "<!-- skip-nexus -->" marker in its body, so .github/workflows/release.yml skips them
    (those versions are already on Nexus, and the historical zip is attached directly here
    rather than rebuilt from current source).

    Idempotent: any tag that already exists is skipped. Releases are created with
    --latest=false so none of them steals "Latest" from the next real release (slm-v1.5.0+).

    Run from the repo root AFTER the repo has been pushed to GitHub and `gh` is authenticated.

.PARAMETER DryRun
    Show what would be created without calling gh.

.EXAMPLE
    pwsh ./scripts/backfill-releases.ps1 -DryRun
    pwsh ./scripts/backfill-releases.ps1
#>
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot     = Split-Path $PSScriptRoot -Parent
$archiveRoot  = Join-Path $repoRoot '_release_archive'
$changelogMain = Join-Path $repoRoot '@changelog.md'
$marker = '<!-- skip-nexus -->'

# Each historical release: artifact id, version, the zip (under _release_archive/), a title,
# and a changelog file to pull notes from (optional).
$releases = @(
    @{ artifact='slm'; version='1.0.0'; zip='slm/SimpleLocationManager_v1.0.0.zip'; changelog=$changelogMain }
    @{ artifact='slm'; version='1.1.0'; zip='slm/SimpleLocationManager_v1.1.0.zip'; changelog=$changelogMain }
    @{ artifact='slm'; version='1.2.0'; zip='slm/SimpleLocationManager_v1.2.0.zip'; changelog=$changelogMain }
    @{ artifact='slm'; version='1.2.1'; zip='slm/SimpleLocationManager_v1.2.1.zip'; changelog=$changelogMain }
    @{ artifact='slm'; version='1.3.0'; zip='slm/SimpleLocationManager_v1.3.0.zip'; changelog=$changelogMain }
    @{ artifact='slm'; version='1.3.1'; zip='slm/SimpleLocationManager_v1.3.1.zip'; changelog=$changelogMain }
    @{ artifact='slm'; version='1.4.0'; zip='slm/SimpleLocationManager_v1.4.0.zip'; changelog=$changelogMain }

    @{ artifact='jnve'; version='1.0.0'; zip='jnve/JNVE_SLM_AOI_Preset1_v1.0.0.zip'; changelog=(Join-Path $repoRoot 'presets/jnve/@changelog.md') }
    @{ artifact='jnve'; version='1.0.1'; zip='jnve/JNVE_SLM_AOI_Preset1_v1.0.1.zip'; changelog=(Join-Path $repoRoot 'presets/jnve/@changelog.md') }

    @{ artifact='konpeki';    version='1.0.0kp';         zip='konpeki/KonpekiPlaza_SLM_Preset_v1.0.0kp.zip'; changelog=(Join-Path $repoRoot 'presets/konpeki/@changelog.md') }
    @{ artifact='apartments'; version='1.0.0apartments'; zip='apartments/SLM_Appartment_Preset.zip';         changelog=(Join-Path $repoRoot 'presets/apartments/@changelog.md') }
    @{ artifact='balatro';    version='1.0.0joker';      zip='balatro/SLM_Balatro_Preset.zip';               changelog=$null }
)

# Pull a "## vX" / "### vX" section out of a changelog file; '' if not found.
function Get-ChangelogSection([string]$file, [string]$version) {
    if (-not $file -or -not (Test-Path $file)) { return '' }
    $lines = Get-Content -LiteralPath $file
    $out = [System.Collections.Generic.List[string]]::new()
    $inSection = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*#{2,3}\s') {
            if ($inSection) { break }                      # next heading ends the section
            if ($line -match ("(?i)v?" + [regex]::Escape($version) + '\b')) { $inSection = $true }
            continue
        }
        if ($inSection) { $out.Add($line) }
    }
    return ($out -join "`n").Trim()
}

# Resolve the artifact display name from the manifest for nicer titles.
$manifest = Get-Content -LiteralPath (Join-Path $repoRoot 'release-manifest.json') -Raw | ConvertFrom-Json

$created = 0; $skipped = 0; $missing = 0
foreach ($r in $releases) {
    $tag   = "$($r.artifact)-v$($r.version)"
    $zip   = Join-Path $archiveRoot $r.zip
    $name  = $manifest.artifacts.($r.artifact).displayName
    $title = "$name v$($r.version)"

    if (-not (Test-Path $zip)) {
        Write-Warning "MISSING zip for $tag : $zip  (skipping)"
        $missing++; continue
    }

    # Idempotent: skip if the release/tag already exists.
    & gh release view $tag *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "exists  $tag  (skip)" -ForegroundColor DarkGray
        $skipped++; continue
    }

    $section = Get-ChangelogSection $r.changelog $r.version
    $body = if ($section) { $section } else { "Archived release of $name v$($r.version)." }
    $body = "$body`n`n$marker"

    if ($DryRun) {
        Write-Host "DRYRUN  would create $tag  <- $($r.zip)" -ForegroundColor Cyan
        continue
    }

    $notesFile = New-TemporaryFile
    Set-Content -LiteralPath $notesFile -Value $body -Encoding utf8
    try {
        & gh release create $tag $zip --title $title --notes-file $notesFile --target main --latest=false
        if ($LASTEXITCODE -ne 0) { throw "gh release create failed for $tag" }
        Write-Host "created $tag" -ForegroundColor Green
        $created++
    }
    finally {
        Remove-Item -LiteralPath $notesFile -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "Done. created=$created skipped=$skipped missing=$missing" -ForegroundColor Yellow
if ($DryRun) { Write-Host "(dry run - nothing was created)" -ForegroundColor Cyan }

# Clean exit code (real failures already threw above; the existence probe leaves a
# stray non-zero $LASTEXITCODE we don't want to surface).
if ($missing -gt 0) { exit 1 } else { exit 0 }
