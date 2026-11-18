if ($env:TERM_PROGRAM -ne 'ghostty' -and -not $env:KITTY_WINDOW_ID) { return }

<# if ($env:TERM_PROGRAM -eq 'ghostty') {
       function Invoke-Starship-PreCommand {
               $cwd = (Get-Location -PSProvider FileSystem).ProviderPath
               $uri = ([UriBuilder]@{ Scheme = 'file'; Host = [Environment]::MachineName; Path = $cwd }).Uri.AbsoluteUri
               # redraw=0: pwsh doesn't repaint its prompt on resize, so ghostty must not clear it
               $Host.UI.Write("`e]133;A;redraw=0`a`e]7;$uri`a")
       }
}  #>

# kitty
function Invoke-Starship-PreCommand {
	$cwd = (Get-Location -PSProvider FileSystem).ProviderPath
	$uri = ([UriBuilder]@{ Scheme = 'file'; Host = [Environment]::MachineName; Path = $cwd }).Uri.AbsoluteUri
	# redraw=0: pwsh doesn't repaint its prompt on resize, so the terminal must not clear it
	$Host.UI.Write("`e]133;A;redraw=0`a`e]7;$uri`a")
}

$global:__term_readline = (Get-Item function:PSConsoleHostReadLine -ErrorAction Ignore).ScriptBlock
if ($global:__term_readline) {
	function global:PSConsoleHostReadLine {
		# hand $? on unchanged, the line editor reads it
		if (-not $?) { Write-Error -Message '' -ErrorAction Ignore }
		$line = & $global:__term_readline
		$Host.UI.Write("`e]133;C`a")
		$line
	}
}
