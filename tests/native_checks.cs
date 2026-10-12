using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using CastBridge;
public static class NativeChecks {
    public static int Main(string[] args) {
        string source=args[0];Common.LoadLanguage(Path.Combine(source,"assets","languages.json"));
        foreach(string code in new[]{"en","es","nb"}){Common.Language=code;if(String.IsNullOrWhiteSpace(Common.T("driverHelp")))throw new Exception("Missing prerequisite guidance");}
        var parsed=Common.Json.Deserialize<Dictionary<string,object>>("{\"devices\":[{\"id\":\"test\"}],\"urls\":[{\"url\":\"https://example.test\"}]}");
        if(Common.Objects(parsed["devices"]).Length!=1 || Common.Objects(parsed["urls"]).Length!=1)throw new Exception("JSON array conversion failed");
        string[] input={"screen with spaces","screen \"quoted\"","path ending in \\","","-3.12"};
        var command=new List<string>{"-3.12","-c","import json,sys; print(json.dumps(sys.argv[1:]))"};command.AddRange(input);
        string output=Common.Run(Common.Find("py.exe"),command,Common.Root,10000);
        string[] actual=Common.Objects(Common.Json.DeserializeObject(output)).Select(Convert.ToString).ToArray();
        if(!input.SequenceEqual(actual))throw new Exception("Command-line argument round trip failed");
        if(Common.Quote("-3.12")!="-3.12")throw new Exception("Python launcher switch must stay unquoted");
        foreach(string relative in new[]{"..\\outside.txt",@"C:\Windows\outside.txt"}){bool refused=false;try{Common.Under(Path.Combine(source,"artifacts","test-root"),relative);}catch(InvalidDataException){refused=true;}if(!refused)throw new Exception("Unsafe archive path accepted");}
        string temporary=Path.Combine(source,"artifacts","locale-test-"+Guid.NewGuid().ToString("N"));string settings=Path.Combine(temporary,"artifacts","ui-settings.json");
        foreach(string code in new[]{"es","nb","en"}){Common.SaveJson(settings,new{language=code});Common.Language="en";Common.LoadSavedLanguage(temporary);if(Common.Language!=code)throw new Exception("Saved language was not restored");}
        Console.WriteLine("Native checks passed: language selection persistence, JSON arrays, process arguments and archive boundaries.");return 0;
    }
}
