# Paths are relative to this folder. All runs first, then the OS files.
# An OS is a list of files, or @{ Run = ...; DontRun = ... }.
# DontRun skips files, also ones from All.
@{
	All = @(
		'variables.ps1'
		'setup.ps1'
		'alias.ps1'
		'functions.ps1'
		'ble.ps1'
		'third-party.ps1'
		'git.ps1'
	)

	Windows = @(
		'windows/obs.ps1'
		'windows/sh.ps1'
		'windows/display.ps1'
		'windows/boot.ps1'
		'windows/getlock.ps1'
		'windows/gnu-utils.ps1'
	)

	Linux = @{
		Run = @(
			'linux/env.ps1'
			'linux/setup.ps1'
			'linux/ls.ps1'
			'linux/ghostty.ps1'
		)
		DontRun = @()
	}
}
