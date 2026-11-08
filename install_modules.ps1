# Installs the modules this config uses. Skips the ones already there.

$modules = @('ble')

if ($IsWindows) {
	$modules += 'Sixel', 'DisplayConfig', 'PSGnuUtils'
}

if ($IsLinux) {
	$modules += 'Microsoft.PowerShell.ConsoleGuiTools'
}

foreach ($name in $modules) {
	if (Get-Module -ListAvailable -Name $name) {
		Write-Host "${name}: already installed"
		continue
	}

	Write-Host "${name}: installing"
	Install-PSResource -Name $name -Scope CurrentUser -Repository PSGallery -TrustRepository
}
