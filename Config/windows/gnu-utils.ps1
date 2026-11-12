try { Import-Module PSGnuUtils -ErrorAction Stop }
catch { Write-Warning "GnuUtils not loaded: $($_.Exception.Message)"; return }

# Import-GnuUtil -MostUsed
Enable-GnuAlias -All  -Exclude ls, cd
