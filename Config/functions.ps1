function tgview {
	Set-PSReadLineOption -PredictionViewStyle $(if ((Get-PSReadLineOption).PredictionViewStyle -eq 'ListView') { 'InlineView' } else { 'ListView' })
}

function Restart-Pwsh {
    $pwsh = (Get-Process -Id $PID).Path
    & $pwsh @args
    exit
}

function Get-Size {
	param (
		[string]$pth = '.', 
		[Alias('a')] [switch] $All,
		[Alias('n')] [int] $Top = 0
	)

	Get-ChildItem -Path $pth -Directory:(!$All) -Force | ForEach-Object {

		$sum = if (!$_.PSIsContainer) { $_.Length } else {
			(Get-ChildItem -LiteralPath $_.FullName `
			-Recurse -File -Force -ErrorAction SilentlyContinue
			| Measure-Object -Property Length -Sum).Sum
		}

		[pscustomobject]@{ 
			Bytes = [long]$sum; 
			Name = $_.Name 
		}

	}	| Sort-Object Bytes
		| Select-Object -Last ($Top -gt 0 ? $Top : [int]::MaxValue)
		| ForEach-Object {
			"{0,10:n2} mb  {1}" -f ($_.Bytes / 1mb), $_.Name
		}
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
