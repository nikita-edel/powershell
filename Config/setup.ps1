Set-PSReadLineOption -BellStyle None

Set-PSReadLineOption -EditMode Vi

Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler {
	param([Microsoft.PowerShell.ViMode]$mode)
	if ($mode -eq 'Command') {
		Write-Host -NoNewLine "`e[2 q"
	} else {
		Write-Host -NoNewLine "`e[6 q"
	}
}

# throws when output is redirected
if (-not [Console]::IsOutputRedirected) {
	Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
}

Set-PSReadLineKeyHandler -Chord 'Alt+j' -Function NextSuggestion
Set-PSReadLineKeyHandler -Chord 'Alt+k' -Function PreviousSuggestion

# linux terminals cannot tell these apart from plain Enter and Escape
if ($IsWindows) {
	Set-PSReadLineKeyHandler -Chord 'Shift+Escape' -Function SwitchPredictionView

	Set-PSReadLineKeyHandler -Chord 'Shift+Enter' -ScriptBlock {
		[Microsoft.PowerShell.PSConsoleReadLine]::AcceptSuggestion()
		[Microsoft.PowerShell.PSConsoleReadLine]::NextSuggestion()
	}
}
