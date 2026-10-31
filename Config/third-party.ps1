if (Get-Command starship -ErrorAction Ignore) {
	Invoke-Expression (&starship init powershell)
}
