if (Get-Command starship -ErrorAction Ignore) {
	Invoke-Expression (&starship init powershell)
}

# after starship: zoxide hooks the prompt
if (Get-Command zoxide -ErrorAction Ignore) {
	Invoke-Expression (& { (zoxide init powershell | Out-String) })
	Set-Alias -Name cd -Value __zoxide_z -Option AllScope -Scope Global -Force
}
