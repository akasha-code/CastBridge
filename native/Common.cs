using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Management;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace CastBridge {
public static class Common {
    public static JavaScriptSerializer Json { get { return new JavaScriptSerializer(); } }
    public static readonly string Root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
    public static string Language = "en";
    static Dictionary<string,object> translations;
    public static void LoadLanguage(string path) {
        string text;
        using (var resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("languages.json")) {
            if (resource != null) { using (var reader = new StreamReader(resource)) text = reader.ReadToEnd(); }
            else text = File.ReadAllText(path, Encoding.UTF8);
        }
        translations = Json.Deserialize<Dictionary<string,object>>(text);
        foreach (string language in new [] {"en", "es", "nb"}) {
            if (!translations.ContainsKey(language)) throw new InvalidDataException("Missing language: " + language);
            var entries = (Dictionary<string,object>)translations[language];
            var english = (Dictionary<string,object>)translations["en"];
            if (!entries.Keys.OrderBy(k=>k).SequenceEqual(english.Keys.OrderBy(k=>k)) || entries.Values.Any(v=>String.IsNullOrWhiteSpace(Convert.ToString(v))))
                throw new InvalidDataException("Incomplete translations: " + language);
        }
    }
    public static string T(string key) { return Convert.ToString(((Dictionary<string,object>)translations[Language])[key]); }
    public static Icon Icon() { return System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath); }
    public static ComboBox Languages() {
        var box = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 200 };
        box.Items.AddRange(new object[] { "English", "Español", "Norsk (bokmål)" });
        box.SelectedIndex = Language == "es" ? 1 : Language == "nb" ? 2 : 0;
        return box;
    }
    public static void SetLanguage(int index) { Language = new [] { "en", "es", "nb" }[index]; }
    public static void LoadSavedLanguage(string root) {string file=Path.Combine(root,"artifacts","ui-settings.json");if(!File.Exists(file))return;var settings=Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(file));string value=Convert.ToString(settings["language"]);if(!new[]{"en","es","nb"}.Contains(value))throw new InvalidDataException("Invalid saved language");Language=value;}
    public static string Quote(string arg) {
        if(arg.Length>0 && !arg.Any(c=>Char.IsWhiteSpace(c)||c=='"')) return arg;
        // Windows command-line escaping, including trailing backslashes.
        var b = new StringBuilder("\""); int slashes = 0;
        foreach (char c in arg) {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') { b.Append('\\', slashes * 2 + 1); b.Append(c); slashes = 0; continue; }
            b.Append('\\', slashes); slashes = 0; b.Append(c);
        }
        b.Append('\\', slashes * 2); return b.Append('"').ToString();
    }
    public static string Run(string file, IEnumerable<string> args, string cwd, int timeout, string log = null) {
        var info = new ProcessStartInfo(file, String.Join(" ", args.Select(Quote))) { UseShellExecute=false, CreateNoWindow=true, RedirectStandardOutput=true, RedirectStandardError=true, WorkingDirectory=cwd };
        var output = new StringBuilder(); var gate = new object();
        using (var process = new Process { StartInfo=info }) {
            DataReceivedEventHandler receive = delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) lock(gate) { output.AppendLine(e.Data); if(log != null) File.AppendAllText(log, e.Data + Environment.NewLine, Encoding.UTF8); } };
            process.OutputDataReceived += receive; process.ErrorDataReceived += receive;
            process.Start(); process.BeginOutputReadLine(); process.BeginErrorReadLine();
            if (!process.WaitForExit(timeout)) { process.Kill(); process.WaitForExit(); throw new TimeoutException("Process timed out: " + Path.GetFileName(file)); }
            process.WaitForExit();
            if (process.ExitCode != 0) {var error=new InvalidOperationException(Path.GetFileName(file) + " exited with code " + process.ExitCode);error.Data["output"]=output.ToString();throw error;}
        }
        return output.ToString();
    }
    public static string Find(string name) {
        foreach (string directory in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';')) {
            if (String.IsNullOrWhiteSpace(directory)) continue;
            try { string path=Path.Combine(directory.Trim('"'),name); if (File.Exists(path)) return Path.GetFullPath(path); } catch (ArgumentException) { }
        }
        return null;
    }
    public static object[] Objects(object value) {return ((System.Collections.IEnumerable)value).Cast<object>().ToArray();}
    public static bool Active() {
        Mutex existing;
        if (!Mutex.TryOpenExisting("Local\\CastAggregatorTray", out existing)) return false;
        using(existing) {
            bool acquired=false;
            try { acquired=existing.WaitOne(0); return !acquired; }
            catch(AbandonedMutexException) { acquired=true; return false; }
            finally { if(acquired) existing.ReleaseMutex(); }
        }
    }
    public static string Under(string root, string relative) {
        string prefix=Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar;
        string path=Path.GetFullPath(Path.Combine(prefix,relative));
        if (!path.StartsWith(prefix,StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("Path escapes application directory");
        return path;
    }
    public static string ValidateDestination(string root) {string path=Path.GetFullPath(root);string windows=Environment.GetFolderPath(Environment.SpecialFolder.Windows);if(path==Path.GetPathRoot(path)||path.StartsWith(windows,StringComparison.OrdinalIgnoreCase)||path.StartsWith(@"\\",StringComparison.Ordinal))throw new InvalidDataException(T("folderInvalid"));return path;}
    public static void EnsureNoLinks(string path) {if(!Directory.Exists(path))return;if((File.GetAttributes(path)&FileAttributes.ReparsePoint)!=0)throw new InvalidDataException("Application directory contains a symbolic link or junction");foreach(string file in Directory.GetFiles(path))if((File.GetAttributes(file)&FileAttributes.ReparsePoint)!=0)throw new InvalidDataException("Application file is a symbolic link");foreach(string directory in Directory.GetDirectories(path))EnsureNoLinks(directory);}
    public static void SaveJson(string path, object data) {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        string temporary=path+"."+Guid.NewGuid().ToString("N")+".tmp";
        File.WriteAllText(temporary,Json.Serialize(data),new UTF8Encoding(false));
        if(File.Exists(path)) File.Replace(temporary,path,null); else File.Move(temporary,path);
    }
    public static void Shortcut(string executable, string path) {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        object shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell")); object shortcut=null;
        try {
            shortcut=shell.GetType().InvokeMember("CreateShortcut",BindingFlags.InvokeMethod,null,shell,new object[]{path});
            foreach(var property in new Dictionary<string,string>{{"TargetPath",executable},{"WorkingDirectory",Path.GetDirectoryName(executable)},{"IconLocation",executable+",0"},{"Description","CastBridge — MateKraft"}})
                shortcut.GetType().InvokeMember(property.Key,BindingFlags.SetProperty,null,shortcut,new object[]{property.Value});
            shortcut.GetType().InvokeMember("Save",BindingFlags.InvokeMethod,null,shortcut,null);
        } finally {if(shortcut!=null) Marshal.FinalReleaseComObject(shortcut); Marshal.FinalReleaseComObject(shell);}
    }
}
public sealed class Requirement {
    public string Key; public bool Ready; public string Url;
    public Requirement(string key,bool ready,string url="") {Key=key;Ready=ready;Url=url;}
}
public static class Requirements {
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct VersionInfo { public uint Size,Major,Minor,Build,Platform; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=128)] public string ServicePack; }
    [DllImport("ntdll.dll")] static extern int RtlGetVersion(ref VersionInfo info);
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] class TrustFile {public uint Size=(uint)Marshal.SizeOf(typeof(TrustFile));public string Path;public IntPtr Handle=IntPtr.Zero,Known=IntPtr.Zero;}
    [StructLayout(LayoutKind.Sequential)] class TrustData {public uint Size=(uint)Marshal.SizeOf(typeof(TrustData));public IntPtr Policy=IntPtr.Zero,Client=IntPtr.Zero;public uint UI=2,Revocation=0,Choice=1;public IntPtr File;public uint StateAction=0;public IntPtr State=IntPtr.Zero;public IntPtr Url=IntPtr.Zero;public uint Flags=0,Context=0;}
    [DllImport("wintrust.dll",ExactSpelling=true)] static extern int WinVerifyTrust(IntPtr window,ref Guid action,[In,Out] TrustData data);
    public static bool Signed(string path) {
        if(!File.Exists(path)) return false;
        var file=new TrustFile {Path=path}; var pointer=Marshal.AllocHGlobal(Marshal.SizeOf(file));
        try {Marshal.StructureToPtr(file,pointer,false);var data=new TrustData {File=pointer};var action=new Guid("00AAC56B-CD44-11d0-8CC2-00C04FC295EE");return WinVerifyTrust(new IntPtr(-1),ref action,data)==0;}
        finally {Marshal.DestroyStructure(pointer,typeof(TrustFile));Marshal.FreeHGlobal(pointer);}
    }
    public static readonly List<string> Diagnostics=new List<string>();
    static bool Try(Func<bool> check) {try{return check();}catch(Exception e){Diagnostics.Add(e.GetType().Name+": "+e.Message);return false;}}
    public static List<Requirement> Check(string root) {
        Diagnostics.Clear();var result=new List<Requirement>(); var version=new VersionInfo {Size=(uint)Marshal.SizeOf(typeof(VersionInfo))};
        result.Add(new Requirement("windows",Environment.Is64BitOperatingSystem && RtlGetVersion(ref version)==0 && version.Build>=22000));
        string py=Common.Find("py.exe");
        if(py==null) {string candidate=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"py.exe");if(File.Exists(candidate)) py=candidate;}
        result.Add(new Requirement("python",Try(()=>py!=null && Common.Run(py,new[]{"-3.12","-c","import struct; assert struct.calcsize('P') == 8"},root,10000)!=null),"https://www.python.org/downloads/windows/"));
        string ffmpeg=File.Exists(Path.Combine(root,"bin","ffmpeg.exe"))?Path.Combine(root,"bin","ffmpeg.exe"):Common.Find("ffmpeg.exe");
        result.Add(new Requirement("ffmpeg",Try(()=>ffmpeg!=null && Common.Run(ffmpeg,new[]{"-hide_banner","-devices"},root,10000).Contains("gdigrab") && Common.Run(ffmpeg,new[]{"-hide_banner","-encoders"},root,10000).Contains("libx264") && Common.Run(ffmpeg,new[]{"-hide_banner","-formats"},root,10000).Contains("hls")),"https://ffmpeg.org/download.html"));
        bool driver=Try(()=>Directory.GetDirectories(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","DriverStore","FileRepository"),"mttvdd.inf_amd64_*").Any(d=>File.Exists(Path.Combine(d,"MttVDD.inf")) && File.ReadAllText(Path.Combine(d,"MttVDD.inf")).Contains("11.30.4.434") && Signed(Path.Combine(d,"MttVDD.cat")) && Signed(Path.Combine(d,"MttVDD.dll"))));
        result.Add(new Requirement("driver",driver,"https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/tag/25.7.23"));
        bool config=Try(()=>{var xml=new System.Xml.XmlDocument();xml.Load(@"C:\VirtualDisplayDriver\vdd_settings.xml");return xml.SelectSingleNode("/vdd_settings/monitors/count").InnerText=="1" && xml.SelectNodes("/vdd_settings/resolutions/resolution").Count==1 && xml.SelectSingleNode("//resolution/width").InnerText=="1280" && xml.SelectSingleNode("//resolution/height").InnerText=="720" && xml.SelectSingleNode("//resolution/refresh_rate").InnerText=="60" && xml.SelectSingleNode("//options/HardwareCursor").InnerText=="false";});
        result.Add(new Requirement("config",config));
        result.Add(new Requirement("network",Try(()=>{ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;var request=(HttpWebRequest)WebRequest.Create("https://pypi.org/pypi/PyChromecast/14.0.10/json");request.Timeout=8000;using(var response=request.GetResponse())using(var reader=new StreamReader(response.GetResponseStream())){var data=Common.Json.Deserialize<Dictionary<string,object>>(reader.ReadToEnd());var urls=Common.Objects(data["urls"]);var uri=new Uri(Convert.ToString(((Dictionary<string,object>)urls[0])["url"]));if(uri.Scheme!="https" || uri.Host!="files.pythonhosted.org")return false;var download=(HttpWebRequest)WebRequest.Create(uri);download.Method="HEAD";download.Timeout=8000;using(var check=download.GetResponse())return true;}})));
        result.Add(new Requirement("closed",!Common.Active()));
        bool free=Try(()=>{using(var query=new ManagementObjectSearcher("SELECT HardwareID FROM Win32_PnPEntity"))foreach(ManagementObject row in query.Get()){using(row){var ids=row["HardwareID"] as string[];if(ids!=null && ids.Any(id=>String.Equals(id,"MttVDD",StringComparison.OrdinalIgnoreCase)||String.Equals(id,@"Root\MttVDD",StringComparison.OrdinalIgnoreCase)))return false;}}return true;});
        result.Add(new Requirement("deviceFree",free));
        return result;
    }
}
}
