param(
    [string]$CMakeListsPath = 'windows/CMakeLists.txt'
)

try {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [Console]::InputEncoding = $utf8NoBom
    [Console]::OutputEncoding = $utf8NoBom
    $OutputEncoding = $utf8NoBom

    if (-not (Test-Path -LiteralPath $CMakeListsPath)) {
        throw "CMake file not found: $CMakeListsPath"
    }

    $content = Get-Content -LiteralPath $CMakeListsPath -Encoding UTF8 -Raw
    $marker = '# NexAI Windows native build compatibility'

    if ($content.Contains($marker)) {
        Write-Output 'Windows native build compatibility settings already present.'
        exit 0
    }

    $compatibilityBlock = @"
$marker
if(MSVC)
  add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)
endif()

if(POLICY CMP0175)
  set(CMAKE_POLICY_DEFAULT_CMP0175 OLD)
  cmake_policy(SET CMP0175 OLD)
endif()

"@

    $projectPattern = [regex]'(?m)^project\([^\r\n]*\)\s*$'
    $updatedContent = $projectPattern.Replace(
        $content,
        [System.Text.RegularExpressions.MatchEvaluator] {
            param($match)
            "$($match.Value)`r`n`r`n$compatibilityBlock"
        },
        1
    )

    if ($updatedContent -eq $content) {
        throw "Unable to locate project() in $CMakeListsPath"
    }

    Set-Content -LiteralPath $CMakeListsPath -Encoding UTF8 -Value $updatedContent
    Write-Output 'Windows native build compatibility settings applied.'
}
catch {
    Write-Error "Windows native build configuration failed: $($_.Exception.Message)"
    exit 1
}
