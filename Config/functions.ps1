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

# a function can't dot-source $PROFILE: everything it defines dies with the
# function's scope. So start a fresh shell, and close this one along with it.
function reconf {
	pwsh -NoLogo
	exit
}

function mkcd {
	param(
		[String] $path
	)

	New-Item -ItemType Directory -Force -Path $path -ErrorAction Stop | Out-Null
	cd $path
}


function lsa {
	ls -a @args
}
