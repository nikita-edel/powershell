function delete-alias {
	param(
		[String] $alias_name
	)

	Remove-Alias -Name $alias_name -Force -ErrorAction SilentlyContinue
}

delete-alias nv
delete-alias ls

Set-Alias l ls
Set-Alias c clear
function e { exit }

Set-Alias n nvim
Set-Alias nv nvim

if ($IsWindows) {
	Set-Alias s0 Stop-Computer
	Set-Alias r0 Restart-Computer
	function lsa { ls -Force @args }

} else {
	function s0 { systemctl poweroff }
	function r0 { systemctl reboot }
	function lsa { ls -A @args }
}

if (Get-Command rg -ErrorAction Ignore) {
	Set-Alias grep rg
}
