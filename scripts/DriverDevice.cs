using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class DriverDevice {
    [StructLayout(LayoutKind.Sequential)]
    public struct Info { public uint Size; public Guid ClassGuid; public uint DevInst; public IntPtr Reserved; }
    [DllImport("setupapi.dll", SetLastError=true)]
    static extern IntPtr SetupDiCreateDeviceInfoList(ref Guid cls, IntPtr parent);
    [DllImport("setupapi.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern bool SetupDiCreateDeviceInfoW(IntPtr set, string name, ref Guid cls, string desc, IntPtr parent, uint flags, ref Info info);
    [DllImport("setupapi.dll", SetLastError=true)]
    static extern bool SetupDiSetDeviceRegistryPropertyW(IntPtr set, ref Info info, uint property, byte[] value, uint size);
    [DllImport("setupapi.dll", SetLastError=true)]
    static extern bool SetupDiCallClassInstaller(uint function, IntPtr set, ref Info info);
    [DllImport("setupapi.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern bool SetupDiGetDeviceInstanceIdW(IntPtr set, ref Info info, System.Text.StringBuilder id, uint length, out uint needed);
    [DllImport("setupapi.dll", SetLastError=true)]
    static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);
    [DllImport("newdev.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern bool UpdateDriverForPlugAndPlayDevicesW(IntPtr parent, string hardwareId, string inf, uint flags, out bool reboot);

    static void Check(bool success) { if (!success) throw new Win32Exception(Marshal.GetLastWin32Error()); }
    public static string CreateDisabled() {
        Guid cls = new Guid("4D36E968-E325-11CE-BFC1-08002BE10318");
        IntPtr set = SetupDiCreateDeviceInfoList(ref cls, IntPtr.Zero);
        if (set == new IntPtr(-1)) throw new Win32Exception(Marshal.GetLastWin32Error());
        try {
            Info info = new Info(); info.Size = (uint)Marshal.SizeOf(typeof(Info));
            Check(SetupDiCreateDeviceInfoW(set, "Display", ref cls, "CastAggregator Virtual Display", IntPtr.Zero, 1, ref info));
            byte[] ids = System.Text.Encoding.Unicode.GetBytes("Root\\MttVDD\0\0");
            Check(SetupDiSetDeviceRegistryPropertyW(set, ref info, 1, ids, (uint)ids.Length));
            // Best-effort initial disable; observed driver binding can clear it.
            byte[] disabled = BitConverter.GetBytes((uint)1);
            Check(SetupDiSetDeviceRegistryPropertyW(set, ref info, 10, disabled, 4));
            Check(SetupDiCallClassInstaller(0x19, set, ref info));
            var id = new System.Text.StringBuilder(512); uint needed;
            Check(SetupDiGetDeviceInstanceIdW(set, ref info, id, 512, out needed));
            return id.ToString();
        } finally { SetupDiDestroyDeviceInfoList(set); }
    }
    public static bool Bind(string inf) {
        bool reboot;
        Check(UpdateDriverForPlugAndPlayDevicesW(IntPtr.Zero, "Root\\MttVDD", inf, 1, out reboot));
        return reboot;
    }
}
