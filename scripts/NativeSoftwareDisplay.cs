using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public sealed class NativeSoftwareDisplay : IDisposable {
    [UnmanagedFunctionPointer(CallingConvention.Winapi, CharSet=CharSet.Unicode)]
    delegate int CreateNative(string instance, StringBuilder id, uint length, out IntPtr context, out uint stage);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    delegate void CloseNative(IntPtr context);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr LoadLibraryExW(string path, IntPtr file, uint flags);
    [DllImport("kernel32.dll", CharSet=CharSet.Ansi, ExactSpelling=true, SetLastError=true)]
    static extern IntPtr GetProcAddress(IntPtr module, string name);
    [DllImport("kernel32.dll")]
    static extern bool FreeLibrary(IntPtr module);
    IntPtr module, context;
    CloseNative close;
    public string InstanceId { get; private set; }
    public NativeSoftwareDisplay(string libraryPath) {
        if (!Path.IsPathRooted(libraryPath)) throw new ArgumentException("Native library path must be absolute");
        try {
            module = LoadLibraryExW(libraryPath, IntPtr.Zero, 0x1100);
            if (module == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            IntPtr createAddress = GetProcAddress(module, "CastAggregatorCreate");
            IntPtr closeAddress = GetProcAddress(module, "CastAggregatorClose");
            if (createAddress == IntPtr.Zero || closeAddress == IntPtr.Zero) throw new InvalidOperationException("Native display exports unavailable");
            CreateNative create = (CreateNative)Marshal.GetDelegateForFunctionPointer(createAddress, typeof(CreateNative));
            close = (CloseNative)Marshal.GetDelegateForFunctionPointer(closeAddress, typeof(CloseNative));
            var id = new StringBuilder(512);
            uint stage;
            int result = create("CastAggregator-display-0", id, 512, out context, out stage);
            if (result < 0) throw new InvalidOperationException("Native software device creation failed at stage " + stage + ": HRESULT 0x" + result.ToString("X8"));
            InstanceId = id.ToString();
        } catch { Dispose(); throw; }
    }
    public void Dispose() {
        if (context != IntPtr.Zero) { close(context); context = IntPtr.Zero; }
        if (module != IntPtr.Zero) { FreeLibrary(module); module = IntPtr.Zero; }
    }
}
