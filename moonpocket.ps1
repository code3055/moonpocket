param([Parameter(ValueFromRemainingArguments=$true)][string[]]$CliArgs)
$ErrorActionPreference = 'Stop'
$taskBundledHome = Join-Path (Split-Path $PSScriptRoot -Parent) 'moonbit-cli'
$taskMoonHome = if ($env:MOON_HOME -and (Test-Path (Join-Path $env:MOON_HOME 'bin/moon.exe'))) { $env:MOON_HOME } else { $taskBundledHome }
$env:MOON_HOME = $taskMoonHome
$taskMoon = Join-Path $taskMoonHome 'bin/moon.exe'
Push-Location $PSScriptRoot
try {
  & $taskMoon build --target js src/cmd/moonpocket
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & node '_build/js/debug/build/cmd/moonpocket/moonpocket.js' @CliArgs
  exit $LASTEXITCODE
} finally { Pop-Location }

