Option Explicit
Dim fso, sh, wd, marker, pidfile, cmd, fb, outlog, errlog

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")

wd = "c:\Users\soham\OneDrive\Desktop\Food Scanner"
marker = fso.BuildPath(wd, "vbs_marker.txt")
pidfile = fso.BuildPath(wd, "flutter_server.pid")
outlog = fso.BuildPath(wd, "flutter_web_stdout.log")
errlog = fso.BuildPath(wd, "flutter_web_stderr.log")
fb = "C:\flutter\bin\flutter.bat"

fso.CreateTextFile marker, True, True
With fso.OpenTextFile(marker, 2, True)
    .WriteLine "VBS_START " & Now
    .WriteLine "CWD " & wd
    .Close
End With

cmd = """" & fb & """ run -d web-server --web-port=8080 --web-hostname=0.0.0.0"

With sh.Environment("PROCESS")
    .Item("FLUTTER_WEB_STDOUT") = outlog
    .Item("FLUTTER_WEB_STDERR") = errlog
End With

Dim exec
On Error Resume Next
Set exec = sh.Exec("cmd.exe /c """"start"" ""FlutterWeb"" /MIN /D """ & wd & """ cmd.exe /c """"" & fb & """ run -d web-server --web-port=8080 --web-hostname=0.0.0.0 >> """ & outlog & """ 2>> """ & errlog & """""""")
If Err.Number <> 0 Then
    With fso.OpenTextFile(marker, 8, True)
        .WriteLine "EXEC_ERR " & Err.Number & " " & Err.Description
        .Close
    End With
    Err.Clear
End If
On Error GoTo 0

With fso.OpenTextFile(marker, 8, True)
    .WriteLine "LAUNCH_ISSUED " & Now
    .WriteLine "USING_ALT_METHOD"
    .Close
End With

sh.CurrentDirectory = wd
Dim ret
ret = sh.Run("cmd.exe /c start ""Flt"" /MIN cmd.exe /c """"" & fb & """ run -d web-server --web-port=8080 --web-hostname=0.0.0.0 >> """ & outlog & """ 2>> """ & errlog & """""", 0, False)

With fso.OpenTextFile(marker, 8, True)
    .WriteLine "RUN_RET " & ret
    .WriteLine "VBS_DONE " & Now
    .Close
End With

WScript.Quit 0
