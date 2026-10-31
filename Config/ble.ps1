# My config, Nikita Edel
try { Import-Module ble -ErrorAction Stop }
catch { Write-Warning "ble.ps1 not loaded: $($_.Exception.Message)"; return }

. $PSScriptRoot\ble.config.ps1
