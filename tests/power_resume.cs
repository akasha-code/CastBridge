using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using CastBridge;
public static class PowerResumeChecks {
    [DllImport("user32.dll")]static extern IntPtr SendMessage(IntPtr window,uint message,IntPtr wParam,IntPtr lParam);
    [STAThread] public static int Main(string[] args) {
        Common.LoadLanguage(Path.Combine(args[0],"assets","languages.json"));Application.EnableVisualStyles();
        var fields=BindingFlags.Instance|BindingFlags.NonPublic;
        foreach(string code in new[]{"en","es","nb"}) {
            Common.Language=code;
            using(var desktop=new Desktop(true)) {
                var home=(Form)typeof(Desktop).GetField("home",fields).GetValue(desktop);home.Show();
                typeof(Desktop).GetField("selected",fields).SetValue(desktop,new Dictionary<string,object>{{"name","Synthetic receiver"},{"id","00000000-0000-0000-0000-000000000001"}});
                typeof(Desktop).GetField("resumeEligible",fields).SetValue(desktop,true);
                var power=(Action<Guid,int>)Delegate.CreateDelegate(typeof(Action<Guid,int>),desktop,typeof(Desktop).GetMethod("DisplayPowerChanged",fields));
                var session=(Action<bool>)Delegate.CreateDelegate(typeof(Action<bool>),desktop,typeof(Desktop).GetMethod("SessionLockChanged",fields));
                using(var watcher=new DisplayPowerNotifications(home.Handle,power,session)) {
                    SendMessage(home.Handle,0x2b1,new IntPtr(7),IntPtr.Zero);
                    if(typeof(Desktop).GetField("reconnectAt",fields).GetValue(desktop)!=null)throw new Exception("Countdown started while locked");
                    SendMessage(home.Handle,0x2b1,new IntPtr(8),IntPtr.Zero);
                    var cancel=(Button)typeof(Desktop).GetField("cancelResume",fields).GetValue(desktop);
                    if(!cancel.Visible||typeof(Desktop).GetField("reconnectAt",fields).GetValue(desktop)==null)throw new Exception("Unlock did not start countdown");
                    var popup=(Form)typeof(Desktop).GetField("resumeDialog",fields).GetValue(desktop);if(popup==null||!popup.Visible)throw new Exception("Reconnect popup not visible");
                    using(var bitmap=new Bitmap(popup.Width,popup.Height)){popup.DrawToBitmap(bitmap,new Rectangle(0,0,bitmap.Width,bitmap.Height));bitmap.Save(Path.Combine(args[0],"artifacts","resume-countdown-"+code+".png"));}
                    popup.Controls.OfType<Button>().Single(b=>b.Text==Common.T("cancelReconnect")).PerformClick();
                    if(cancel.Visible||typeof(Desktop).GetField("reconnectAt",fields).GetValue(desktop)!=null||(bool)typeof(Desktop).GetField("resumeEligible",fields).GetValue(desktop))throw new Exception("Cancel left reconnect armed");
                    typeof(Desktop).GetField("resumeEligible",fields).SetValue(desktop,true);SendMessage(home.Handle,0x2b1,new IntPtr(7),IntPtr.Zero);power(DisplayPowerNotifications.Presence,0);if(typeof(Desktop).GetField("reconnectAt",fields).GetValue(desktop)!=null)throw new Exception("Presence started countdown before unlock");SendMessage(home.Handle,0x2b1,new IntPtr(8),IntPtr.Zero);((Form)typeof(Desktop).GetField("resumeDialog",fields).GetValue(desktop)).Close();if(typeof(Desktop).GetField("reconnectAt",fields).GetValue(desktop)!=null)throw new Exception("Closing popup did not cancel");
                }
            }
        }
        Console.WriteLine("Power resume checks passed: owned-window lock/unlock messages, countdown, cancellation and three languages.");return 0;
    }
}
