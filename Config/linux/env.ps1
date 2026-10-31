$env:JAVA_HOME = '/usr/lib/jvm/default'
$env:TESSDATA_PREFIX = '/usr/share/tessdata/'
$env:CHROME_EXECUTABLE = '/usr/bin/google-chrome-stable'
$env:KITTY_WINDOW_ID = "`e[11t"

# usually inherited from bash already, so only add what is missing
$local_bin = Join-Path $HOME .local bin
$go_bin = Join-Path $HOME go bin
$flutter_bin = Join-Path $HOME flutter bin
$env_paths = $env:PATH -split ':'

if ($local_bin -notin $env_paths) { $env:PATH = "${local_bin}:${env:PATH}" }
if ($go_bin -notin $env_paths) { $env:PATH = "${env:PATH}:${go_bin}" }
if ($flutter_bin -notin $env_paths) { $env:PATH = "${flutter_bin}:${env:PATH}" }
