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

function git-cherry-all {
	param(
		[String] $message
	)

	git commit -m $message
	if ($LASTEXITCODE) { return }

	$sha = git rev-parse HEAD
	$cur = git branch --show-current

	# stash what wasn't committed so it can't block switch/cherry-pick
	$stashed = $false
	if (git status --porcelain) {
		git stash push -q --include-untracked -m git-cherry-all
		if ($LASTEXITCODE) { return }
		$stashed = $true
	}

	try {
		foreach ($b in git for-each-ref --format='%(refname:short)' refs/heads/) {
			if ($b -eq $cur) { continue }

			git switch -q $b
			if ($LASTEXITCODE) { throw "git-cherry-all: cannot switch to $b" }

			git cherry-pick -x $sha
			if ($LASTEXITCODE) {
				git cherry-pick --abort
				Write-Warning "git-cherry-all: skipped $b (cherry-pick failed)"
			}
		}
	} finally {
		git switch -q $cur
		if ($stashed) { git stash pop -q }
	}
}

function git-add-cherry-all {
	param(
		[String] $message
	)

	git add -A
	if (-not $LASTEXITCODE) { git-cherry-all $message }
}

function git-last-commit {
	git rev-parse HEAD
}

function copy-last-commit {
	git rev-parse HEAD | clip
}

function git-init {
	ssh-add $HOME/.ssh/id_ed25519
	if ($IsWindows) {
		git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
	}
}

function git-deinit {
	ssh-add -D
}
