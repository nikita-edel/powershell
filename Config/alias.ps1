function delete-alias {
	param(
		[String] $alias_name
	)

	Remove-Alias -Name $alias_name -Force -ErrorAction SilentlyContinue
}

delete-alias nv
delete-alias ls

Set-Alias l ls
Set-Alias lsd ls # for typos
Set-Alias c clear
function e { exit }

Set-Alias n nvim
Set-Alias nv nvim

if ($IsWindows) {
	Set-Alias s0 Stop-Computer
	Set-Alias r0 Restart-Computer

} else {
	function s0 { systemctl poweroff }
	function r0 { systemctl reboot }
}

