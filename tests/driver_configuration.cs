using System;
using System.IO;
using System.Linq;
using System.Text;
using CastBridge;
public static class DriverConfigurationChecks {
    public static int Main(string[] args) {
        Common.LoadLanguage(Path.Combine(args[0],"assets","languages.json"));
        string directory=Path.Combine(args[0],"artifacts","config-validation-"+Guid.NewGuid().ToString("N"));
        byte[] content=File.ReadAllBytes(Path.Combine(args[0],"driver","vdd_settings.xml"));
        if(!DriverConfiguration.Template().SequenceEqual(content))throw new Exception("Embedded configuration differs from the reviewed template");
        if(!DriverConfiguration.Apply(directory,content))throw new Exception("Fresh configuration was not applied");
        if(DriverConfiguration.Apply(directory,content))throw new Exception("Matching configuration was rewritten");
        string file=Path.Combine(directory,"vdd_settings.xml");byte[] previous=Encoding.UTF8.GetBytes("Previous configuration retained exactly");File.WriteAllBytes(file,previous);
        if(!DriverConfiguration.Apply(directory,content))throw new Exception("Replacement was not applied");
        string backup=Directory.GetFiles(directory,"*.bak").Single();
        if(!File.ReadAllBytes(backup).SequenceEqual(previous)||!File.ReadAllBytes(file).SequenceEqual(content))throw new Exception("Backup or configuration differs");
        if(Directory.GetFiles(directory,"*.tmp").Length!=0)throw new Exception("Temporary file retained");
        Console.WriteLine("Driver configuration checks passed: fresh write, matching-file preservation, exact backup and atomic replacement.");return 0;
    }
}
