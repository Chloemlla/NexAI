param(
  [string]$OwnerRepo = "Chloemlla/Project-Lumen"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $root "android"
$localMaven = Join-Path $androidDir "local-maven"
$versionFile = Join-Path $androidDir "lumen-crash.version"
$gradleProps = Join-Path $androidDir "gradle.properties"

$headers = @{
  Accept = "application/vnd.github+json"
  "User-Agent" = "nexai-lumen-crash-resolver"
}
$token = $env:GH_TOKEN
if (-not $token) { $token = $env:GITHUB_TOKEN }
if ($token) { $headers.Authorization = "Bearer $token" }

Write-Host "Resolving latest lumen-crash-v* release from $OwnerRepo..."
$releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$OwnerRepo/releases?per_page=100" -Headers $headers
$latest = $releases |
  Where-Object { -not $_.draft -and $_.tag_name -like "lumen-crash-v*" } |
  Sort-Object { if ($_.published_at) { [datetime]$_.published_at } else { [datetime]$_.created_at } } -Descending |
  Select-Object -First 1

if (-not $latest) {
  throw "No lumen-crash release found"
}

$version = $latest.tag_name -replace '^lumen-crash-v', ''
Write-Host "Resolved latest lumen-crash main auto release: $version"
Set-Content -Encoding UTF8 -Path $versionFile -Value $version

if (Test-Path $gradleProps) {
  $lines = Get-Content -Encoding UTF8 $gradleProps | Where-Object { $_ -notmatch '^lumenCrashVersion=' }
  $content = ($lines -join "`n").TrimEnd() + "`nlumenCrashVersion=$version`n"
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($gradleProps, $content, $utf8)
} else {
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($gradleProps, "lumenCrashVersion=$version`n", $utf8)
}

$env:LUMEN_CRASH_VERSION = $version

Write-Host "Staging lumen-crash $version into local Maven repo..."
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("lumen-crash-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
  function Get-AssetUrl([string]$name) {
    $asset = $latest.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $asset) { return $null }
    return $asset.browser_download_url
  }

  function Download-Asset([string]$name, [bool]$required = $true) {
    $url = Get-AssetUrl $name
    if (-not $url) {
      if ($required) { throw "Asset not found: $name" }
      Write-Host "Optional asset not found: $name"
      return $false
    }
    Write-Host "Downloading $name..."
    Invoke-WebRequest -Headers $headers -Uri $url -OutFile (Join-Path $stage $name)
    return $true
  }

  function Stage-MavenArtifact([string]$artifactId) {
    $aar = Join-Path $stage "$artifactId-$version.aar"
    $pom = Join-Path $stage "$artifactId-$version.pom"
    $module = Join-Path $stage "$artifactId-$version.module"
    if (-not (Test-Path $aar)) {
      throw "Failed to stage ${artifactId}: missing AAR"
    }
    $dest = Join-Path $localMaven "com/chloemlla/lumen/$artifactId/$version"
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item $aar $dest
    if (Test-Path $pom) {
      Copy-Item $pom $dest
    } else {
      @"
<?xml version="1.0" encoding="UTF-8"?>
<project xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd"
  xmlns="http://maven.apache.org/POM/4.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.chloemlla.lumen</groupId>
  <artifactId>$artifactId</artifactId>
  <version>$version</version>
  <packaging>aar</packaging>
  <name>$artifactId</name>
</project>
"@ | Set-Content -Encoding UTF8 (Join-Path $dest "$artifactId-$version.pom")
    }
    if (Test-Path $module) {
      Copy-Item $module $dest
    }
    Write-Host "Staged ${artifactId}:$version -> $dest"
  }

  [void](Download-Asset "lumen-crash-$version.aar" $true)
  [void](Download-Asset "lumen-crash-$version.pom" $false)
  [void](Download-Asset "lumen-crash-$version.module" $false)
  [void](Download-Asset "lumen-crash-core-$version.aar" $true)
  [void](Download-Asset "lumen-crash-core-$version.pom" $false)
  [void](Download-Asset "lumen-crash-core-$version.module" $false)

  Stage-MavenArtifact "lumen-crash-core"
  Stage-MavenArtifact "lumen-crash"

  $bundlePom = Join-Path $localMaven "com/chloemlla/lumen/lumen-crash/$version/lumen-crash-$version.pom"
  if ((Test-Path $bundlePom) -and -not (Select-String -Path $bundlePom -Pattern "lumen-crash-core" -Quiet)) {
    $pomText = Get-Content -Encoding UTF8 -Raw $bundlePom
    $dep = @"
  <dependencies>
    <dependency>
      <groupId>com.chloemlla.lumen</groupId>
      <artifactId>lumen-crash-core</artifactId>
      <version>$version</version>
      <scope>compile</scope>
    </dependency>
  </dependencies>
"@
    if ($pomText -notmatch "</project>") {
      throw "Invalid POM: $bundlePom"
    }
    $updated = $pomText -replace "</project>", ($dep + "</project>")
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($bundlePom, $updated, $utf8)
    Write-Host "Injected lumen-crash-core dependency into $bundlePom"
  }

  Write-Host "Local Maven repo ready at $localMaven"
} finally {
  Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
}

Write-Host "implementation(`"com.chloemlla.lumen:lumen-crash:$version`")"
Write-Host "Release page: https://github.com/$OwnerRepo/releases/tag/lumen-crash-v$version"