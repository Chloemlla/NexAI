param(
    [string]$Arg = ''
)

try {
    $versionName = $null

    $versionCode = [int](git rev-list --count HEAD).Trim()

    $commitHash = (git rev-parse HEAD).Trim()
    $shortHash = $commitHash.Substring(0, 9)

    $updatedContent = foreach ($line in (Get-Content -Path 'pubspec.yaml' -Encoding UTF8)) {
        if ($line -match '^\s*version:\s*([\d\.]+)') {
            $versionName = $matches[1]
            if ($Arg -eq 'android') {
                $displayName = "$versionName-$shortHash"
            }
            else {
                $displayName = $versionName
            }
            "version: $displayName+$versionCode"
        }
        else {
            $line
        }
    }

    if ($null -eq $versionName) {
        throw 'version not found'
    }

    $updatedContent | Set-Content -Path 'pubspec.yaml' -Encoding UTF8

    $buildTime = [int]([DateTimeOffset]::Now.ToUnixTimeSeconds())

    $data = @{
        'pili.name'  = $versionName
        'pili.code'  = $versionCode
        'pili.hash'  = $commitHash
        'pili.time'  = $buildTime
        'pili.short' = $shortHash
    }

    $data | ConvertTo-Json -Compress | Out-File 'pili_release.json' -Encoding UTF8

    # Export for GitHub Actions
    if ($env:GITHUB_ENV) {
        Add-Content -Path $env:GITHUB_ENV -Value "version=$displayName+$versionCode"
        Add-Content -Path $env:GITHUB_ENV -Value "VERSION_NAME=$versionName"
        Add-Content -Path $env:GITHUB_ENV -Value "VERSION_CODE=$versionCode"
        Add-Content -Path $env:GITHUB_ENV -Value "SHORT_HASH=$shortHash"
    }

    Write-Host "Version: $displayName+$versionCode (hash: $shortHash)"
}
catch {
    Write-Error "Prebuild Error: $($_.Exception.Message)"
    exit 1
}
