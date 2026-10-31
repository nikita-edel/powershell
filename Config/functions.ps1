function tgview {
	Set-PSReadLineOption -PredictionViewStyle $(if ((Get-PSReadLineOption).PredictionViewStyle -eq 'ListView') { 'InlineView' } else { 'ListView' })
}

if ($IsWindows) {
	function rmf { Remove-Item @args -Force }

} else {
	function rmf { rm -f @args }
}

function gpoh {
	git push origin HEAD @args
}

function gpoa {
	git push origin --all @args
}

# TODO: port bash config

function git-init {
	ssh-add $HOME/.ssh/id_ed25519
	if ($IsWindows) {
		git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
	}
}
