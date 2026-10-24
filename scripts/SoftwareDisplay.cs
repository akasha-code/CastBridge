using System;
using System.Runtime.InteropServices;
using System.Threading;

public sealed class SoftwareDisplay : IDisposable {
    [StructLayout(LayoutKind.Sequential)]
    struct CreateInfo {
        public uint Size;
        public IntPtr Instance, Hardware, Compatible, Container;
        public uint Capabilities;
        public IntPtr Description, Location, Security;
    }
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    delegate void Callback(IntPtr device, int result, IntPtr context, IntPtr instance);
    [DllImport("cfgmgr32.dll", CharSet=CharSet.Unicode, ExactSpelling=true)]
    static extern int SwDeviceCreate(string enumerator, string parent, ref CreateInfo info, uint count, IntPtr properties, Callback callback, IntPtr context, out IntPtr handle);
    [DllImport("cfgmgr32.dll")]
    static extern int SwDeviceSetLifetime(IntPtr device, int lifetime);
    [DllImport("cfgmgr32.dll")]
    static extern void SwDeviceClose(IntPtr device);
    IntPtr handle;
    Callback callback;
    ManualResetEventSlim completed = new ManualResetEventSlim(false);
    int creationResult;
    public string InstanceId { get; private set; }
    static void Check(int result, string operation) {
        if (result < 0) throw new InvalidOperationException(operation + " failed: HRESULT 0x" + result.ToString("X8"));
    }

    public SoftwareDisplay() {
        IntPtr instance = Marshal.StringToHGlobalUni("CastAggregator-" + Guid.NewGuid().ToString("N"));
        IntPtr hardware = Marshal.StringToHGlobalUni("MttVDD\0\0");
        IntPtr description = Marshal.StringToHGlobalUni("CastAggregator temporary virtual display");
        try {
            CreateInfo info = new CreateInfo();
            info.Size = (uint)Marshal.SizeOf(typeof(CreateInfo));
            info.Instance = instance; info.Hardware = hardware;
            info.Description = description; info.Capabilities = 9;
            callback = delegate(IntPtr device, int result, IntPtr context, IntPtr id) {
                creationResult = result; InstanceId = Marshal.PtrToStringUni(id); completed.Set();
            };
            int hr = SwDeviceCreate("CastAggregator", "HTREE\\ROOT\\0", ref info, 0, IntPtr.Zero, callback, IntPtr.Zero, out handle);
            Check(hr, "SwDeviceCreate");
            Check(SwDeviceSetLifetime(handle, 0), "SwDeviceSetLifetime");
            if (!completed.Wait(20000)) throw new TimeoutException("Software device enumeration timed out");
            Check(creationResult, "Software device enumeration callback");
            if (String.IsNullOrEmpty(InstanceId)) throw new InvalidOperationException("Software device did not return an identity");
        } catch { Dispose(); throw; }
        finally { Marshal.FreeHGlobal(instance); Marshal.FreeHGlobal(hardware); Marshal.FreeHGlobal(description); }
    }
    public void Dispose() {
        if (handle != IntPtr.Zero) { SwDeviceClose(handle); handle = IntPtr.Zero; }
        if (completed != null) { completed.Dispose(); completed = null; }
        GC.KeepAlive(callback);
    }
}
