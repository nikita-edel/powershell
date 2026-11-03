# lsof / unlock: who is holding a file or directory (and everything inside it), and kill them.
#   lsof <path>              list processes with open handles or loaded exe/dlls in <path>
#   lsof <path> -Summary     one line per process instead of one per file
#   unlock <path>            show them, ask, then kill them
#   unlock <path> -Force     kill without asking
# Directories are recursive: a process whose working directory is inside counts too.
# Works like Sysinternals handle.exe (system handle table). Without admin you only see
# your own processes; run elevated to see (and kill) everything.

function Initialize-FileLocks {
	if ('FileLocks' -as [type]) { return }
	Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class FileLocks {
	[DllImport("ntdll.dll")] static extern uint NtQuerySystemInformation(int cls, IntPtr buf, int len, out int ret);
	[DllImport("ntdll.dll")] static extern uint NtQueryObject(IntPtr h, int cls, IntPtr buf, int len, out int ret);
	[DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint acc, bool inherit, int pid);
	[DllImport("kernel32.dll", SetLastError=true)] static extern bool CloseHandle(IntPtr h);
	[DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
	[DllImport("kernel32.dll", SetLastError=true)]
	static extern bool DuplicateHandle(IntPtr srcProc, IntPtr src, IntPtr dstProc, out IntPtr dst, uint acc, bool inherit, uint opt);
	[DllImport("kernel32.dll")] static extern uint GetFileType(IntPtr h);
	[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
	static extern uint GetFinalPathNameByHandleW(IntPtr h, StringBuilder buf, uint len, uint flags);
	[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
	static extern uint QueryDosDeviceW(string dev, StringBuilder buf, int len);
	[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
	static extern IntPtr CreateFileW(string name, uint acc, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
	[DllImport("advapi32.dll", SetLastError=true)] static extern bool OpenProcessToken(IntPtr h, uint acc, out IntPtr tok);
	[DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
	static extern bool LookupPrivilegeValue(string sys, string name, out long luid);
	[DllImport("advapi32.dll", SetLastError=true)]
	static extern bool AdjustTokenPrivileges(IntPtr tok, bool dis, ref TP n, int len, IntPtr p, IntPtr r);
	[DllImport("psapi.dll", SetLastError=true)]
	static extern bool EnumProcessModulesEx(IntPtr proc, IntPtr[] mods, int cb, out int needed, uint filter);
	[DllImport("psapi.dll", SetLastError=true, CharSet=CharSet.Unicode)]
	static extern uint GetModuleFileNameExW(IntPtr proc, IntPtr mod, StringBuilder buf, int len);
	[StructLayout(LayoutKind.Sequential, Pack=4)] struct TP { public int Count; public long Luid; public int Attr; }

	public class Hit { public int Pid; public string File; public bool Module; }

	static bool Inside(string name, string[] targets) {
		if (name == null) return false;
		foreach (var t in targets)
			if (name.Equals(t, StringComparison.OrdinalIgnoreCase) || name.StartsWith(t + @"\", StringComparison.OrdinalIgnoreCase))
				return true;
		return false;
	}

	// loaded exe/dlls: mapped images don't always keep a visible file handle
	public static List<Hit> FindModules(string[] targets) {
		var hits = new List<Hit>();
		var mods = new IntPtr[2048];
		var sb = new StringBuilder(1024);
		foreach (var p in System.Diagnostics.Process.GetProcesses()) {
			int pid = p.Id; p.Dispose();
			IntPtr proc = OpenProcess(0x410, false, pid); // QUERY_INFORMATION | VM_READ
			if (proc == IntPtr.Zero) continue;
			try {
				int needed;
				if (!EnumProcessModulesEx(proc, mods, mods.Length * IntPtr.Size, out needed, 3)) continue; // LIST_MODULES_ALL
				int n = Math.Min(needed / IntPtr.Size, mods.Length);
				for (int i = 0; i < n; i++) {
					if (GetModuleFileNameExW(proc, mods[i], sb, sb.Capacity) == 0) continue;
					string name = sb.ToString();
					if (Inside(name, targets)) hits.Add(new Hit { Pid = pid, File = name, Module = true });
				}
			} finally { CloseHandle(proc); }
		}
		return hits;
	}

	static readonly IntPtr Invalid = new IntPtr(-1);

	public static void EnableDebug() {
		IntPtr t;
		if (!OpenProcessToken(GetCurrentProcess(), 0x28, out t)) return;
		TP tp = new TP(); tp.Count = 1; tp.Attr = 2;
		if (LookupPrivilegeValue(null, "SeDebugPrivilege", out tp.Luid))
			AdjustTokenPrivileges(t, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
		CloseHandle(t);
	}

	// "\\?\C:\x" -> "C:\x", "\\?\UNC\srv\share" -> "\\srv\share"
	static string Clean(string p) {
		if (p == null) return null;
		if (p.StartsWith(@"\\?\UNC\")) return @"\" + p.Substring(7);
		if (p.StartsWith(@"\\?\")) return p.Substring(4);
		return p;
	}

	static string FinalPath(IntPtr h) {
		var sb = new StringBuilder(1024);
		uint n = GetFinalPathNameByHandleW(h, sb, (uint)sb.Capacity, 0);
		if (n > sb.Capacity) { sb = new StringBuilder((int)n + 1); n = GetFinalPathNameByHandleW(h, sb, (uint)sb.Capacity, 0); }
		return n == 0 ? null : Clean(sb.ToString());
	}

	// fallback: \Device\HarddiskVolume3\x -> C:\x
	static Dictionary<string, string> devices;
	static string ObjectName(IntPtr h) {
		IntPtr buf = Marshal.AllocHGlobal(4096);
		try {
			int ret;
			if (NtQueryObject(h, 1, buf, 4096, out ret) != 0) return null;
			string name = Marshal.PtrToStringUni(Marshal.ReadIntPtr(buf, IntPtr.Size), Marshal.ReadInt16(buf) / 2);
			if (string.IsNullOrEmpty(name)) return null;
			foreach (var d in devices)
				if (name.StartsWith(d.Key + @"\", StringComparison.OrdinalIgnoreCase) || name.Equals(d.Key, StringComparison.OrdinalIgnoreCase))
					return d.Value + name.Substring(d.Key.Length);
			return null;
		} finally { Marshal.FreeHGlobal(buf); }
	}

	// Querying a name can block forever (handle with a pending synchronous I/O),
	// so it runs on a worker thread that gets abandoned on timeout.
	class Worker {
		IntPtr h; string res;
		readonly AutoResetEvent go = new AutoResetEvent(false), done = new AutoResetEvent(false);
		public Worker() { var t = new Thread(Loop); t.IsBackground = true; t.Start(); }
		void Loop() { while (true) { go.WaitOne(); try { res = FinalPath(h) ?? ObjectName(h); } catch { res = null; } done.Set(); } }
		public bool Query(IntPtr handle, out string r) {
			h = handle; go.Set();
			if (done.WaitOne(300)) { r = res; return true; }
			r = null; return false;
		}
	}

	// Resolve the target the same way handle paths get resolved (junctions, subst, 8.3 names).
	public static string Normalize(string path) {
		string full = Path.GetFullPath(path);
		IntPtr h = CreateFileW(full, 0, 7, IntPtr.Zero, 3, 0x02000000, IntPtr.Zero); // OPEN_EXISTING, BACKUP_SEMANTICS
		if (h == Invalid) return full.TrimEnd('\\');
		try { return (FinalPath(h) ?? full).TrimEnd('\\'); } finally { CloseHandle(h); }
	}

	public static List<Hit> Find(string[] targets) {
		if (devices == null) {
			devices = new Dictionary<string, string>();
			foreach (var drive in Environment.GetLogicalDrives()) {
				string letter = drive.Substring(0, 2);
				var sb = new StringBuilder(512);
				if (QueryDosDeviceW(letter, sb, sb.Capacity) != 0) devices[sb.ToString()] = letter;
			}
			devices[@"\Device\Mup"] = @"\";
		}

		var hits = new List<Hit>();
		int self = System.Diagnostics.Process.GetCurrentProcess().Id;
		int p = IntPtr.Size, entrySize = 3 * p + 16;
		IntPtr buf = IntPtr.Zero;

		// keep a known file open during the snapshot to learn the "File" object type index
		using (var probe = File.OpenRead(Path.Combine(Environment.SystemDirectory, "kernel32.dll"))) {
			long probeHandle = probe.SafeFileHandle.DangerousGetHandle().ToInt64();
			int len = 1 << 20, ret;
			while (true) {
				buf = Marshal.AllocHGlobal(len);
				uint st = NtQuerySystemInformation(64, buf, len, out ret); // SystemExtendedHandleInformation
				if (st == 0) break;
				Marshal.FreeHGlobal(buf); buf = IntPtr.Zero;
				if (st != 0xC0000004) throw new Exception("NtQuerySystemInformation failed: 0x" + st.ToString("X"));
				len = Math.Max(len * 2, ret + (1 << 16));
			}

			try {
				long count = Marshal.ReadIntPtr(buf).ToInt64();
				IntPtr first = buf + 2 * p;
				int fileType = -1;
				for (long i = 0; i < count && fileType < 0; i++) {
					IntPtr e = first + (int)(i * entrySize);
					if (Marshal.ReadIntPtr(e, p).ToInt64() == self && Marshal.ReadIntPtr(e, 2 * p).ToInt64() == probeHandle)
						fileType = (ushort)Marshal.ReadInt16(e, 3 * p + 6);
				}
				if (fileType < 0) throw new Exception("could not determine the File object type");

				var procs = new Dictionary<int, IntPtr>();
				var worker = new Worker();
				IntPtr me = GetCurrentProcess();

				for (long i = 0; i < count; i++) {
					IntPtr e = first + (int)(i * entrySize);
					if ((ushort)Marshal.ReadInt16(e, 3 * p + 6) != fileType) continue;
					int pid = (int)Marshal.ReadIntPtr(e, p).ToInt64();
					IntPtr handle = Marshal.ReadIntPtr(e, 2 * p);

					IntPtr proc;
					if (!procs.TryGetValue(pid, out proc)) {
						proc = OpenProcess(0x40, false, pid); // PROCESS_DUP_HANDLE
						procs[pid] = proc;
					}
					if (proc == IntPtr.Zero) continue;

					IntPtr dup;
					if (!DuplicateHandle(proc, handle, me, out dup, 0, false, 2)) continue; // DUPLICATE_SAME_ACCESS
					string name; bool closeIt = true;
					if (GetFileType(dup) == 1) { // FILE_TYPE_DISK
						if (!worker.Query(dup, out name)) { worker = new Worker(); closeIt = false; } // stuck thread keeps it
						else if (Inside(name, targets))
							hits.Add(new Hit { Pid = pid, File = name });
					}
					if (closeIt) CloseHandle(dup);
				}
				foreach (var h in procs.Values) if (h != IntPtr.Zero) CloseHandle(h);
			} finally { Marshal.FreeHGlobal(buf); }
		}
		return hits;
	}
}
'@
}

function Test-Admin {
	([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')
}

function Get-FileLocks {
	param([Parameter(Mandatory, Position = 0)][string]$Path)
	Initialize-FileLocks
	if (-not (Test-Path -LiteralPath $Path)) { throw "lsof: '$Path' does not exist" }
	$full = (Resolve-Path -LiteralPath $Path).ProviderPath
	$target = [FileLocks]::Normalize($full)
	if (Test-Admin) { [FileLocks]::EnableDebug() }

	$targets = @($target, $full) | Select-Object -Unique
	$procs = @{}; Get-Process | ForEach-Object { $procs[$_.Id] = $_ }

	$found = @([FileLocks]::Find($targets)) + @([FileLocks]::FindModules($targets))
	$hits = foreach ($h in $found) {
		$p = $procs[$h.Pid]
		$kind = if (-not $h.Module) { 'handle' } elseif ($p -and $h.File -eq $p.Path) { 'exe' } else { 'dll' }
		[pscustomobject]@{ PID = $h.Pid; Process = $p.ProcessName; Kind = $kind; File = $h.File }
	}
	$hits | Sort-Object PID, File -Unique
}

function getlock {
	param(
		[Parameter(Position = 0)][string]$Path = '.',
		[switch]$Summary
	)
	if (-not (Test-Admin)) { Write-Host 'lsof: not elevated, only your own processes are visible' -ForegroundColor DarkYellow }
	$hits = @(Get-FileLocks $Path)
	if (-not $hits) { Write-Host "lsof: nothing is holding '$Path'" -ForegroundColor Green; return }
	if (-not $Summary) { return $hits | Format-Table PID, Process, Kind, File -AutoSize }
	$hits | Group-Object PID | ForEach-Object {
		[pscustomobject]@{ PID = [int]$_.Name; Process = $_.Group[0].Process; Files = $_.Count; Example = $_.Group[0].File }
	} | Format-Table -AutoSize
}

function unlock {
	param(
		[Parameter(Position = 0)][string]$Path = '.',
		[switch]$Force
	)
	if (-not (Test-Admin)) { Write-Host 'unlock: not elevated, only your own processes are visible/killable' -ForegroundColor DarkYellow }
	$groups = @(Get-FileLocks $Path | Group-Object PID)
	if (-not $groups) { Write-Host "unlock: nothing is holding '$Path'" -ForegroundColor Green; return }

	$kill = @()
	foreach ($g in $groups) {
		$id = [int]$g.Name; $name = $g.Group[0].Process
		$note = '{0} file(s), e.g. {1}' -f $g.Count, $g.Group[0].File
		if ($id -eq $PID) { Write-Host "  $id  $name  (this shell, skipped: cd out / close the files)  $note" -ForegroundColor Cyan; continue }
		if ($id -le 4) { Write-Host "  $id  $name  (kernel, can't be killed)  $note" -ForegroundColor DarkGray; continue }
		Write-Host "  $id  $name  $note" -ForegroundColor Yellow
		$kill += $id
	}
	if (-not $kill) { return }

	if (-not $Force) {
		$answer = Read-Host "Kill $($kill.Count) process(es)? [y/N]"
		if ($answer -notmatch '^y') { return }
	}
	foreach ($id in $kill) {
		try { Stop-Process -Id $id -Force -ErrorAction Stop; Write-Host "  killed $id" -ForegroundColor Green }
		catch { Write-Host "  failed $id`: $($_.Exception.Message)" -ForegroundColor Red }
	}
}
