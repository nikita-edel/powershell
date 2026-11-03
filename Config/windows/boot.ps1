# boot: pick what systemd-boot starts next (one time), from Windows.
#   boot                  list entries (same as: boot list)
#   boot <entry-id>       reboot into that entry once (ids come from systemd-boot, tab-completes)
#   boot 2                same, by number from the list
#   boot select           pick from a menu
#   boot <entry> -Plan    only plan the next boot, reboot later yourself
#   boot cancel           drop a planned boot
#   boot-win / boot-arch / boot-bios [-Plan]   shortcuts for the entries below
# Works by setting systemd-boot's LoaderEntryOneShot EFI variable (like
# `systemctl reboot --boot-loader-entry=...` on Linux). Needs admin.

function Initialize-SdBoot {
	if ('SdBoot' -as [type]) { return }
	Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SdBoot {
	const string Guid = "{4a67b082-0a4c-41cf-b6c7-440b29bb8c4f}";
	[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
	static extern bool SetFirmwareEnvironmentVariableExW(string name, string guid, byte[] buf, uint size, uint attr);
	[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
	static extern uint GetFirmwareEnvironmentVariableExW(string name, string guid, byte[] buf, uint size, out uint attr);
	[DllImport("advapi32.dll", SetLastError=true)]
	static extern bool OpenProcessToken(IntPtr h, uint acc, out IntPtr tok);
	[DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
	static extern bool LookupPrivilegeValue(string sys, string name, out long luid);
	[DllImport("advapi32.dll", SetLastError=true)]
	static extern bool AdjustTokenPrivileges(IntPtr tok, bool dis, ref TP n, int len, IntPtr p, IntPtr r);
	[DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
	[StructLayout(LayoutKind.Sequential, Pack=4)] struct TP { public int Count; public long Luid; public int Attr; }
	public static bool Enable() {
		IntPtr t;
		if (!OpenProcessToken(GetCurrentProcess(), 0x28, out t)) return false;
		TP tp = new TP(); tp.Count = 1; tp.Attr = 2;
		LookupPrivilegeValue(null, "SeSystemEnvironmentPrivilege", out tp.Luid);
		AdjustTokenPrivileges(t, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
		return Marshal.GetLastWin32Error() == 0;
	}
	public static string Get(string name) {
		byte[] b = new byte[8192]; uint a;
		uint n = GetFirmwareEnvironmentVariableExW(name, Guid, b, (uint)b.Length, out a);
		return n == 0 ? null : System.Text.Encoding.Unicode.GetString(b, 0, (int)n).TrimEnd('\0');
	}
	public static void Set(string name, string value) {
		byte[] b = value == null ? new byte[0] : System.Text.Encoding.Unicode.GetBytes(value + "\0");
		if (!SetFirmwareEnvironmentVariableExW(name, Guid, b, (uint)b.Length, 7))
			throw new Exception("SetFirmwareEnvironmentVariable failed, error " + Marshal.GetLastWin32Error());
	}
}
'@
}

function Get-BootEntries {
	Initialize-SdBoot
	if (-not [SdBoot]::Enable()) { throw 'boot: needs an admin shell' }
	$ids = [SdBoot]::Get('LoaderEntries')
	if (-not $ids) { throw 'boot: systemd-boot variables not found (not booted via systemd-boot?)' }
	$current = [SdBoot]::Get('LoaderEntrySelected')
	$default = [SdBoot]::Get('LoaderEntryDefault')
	$next = [SdBoot]::Get('LoaderEntryOneShot')
	$i = 0
	foreach ($id in $ids -split "`0" | Where-Object { $_ }) {
		[pscustomobject]@{
			N       = ++$i
			Id      = $id
			Current = $id -eq $current
			Default = $id -eq $default
			Next    = $id -eq $next
		}
	}
}

function Show-BootEntries($entries) {
	foreach ($e in $entries) {
		$tags = @()
		if ($e.Current) { $tags += 'running now' }
		if ($e.Default) { $tags += 'default' }
		if ($e.Next) { $tags += 'NEXT BOOT' }
		$tag = if ($tags) { "  ($($tags -join ', '))" } else { '' }
		$color = if ($e.Next) { 'Yellow' } elseif ($e.Current) { 'Green' } else { 'Gray' }
		Write-Host ('  {0}  {1}{2}' -f $e.N, $e.Id, $tag) -ForegroundColor $color
	}
	if (-not ($entries | Where-Object Next)) { Write-Host '  next boot: normal (systemd-boot default)' -ForegroundColor DarkGray }
}

function boot {
	param(
		[Parameter(Position = 0)][string]$Target = 'list',
		[switch]$Plan
	)
	$entries = @(Get-BootEntries)

	switch ($Target) {
		{ $_ -in 'list', 'ls' } { Show-BootEntries $entries; return }
		'cancel' {
			if ($entries | Where-Object Next) { [SdBoot]::Set('LoaderEntryOneShot', $null) }
			Write-Host 'Planned boot cancelled. Next boot: normal.'; return
		}
		'select' {
			Show-BootEntries $entries
			$Target = Read-Host 'Boot into (number or id, empty = abort)'
			if (-not $Target) { return }
		}
	}

	$entry = $entries | Where-Object { "$($_.N)" -eq $Target -or $_.Id -eq $Target } | Select-Object -First 1
	if (-not $entry) {
		Write-Host "boot: no entry '$Target'. Entries:" -ForegroundColor Red
		Show-BootEntries $entries; return
	}

	[SdBoot]::Set('LoaderEntryOneShot', $entry.Id)
	if ($Plan) {
		Write-Host "Next boot: $($entry.Id), once. Reboot whenever you want; 'boot cancel' to undo."
		return
	}
	Write-Host "Rebooting into $($entry.Id)..."
	shutdown.exe /r /t 0
}

# Shortcuts: real systemd-boot entry ids (see `boot list`)
function boot-win  { param([switch]$Plan) boot 'auto-windows' -Plan:$Plan }
function boot-arch { param([switch]$Plan) boot 'arch.conf' -Plan:$Plan }
function boot-bios { param([switch]$Plan) boot 'auto-reboot-to-firmware-setup' -Plan:$Plan }

# Tab completion reads the entry ids live from systemd-boot
Register-ArgumentCompleter -CommandName boot -ParameterName Target -ScriptBlock {
	param($cmd, $param, $word)
	$ids = try { (Get-BootEntries).Id } catch { @() }
	@('list', 'select', 'cancel') + $ids |
		Where-Object { $_ -like "$word*" } |
		ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}
