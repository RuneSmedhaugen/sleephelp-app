$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$originalPubspec = [System.IO.File]::ReadAllText($pubspecPath)
$demoPubspec = [System.Text.RegularExpressions.Regex]::Replace(
    $originalPubspec,
    '(?m)^    - assets/sounds/.*(?:\r?\n|$)',
    ''
)
$baseHref = '/sleephelp-app/'
if ($env:GITHUB_REPOSITORY) {
    $repositoryName = $env:GITHUB_REPOSITORY.Split('/')[-1]
    $baseHref = "/$repositoryName/"
}

try {
    [System.IO.File]::WriteAllText($pubspecPath, $demoPubspec)
    Push-Location $projectRoot
    try {
        $webOutput = Join-Path $projectRoot 'build/web'
        if (Test-Path -LiteralPath $webOutput) {
            Remove-Item -LiteralPath $webOutput -Recurse -Force
        }
        if ($env:FLUTTER_ROOT) {
            $flutterDart = Join-Path $env:FLUTTER_ROOT 'bin/cache/dart-sdk/bin/dart.exe'
            $flutterSnapshot = Join-Path $env:FLUTTER_ROOT 'bin/cache/flutter_tools.snapshot'
            & $flutterDart $flutterSnapshot --no-version-check build web --release --no-pub --base-href $baseHref
        }
        else {
            flutter build web --release --no-pub --base-href $baseHref
        }
        if ($LASTEXITCODE -ne 0) { throw 'Flutter web showcase build failed.' }
    }
    finally {
        Pop-Location
    }
}
finally {
    [System.IO.File]::WriteAllText($pubspecPath, $originalPubspec)
}
