 ' This file is used only for testing.
 ' Enable block [Test_cron_2] in Cron configuration file cron.ini

 Dim FSO, WshShell,path,myFile                           ' Declare variables
 Set WshShell = CreateObject("WScript.Shell")            ' Create shell object
 Set FSO = CreateObject("Scripting.FileSystemObject")    ' Create file system object
 path = FSO.GetFile(Wscript.ScriptFullName).ParentFolder ' Get path to this file

  Const ForAppending = 8
 If fso.FileExists(path & "\test_cron_2_vbs_result.txt") Then
  Set myfile = fso.OpenTextFile(path & "\test_cron_2_vbs_result.txt", ForAppending, True)
 Else
  Set myFile = fso.CreateTextFile(path & "\test_cron_2_vbs_result.txt", True)
 End If
 myFile.WriteLine("Cron test 2 VBS Script")
 myFile.Close

 Set FSO = Nothing
 Set WshShell = Nothing 

