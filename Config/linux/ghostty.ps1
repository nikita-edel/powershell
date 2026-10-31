# ghostty ships no powershell integration, so report what it needs by hand:
# 133;A marks the prompt (jump_to_prompt), 7 is the cwd (new splits inherit it)
if ($env:TERM_PROGRAM -eq 'ghostty') {
	function Invoke-Starship-PreCommand {
		$cwd = (Get-Location -PSProvider FileSystem).ProviderPath
		$uri = ([UriBuilder]@{ Scheme = 'file'; Host = [Environment]::MachineName; Path = $cwd }).Uri.AbsoluteUri
		$Host.UI.Write("`e]133;A`a`e]7;$uri`a")
	}
}
