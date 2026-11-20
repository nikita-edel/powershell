# My config, Nikita Edel
# noattach: the module only auto-attaches when [Environment]::UserInteractive is true,
# which is always false over Windows OpenSSH (sshd is a service, session 0). Attach here instead.
try { Import-Module ble -ArgumentList noattach -ErrorAction Stop }
catch { Write-Warning "ble.ps1 not loaded: $($_.Exception.Message)"; return }

. $PSScriptRoot\ble.config.ps1

if ($env:BLE_ATTACH -ne 'none' -and -not [Console]::IsInputRedirected) { Connect-Ble }
