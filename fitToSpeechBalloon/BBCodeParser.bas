B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=7.51
@EndOfDesignText@
Sub Class_Globals
	Type TextRun(text As String,fontname As String,fontsize As Double,bold As Boolean,italic As Boolean,fauxBold As Boolean,fauxBoldStrokeWidth As Double,fauxItalic As Boolean,horizontal As Boolean,color As String,fauxItalicOffset As Int,fauxItalicYDiff As Double,fauxItalicHeightDiff As Double,offsetx As Double,offsety As Double,underline As Boolean,strikethrough As Boolean,className As String,tracking As Int)
	Private supportedBBCodes As List = Array As String("tracking","b","color","i","fi","fb","fontname","fontsize","offsetx","offsety","h","u","s","class")
End Sub

'Initializes the object. You can add parameters to this method if needed.
Public Sub Initialize
	
End Sub

'[b]Hello [i]world[/i][/b]! [color=#ff00ff]Red[/color] -> [Hello ,world,! ,Red]
Public Sub Parse(str As String) As List
	Dim run As TextRun
	run.Initialize
	run.text = str
	run.tracking = -999
	If validBBCode(str) Then
		Return ParseRun(run)
	Else
		Return Array(run)
	End If
End Sub

Private Sub ParseRun(run As TextRun) As List
	Dim runs As List
	runs.Initialize
	If run.text = "" Then
		Return runs
	End If
	Dim str As String = run.text
	Dim plainText As StringBuilder
	plainText.Initialize
	For index=0 To str.Length-1
		If CurrentChar(str,index)="[" Then
			Dim tagContent As String = TextUntil("]",str,index)
			Dim codeName As String = GetBBCodeName(tagContent)
			If codeName <> "" And tagContent.Contains("/") = False Then
				Dim text As String = plainText.ToString
				If text <> "" Then
					runs.Add(CreateRun(text,run,"",""))
				End If
				plainText.Initialize
				Dim endTag As String = "[/"&codeName&"]"
				Dim runText As String = TextUntil(endTag,str,index)
				If runText<>"" Then
					index = index + runText.Length - 1
					runText = CodePairStripped(runText,tagContent,endTag)
					Dim richRun As TextRun = CreateRun(runText,run,codeName,tagContent)
					Dim innerRuns As List
					innerRuns.Initialize
					parseInnerRuns(richRun,innerRuns)
					runs.AddAll(innerRuns)
				End If
			End If
		Else
			plainText.Append(CurrentChar(str,index))
		End If
	Next
	Dim text As String = plainText.ToString
	If text <> "" Then
		runs.Add(CreateRun(text,run,"",""))
	End If
	Return runs
End Sub

Private Sub parseInnerRuns(run As TextRun,runs As List)
	Dim parsedRuns As List  = ParseRun(run)
	If parsedRuns.Size = 1 Then ' no tags
		runs.Add(parsedRuns.Get(0))
	Else
		For Each innerRun As TextRun In parsedRuns
			parseInnerRuns(innerRun,runs)
		Next
	End If
End Sub


'[b]Hello [i]world[/i][/b] -> Hello [i]world[/i]
Private Sub CodePairStripped(runText As String,tagContent As String,endTag As String) As String
	runText = runText.Replace(tagContent,"")
	runText= runText.Replace(endTag,"")
	Return runText
End Sub

'text:[color=#ff00ff]Red[/color],codeName:color,tagContent:[color=#ff00ff]
private Sub CreateRun(text As String,parentRun As TextRun,codeName As String,tagContent As String) As TextRun
	Dim run As TextRun
	run.Initialize
	run.text = text
	run.tracking = -999
	If parentRun.IsInitialized Then
		run.bold = parentRun.bold
		run.color = parentRun.color
		run.italic = parentRun.italic
		run.fauxBold = parentRun.fauxBold
		run.fauxBoldStrokeWidth = parentRun.fauxBoldStrokeWidth
		run.fauxItalic = parentRun.fauxItalic
		run.fauxItalicOffset = parentRun.fauxItalicOffset
		run.fauxItalicYDiff = parentRun.fauxItalicYDiff
		run.fauxItalicHeightDiff = parentRun.fauxItalicHeightDiff
		run.fontname = parentRun.fontname
		run.fontsize = parentRun.fontsize
		run.offsetx = parentRun.offsetx
		run.offsety = parentRun.offsety
		run.horizontal = parentRun.horizontal
		run.underline = parentRun.underline
		run.strikethrough = parentRun.strikethrough
		run.className = parentRun.className
		run.tracking = parentRun.tracking
	End If
	
	codeName = codeName.ToLowerCase

	If codeName = "b" Then
		run.bold = True
	else if codeName = "i" Then
		run.italic = True
	else if codeName = "fb" Then
		run.fauxBold = True
		run.fauxBoldStrokeWidth = ParseFauxBoldStrokeWidth(tagContent)
	else if codeName = "fi" Then
		run.fauxItalic = True
		ParseFauxItalicOffset(run,tagContent)
	else if codeName = "color" Then
		run.color = ParseColor(tagContent)
	else if codeName = "fontname" Then
		run.fontname = ParseFontName(tagContent)
	else if codeName = "fontsize" Then
		run.fontsize = ParseFontSize(tagContent)
	else if codeName = "offsetx" Then
		run.offsetx = ParseOffset(tagContent)
	else if codeName = "offsety" Then
		run.offsety = ParseOffset(tagContent)
	else if codeName = "h" Then
		run.horizontal = True
	else if codeName = "u" Then
		run.underline = True
	else if codeName = "s" Then
		run.strikethrough = True
	else if codeName = "class" Then
		run.className = ParseClass(tagContent)
	else if codeName = "tracking" Then
		run.tracking = ParseTracking(tagContent)
	End If
	Return run
End Sub


'parse [class=test] and return test
private Sub ParseClass(tagContent As String) As String
	Try
		Dim name As String
		name = tagContent.SubString2(tagContent.IndexOf("=")+1,tagContent.Length-1)
		Return name
	Catch
		Log(LastException)
	End Try
	Return ""
End Sub


'parse [fontname=Tahoma] and return Tahoma
private Sub ParseFontName(tagContent As String) As String
	Try
		Dim name As String
		name = tagContent.SubString2(tagContent.IndexOf("=")+1,tagContent.Length-1)
		Return name
	Catch
		Log(LastException)
	End Try
	Return ""
End Sub

'parse [offsetx=11] and return 11
private Sub ParseOffset(tagContent As String) As Double
	Try
		Dim size As Double
		size = tagContent.SubString2(tagContent.IndexOf("=")+1,tagContent.Length-1)
		Return size
	Catch
		Log(LastException)
	End Try
	Return 0
End Sub

'parse [kerning=5] and return 5
private Sub ParseTracking(tagContent As String) As Int
	Try
		Dim size As Int
		size = tagContent.SubString2(tagContent.IndexOf("=")+1,tagContent.Length-1)
		Return size
	Catch
		Log(LastException)
	End Try
	Return -999
End Sub

'parse [fontsize=11.0] and return 11.0
private Sub ParseFontSize(tagContent As String) As Double
	Try
		Dim size As Double
		size = tagContent.SubString2(tagContent.IndexOf("=")+1,tagContent.Length-1)
		Return size
	Catch
		Log(LastException)
	End Try
	Return 16
End Sub

'parse [color=#ff0000] and return the rgb value 255,0,0
private Sub ParseColor(tagContent As String) As String
	Try
		Dim hex As String
		hex = tagContent.SubString2(tagContent.IndexOf("=")+1,tagContent.Length-1).ToLowerCase
		Dim r As Int = Bit.ParseInt(hex.SubString2(1,3), 16)
		Dim g As Int = Bit.ParseInt(hex.SubString2(3,5), 16)
		Dim b As Int = Bit.ParseInt(hex.SubString2(5,7), 16)
		Return r&","&g&","&b
	Catch
		Log(LastException)
	End Try
	Return ""
End Sub

Private Sub ParseFauxItalicOffset(run As TextRun, tagContent As String)
	Try
		Dim content As String = tagContent.SubString2(tagContent.IndexOf("=")+1,tagContent.Length-1)
		If content.Contains(",") Then
			Dim values() As String = Regex.Split(",",content)
			For i = 0 To values.Length - 1
				Dim value As Double = values(i)
				If i = 0 Then
					run.fauxItalicOffset = value
				else if i = 1 Then
					run.fauxItalicYDiff = value
				else if i = 2 Then
					run.fauxItalicHeightDiff = value
				End If
			Next
		Else
			Dim offset As Int
			offset = content
			run.fauxItalicOffset = offset
		End If
	Catch
		run.fauxItalicOffset = 2
	End Try
End Sub


Private Sub ParseFauxBoldStrokeWidth(tagContent As String) As Double
	Try
		Dim strokeWidth As Double
		strokeWidth = tagContent.SubString2(tagContent.IndexOf("=")+1,tagContent.Length-1)
		Return strokeWidth
	Catch
		Return 0.5
	End Try
End Sub

private Sub GetBBCodeName(str As String) As String
	Dim matcher As Matcher = Regex.Matcher("\[/?(.*?)]",str)
	If matcher.Find Then
		Dim match As String = matcher.Group(1)
		If match.Contains("=") Then
			match = match.SubString2(0,match.IndexOf("="))
		End If
		If supportedBBCodes.IndexOf(match.ToLowerCase) <> -1 Then
			Return match
		End If
	End If
	Return ""
End Sub

private Sub TextUntil(EndStr As String,str As String,index As Int) As String
	Dim sb As StringBuilder
	sb.Initialize
	Dim textLeft As String=str.SubString2(index,str.Length)
	If textLeft.Contains(EndStr) Then
		For i=index To str.Length - EndStr.Length
			Dim s As String=str.CharAt(i)
			If str.SubString2(i,i + EndStr.Length) = EndStr Then
				sb.Append(EndStr)
				Exit
			Else
				sb.Append(s)
			End If
		Next
	End If
	Return sb.ToString
End Sub

private Sub CurrentChar(str As String,index As Int) As String
	Return str.CharAt(index)
End Sub

private Sub validBBCode(str As String) As Boolean
	Dim count As Int = 0
	Dim matcher As Matcher = Regex.Matcher("\[/?(.*?)]",str)
	Do While matcher.Find
		Dim match As String = matcher.Group(1)
		If match.Contains("=") Then
			match = match.SubString2(0,match.IndexOf("="))
		End If
		If match.Contains("[") Or match.Contains("]") Then
			Return False
		End If
		If supportedBBCodes.IndexOf(match.ToLowerCase) <> -1 Then
			count = count + 1
		End If
	Loop
	If count > 0 Then
		If count Mod 2 = 0 Then
			Return True
		End If
	End If
	Return False
End Sub
