function git-last-commit {
	git rev-parse HEAD
}

function copy-last-commit {
	git rev-parse HEAD | clip
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

if ($IsLinux -and (Test-Path "$HOME/.ssh/agent.sock")) {
    $env:SSH_AUTH_SOCK = "$HOME/.ssh/agent.sock"
}

if ($IsWindows) {
    function Invoke-GitSshTool($Tool, $ToolArgs) {
        $dir = if ($env:SSH_AUTH_SOCK) { "C:/Program Files/Git/usr/bin" } else { "C:/Windows/System32/OpenSSH" }
        & "$dir/$Tool.exe" @ToolArgs
    }
    function ssh { Invoke-GitSshTool ssh $args }
    function ssh-add { Invoke-GitSshTool ssh-add $args }
}

function Set-GitSshVar($Name, $Value) {
    if ($Value) {
        Set-Item "env:$Name" $Value
        [Environment]::SetEnvironmentVariable($Name, $Value, "User")
    } else {
        Remove-Item "env:$Name" -ErrorAction Ignore
        [Environment]::SetEnvironmentVariable($Name, [NullString]::Value, "User")
    }
}

function Get-GitSshAgent {
    $file = [IO.Path]::Combine($HOME, ".ssh", "agent.sock")

    if ($IsWindows) {
        $bin  = "C:/Program Files/Git/usr/bin"
        $unix = "/" + $HOME.Substring(0, 1).ToLower() + ($HOME.Substring(2) -replace '\\', '/')
        @{
            Add   = "$bin/ssh-add.exe"
            Agent = "$bin/ssh-agent.exe"
            Ssh   = "`"$bin/ssh.exe`""
            File  = $file
            Sock  = "$unix/.ssh/agent.sock"
        }
    } else {
        @{ Add = "ssh-add"; Agent = "ssh-agent"; Ssh = $null; File = $file; Sock = $file }
    }
}

function git-init {
    [CmdletBinding(DefaultParameterSetName = "Boot")]
    param(
        [Parameter(ParameterSetName = "Boot", Position = 0)]
        [Parameter(ParameterSetName = "Perma", Position = 0)]
        [Parameter(ParameterSetName = "Timer")]
        [String] $Key = "id_ed25519",

        [Parameter(ParameterSetName = "Perma")]
        [Switch] $Perma,

        [Parameter(ParameterSetName = "Timer")]
        [Switch] $Timer,

        # Hidden: holds the value in "-Timer 2h". PowerShell can't give a switch a value.
        [Parameter(ParameterSetName = "Timer", Position = 0, DontShow)]
        [ValidatePattern("^(\d+[smhdwSMHDW]?)+$")]
        [String] $Duration = "8h"
    )

    if ($PSBoundParameters.ContainsKey("Duration") -and -not $Timer) {
        throw "A duration requires -Timer."
    }

    $keyPath = [IO.Path]::Combine($HOME, ".ssh", $Key)
    if (-not (Test-Path $keyPath)) {
        throw "Key not found: $keyPath"
    }

    if ($Perma) {
        if (-not $IsWindows) {
            throw "-Perma is Windows-only: ssh-agent on Linux cannot keep keys across reboots."
        }

        try {
            $service = Get-Service ssh-agent
            if ($service.StartType -eq "Disabled") {
                Set-Service ssh-agent -StartupType Automatic -ErrorAction Stop
            }
            if ($service.Status -ne "Running") {
                Start-Service ssh-agent -ErrorAction Stop
            }
        } catch {
            throw "Could not start the Windows ssh-agent service (the first -Perma run needs an admin shell): $_"
        }

        Set-GitSshVar SSH_AUTH_SOCK $null
        Set-GitSshVar GIT_SSH_COMMAND "C:/Windows/System32/OpenSSH/ssh.exe"
        & "C:/Windows/System32/OpenSSH/ssh-add.exe" $keyPath
        return
    }

    $agent = Get-GitSshAgent
    Set-GitSshVar SSH_AUTH_SOCK $agent.Sock
    Set-GitSshVar GIT_SSH_COMMAND $agent.Ssh

    # Exit code 2 means nothing is listening, including a stale socket from before a reboot.
    & $agent.Add -l *> $null
    if ($LASTEXITCODE -eq 2) {
        Remove-Item -Force $agent.File -ErrorAction Ignore
        $null = & $agent.Agent -s -a $agent.Sock
    }

    if ($Timer) {
        & $agent.Add -t $Duration $keyPath
    } else {
        & $agent.Add $keyPath
    }
}

function git-deinit {
    $agent = Get-GitSshAgent
    $previous = $env:SSH_AUTH_SOCK

    $env:SSH_AUTH_SOCK = $agent.Sock
    & $agent.Add -D 2>$null

    if ($IsWindows -and (Get-Service ssh-agent).Status -eq "Running") {
        Remove-Item env:SSH_AUTH_SOCK -ErrorAction Ignore
        & "C:/Windows/System32/OpenSSH/ssh-add.exe" -D
    }

    $env:SSH_AUTH_SOCK = $previous
}
