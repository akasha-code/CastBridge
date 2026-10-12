using System;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;
using System.Collections.Generic;
using CastBridge;
public static class CrashWindow {
    [STAThread] public static int Main(string[] args) {
        bool placed=false;DateTime started=DateTime.UtcNow;DateTime? removed=null;
        Application.EnableVisualStyles();
        using(var form=new Form {Text="CastBridge forced-exit recovery test",Size=new Size(650,240),StartPosition=FormStartPosition.Manual,Location=new Point(50,50)})
        using(var timer=new Timer {Interval=250}) {
            form.Controls.Add(new Label {Text="Synthetic window for forced-exit recovery. No user content.",Dock=DockStyle.Fill,Font=new Font("Segoe UI",20)});
            string source=null;
            timer.Tick+=delegate {
                if(!placed&&File.Exists(args[0])) {
                    var data=Common.Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(args[0]));var row=Common.Objects(data["topology"]).Cast<Dictionary<string,object>>().Single(r=>Convert.ToString(r["target_path"]).Contains("#MTT1337#"));source=Convert.ToString(row["source"]);
                    var bounds=(Dictionary<string,object>)((Dictionary<string,object>)data["bounds"])[source];form.Location=new Point(Convert.ToInt32(bounds["x"])+50,Convert.ToInt32(bounds["y"])+50);placed=true;
                }
                if(placed&&!Screen.AllScreens.Any(s=>s.DeviceName==source)){if(!removed.HasValue)removed=DateTime.UtcNow;}
                if((removed.HasValue&&DateTime.UtcNow-removed.Value>TimeSpan.FromSeconds(5))||DateTime.UtcNow-started>TimeSpan.FromSeconds(120)) {
                    Common.SaveJson(args[1],new{virtualWasObserved=placed,virtualRemoved=removed.HasValue,windowAccessible=Screen.AllScreens.Any(s=>s.Bounds.Contains(form.Location)),physicalScreenCount=Screen.AllScreens.Length});timer.Stop();form.Close();
                }
            };
            timer.Start();Application.Run(form);
        }return 0;
    }
}
