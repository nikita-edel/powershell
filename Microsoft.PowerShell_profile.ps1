# this config needs pwsh 7, Windows PowerShell 5.1 skips it

if ($PSVersionTable.PSVersion.Major -lt 7) { return }

$global:ps_config = Join-Path (Split-Path $PROFILE -Parent) 'Config'
$global:ps_profile = $ps_config

# every file in ps-util/ loads first, so the rest of the config can use it
foreach ($util in Get-ChildItem "$ps_config/ps-util" -Filter *.ps1) {
	. $util.FullName
}

$config = Import-PowerShellDataFile "$ps_config/config.psd1"

$os = if ($IsLinux) { $config.Linux } else { $config.Windows }

if ($os -isnot [hashtable]) { $os = @{ Run = $os } }

$files = @($config.All) + $os.Run | Where-Object { $_ -and $_ -notin $os.DontRun }

foreach ($file in $files) {
	. "$ps_config/$file"
}
