if ($PSVersionTable.PSVersion.Major -lt 7) { return }

$global:ps_profile = Split-Path $PROFILE -Parent
$global:ps_config = "$ps_profile/Config"

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
