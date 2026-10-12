using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;
namespace CastBridge {
public sealed class Installer : Form {
    readonly ComboBox languages=Common.Languages();readonly ListView list=new ListView();readonly TextBox help=new TextBox(),destination=new TextBox();
    readonly Label status=new Label(),credit=new Label(),folderLabel=new Label(),unsigned=new Label();readonly Button check=new Button(),download=new Button(),install=new Button(),browse=new Button(),template=new Button(),about=new Button();
    List<Requirement> requirements;bool busy,complete;
    public Installer(bool test=false) {
        Text="CastBridge — MateKraft";ClientSize=new Size(820,690);MinimumSize=new Size(836,729);StartPosition=FormStartPosition.CenterScreen;Icon=Common.Icon();Font=new Font("Segoe UI",10);BackColor=Color.FromArgb(10,20,18);ForeColor=Color.FromArgb(247,242,228);
        var title=new Label {Text="CastBridge",Font=new Font("Segoe UI",24,FontStyle.Bold),Location=new Point(20,15),AutoSize=true};credit.Location=new Point(22,63);credit.Size=new Size(500,25);
        languages.Location=new Point(590,30);languages.SelectedIndexChanged+=delegate{Common.SetLanguage(languages.SelectedIndex);RefreshText();};
        folderLabel.Location=new Point(20,103);folderLabel.Size=new Size(250,25);destination.Location=new Point(20,132);destination.Size=new Size(650,27);destination.Text=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Programs","CastBridge");destination.TextChanged+=delegate{UpdateActions();};
        browse.Location=new Point(685,128);browse.Size=new Size(115,32);browse.Click+=delegate{using(var dialog=new FolderBrowserDialog()){dialog.SelectedPath=destination.Text;if(dialog.ShowDialog(this)==DialogResult.OK)destination.Text=dialog.SelectedPath;}};
        list.Location=new Point(20,180);list.Size=new Size(780,205);list.View=View.Details;list.FullRowSelect=true;list.MultiSelect=false;list.Columns.Add("",650);list.Columns.Add("",100);list.SelectedIndexChanged+=delegate{UpdateActions();};
        help.Location=new Point(20,395);help.Size=new Size(780,115);help.Multiline=true;help.ReadOnly=true;help.ScrollBars=ScrollBars.Vertical;
        Button[] buttons={check,download,template,about,install};int[] widths={155,145,205,120,115};int x=20;for(int i=0;i<buttons.Length;i++){buttons[i].Location=new Point(x,525);buttons[i].Size=new Size(widths[i],45);x+=widths[i]+8;}
        status.Location=new Point(20,585);status.Size=new Size(780,50);unsigned.Location=new Point(20,648);unsigned.Size=new Size(780,27);unsigned.ForeColor=Color.FromArgb(212,175,55);credit.ForeColor=Color.FromArgb(212,175,55);foreach(var button in buttons){button.ForeColor=Color.FromArgb(10,20,18);button.BackColor=Color.FromArgb(247,242,228);}
        install.Enabled=false;download.Enabled=false;check.Click+=async delegate{await Check();};download.Click+=delegate{if(list.SelectedItems.Count>0)Process.Start(((Requirement)list.SelectedItems[0].Tag).Url);};template.Click+=delegate{SaveTemplate();};about.Click+=delegate{Desktop.About(this);};install.Click+=async delegate{if(complete){Process.Start(Path.Combine(destination.Text,"CastBridge.exe"));Close();}else await Install();};
        Controls.AddRange(new Control[]{title,credit,languages,folderLabel,destination,browse,list,help,check,download,template,about,install,status,unsigned});
        FormClosing+=delegate(object sender,FormClosingEventArgs e){if(busy){e.Cancel=true;MessageBox.Show(this,Common.T("waiting"),"CastBridge");}};
        RefreshText();if(!test)Shown+=async delegate{await Check();};
    }
    void RefreshText() {Text=Common.T("installTitle")+" — MateKraft";credit.Text=Common.T("credit");folderLabel.Text=Common.T("destination");browse.Text=Common.T("browse");check.Text=Common.T("check");download.Text=Common.T("download");template.Text=Common.T("template");about.Text=Common.T("about");install.Text=Common.T(complete?"launch":"install");unsigned.Text=Common.T("unsigned");list.Columns[0].Text=Common.T("requirement");list.Columns[1].Text=Common.T("status");Render();if(!busy)status.Text=Common.T(complete?"complete":requirements!=null && requirements.All(r=>r.Ready)?"installReady":"blocked");}
    void Render() {string selected=list.SelectedItems.Count>0?((Requirement)list.SelectedItems[0].Tag).Key:null;list.Items.Clear();if(requirements!=null)foreach(var requirement in requirements){var row=new ListViewItem(Common.T(requirement.Key+"Name"));row.Tag=requirement;row.SubItems.Add(Common.T(requirement.Ready?"ready":"missingState"));list.Items.Add(row);if(requirement.Key==selected)row.Selected=true;}if(list.SelectedItems.Count==0&&requirements!=null){foreach(ListViewItem row in list.Items)if(!((Requirement)row.Tag).Ready){row.Selected=true;break;}}UpdateActions();}
    void UpdateActions() {
        bool ready=requirements!=null&&requirements.All(r=>r.Ready);
        var selected=list.SelectedItems.Count>0?(Requirement)list.SelectedItems[0].Tag:null;
        check.Visible=!ready&&!complete;check.Enabled=!busy&&!complete;
        download.Visible=!complete&&selected!=null&&!selected.Ready&&selected.Url!="";download.Enabled=!busy;
        if(selected!=null&&selected.Url!="")download.Text=Common.T(selected.Key+"Download");
        template.Visible=!complete&&selected!=null&&!selected.Ready&&selected.Key=="config";template.Enabled=!busy;
        install.Enabled=!busy&&(complete||(ready&&!String.IsNullOrWhiteSpace(destination.Text)));
        help.Text=complete?Common.T("complete"):ready?Common.T("installReady"):selected==null?Common.T("selectHelp"):Common.T(selected.Key+"Help");
        int x=20;foreach(var button in new[]{check,download,template,about})if(button.Visible){button.Location=new Point(x,525);button.Width=button==about?120:220;x+=button.Width+8;}install.Location=new Point(685,525);
    }
    void Enable(bool enabled) {languages.Enabled=enabled;browse.Enabled=enabled;destination.Enabled=enabled&&!complete;about.Enabled=enabled;UpdateActions();}
    async Task Check() {
        if(busy)return;busy=true;Enable(false);install.Enabled=false;status.Text=Common.T("checking");
        try{requirements=await Task.Run(()=>Requirements.Check(Common.Root));Render();status.Text=Common.T(requirements.All(r=>r.Ready)?"installReady":"blocked");install.Enabled=requirements.All(r=>r.Ready);}
        catch(Exception e){status.Text=Common.T("operationFailed");MessageBox.Show(this,e.Message,"CastBridge");}
        finally{busy=false;Enable(true);}
    }
    void SaveTemplate() {using(var dialog=new SaveFileDialog {FileName="vdd_settings.xml",Filter="XML|*.xml",OverwritePrompt=true}){if(dialog.ShowDialog(this)!=DialogResult.OK)return;using(var input=Assembly.GetExecutingAssembly().GetManifestResourceStream("driver-template.xml"))using(var output=File.Create(dialog.FileName))input.CopyTo(output);}}
    async Task Install() {
        if(busy)return;busy=true;Enable(false);install.Enabled=false;status.Text=Common.T("checking");string target=null;
        try {
            target=Common.ValidateDestination(destination.Text);
            requirements=await Task.Run(()=>Requirements.Check(Common.Root));Render();if(!requirements.All(r=>r.Ready)){status.Text=Common.T("blocked");return;}
            if(Directory.Exists(target)&&Directory.EnumerateFileSystemEntries(target).Any()&&!File.Exists(Path.Combine(target,"castbridge-install.json")))throw new InvalidOperationException(Common.T("folderInvalid"));
            if(File.Exists(Path.Combine(target,"castbridge-install.json"))){var previous=Common.Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(Path.Combine(target,"castbridge-install.json")));if(Convert.ToString(previous["product"])!="CastBridge")throw new InvalidDataException("Unexpected installation manifest");}
            if(Directory.Exists(target)&&(File.GetAttributes(target)&FileAttributes.ReparsePoint)!=0)throw new InvalidDataException("Installation folder must not be a junction or symbolic link");
            status.Text=Common.T("installing");string selectedLanguage=Common.Language;
            await Task.Run(()=>InstallFiles(target,selectedLanguage));complete=true;install.Enabled=true;status.Text=Common.T("complete");install.Text=Common.T("launch");
        }catch(Exception e){status.Text=Common.T("installFailed");if(target!=null&&File.Exists(Path.Combine(target,"castbridge-install.json")))File.AppendAllText(Path.Combine(target,"install-error.log"),e+Environment.NewLine);MessageBox.Show(this,Common.T("installFailed"),"CastBridge",MessageBoxButtons.OK,MessageBoxIcon.Error);}
        finally{busy=false;Enable(true);}
    }
    public static void InstallFiles(string target,string language,bool register=true) {
        target=Common.ValidateDestination(target);Common.EnsureNoLinks(target);
        Directory.CreateDirectory(target);var files=new List<string>();string manifest=Path.Combine(target,"castbridge-install.json");
        if(File.Exists(manifest)){var previous=Common.Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(manifest));if(Convert.ToString(previous["product"])!="CastBridge")throw new InvalidDataException("Unexpected installation manifest");foreach(object file in Common.Objects(previous["files"])){string name=Convert.ToString(file);Common.Under(target,name);files.Add(name);}}
        using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))using(var zip=new ZipArchive(stream,ZipArchiveMode.Read)) {
            // Validate every archive path before extracting any application file.
            foreach(var entry in zip.Entries){Common.Under(target,entry.FullName);if(entry.FullName.EndsWith("/"))continue;if(!files.Contains(entry.FullName,StringComparer.OrdinalIgnoreCase))files.Add(entry.FullName);}
            Common.SaveJson(manifest,new{product="CastBridge",version=Common.Version,complete=false,files=files});
            foreach(var entry in zip.Entries){if(entry.FullName.EndsWith("/"))continue;string output=Common.Under(target,entry.FullName);Directory.CreateDirectory(Path.GetDirectoryName(output));using(var input=entry.Open())using(var file=File.Create(output))input.CopyTo(file);}
        }
        string py=Common.Find("py.exe")??Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"py.exe");string python=Path.Combine(target,".venv","Scripts","python.exe"),log=Path.Combine(target,"install.log");
        if(!File.Exists(python))Common.Run(py,new[]{"-3.12","-m","venv",Path.Combine(target,".venv")},target,120000,log);
        Common.Run(python,new[]{"-m","pip","install","--disable-pip-version-check","-r",Path.Combine(target,"requirements-prototype.lock.txt")},target,900000,log);
        Common.Run(python,new[]{"-m","pip","check"},target,120000,log);
        Common.SaveJson(Path.Combine(target,"artifacts","ui-settings.json"),new{language=language});
        File.Copy(Application.ExecutablePath,Path.Combine(target,"Uninstall.exe"),true);files.Add("Uninstall.exe");
        if(register) {
            Common.Shortcut(Path.Combine(target,"CastBridge.exe"),Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs),"MateKraft","CastBridge.lnk"));
            using(var key=Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\MateKraft.CastBridge")){key.SetValue("DisplayName","CastBridge");key.SetValue("DisplayVersion",Common.Version);key.SetValue("Publisher","MateKraft");key.SetValue("URLInfoAbout","https://matekraft.tech");key.SetValue("InstallLocation",target);key.SetValue("DisplayIcon",Path.Combine(target,"CastBridge.exe"));key.SetValue("UninstallString",Common.Quote(Path.Combine(target,"Uninstall.exe"))+" --uninstall");}
        }
        Common.SaveJson(manifest,new{product="CastBridge",version=Common.Version,complete=true,files=files});
    }
    void VerifyActions() {
        var saved=requirements;
        try {
            requirements=new List<Requirement>{new Requirement("python",false,"https://www.python.org/downloads/windows/")};Render();Application.DoEvents();
            if(install.Enabled||!check.Visible||!download.Visible||template.Visible||download.Text!=Common.T("pythonDownload"))throw new InvalidOperationException("Missing Python action state failed");
            requirements=new List<Requirement>{new Requirement("config",false)};Render();Application.DoEvents();
            if(install.Enabled||!check.Visible||download.Visible||!template.Visible)throw new InvalidOperationException("Missing configuration action state failed");
            requirements=new List<Requirement>{new Requirement("config",true)};Render();Application.DoEvents();
            if(!install.Enabled||check.Visible||download.Visible||template.Visible)throw new InvalidOperationException("Ready installation action state failed");
        }finally{requirements=saved;Render();}
    }
    public void Smoke(string report) {requirements=Requirements.Check(Common.Root);install.Enabled=requirements.All(r=>r.Ready);var results=new List<object>();foreach(string code in new[]{"en","es","nb"}){languages.SelectedIndex=code=="en"?0:code=="es"?1:2;RefreshText();VerifyActions();using(var image=new Bitmap(Width,Height)){DrawToBitmap(image,new Rectangle(0,0,Width,Height));image.Save(Path.ChangeExtension(report,"."+code+".png"));}results.Add(new{language=Common.Language,title=Text,credit=credit.Text,button=install.Text,installEnabled=install.Enabled,checks=list.Items.Count,actionStatesVerified=true});}Common.SaveJson(report,new{success=true,languages=results,powershellUsed=false});}
}
public static class SetupProgram {
    static void Uninstall(string root,bool interactive=true) {
        root=Common.ValidateDestination(root);Common.LoadSavedLanguage(root);
        if(Common.Active())throw new InvalidOperationException(Common.T("closedHelp"));
        string manifest=Common.Under(root,"castbridge-install.json");var data=Common.Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(manifest));if(Convert.ToString(data["product"])!="CastBridge")throw new InvalidDataException("Unexpected installation manifest");
        if(interactive && MessageBox.Show(Common.T("uninstallConfirm"),"CastBridge",MessageBoxButtons.YesNo,MessageBoxIcon.Question)!=DialogResult.Yes)return;
        var paths=Common.Objects(data["files"]).Select(item=>Common.Under(root,Convert.ToString(item))).ToArray();string venv=Common.Under(root,".venv");Common.EnsureNoLinks(root);
        foreach(string path in paths)if(File.Exists(path))File.Delete(path);if(Directory.Exists(venv))Directory.Delete(venv,true);File.Delete(manifest);
        bool registered=false;using(var key=Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\MateKraft.CastBridge")){registered=key!=null&&String.Equals(Convert.ToString(key.GetValue("InstallLocation")),root,StringComparison.OrdinalIgnoreCase);}
        if(registered){string shortcut=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs),"MateKraft","CastBridge.lnk");if(File.Exists(shortcut))File.Delete(shortcut);Registry.CurrentUser.DeleteSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\MateKraft.CastBridge",false);}
        Common.SaveJson(manifest,new{product="CastBridge",uninstalled=true,complete=false,files=new string[0]});
        // User preferences and diagnostic logs are intentionally retained.
        if(interactive)MessageBox.Show(Common.T("uninstalled"),"CastBridge");
    }
    static string ValidationTarget(string value) {
        string target=Common.ValidateDestination(value);string prefix=Common.Root+Path.DirectorySeparatorChar+"release-validation-";
        if(!target.StartsWith(prefix,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("Validation target must be an isolated release-validation directory beside this test installer");
        Guid token;if(!Guid.TryParseExact(target.Substring(prefix.Length),"N",out token))throw new InvalidDataException("Invalid validation directory token");
        string marker=Common.Under(target,".castbridge-validation.json");var data=Common.Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(marker));if(Convert.ToString(data["token"])!=token.ToString("N"))throw new InvalidDataException("Validation marker mismatch");
        using(var key=Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\MateKraft.CastBridge")){if(key!=null&&!String.Equals(Convert.ToString(key.GetValue("InstallLocation")),target,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Another registered installation exists; refusing to alter it");}
        return target;
    }
    [STAThread] public static int Main(string[] args) {
        try {
            Common.LoadLanguage("");Application.EnableVisualStyles();
            if(args.Length==1&&args[0]=="--uninstall"){string copy=Path.Combine(Path.GetTempPath(),"CastBridge-Uninstall-"+Guid.NewGuid().ToString("N")+".exe");File.Copy(Application.ExecutablePath,copy);Process.Start(copy,"--remove "+Common.Quote(Common.Root));return 0;}
            if(args.Length==2&&args[0]=="--remove"){Uninstall(Path.GetFullPath(args[1]));return 0;}
            if(args.Length==2&&args[0]=="--check"){var result=Requirements.Check(Common.Root);Common.SaveJson(args[1],new{ready=result.All(r=>r.Ready),checks=result,diagnostics=Requirements.Diagnostics});return 0;}
            if(args.Length==3&&(args[0]=="--upgrade-test"||args[0]=="--uninstall-test")) {
                try{string target=ValidationTarget(args[1]);if(args[0]=="--upgrade-test"){var result=Requirements.Check(Common.Root);if(!result.All(r=>r.Ready)){Common.SaveJson(args[2],new{success=false,blocked=true,checks=result});return 2;}Common.LoadSavedLanguage(target);Installer.InstallFiles(target,Common.Language);}
                    else Uninstall(target,false);Common.SaveJson(args[2],new{success=true,operation=args[0],version=Common.Version});return 0;}
                catch(Exception e){Common.SaveJson(args[2],new{success=false,error=e.ToString()});return 1;}
            }
            if(args.Length==3&&args[0]=="--install-test") {
                string target=Path.GetFullPath(args[1]);if(Directory.Exists(target))throw new InvalidOperationException("Integration test requires a new destination");
                try{var result=Requirements.Check(Common.Root);if(!result.All(r=>r.Ready)){Common.SaveJson(args[2],new{installed=false,blocked=true,checks=result});return 2;}Installer.InstallFiles(target,"en",false);Common.SaveJson(args[2],new{installed=true,blocked=false,powershellUsed=false,registered=false});return 0;}
                catch(Exception e){Common.SaveJson(args[2],new{installed=false,error=e.ToString()});return 1;}
            }
            if(args.Length==2&&args[0]=="--smoke"){try{using(var test=new Installer(true)){test.Show();test.Smoke(args[1]);}return 0;}catch(Exception e){Common.SaveJson(args[1],new{success=false,error=e.ToString()});return 1;}}
            Application.Run(new Installer());return 0;
        }catch(Exception e){MessageBox.Show(e.Message,"CastBridge",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}
    }
}
}
