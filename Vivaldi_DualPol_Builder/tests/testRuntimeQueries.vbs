Option Explicit
' Windows-only protocol fixtures. No HFSS CAD is created or validated here.
Dim fs, vStatusPath, vStage, vStageName, vCommand, vSaveDebug, vDebugPath
Dim oEditor, oProject, oDesign, oReport, oBoundary, oMaterials, folder, stream, runtime, values, number, text
Set fs = CreateObject("Scripting.FileSystemObject")
If WScript.Arguments.Count <> 1 Then
  WScript.Echo "Usage: cscript //nologo testRuntimeQueries.vbs <hfssVivaldiChecks.vbs>"
  WScript.Quit 2
End If
folder = fs.BuildPath(fs.GetSpecialFolder(2), fs.GetTempName())
fs.CreateFolder folder
vStatusPath = fs.BuildPath(folder, "status.txt")
vDebugPath = fs.BuildPath(folder, "CAD_DEBUG_INCOMPLETE.aedt")
vSaveDebug = False
Set stream = fs.CreateTextFile(vStatusPath, True, True): stream.Close
Set stream = CreateObject("ADODB.Stream")
stream.Type = 2: stream.Charset = "utf-8": stream.Open
stream.LoadFromFile WScript.Arguments(0)
runtime = stream.ReadText: stream.Close
ExecuteGlobal runtime
Set oEditor = New FakeEditor
Set oProject = New FakeProject
Stage "CHECK_02"

' Direct Sheets is independent of another group throwing error 450.
oEditor.Mode = "fail_lines"
values = QueryGroup("Sheets")
Assert HasName(values, "EquationSurface1"), "Direct Sheets query"
Err.Clear
On Error Resume Next
values = ObjectNames()
number = Err.Number
On Error GoTo 0
Assert number = 450, "Inventory must propagate group error 450"
Assert InStr(vCommand, "Lines") > 0, "Error must identify the failing group"

' Normalize empty/null/scalar arrays without Dictionary default properties.
oEditor.Mode = "normal"
values = ObjectNames()
Assert UBound(values) = 2, "Deduplicate names across all four groups"
Assert HasName(values, "Body"), "Solids must remain in inventory"
oEditor.Mode = "scalar"
values = QueryGroup("Sheets")
Assert HasName(values, "EquationSurface1"), "Scalar string return"
oEditor.Mode = "empty"
values = QueryGroup("Sheets")
Assert Not HasName(values, "EquationSurface1"), "Empty is successful absence"
oEditor.Mode = "null"
values = QueryGroup("Sheets")
Assert Not HasName(values, "EquationSurface1"), "Null empty group"
oEditor.Mode = "invalid"
Err.Clear
On Error Resume Next
values = QueryGroup("Sheets")
number = Err.Number
On Error GoTo 0
Assert number = 513, "Invalid return type must not become absence"

' A query exception is different from a false assertion and must remain FAILED.
oEditor.Mode = "fail_sheets"
Err.Clear
On Error Resume Next
values = QueryGroup("Sheets")
number = Err.Number
On Error GoTo 0
Assert number = 450, "Direct Sheets must propagate error 450"
OperationFailed "Query Sheets", "QUERY", number, "FakeEditor", "Injected error"
Assert oProject.Saves = 0, "Debug save must be opt-in"

' Debug snapshot is separate, never overwrites and never emits VERIFIED.
vSaveDebug = True
OperationFailed "Query Sheets", "QUERY", 450, "FakeEditor", "Injected error"
Assert oProject.Saves = 1, "Opt-in saves exactly one incomplete snapshot"
TrySaveDebug
Assert oProject.Saves = 1, "Never overwrite an existing debug snapshot"
Set stream = fs.OpenTextFile(vStatusPath, 1, False, -1)
text = stream.ReadAll: stream.Close
Assert InStr(text, "QUERY|CHECK_02|oEditor.GetObjectsInGroup(""Lines"")|ERROR|450|") > 0, "Per-group method/error log"
Assert InStr(text, "ERROR|CHECK_02|") > 0, "Stage and operation error log"
Assert InStr(text, "DEBUG|SAVED_INCOMPLETE|") > 0, "Debug must be labelled incomplete"
Assert InStr(text, "STATE|FAILED") > 0 And InStr(text, "VERIFIED|1") = 0, "No completed antenna from fixtures"
' Material defaults are valid only within a successfully read named definition.
values = Array("NAME:aluminum","permeability:=","1.000021","conductivity:=","38000000")
Assert DefinitionMatchesData(values,1,1.000021,38000000,0), "Omitted scalar defaults in source aluminum"
Assert Not DefinitionMatchesData(values,2,1.000021,38000000,0), "Missing epsilon cannot match nondefault"
Assert Not DefinitionMatchesData(values,1,1,38000000,0), "Explicit mismatched mu"
Assert Not DefinitionMatchesData(Empty,1,1,0,0), "Failed/empty GetData is not a definition"
Assert Not DefinitionMatchesData(Array(),1,1,0,0), "Empty array is not a definition"
Assert Not DefinitionMatchesData(Array("invalid"),1,1,0,0), "Named definition required"
values = Array("NAME:bad","conductivity:=","not-a-number")
Assert Not DefinitionMatchesData(values,1,1,0,0), "Explicit invalid property never defaults"
values = Array("NAME:custom","permittivity:=","2","permeability:=","1.01","conductivity:=","41234567.89","dielectric_loss_tangent:=","0.003")
Assert DefinitionMatchesData(values,2,1.01,41234567.89,0.003), "Readback all custom scalar properties"
WScript.Echo "PASS: runtime query/material protocol fixtures only; HFSS CAD remains PENDING. Log: " & vStatusPath

Sub Assert(condition, message)
  If Not condition Then
    WScript.Echo "FAIL: " & message
    WScript.Quit 1
  End If
End Sub

Class FakeEditor
  Public Mode
  Public Function GetObjectsInGroup(groupName)
    If (Mode = "fail_lines" And groupName = "Lines") Or (Mode = "fail_sheets" And groupName = "Sheets") Then
      Err.Raise 450, "FakeEditor.GetObjectsInGroup", "Injected 450"
    End If
    Select Case groupName
      Case "Sheets"
        Select Case Mode
          Case "scalar": GetObjectsInGroup = "EquationSurface1"
          Case "empty": GetObjectsInGroup = Empty
          Case "null": GetObjectsInGroup = Null
          Case "invalid": GetObjectsInGroup = 123
          Case Else: GetObjectsInGroup = Array("EquationSurface1", "EquationSurface2")
        End Select
      Case "Solids": GetObjectsInGroup = Array("Body", "EquationSurface1")
      Case "Lines": GetObjectsInGroup = Array()
      Case "Unclassified": GetObjectsInGroup = Empty
      Case Else: Err.Raise 513, "FakeEditor", "Unexpected group"
    End Select
  End Function
End Class

Class FakeProject
  Public Saves
  Private Sub Class_Initialize()
    Saves = 0
  End Sub
  Public Sub SaveAs(path, overwrite)
    Dim file
    Assert Not overwrite, "Debug overwrite flag"
    Set file = fs.CreateTextFile(path, False, False)
    file.WriteLine "PROTOCOL FIXTURE ONLY - NOT AN AEDT PROJECT"
    file.Close
    Saves = Saves + 1
  End Sub
End Class
