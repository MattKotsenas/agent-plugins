using System.Diagnostics;
using System.Runtime.InteropServices;

const uint ES_CONTINUOUS = 0x80000000;
const uint ES_SYSTEM_REQUIRED = 0x00000001;

if (args.Length == 0)
{
    Console.Error.WriteLine("Usage: vigil start <watchPid>  — keep system awake, exit when watchPid dies");
    Console.Error.WriteLine("       vigil end               — release the vigil for the calling session");
    Console.Error.WriteLine("       vigil clear             — kill all vigil processes and clean up");
    return 1;
}

var pidDir = Path.Combine(Path.GetTempPath(), "vigil");
Directory.CreateDirectory(pidDir);

switch (args[0])
{
    case "start":
    {
        if (args.Length < 2 || !int.TryParse(args[1], out var watchPid))
        {
            Console.Error.WriteLine("vigil start requires a PID to watch");
            return 1;
        }

        // Verify the watched process exists
        try { Process.GetProcessById(watchPid); }
        catch
        {
            Console.Error.WriteLine($"Process {watchPid} not found");
            return 1;
        }

        // Write our own PID file, keyed by the watched PID
        var myPidFile = Path.Combine(pidDir, $"{watchPid}.pid");
        File.WriteAllText(myPidFile, Environment.ProcessId.ToString());

        // Acquire sleep inhibitor
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED);
            WaitForProcessExit(watchPid);
        }
        else // Linux: systemd-inhibit holds the lock while its child runs
        {
            var inhibit = Process.Start(new ProcessStartInfo
            {
                FileName = "systemd-inhibit",
                ArgumentList = { "--what=sleep", "--who=vigil", "--why=AI agent active", "sleep", "infinity" },
            });

            WaitForProcessExit(watchPid);
            try { inhibit?.Kill(); } catch { }
        }

        // Clean up our PID file on exit (crash safety: WaitForExit returned)
        try { File.Delete(myPidFile); } catch { }
        break;
    }

    case "end":
    {
        if (args.Length < 2 || !int.TryParse(args[1], out var copilotPid))
        {
            Console.Error.WriteLine("vigil end requires the copilot PID");
            return 1;
        }

        var pidFile = Path.Combine(pidDir, $"{copilotPid}.pid");
        if (!File.Exists(pidFile))
            return 0; // no vigil running for this session

        if (int.TryParse(File.ReadAllText(pidFile).Trim(), out var vigilPid))
        {
            try { Process.GetProcessById(vigilPid).Kill(); } catch { }
        }

        try { File.Delete(pidFile); } catch { }
        break;
    }

    case "clear":
    {
        if (!Directory.Exists(pidDir)) break;

        var killed = 0;
        foreach (var file in Directory.GetFiles(pidDir, "*.pid"))
        {
            if (int.TryParse(File.ReadAllText(file).Trim(), out var pid))
            {
                try
                {
                    Process.GetProcessById(pid).Kill();
                    killed++;
                }
                catch { } // already dead
            }
            try { File.Delete(file); } catch { }
        }
        Console.WriteLine($"Cleared {killed} vigil(s)");
        break;
    }

    default:
        Console.Error.WriteLine($"Unknown command: {args[0]}");
        return 1;
}

return 0;

// --- Helpers ---

static void WaitForProcessExit(int pid)
{
    try { Process.GetProcessById(pid).WaitForExit(); }
    catch { } // process already gone
}

// --- Windows P/Invoke ---

[DllImport("kernel32.dll", SetLastError = true)]
static extern uint SetThreadExecutionState(uint esFlags);
