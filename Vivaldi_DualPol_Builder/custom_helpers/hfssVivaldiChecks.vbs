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
  Select Case name
    Case "CHECK_01": vStageName = "Tạo hệ tọa độ"
    Case "CHECK_02": vStageName = "Tạo và truy vấn mặt loe dài"
    Case "CHECK_03": vStageName = "Tạo và truy vấn mặt loe ngắn"
    Case "CHECK_04": vStageName = "Copy/Paste và trim mặt loe"
    Case "CHECK_05": vStageName = "Rotate transition"
    Case "CHECK_06": vStageName = "Tạo Rectangle khe/cavity"
    Case "CHECK_07": vStageName = "Unite vùng khoét"
    Case "CHECK_08": vStageName = "Subtract vùng loe khỏi tấm"
    Case "CHECK_09": vStageName = "SheetThicken BothSides"
    Case "CHECK_10": vStageName = "DuplicateAroundAxis phân cực hai"
    Case "CHECK_11": vStageName = "Tạo khối nối và đế"
    Case "CHECK_12": vStageName = "Unite thân nhôm"
    Case "CHECK_13": vStageName = "Tạo coax thứ nhất"
    Case "CHECK_14": vStageName = "Duplicate coax và cổng"
    Case "CHECK_15": vStageName = "Khoét coax và đo CAD"
    Case "CHECK_16": vStageName = "Gán hai Lumped Ports"
    Case "CHECK_17": vStageName = "Gán Radiation Boundary"
    Case "CHECK_18": vStageName = "Thiết lập solver và sweep"
    Case Else: vStageName = name
  End Select
  WriteStatus "CHECK|" & name & "|PENDING|PENDING|" & vStageName
End Sub
Sub TraceCommand(command)
  vCommand = command
  WriteStatus "COMMAND|" & vStage & "|" & CleanLine(vStageName) & "|" & CleanLine(command)
End Sub
Sub OperationFailed(operation, phase, number, source, description)
  WriteStatus "ERROR|" & vStage & "|" & CleanLine(vStageName) & "|" & phase & "|" & CleanLine(operation) & "|" & CleanLine(vCommand) & "|" & CStr(number) & "|" & CleanLine(source) & "|" & CleanLine(description)
  If phase = "QUERY" Then
    Fail "Lỗi truy vấn kiểm chứng; chưa thể kết luận đối tượng thiếu. " & CStr(number) & " " & description
  Else
    Fail operation & ": " & CStr(number) & " " & description
  End If
End Sub
Sub Fail(message)
  WriteStatus "CHECK|" & vStage & "|FAIL|PENDING|" & CleanLine(message)
  TrySaveDebug
  WriteStatus "STATE|FAILED"
End Sub
Sub TrySaveDebug()
  Dim number, description
  If Not vSaveDebug Then Exit Sub
  If Not IsObject(oProject) Then
    WriteStatus "DEBUG|UNAVAILABLE|Chưa có project để lưu"
    Exit Sub
  End If
  Err.Clear
  On Error Resume Next
  If fs.FileExists(vDebugPath) Then
    WriteStatus "DEBUG|SKIPPED_EXISTS|" & vDebugPath
  Else
    oProject.SaveAs vDebugPath, False
    number = Err.Number: description = Err.Description
    Err.Clear
    If number <> 0 Then
      WriteStatus "DEBUG|FAILED|" & CStr(number) & "|" & CleanLine(description)
    ElseIf fs.FileExists(vDebugPath) Then
      WriteStatus "DEBUG|SAVED_INCOMPLETE|" & vDebugPath & "|CAD debug chưa hoàn chỉnh, không phải anten đã kiểm chứng"
    Else
      WriteStatus "DEBUG|FAILED|Không tìm thấy CAD debug sau SaveAs"
    End If
  End If
  On Error GoTo 0
End Sub
Function CleanLine(value)
  CleanLine = Replace(Replace(Replace(CStr(value), vbCr, " "), vbLf, " "), "|", "/")
End Function
Function QueryGroup(groupName)
  ' Chỉ truy vấn một nhóm: lỗi COM được ghi riêng trước khi chuẩn hóa danh sách.
  Dim objects, number, source, description, names, item, count, kind, command
  command = "oEditor.GetObjectsInGroup(" & Chr(34) & CStr(groupName) & Chr(34) & ")"
  TraceCommand command
  Err.Clear
  On Error Resume Next
  objects = oEditor.GetObjectsInGroup(CStr(groupName))
  number = Err.Number: source = Err.Source: description = Err.Description
  On Error GoTo 0
  If number <> 0 Then
    WriteStatus "QUERY|" & vStage & "|" & command & "|ERROR|" & CStr(number) & "|" & CleanLine(source) & "|" & CleanLine(description)
    Err.Raise number, command, description
  End If
  kind = TypeName(objects)
  names = NormalizeObjectNames(objects, command)
  count = 0
  For Each item In names
    count = count + 1
  Next
  WriteStatus "QUERY|" & vStage & "|" & command & "|OK|" & kind & "|" & CStr(count) & "|" & CleanLine(Join(names, ","))
  QueryGroup = names
End Function
Function NormalizeObjectNames(objects, command)
  ' Chấp nhận SAFEARRAY, chuỗi đơn và nhóm rỗng; kiểu lạ là lỗi, không suy ra không có mặt.
  Dim names, item, count
  names = Array(): count = 0
  If IsArray(objects) Then
    For Each item In objects
      AddObjectName names, count, item
    Next
  ElseIf IsEmpty(objects) Or IsNull(objects) Then
    ' Nhóm rỗng là kết quả hợp lệ, khác với lỗi truy vấn.
  ElseIf VarType(objects) = 8 Then
    AddObjectName names, count, objects
  Else
    WriteStatus "QUERY|" & vStage & "|" & command & "|INVALID_RETURN|" & TypeName(objects)
    Err.Raise 513, command, "Kiểu trả về không hỗ trợ: " & TypeName(objects)
  End If
  NormalizeObjectNames = names
End Function
Sub AddObjectName(ByRef names, ByRef count, value)
  If IsEmpty(value) Or IsNull(value) Then Exit Sub
  If VarType(value) <> 8 Then Err.Raise 513, "AddObjectName", "Tên đối tượng không phải chuỗi: " & TypeName(value)
  If CStr(value) = "" Then Exit Sub
  If HasName(names, CStr(value)) Then Exit Sub
  If count = 0 Then
    names = Array(CStr(value))
  Else
    ReDim Preserve names(count)
    names(count) = CStr(value)
  End If
  count = count + 1
End Sub
Function ObjectNames()
  ' Không dùng default Item/Keys của Dictionary; không nuốt lỗi bất kỳ nhóm nào.
  Dim names, groupName, objects, objectName, count
  names = Array(): count = 0
  For Each groupName In Array("Sheets", "Solids", "Lines", "Unclassified")
    objects = QueryGroup(CStr(groupName))
    For Each objectName In objects
      AddObjectName names, count, objectName
    Next
  Next
  ObjectNames = names
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
    TraceCommand "oEditor.Copy / source=" & sourceName
    oEditor.Copy Array("NAME:Selections", "Selections:=", sourceName)
    TraceCommand "oEditor.Paste / source=" & sourceName
    oEditor.Paste
  ElseIf operation = "rotate" Then
    TraceCommand "oEditor.DuplicateAroundAxis / source=" & sourceName & " / Z=-90deg / RelativeCS1"
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
    TraceCommand "oEditor.ChangeProperty / rename=" & CStr(newName) & " -> " & desiredName
    oEditor.ChangeProperty Array("NAME:AllTabs", Array("NAME:Geometry3DAttributeTab", Array("NAME:PropServers", newName), Array("NAME:ChangedProps", Array("NAME:Name", "Value:=", desiredName))))
  End If
  afterNames = ObjectNames()
  If Not HasName(afterNames, desiredName) Then Err.Raise 513, "CloneNamed", "Không đọc lại được clone"
End Sub
Function PointMatches(name, xyz, expected)
  Dim bodies
  TraceCommand "oEditor.GetBodyNamesByPosition / object=" & name & " / xyz=" & CStr(xyz(0)) & "," & CStr(xyz(1)) & "," & CStr(xyz(2))
  bodies = oEditor.GetBodyNamesByPosition(Array("NAME:Parameters", "XPosition:=", CStr(xyz(0)) & "mm", "YPosition:=", CStr(xyz(1)) & "mm", "ZPosition:=", CStr(xyz(2)) & "mm"))
  bodies = NormalizeObjectNames(bodies, "oEditor.GetBodyNamesByPosition")
  PointMatches = (HasName(bodies, name) = expected)
End Function
Function BodyBoundsMatch(name, expected)
  Dim ids, id, xyz, bounds, i
  BodyBoundsMatch = False
  TraceCommand "oEditor.GetVertexIDsFromObject / object=" & name
  ids = oEditor.GetVertexIDsFromObject(name)
  If Not IsArray(ids) Then Exit Function
  bounds = Array(1E+100, -1E+100, 1E+100, -1E+100, 1E+100, -1E+100)
  For Each id In ids
    TraceCommand "oEditor.GetVertexPosition / id=" & CStr(id)
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
  TraceCommand "oEditor.GetFaceIDs / object=" & name
  faces = oEditor.GetFaceIDs(name)
  For Each face In faces
    count = count + 1
    TraceCommand "oEditor.GetFaceArea / face=" & CStr(face)
    area = CDbl(oEditor.GetFaceArea(face))
    TraceCommand "oEditor.GetFaceCenter / face=" & CStr(face)
    xyz = oEditor.GetFaceCenter(face)
    If Abs(area - 4*Atn(1)*radius*radius) > 0.000001 Then Exit Function
    If Abs(CDbl(xyz(0))-center(0)) > 0.00001 Or Abs(CDbl(xyz(1))-center(1)) > 0.00001 Or Abs(CDbl(xyz(2))-center(2)) > 0.00001 Then Exit Function
  Next
  CircleMatches = (count = 1)
End Function
Function VolumeMatches(name, volume)
  TraceCommand "oEditor.GetObjectVolume / object=" & name
  VolumeMatches = (Abs(CDbl(oEditor.GetObjectVolume(name))-volume) < 0.0000001 + Abs(volume)*0.00001)
End Function
Function MaterialMatches(name, material, inside)
  Dim actual, solveInside
  TraceCommand "oEditor.GetPropertyValue / Material / object=" & name
  actual = Replace(CStr(oEditor.GetPropertyValue("Geometry3DAttributeTab", name, "Material")), Chr(34), "")
  TraceCommand "oEditor.GetPropertyValue / Solve Inside / object=" & name
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
  TraceCommand "oBoundary.GetExcitations() / expected Lumped Ports 1,2"
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
  TraceCommand "oDesign.GetVariableValue / variable=" & name
  actual = LiteralNumber(oDesign.GetVariableValue(name),unit)
  VariableMatches = (Abs(actual-expected) <= (1+Abs(expected))*0.0000000001)
End Function
Function ExpressionMatches(name, expected)
  Dim text
  TraceCommand "oDesign.GetVariableValue / expression=" & name
  text = CStr(oDesign.GetVariableValue(name))
  text = Replace(Replace(Replace(Replace(text," ",""),vbTab,""),vbCr,""),vbLf,"")
  expected = Replace(expected," ","")
  ExpressionMatches = (text = expected)
End Function
Function HasRealData(category, solution, context, families, expressions, fieldGHz)
  Dim variations, variation, expression, values, value, found, frequencies, frequency, units, factor, frequencyOK
  HasRealData = False
  TraceCommand "oReport.GetSolutionDataPerVariation / category=" & category & " / solution=" & solution
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

Function DefinitionProperty(data, key)
  Dim i, value
  DefinitionProperty = Empty
  If Not IsArray(data) Then Exit Function
  For i = LBound(data) To UBound(data)
    If IsArray(data(i)) Then
      value = DefinitionProperty(data(i),key)
      If Not IsEmpty(value) Then DefinitionProperty = value: Exit Function
    ElseIf VarType(data(i)) = 8 Then
      If LCase(CStr(data(i))) = LCase(key & ":=") And i < UBound(data) Then
        DefinitionProperty = data(i+1): Exit Function
      End If
    End If
  Next
End Function
Function DefinitionMatchesData(data, epsilon, mu, sigma, loss)
  Dim keys, expected, defaults, i, value
  keys = Array("permittivity","permeability","conductivity","dielectric_loss_tangent")
  expected = Array(epsilon,mu,sigma,loss)
  defaults = Array(1,1,0,0)
  DefinitionMatchesData = False
  ' Scalar HFSS defaults apply only to omitted keys of a valid definition.
  ' A failed GetData, empty return or explicit nonnumeric/anisotropic value fails.
  If Not IsArray(data) Then Exit Function
  If UBound(data) < LBound(data) Then Exit Function
  If VarType(data(LBound(data))) <> 8 Then Exit Function
  If LCase(Left(CStr(data(LBound(data))),5)) <> "name:" Then Exit Function
  For i = 0 To 3
    value = DefinitionProperty(data,keys(i))
    If IsEmpty(value) Then
      value = defaults(i)
      WriteStatus "MATERIAL_DEFAULT|" & keys(i) & "|" & CStr(value)
    End If
    If Not IsNumeric(value) Then Exit Function
    If Abs(CDbl(value)-CDbl(expected(i))) > 0.000000001*(1+Abs(CDbl(expected(i)))) Then Exit Function
  Next
  DefinitionMatchesData = True
End Function
Function MaterialDefinitionMatches(name, epsilon, mu, sigma, loss)
  Dim manager, data
  TraceCommand "oMaterials.GetManager(Material).GetData / material=" & name
  Set manager = oMaterials.GetManager("Material")
  data = manager.GetData(name)
  MaterialDefinitionMatches = DefinitionMatchesData(data,epsilon,mu,sigma,loss)
End Function
Sub EnsureMaterial(name, epsilon, mu, sigma, loss)
  ' Uu tien dinh nghia co san neu doc va doi chieu duoc; khong EditMaterial.
  Dim manager, data, number, source, description, existsInProject, readable
  TraceCommand "oMaterials.GetProjectMaterialNames / material=" & name
  existsInProject = HasName(oMaterials.GetProjectMaterialNames(),name)
  Set manager = oMaterials.GetManager("Material")
  TraceCommand "oMaterials.GetManager(Material).GetData / material=" & name
  Err.Clear
  On Error Resume Next
  data = manager.GetData(name)
  number = Err.Number: source = Err.Source: description = Err.Description
  On Error GoTo 0
  readable = False
  If number = 0 Then
    If IsArray(data) Then readable = (UBound(data) >= LBound(data))
  End If
  If number <> 0 Then
    WriteStatus "MATERIAL_LOOKUP|" & name & "|" & CStr(number) & "|" & CleanLine(source) & "|" & CleanLine(description)
    If existsInProject Then Err.Raise number, "GetData/" & name, description
  End If
  If readable Then
    If Not DefinitionMatchesData(data,epsilon,mu,sigma,loss) Then Err.Raise 513, "EnsureMaterial", "Dinh nghia vat lieu co san khong khop; khong tu ghi de: " & name
    WriteStatus "MATERIAL|REUSED_VERIFIED|" & name
  Else
    If existsInProject Then Err.Raise 513, "EnsureMaterial", "Khong doc duoc dinh nghia trong project: " & name
    TraceCommand "oMaterials.AddMaterial / project definition=" & name
    oMaterials.AddMaterial Array("NAME:" & name, "CoordinateSystemType:=", "Cartesian", "BulkOrSurfaceType:=", 1, Array("NAME:PhysicsTypes", "set:=", Array("Electromagnetic")), "permittivity:=", MaterialNumber(epsilon), "permeability:=", MaterialNumber(mu), "conductivity:=", MaterialNumber(sigma), "dielectric_loss_tangent:=", MaterialNumber(loss))
    WriteStatus "MATERIAL|PROJECT_DEFINITION_CREATED|" & name
  End If
  If Not MaterialDefinitionMatches(name,epsilon,mu,sigma,loss) Then Err.Raise 513, "EnsureMaterial", "Thuoc tinh vat lieu khong khop sau khi khai bao: " & name
  WriteStatus "MATERIAL|PROPERTIES_VERIFIED|" & name & "|epsilon=" & CStr(epsilon) & "|mu=" & CStr(mu) & "|sigma=" & CStr(sigma) & "|loss=" & CStr(loss)
End Sub

Function MaterialNumber(value)
  MaterialNumber = Replace(CStr(value), ",", ".")
End Function
