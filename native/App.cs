using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Management;
using System.Reflection;
using System.Security.Principal;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
[assembly: AssemblyTitle("CastBridge")]
[assembly: AssemblyProduct("CastBridge")]
[assembly: AssemblyCompany("MateKraft")]
[assembly: AssemblyVersion("0.2.0.0")]
namespace CastBridge {
public class Desktop : ApplicationContext {
    readonly string root=Common.Root, prefs=Path.Combine(Common.Root,"artifacts","preferences.json"), settings=Path.Combine(Common.Root,"artifacts","ui-settings.json");
    readonly NotifyIcon tray; readonly ContextMenuStrip menu=new ContextMenuStrip(); readonly Form home=new Form();
    readonly Label status=new Label(), credit=new Label(), selectedLabel=new Label(), hint=new Label();
    readonly Button connect=new Button(), disconnect=new Button(), choose=new Button(), about=new Button();
    readonly ComboBox languages; readonly System.Windows.Forms.Timer timer=new System.Windows.Forms.Timer();
    Dictionary<string,object> selected; Task sessionTask; bool exiting,busy,failed; string session, state="disconnected";
    List<ToolStripMenuItem> profiles=new List<ToolStripMenuItem>(); int profile;
    readonly bool smoke;
    string integrationReport;DateTime integrationDeadline;DateTime? connectedAt;
    public Desktop(bool test) {
        smoke=test;
        Directory.CreateDirectory(Path.Combine(root,"artifacts"));
        Common.LoadSavedLanguage(root);
        if(File.Exists(prefs)) {try{selected=Common.Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(prefs));}catch(Exception e){Log(e);failed=true;}}
        profile=selected!=null && selected.ContainsKey("aggressiveLatency") && Convert.ToBoolean(selected["aggressiveLatency"])?2:selected!=null && selected.ContainsKey("lowLatency") && Convert.ToBoolean(selected["lowLatency"])?1:0;
        tray=new NotifyIcon {Icon=Common.Icon(),ContextMenuStrip=menu,Visible=!test};tray.DoubleClick+=delegate{home.Show();home.Activate();};
        home.Text="CastBridge — MateKraft";home.ClientSize=new Size(600,360);home.StartPosition=FormStartPosition.CenterScreen;home.Icon=Common.Icon();home.BackColor=Color.FromArgb(10,20,18);home.ForeColor=Color.FromArgb(247,242,228);home.Font=new Font("Segoe UI",10);
        var picture=new PictureBox {Image=tray.Icon.ToBitmap(),SizeMode=PictureBoxSizeMode.Zoom,Location=new Point(25,25),Size=new Size(64,64)};
        var title=new Label {Text="CastBridge",Font=new Font("Segoe UI",23,FontStyle.Bold),Location=new Point(110,20),AutoSize=true};
        credit.Location=new Point(112,64);credit.Size=new Size(450,30);credit.ForeColor=Color.FromArgb(212,175,55);
        languages=Common.Languages();languages.Location=new Point(365,115);languages.SelectedIndexChanged+=delegate{Common.SetLanguage(languages.SelectedIndex);if(!smoke)Common.SaveJson(settings,new{language=Common.Language});RefreshText();};
        status.Location=new Point(25,115);status.Size=new Size(310,30);selectedLabel.Location=new Point(25,155);selectedLabel.Size=new Size(545,35);
        Button[] buttons={choose,connect,disconnect,about};for(int i=0;i<buttons.Length;i++){buttons[i].Location=new Point(25+i*140,210);buttons[i].Size=new Size(130,38);buttons[i].ForeColor=Color.FromArgb(10,20,18);buttons[i].BackColor=Color.FromArgb(247,242,228);}
        hint.Location=new Point(25,270);hint.Size=new Size(545,60);
        choose.Click+=delegate{Discover();};connect.Click+=delegate{Connect();};disconnect.Click+=delegate{Stop();};about.Click+=delegate{About(home);};
        home.Controls.AddRange(new Control[]{picture,title,credit,languages,status,selectedLabel,choose,connect,disconnect,about,hint});
        home.FormClosing+=delegate(object sender,FormClosingEventArgs e){if(!smoke && (!exiting||sessionTask!=null)){e.Cancel=true;if(!exiting)home.Hide();}};
        timer.Interval=500;timer.Tick+=delegate{Tick();};RefreshText();if(!test){timer.Start();home.Show();}
    }
    void Log(Exception e) {File.AppendAllText(Path.Combine(root,"artifacts","desktop-errors.log"),DateTime.UtcNow.ToString("o")+" "+e+Environment.NewLine);}
    void Problem(string key,Exception e=null) {if(e!=null)Log(e);tray.ShowBalloonTip(8000,"CastBridge — MateKraft",Common.T(key),ToolTipIcon.Error);if(home.Visible)MessageBox.Show(home,Common.T(key),"CastBridge",MessageBoxButtons.OK,MessageBoxIcon.Warning);}
    string Name() {return selected==null?Common.T("select"):selected.ContainsKey("displayName")?Convert.ToString(selected["displayName"]):Convert.ToString(selected["name"]);}
    void Save() {Common.SaveJson(prefs,selected);}
    void Item(string key,Action action,bool enabled=true) {var item=new ToolStripMenuItem(Common.T(key));item.Enabled=enabled;item.Click+=delegate{action();};menu.Items.Add(item);}
    public void RefreshText() {
        credit.Text=Common.T("credit");status.Text=Common.T(state);selectedLabel.Text=Name();hint.Text=Common.T("profileHint")+Environment.NewLine+Common.T("restoreWarning");
        choose.Text=Common.T("select");connect.Text=Common.T("connect");disconnect.Text=Common.T("disconnect");about.Text=Common.T("about");
        bool active=sessionTask!=null;choose.Enabled=!active && !busy;connect.Enabled=!active && !busy && selected!=null && !failed;disconnect.Enabled=active && state!="disconnecting";
        tray.Text="CastBridge — MateKraft: "+Common.T(state);
        menu.Items.Clear();menu.Items.Add(new ToolStripMenuItem("CastBridge — "+Common.T("credit")){Enabled=false});menu.Items.Add(new ToolStripMenuItem(Common.T(state)){Enabled=false});
        Item("select",()=>Discover(),!active&&!busy);Item("rename",()=>Rename(),!active&&selected!=null);
        var latency=new ToolStripMenuItem(Common.T("latency")){Enabled=!active&&selected!=null};profiles.Clear();
        string[] keys={"stable","reduced","minimum"};for(int i=0;i<keys.Length;i++){int captured=i;var item=new ToolStripMenuItem(Common.T(keys[i])){Checked=profile==i};item.Click+=delegate{profile=captured;selected["lowLatency"]=profile>0;selected["aggressiveLatency"]=profile==2;Save();RefreshText();};latency.DropDownItems.Add(item);profiles.Add(item);}menu.Items.Add(latency);
        var language=new ToolStripMenuItem(Common.T("language"));string[] labels={"English","Español","Norsk (bokmål)"};for(int i=0;i<labels.Length;i++){int captured=i;var item=new ToolStripMenuItem(labels[i]){Checked=languages.SelectedIndex==i};item.Click+=delegate{languages.SelectedIndex=captured;};language.DropDownItems.Add(item);}menu.Items.Add(language);
        Item("connect",()=>Connect(),connect.Enabled);Item("disconnect",()=>Stop(),disconnect.Enabled);Item("sync",()=>File.WriteAllText(Path.Combine(session,"sync"),"sync"),active&&state=="connected");
        Item("about",()=>About(home));Item("exit",()=>{exiting=true;if(active){home.Show();Stop();}else ExitThread();});
    }
    void Rename() {using(var dialog=new Form {Text=Common.T("screenTitle"),ClientSize=new Size(440,110),StartPosition=FormStartPosition.CenterParent,Icon=Common.Icon()}){var text=new TextBox {Text=Name(),MaxLength=80,Location=new Point(15,15),Width=410};var save=new Button {Text=Common.T("save"),DialogResult=DialogResult.OK,Location=new Point(310,60)};dialog.Controls.AddRange(new Control[]{text,save});dialog.AcceptButton=save;if(dialog.ShowDialog(home)==DialogResult.OK && !String.IsNullOrWhiteSpace(text.Text)){selected["displayName"]=text.Text.Trim();Save();RefreshText();}}}
    async void Discover() {
        if(busy || sessionTask!=null)return;busy=true;state="discovering";RefreshText();
        try {
            string python=Path.Combine(root,".venv","Scripts","python.exe");if(!File.Exists(python)){Problem("missing");return;}
            string output=await Task.Run(()=>Common.Run(python,new[]{"-m","prototype.discover","--selectable"},root,30000));
            var data=Common.Json.Deserialize<Dictionary<string,object>>(output);var devices=Common.Objects(data["devices"]);if(devices.Length==0){Problem("noDevices");return;}
            using(var dialog=new Form {Text=Common.T("choose"),ClientSize=new Size(440,130),StartPosition=FormStartPosition.CenterParent,Icon=Common.Icon()}) {
                var list=new ComboBox {DropDownStyle=ComboBoxStyle.DropDownList,Location=new Point(15,20),Width=410};foreach(var device in devices){var row=(Dictionary<string,object>)device;list.Items.Add(row["name"]+" ("+row["model"]+")");}list.SelectedIndex=0;
                var save=new Button {Text=Common.T("save"),DialogResult=DialogResult.OK,Location=new Point(310,75)};dialog.Controls.AddRange(new Control[]{list,save});dialog.AcceptButton=save;
                if(dialog.ShowDialog(home)==DialogResult.OK){var row=(Dictionary<string,object>)devices[list.SelectedIndex];string id=Convert.ToString(row["id"]);Guid.Parse(id);string name=selected!=null && Convert.ToString(selected["id"])==id?Name():Convert.ToString(row["name"]);selected=new Dictionary<string,object>{{"id",id},{"name",row["name"]},{"model",row["model"]},{"displayName",name},{"lowLatency",profile>0},{"aggressiveLatency",profile==2}};Save();failed=false;}
            }
        }catch(Exception e){Problem("discoveryFailed",e);}finally{busy=false;state="disconnected";RefreshText();}
    }
    void Connect() {
        if(busy||sessionTask!=null||selected==null||failed)return;
        if(!File.Exists(Path.Combine(root,".venv","Scripts","python.exe"))||!File.Exists(Path.Combine(root,"artifacts","castaggregator-device.dll"))){Problem("missing");return;}
        if(!new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)) {
            try{Process.Start(new ProcessStartInfo(Application.ExecutablePath,"--connect"){UseShellExecute=true,Verb="runas"});exiting=true;ExitThread();}
            catch(Exception e){Problem("adminRequired",e);}return;
        }
        Guid.Parse(Convert.ToString(selected["id"]));
        session=Path.Combine(root,"artifacts","session-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(session);state="connecting";
        string id=Convert.ToString(selected["id"]),name=Name();int latency=profile;
        sessionTask=Task.Run(()=>Session(id,name,latency));RefreshText();
    }
    public void ConnectNow() {Connect();}
    public void BeginIntegration(string report) {if(selected==null)throw new InvalidOperationException("Integration requires an already selected receiver");integrationReport=report;integrationDeadline=DateTime.UtcNow.AddSeconds(150);Connect();}
    void Session(string id,string name,int latency) {
        string python=Path.Combine(root,".venv","Scripts","python.exe"),baseline=Path.Combine(session,"monitor-cast-baseline.json"),log=Path.Combine(session,"monitor-cast.log"),target=null;
        NativeSoftwareDisplay display=null;var errors=new List<string>();bool restored=false,closed=false;Exception failure=null;
        Action<string[]> run=args=>Common.Run(python,args,root,90000000,log);
        try {
            using(var query=new ManagementObjectSearcher("SELECT HardwareID FROM Win32_PnPEntity"))foreach(ManagementObject row in query.Get()){using(row){var ids=row["HardwareID"] as string[];if(ids!=null&&ids.Any(h=>String.Equals(h,"MttVDD",StringComparison.OrdinalIgnoreCase)||String.Equals(h,@"Root\MttVDD",StringComparison.OrdinalIgnoreCase)))throw new InvalidOperationException("Existing VDD device; refusing concurrent session");}}
            var config=new System.Xml.XmlDocument();config.Load(@"C:\VirtualDisplayDriver\vdd_settings.xml");if(config.SelectSingleNode("//monitors/count").InnerText!="1"||config.SelectSingleNode("//resolution/width").InnerText!="1280"||config.SelectSingleNode("//resolution/height").InnerText!="720"||config.SelectSingleNode("//resolution/refresh_rate").InnerText!="60"||config.SelectSingleNode("//options/HardwareCursor").InnerText!="false")throw new InvalidDataException("Unexpected driver configuration");
            run(new[]{"-m","prototype.display_session","snapshot",baseline});display=new NativeSoftwareDisplay(Path.Combine(root,"artifacts","castaggregator-device.dll"));Thread.Sleep(3000);
            run(new[]{"-m","prototype.display_session","extend",baseline,"--layout-file",Path.Combine(root,"artifacts","display-layout.json"),"--display-id",id});
            string active=Path.Combine(session,"monitor-cast-active.json");run(new[]{"-m","prototype.display_session","snapshot",active});var data=Common.Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(active));var targets=Common.Objects(data["topology"]).Cast<Dictionary<string,object>>().Where(r=>Convert.ToString(r["target_path"]).Contains("#MTT1337#")).ToArray();if(targets.Length!=1)throw new InvalidOperationException("Cannot attribute virtual target");target=Convert.ToString(targets[0]["target_path"]);
            var args=new List<string>{"-u","-m","prototype.cast","--capture-target",target,"--seconds","86400","--device-id",id,"--display-name",name,"--stop-file",Path.Combine(session,"stop"),"--sync-file",Path.Combine(session,"sync")};if(latency>0)args.Add("--low-latency");if(latency==2)args.Add("--aggressive-latency");run(args.ToArray());
        }catch(Exception e){failure=e;Log(e);}
        finally {
            if(target!=null){try{run(new[]{"-m","prototype.display_layout",Path.Combine(root,"artifacts","display-layout.json"),"--display-id",id,"--target",target});}catch(Exception e){errors.Add(e.ToString());}try{run(new[]{"-m","prototype.window_recovery",target});}catch(Exception e){errors.Add(e.ToString());}}
            if(display!=null){try{display.Dispose();closed=true;}catch(Exception e){errors.Add(e.ToString());}}
            try{if(File.Exists(baseline)){Thread.Sleep(3000);run(new[]{"-m","prototype.display_session","restore",baseline});restored=true;}}catch(Exception e){errors.Add(e.ToString());}
            Common.SaveJson(Path.Combine(session,"monitor-cast-result.json"),new{error=failure==null?null:failure.ToString(),cleanupErrors=errors,physicalRestored=restored,monitorClosed=closed});
            if(failure!=null||errors.Count!=0||!restored)throw new InvalidOperationException("Session failed or cleanup incomplete");
        }
    }
    void Stop() {if(sessionTask!=null){File.WriteAllText(Path.Combine(session,"stop"),"stop");state="disconnecting";RefreshText();}}
    void Tick() {
        try{
            if(sessionTask==null)return;
            if(sessionTask.IsCompleted){bool faulted=sessionTask.IsFaulted;Exception error=sessionTask.Exception;sessionTask=null;state=faulted?"error":"disconnected";failed=faulted;RefreshText();if(integrationReport!=null){Common.SaveJson(integrationReport,new{success=!faulted,cleanup=Common.Json.DeserializeObject(File.ReadAllText(Path.Combine(session,"monitor-cast-result.json")))});exiting=true;ExitThread();return;}if(faulted){exiting=false;Problem("cleanupFailed",error);}else if(exiting)ExitThread();}
            else if(state=="connecting"){string log=Path.Combine(session,"monitor-cast.log");if(File.Exists(log)&&File.ReadAllText(log).Contains("\"receiver_confirmed\": \"PLAYING\"")){state="connected";RefreshText();}}
            if(integrationReport!=null&&sessionTask!=null&&state!="disconnecting") {if(state=="connected"&&!connectedAt.HasValue)connectedAt=DateTime.UtcNow;if((connectedAt.HasValue&&DateTime.UtcNow-connectedAt.Value>TimeSpan.FromSeconds(8))||DateTime.UtcNow>integrationDeadline)Stop();}
        }catch(Exception e){Log(e);Problem("operationFailed");}
    }
    public static Form AboutForm() {
        var form=new Form {Text=Common.T("about"),ClientSize=new Size(520,310),StartPosition=FormStartPosition.CenterParent,Icon=Common.Icon(),Font=new Font("Segoe UI",10),BackColor=Color.FromArgb(10,20,18),ForeColor=Color.FromArgb(247,242,228)};
        var title=new Label {Text="CastBridge",Font=new Font("Segoe UI",23,FontStyle.Bold),Location=new Point(25,15),AutoSize=true};
        var body=new Label {Text=Common.T("credit")+Environment.NewLine+Environment.NewLine+Common.T("aboutText")+Environment.NewLine+Environment.NewLine+Common.T("version")+" 0.2.0-preview",Location=new Point(25,65),Size=new Size(470,135)};
        var website=new LinkLabel {Text=Common.T("website"),Location=new Point(25,210),AutoSize=true,LinkColor=Color.FromArgb(212,175,55)};website.LinkClicked+=delegate{Process.Start("https://matekraft.tech");};
        var source=new LinkLabel {Text=Common.T("source"),Location=new Point(25,240),AutoSize=true,LinkColor=Color.FromArgb(212,175,55)};source.LinkClicked+=delegate{Process.Start("https://github.com/akasha-code/CastBridge");};
        var close=new Button {Text=Common.T("close"),DialogResult=DialogResult.OK,Location=new Point(380,260),ForeColor=Color.FromArgb(10,20,18),BackColor=Color.FromArgb(247,242,228)};form.Controls.AddRange(new Control[]{title,body,website,source,close});return form;
    }
    public static void About(Form owner) {using(var dialog=AboutForm())dialog.ShowDialog(owner);}
    public void Smoke(string report) {
        var results=new List<object>();foreach(string code in new[]{"en","es","nb"}){languages.SelectedIndex=code=="en"?0:code=="es"?1:2;RefreshText();using(var dialog=AboutForm()){dialog.Show();Application.DoEvents();using(var image=new Bitmap(dialog.Width,dialog.Height)){dialog.DrawToBitmap(image,new Rectangle(0,0,image.Width,image.Height));image.Save(Path.ChangeExtension(report,"."+code+".png"));}dialog.Close();}results.Add(new{language=Common.Language,status=status.Text,connect=connect.Text,about=about.Text,credit=credit.Text,menuItems=menu.Items.Count});}Common.SaveJson(report,new{success=true,languages=results,powershellUsed=false});
    }
    protected override void Dispose(bool disposing){if(disposing){timer.Stop();timer.Dispose();tray.Visible=false;tray.Icon.Dispose();tray.Dispose();menu.Dispose();home.Dispose();}base.Dispose(disposing);}
}
public static class Program {
    [STAThread] public static int Main(string[] args) {
        try {
            Common.LoadLanguage(Path.Combine(Common.Root,"assets","languages.json"));Application.EnableVisualStyles();
            if(args.Length==2&&args[0]=="--smoke"){using(var test=new Desktop(true))test.Smoke(args[1]);return 0;}
            using(var mutex=new Mutex(false,"Local\\CastAggregatorTray")) {
                bool acquired=false;try{acquired=mutex.WaitOne(args.Contains("--connect")?10000:0);}catch(AbandonedMutexException){acquired=true;}
                if(!acquired){MessageBox.Show(Common.T("alreadyOpen"),"CastBridge");return 1;}
                try{using(var context=new Desktop(false)){if(args.Length==2&&args[0]=="--integration-session")context.BeginIntegration(args[1]);else if(args.Contains("--connect"))context.ConnectNow();Application.Run(context);}}finally{mutex.ReleaseMutex();}
            }return 0;
        }catch(Exception e){MessageBox.Show(e.Message,"CastBridge",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}
    }
}
}
