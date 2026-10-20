' Các hàm runtime chỉ chạy trong HFSS; không coi sinh script là kiểm chứng CAD.
Sub WriteStatus(text)
  Dim stream
  Set stream = fs.OpenTextFile(vStatusPath, 8, True, -1)
  If Left(text,6) = "CHECK|" Then text = text & " (" & CStr(Now) & ")"
  stream.WriteLine text
  stream.Close
End Sub
Sub Stage(name)
  vStage = name
  WriteStatus "CHECK|" & name & "|PENDING|PENDING|Đang thực hiện"
End Sub
Sub DebugPause(name)
  If Not vDebug Then Exit Sub
  If MsgBox("Kiểm tra hình học tại " & name & ". OK: tiếp tục; Cancel: dừng.", 1, "Vivaldi — kiểm tra từng bước") = 2 Then
    Err.Raise 513, "Vivaldi", "Người dùng dừng tại " & name
  End If
End Sub
Sub Fail(message)
  Dim rollbackError, rollbackDescription
  WriteStatus "CHECK|" & vStage & "|FAIL|PENDING|" & CleanLine(message)
  If vRollbackEnabled Then
    vRollbackEnabled = False
    Err.Clear
    On Error Resume Next
    RestorePrevious
    rollbackError = Err.Number
    rollbackDescription = Err.Description
    On Error GoTo 0
    If rollbackError = 0 Then
      WriteStatus "ROLLBACK|PASS|Đã phục hồi và kiểm tra lại; lần cập nhật vẫn thất bại"
      WriteStatus "STATE|FAILED_ROLLED_BACK"
      Exit Sub
    End If
    WriteStatus "ROLLBACK|FAIL|" & CleanLine(rollbackDescription)
  End If
  WriteStatus "STATE|FAILED"
End Sub
Function CleanLine(value)
  CleanLine = Replace(Replace(Replace(CStr(value), vbCr, " "), vbLf, " "), "|", "/")
End Function
Function ObjectNames()
  Dim names, groupName, objects, objectName
  Set names = CreateObject("Scripting.Dictionary")
  names.CompareMode = 1
  For Each groupName In Array("Solids", "Sheets", "Lines", "Unclassified")
    objects = oEditor.GetObjectsInGroup(CStr(groupName))
    If IsArray(objects) Then
      For Each objectName In objects
        names(CStr(objectName)) = True
      Next
    ElseIf Not IsEmpty(objects) Then
      If Not IsNull(objects) Then
        If CStr(objects) <> "" Then names(CStr(objects)) = True
      End If
    End If
  Next
  ObjectNames = names.Keys
End Function
Function HasName(values, target)
  Dim name
  HasName = False
  If Not IsArray(values) Then Exit Function
  For Each name In values
    If StrComp(CStr(name), CStr(target), 1) = 0 Then HasName = True
  Next
End Function
Function ExactNames(expected)
  Dim actual, name, n, m
  actual = ObjectNames(): n = 0: m = 0: ExactNames = False
  For Each name In actual
    n = n + 1
    If Not HasName(expected, name) Then Exit Function
  Next
  For Each name In expected
    m = m + 1
    If Not HasName(actual, name) Then Exit Function
  Next
  ExactNames = (n = m)
End Function
Sub CloneNamed(sourceName, desiredName, operation)
  Dim beforeNames, afterNames, name, newName, count
  beforeNames = ObjectNames()
  If Not HasName(beforeNames, sourceName) Or HasName(beforeNames, desiredName) Then Err.Raise 513, "CloneNamed", "Tên nguồn/đích clone không hợp lệ"
  If operation = "copy" Then
    oEditor.Copy Array("NAME:Selections", "Selections:=", sourceName)
    oEditor.Paste
  ElseIf operation = "rotate" Then
    oEditor.DuplicateAroundAxis Array("NAME:Selections", "Selections:=", sourceName, "NewPartsModelFlag:=", "Model"), Array("NAME:DuplicateAroundAxisParameters", "CreateNewObjects:=", True, "WhichAxis:=", "Z", "AngleStr:=", "-90deg", "NumClones:=", "2"), Array("NAME:Options", "DuplicateAssignments:=", False)
  Else
    Err.Raise 513, "CloneNamed", "Kiểu clone không hợp lệ"
  End If
  afterNames = ObjectNames(): count = 0
  For Each name In afterNames
    If Not HasName(beforeNames, name) Then newName = name: count = count + 1
  Next
  If count <> 1 Then Err.Raise 513, "CloneNamed", "Clone phải tạo đúng một đối tượng"
  If StrComp(CStr(newName), desiredName, 0) <> 0 Then
    oEditor.ChangeProperty Array("NAME:AllTabs", Array("NAME:Geometry3DAttributeTab", Array("NAME:PropServers", newName), Array("NAME:ChangedProps", Array("NAME:Name", "Value:=", desiredName))))
  End If
  If Not HasName(ObjectNames(), desiredName) Then Err.Raise 513, "CloneNamed", "Không đọc lại được clone"
End Sub
Function PointMatches(name, xyz, expected)
  Dim bodies
  bodies = oEditor.GetBodyNamesByPosition(Array("NAME:Parameters", "XPosition:=", CStr(xyz(0)) & "mm", "YPosition:=", CStr(xyz(1)) & "mm", "ZPosition:=", CStr(xyz(2)) & "mm"))
  PointMatches = (HasName(bodies, name) = expected)
End Function
Function BodyBoundsMatch(name, expected)
  Dim ids, id, xyz, bounds, i
  BodyBoundsMatch = False
  ids = oEditor.GetVertexIDsFromObject(name)
  If Not IsArray(ids) Then Exit Function
  bounds = Array(1E+100, -1E+100, 1E+100, -1E+100, 1E+100, -1E+100)
  For Each id In ids
    xyz = oEditor.GetVertexPosition(id)
    For i = 0 To 2
      If CDbl(xyz(i)) < bounds(2*i) Then bounds(2*i) = CDbl(xyz(i))
      If CDbl(xyz(i)) > bounds(2*i+1) Then bounds(2*i+1) = CDbl(xyz(i))
    Next
  Next
  For i = 0 To 5
    If Abs(bounds(i)-CDbl(expected(i))) > 0.00001 Then Exit Function
  Next
  BodyBoundsMatch = True
End Function
Function CircleMatches(name, center, radius)
  Dim faces, face, count, xyz, area
  CircleMatches = False: count = 0
  faces = oEditor.GetFaceIDs(name)
  For Each face In faces
    count = count + 1
    area = CDbl(oEditor.GetFaceArea(face))
    xyz = oEditor.GetFaceCenter(face)
    If Abs(area - 4*Atn(1)*radius*radius) > 0.000001 Then Exit Function
    If Abs(CDbl(xyz(0))-center(0)) > 0.00001 Or Abs(CDbl(xyz(1))-center(1)) > 0.00001 Or Abs(CDbl(xyz(2))-center(2)) > 0.00001 Then Exit Function
  Next
  CircleMatches = (count = 1)
End Function
Function VolumeMatches(name, volume)
  VolumeMatches = (Abs(CDbl(oEditor.GetObjectVolume(name))-volume) < 0.0000001 + Abs(volume)*0.00001)
End Function
Function MaterialMatches(name, material, inside)
  Dim actual, solveInside
  actual = Replace(CStr(oEditor.GetPropertyValue("Geometry3DAttributeTab", name, "Material")), Chr(34), "")
  solveInside = LCase(CStr(oEditor.GetPropertyValue("Geometry3DAttributeTab", name, "Solve Inside")))
  MaterialMatches = (LCase(actual) = LCase(material) And solveInside = LCase(CStr(inside)))
End Function
Function PairExists(values, name, kind)
  Dim i
  PairExists = False
  If Not IsArray(values) Then Exit Function
  For i = LBound(values) To UBound(values)-1 Step 2
    If CStr(values(i)) = name And CStr(values(i+1)) = kind Then PairExists = True
  Next
End Function
Function ExactlyTwoPorts()
  Dim values
  values = oBoundary.GetExcitations()
  ExactlyTwoPorts = False
  If Not IsArray(values) Then Exit Function
  If UBound(values)-LBound(values)+1 <> 4 Then Exit Function
  ExactlyTwoPorts = PairExists(values,"1","Lumped Port") And PairExists(values,"2","Lumped Port")
End Function
Function LiteralNumber(raw, unit)
  Dim text, suffix, factor
  text = Trim(CStr(raw)): factor = 1
  If unit = "mm" Then
    If LCase(Right(text,2)) = "mm" Then
      text = Left(text,Len(text)-2)
    ElseIf LCase(Right(text,2)) = "cm" Then
      text = Left(text,Len(text)-2): factor = 10
    ElseIf LCase(Right(text,2)) = "um" Then
      text = Left(text,Len(text)-2): factor = 0.001
    ElseIf LCase(Right(text,2)) = "in" Then
      text = Left(text,Len(text)-2): factor = 25.4
    ElseIf LCase(Right(text,1)) = "m" Then
      text = Left(text,Len(text)-1): factor = 1000
    Else
      Err.Raise 513, "LiteralNumber", "Đơn vị chiều dài không hợp lệ"
    End If
  ElseIf unit = "deg" Then
    suffix = LCase(Right(text,3))
    If suffix <> "deg" And suffix <> "rad" Then Err.Raise 513, "LiteralNumber", "Đơn vị góc không hợp lệ"
    text = Left(text,Len(text)-3)
    If suffix = "rad" Then factor = 45/Atn(1)
  Else
    Err.Raise 513, "LiteralNumber", "Đơn vị không hỗ trợ"
  End If
  LiteralNumber = CDbl(text)*factor
End Function
Function VariableMatches(name, expected, unit)
  Dim actual
  actual = LiteralNumber(oDesign.GetVariableValue(name),unit)
  VariableMatches = (Abs(actual-expected) <= (1+Abs(expected))*0.0000000001)
End Function
Function ExpressionMatches(name, expected)
  Dim text
  text = CStr(oDesign.GetVariableValue(name))
  text = Replace(Replace(Replace(Replace(text," ",""),vbTab,""),vbCr,""),vbLf,"")
  expected = Replace(expected," ","")
  ExpressionMatches = (text = expected)
End Function
Function WorkingPathMatches(expected)
  Dim actual
  actual = oProject.GetPath() & "\" & oProject.GetName() & ".aedt"
  WorkingPathMatches = (LCase(fs.GetAbsolutePathName(actual)) = LCase(fs.GetAbsolutePathName(expected)))
End Function
Function HasRealData(category, solution, context, families, expressions, fieldGHz)
  Dim variations, variation, expression, values, value, found, frequencies, frequency, units, factor, frequencyOK
  HasRealData = False
  variations = oReport.GetSolutionDataPerVariation(category,solution,context,families,expressions)
  If Not IsArray(variations) Then Exit Function
  For Each expression In expressions
    found = False
    For Each variation In variations
      frequencyOK = True
      If fieldGHz > 0 Then
        frequencyOK = False
        frequencies = variation.GetSweepValues("Freq",False)
        units = LCase(CStr(variation.GetSweepUnits("Freq")))
        Select Case units
          Case "hz": factor = 1
          Case "khz": factor = 1000
          Case "mhz": factor = 1000000
          Case "ghz": factor = 1000000000
          Case Else: Err.Raise 513, "HasRealData", "Đơn vị tần số không hỗ trợ"
        End Select
        For Each frequency In frequencies
          If Abs(CDbl(frequency)*factor-fieldGHz*1000000000) < 1 Then frequencyOK = True
        Next
      End If
      If frequencyOK Then
        values = variation.GetRealDataValues(CStr(expression),False)
        If IsArray(values) Then
          For Each value In values
            If IsNumeric(value) Then found = True
          Next
        End If
      End If
    Next
    If Not found Then Exit Function
  Next
  HasRealData = True
End Function

Sub CheckVariables(independent, derived)
  Dim item
  For Each item In independent
    If Not VariableMatches(item(0),item(1),item(2)) Then Err.Raise 513, "Vivaldi", "Biến không khớp: " & item(0)
  Next
  For Each item In derived
    If Not ExpressionMatches(item(0),item(1)) Then Err.Raise 513, "Vivaldi", "Biểu thức không khớp: " & item(0)
  Next
End Sub
Sub CheckPoints(name, points)
  Dim item, count
  count = 0
  For Each item In points
    count = count + 1
    If Not PointMatches(name,Array(item(0),item(1),item(2)),item(3)) Then
      Err.Raise 513, "Vivaldi", CStr(item(4)) & ": " & name & " / probe " & CStr(count) & " (" & CStr(item(0)) & "," & CStr(item(1)) & "," & CStr(item(2)) & ")"
    End If
  Next
  If count = 0 Then Err.Raise 513, "Vivaldi", "Plan kiểm tra không có điểm"
End Sub
