using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Windows.Forms;
using CastBridge;
public static class DesktopLifecycle {
    [STAThread] public static int Main(string[] args) {
        Common.LoadLanguage(Path.Combine(args[0],"assets","languages.json"));Application.EnableVisualStyles();
        try {
            using(var context=new Desktop(false)) {
                using(var timer=new Timer {Interval=300}) {
                    timer.Tick+=delegate {timer.Stop();var menu=(ContextMenuStrip)typeof(Desktop).GetField("menu",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(context);menu.Items.OfType<ToolStripMenuItem>().Single(item=>item.Text==Common.T("exit")).PerformClick();};
                    timer.Start();Application.Run(context);
                }
                context.Dispose();
            }
            Common.SaveJson(args[1],new{success=true,normalExit=true,repeatedDisposal=true});return 0;
        }catch(Exception e){Common.SaveJson(args[1],new{success=false,error=e.ToString()});return 1;}
    }
}
