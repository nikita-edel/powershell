Set-Alias bash "C:\Program Files\Git\bin\bash.exe"
$env:PATH += ";$HOME\.cargo\bin"

if ($env:PATHEXT -notmatch '\.SH(;|$)') { $env:PATHEXT += ';.SH' }

$git_bash = "C:\Program Files\Git\bin\bash.exe"

if (Test-Path -LiteralPath $git_bash) {
	$sh_key = 'HKEY_CURRENT_USER\Software\Classes\sh_auto_file\shell\open\command'
	$sh_cmd = "`"$git_bash`" `"%1`" %*"
	if ([Microsoft.Win32.Registry]::GetValue($sh_key, '', $null) -ne $sh_cmd) {
		[Microsoft.Win32.Registry]::SetValue($sh_key, '', $sh_cmd)
	}
}
