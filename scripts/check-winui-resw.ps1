# Validates WinUI .resw keys for PRI resource/scope collisions and common key issues.
# PRI forbids a key from being both a leaf resource and a parent scope, e.g.:
#   Settings.Theme
#   Settings.Theme.System
param(
    [string]$StringsRoot = "winui/NexAI.WinUI3/Strings",
    [switch]$CheckCodeReferences
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $StringsRoot)) {
    throw "Strings root not found: $StringsRoot"
}

$reswFiles = Get-ChildItem -Path $StringsRoot -Filter *.resw -Recurse
if ($reswFiles.Count -eq 0) {
    throw "No .resw files under $StringsRoot"
}

$allIssues = New-Object System.Collections.Generic.List[string]

function Get-ReswKeys([string]$path) {
    [xml]$xml = Get-Content -LiteralPath $path -Encoding UTF8
    $keys = New-Object System.Collections.Generic.List[string]
    foreach ($node in $xml.root.data) {
        if ($null -ne $node.name) {
            $keys.Add([string]$node.name)
        }
    }
    return $keys
}

function Find-ResourceScopeCollisions([string[]]$keys) {
    $set = [System.Collections.Generic.HashSet[string]]::new([string[]]$keys, [System.StringComparer]::Ordinal)
    $collisions = New-Object System.Collections.Generic.List[object]
    foreach ($key in ($keys | Sort-Object -Unique)) {
        $prefix = $key + '.'
        $children = @($keys | Where-Object { $_.StartsWith($prefix, [System.StringComparison]::Ordinal) })
        if ($children.Count -gt 0 -and $set.Contains($key)) {
            $collisions.Add([pscustomobject]@{
                Parent = $key
                Children = $children
            })
        }
    }
    return $collisions
}

Write-Host "== WinUI .resw validation =="
foreach ($file in $reswFiles) {
    $rel = Resolve-Path -Relative $file.FullName
    $keys = @(Get-ReswKeys $file.FullName)
    Write-Host ("- {0}: {1} keys" -f $rel, $keys.Count)

    $dupes = $keys | Group-Object | Where-Object { $_.Count -gt 1 }
    foreach ($d in $dupes) {
        $allIssues.Add(("DUPLICATE KEY in {0}: {1} (x{2})" -f $rel, $d.Name, $d.Count))
    }

    $collisions = Find-ResourceScopeCollisions $keys
    foreach ($c in $collisions) {
        $childPreview = ($c.Children | Select-Object -First 8) -join ', '
        if ($c.Children.Count -gt 8) { $childPreview += ', ...' }
        $allIssues.Add(("PRI RESOURCE/SCOPE COLLISION in {0}: '{1}' is both a leaf and a parent of: {2}" -f $rel, $c.Parent, $childPreview))
    }
}

# Cross-language key parity (en-US vs others)
$byLang = @{}
foreach ($file in $reswFiles) {
    $lang = $file.Directory.Name
    if (-not $byLang.ContainsKey($lang)) { $byLang[$lang] = @{} }
    foreach ($k in (Get-ReswKeys $file.FullName)) {
        $byLang[$lang][$k] = $true
    }
}
if ($byLang.ContainsKey('en-US')) {
    $en = $byLang['en-US'].Keys
    foreach ($lang in ($byLang.Keys | Where-Object { $_ -ne 'en-US' } | Sort-Object)) {
        $missing = @($en | Where-Object { -not $byLang[$lang].ContainsKey($_) } | Sort-Object)
        $extra = @($byLang[$lang].Keys | Where-Object { -not $byLang['en-US'].ContainsKey($_) } | Sort-Object)
        foreach ($k in $missing) {
            $allIssues.Add(("MISSING KEY in {0}: {1} (present in en-US)" -f $lang, $k))
        }
        foreach ($k in $extra) {
            $allIssues.Add(("EXTRA KEY in {0}: {1} (missing in en-US)" -f $lang, $k))
        }
    }
}

if ($CheckCodeReferences) {
    Write-Host "== Code GetString key reference check =="
    $codeFiles = Get-ChildItem -Path 'winui' -Recurse -Include *.cs,*.xaml |
        Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' }
    $enKeys = if ($byLang.ContainsKey('en-US')) { $byLang['en-US'] } else { @{} }
    $refPattern = 'GetString\(\s*"([^"]+)"'
    foreach ($cf in $codeFiles) {
        $content = Get-Content -LiteralPath $cf.FullName -Raw -Encoding UTF8
        $matches = [regex]::Matches($content, $refPattern)
        foreach ($m in $matches) {
            $key = $m.Groups[1].Value
            if ($enKeys.Count -gt 0 -and -not $enKeys.ContainsKey($key)) {
                $rel = Resolve-Path -Relative $cf.FullName
                    $allIssues.Add(("MISSING RESOURCE for code reference {0} -> GetString('{1}')" -f $rel, $key))
            }
        }
    }
}

if ($allIssues.Count -eq 0) {
    Write-Host "OK: no .resw collisions or key parity issues found."
    exit 0
}

Write-Host ""
Write-Host ("FOUND {0} ISSUE(S):" -f $allIssues.Count)
$i = 1
foreach ($issue in $allIssues) {
    Write-Host ("{0}. {1}" -f $i, $issue)
    $i++
}
Write-Host ""
Write-Host "Fix all listed issues before WinUI build. PRI typically only reports the first collision."
exit 1
