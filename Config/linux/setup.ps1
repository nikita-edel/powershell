$env:EDITOR = 'nvim'

$global:trash = Join-Path $data_home Trash
$global:bconf = Join-Path $HOME .bashrc

Set-Alias ogv Out-ConsoleGridView

Set-Alias clip Set-Clipboard
Set-Alias paste wl-paste

# the real cmdlets do nothing on wayland, and ble's vi yank/paste goes through them
function Set-Clipboard {
	param(
		[Parameter(ValueFromPipeline)] [String[]] $Value
	)

	begin { $lines = @() }
	process { $lines += $Value }
	# wl-copy stays in the background: if it keeps a captured stream open, ble hangs
	end { $lines | sh -c 'exec wl-copy -n >/dev/null 2>&1' }
}

function Get-Clipboard {
	param(
		[Switch] $Raw
	)

	$text = wl-paste -n 2>$null
	if ($Raw) { $text -join "`n" } else { $text }
}

Set-Alias ytm youtube-music-desktop-app
Set-Alias chrome google-chrome-stable

function pdf { setsid -f zathura @args }

function boot-win { systemctl reboot --boot-loader-entry=auto-windows }
function boot-bios { systemctl reboot --firmware-setup }

<# Import-Module Microsoft.PowerShell.UnixTabCompletion -ErrorAction Ignore
if (Get-Module Microsoft.PowerShell.UnixTabCompletion) {
	Import-PSUnixTabCompletion
} #>
