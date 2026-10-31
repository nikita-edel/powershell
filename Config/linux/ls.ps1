if (Get-Command eza -ErrorAction Ignore) {
	function ls {
		eza --color=auto --git --icons=auto --no-time --no-user --no-permissions @args
	}
}
