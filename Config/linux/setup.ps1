# Install-PSResource ble, Microsoft.PowerShell.UnixTabCompletion, Microsoft.PowerShell.ConsoleGuiTools

$env:EDITOR = 'nvim'

Set-Alias ogv Out-ConsoleGridView

Import-Module Microsoft.PowerShell.UnixTabCompletion -ErrorAction Ignore
if (Get-Module Microsoft.PowerShell.UnixTabCompletion) {
	Import-PSUnixTabCompletion
}
