B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=7.8
@EndOfDesignText@
Sub Class_Globals
	Private fx As JFX
	Private tfJO As JavaObject
	Private mTargetLang As String
	Private mDoNotBreakWords As String
	Private mMinWordLengthForBreak As Int
	Public mGlobalRun As TextRun
	Public upscaleRatioForRotation As Double = 1.414
	Type HorizontalTextEngineResult(img As B4XBitmap,fontsize As Double,width As Double,scale As Double)
End Sub

'Initializes the object. You can add parameters to this method if needed.
Public Sub Initialize(targetLang As String,doNotBreakWords As Boolean,minWordLengthForBreak As Int)
	mTargetLang = targetLang
	mMinWordLengthForBreak = minWordLengthForBreak
	mDoNotBreakWords = doNotBreakWords
	tfJO.InitializeNewInstance("javafx.scene.text.TextFlow", Null)
End Sub

Public Sub setGlobalRun(run As TextRun)
	mGlobalRun = run
End Sub

Public Sub Draw(parent As Pane,text As String,f As Font,fontname As String,color As Paint,bold As Boolean,italic As Boolean,wrap As Boolean,boxWidth As Double,boxHeight As Double,alignment As String,linespace As Double,wordspace As Double,padding As Double,style As String,className As String,rotation As Double) As HorizontalTextEngineResult
	Dim result As HorizontalTextEngineResult
	result.Initialize
	result.fontsize = f.Size
	CreateTextFlow(result,parent,text,f,fontname,color,bold,italic,wrap,boxWidth,boxHeight,alignment,linespace,wordspace,padding,style,className,rotation)
	Dim p As Pane = tfJO
	If rotation <> 0 Then
		'Rotating a rasterized image resamples it; the worst case is 45 degrees,
		'where the diagonal grows by ~1.414. Render the snapshot at that higher
		'resolution so the ImageView has enough pixels when it is rotated.
		'The caller divides by result.scale to keep the on-screen size unchanged.
		Dim s As Double = upscaleRatioForRotation
		Dim joNode As JavaObject = p
		joNode.RunMethod("setScaleX",Array(s))
		joNode.RunMethod("setScaleY",Array(s))
		Dim img As B4XBitmap = p.Snapshot2(fx.Colors.ARGB(0,255,255,255))
		joNode.RunMethod("setScaleX",Array(1.0))
		joNode.RunMethod("setScaleY",Array(1.0))
		p.RemoveNodeFromParent
		result.img = img
		result.scale = s
		result.width = boxWidth
		Return result
	End If
	Dim img As B4XBitmap=p.Snapshot2(fx.Colors.ARGB(0,255,255,255))
	p.RemoveNodeFromParent
	result.img = img
	result.scale = 1.0
	result.width = boxWidth
	Return result
End Sub

Public Sub CreateTextFlow(result As HorizontalTextEngineResult, parent As Pane,text As String,f As Font,fontname As String,color As Paint,bold As Boolean,italic As Boolean,wrap As Boolean,boxWidth As Double,boxHeight As Double,alignment As String,linespace As Double,wordspace As Double,padding As Double,style As String,className As String,rotation As Double) As List
	parent.AddNode(tfJO,0,0,-1,-1)
	Dim tf As TextFlow
	tf.Initialize
	tfJO.RunMethod("setTextAlignment",Array(tf.TextAlignment.GetField(alignment)))
	If LanguageUtils.LanguageIsRight2Left(mTargetLang) Then
		Dim NodeOrientation As EnumClass
		NodeOrientation.Initialize("javafx.geometry.NodeOrientation")
		tfJO.RunMethod("setNodeOrientation",Array(NodeOrientation.ValueOf("RIGHT_TO_LEFT")))
	End If
	'Do NOT rotate the node here. This method builds the node that Draw()/calculateHeight()
	'snapshot, and Snapshot2 includes the node's own rotation, so rotating here would bake
	'the angle into the bitmap. TextBox then rotates the ImageView around the parent center
	'with Utils.RotateNode, which is the single rotation we want (crisp, pivoted at the
	'parent center). The AddTextFlow path does its own RotateNode, so it is unaffected.
	If wrap = True Then
		If mDoNotBreakWords Then
			If LanguageUtils.LanguageHasSpace(mTargetLang) And Utils.isChinese(text) = False Then
				Dim desiredWidth As Int
				Dim textForCalculation As String = text
				If text.Contains(" ") Then
					textForCalculation = textForCalculation & " "
				End If
				desiredWidth = calculateMinimumWidth(parent,textForCalculation,f)
				Do While desiredWidth > boxWidth
					If f.Size >= Utils.getSetting("minFontSize",12) Then
						f = fx.CreateFont(f.FamilyName,f.Size-1,bold,italic)
						desiredWidth = calculateMinimumWidth(parent,textForCalculation,f)
					Else
						boxWidth = desiredWidth
						Exit
					End If
				Loop
				result.fontsize = f.Size
			End If
		End If
		tfJO.RunMethod("setPrefWidth",Array(boxWidth))
		tfJO.RunMethod("setMaxWidth",Array(boxWidth))
	End If
	tfJO.RunMethodJO("getChildren", Null).RunMethod("clear", Null)
	Dim texts As List = formatedText(text,color,f,fontname,bold,italic,linespace,wordspace,className)
	tfJO.RunMethod("setLineSpacing",Array(linespace))
	tfJO.RunMethodJO("getChildren", Null).RunMethod("addAll", Array(texts))
	Dim p As Pane=tfJO
	If style <> "" Then
		p.Style = style
	End If
	If padding>0 Then
		Dim insets As JavaObject
		insets.InitializeNewInstance("javafx.geometry.Insets",Array(padding,0.0,0.0,0.0))
		Dim jo As JavaObject = p
		jo.RunMethod("setPadding",Array(insets))
	End If
	Return texts
End Sub

public Sub calculateHeight(parent As Pane,text As String,f As Font,fontname As String,color As Paint,bold As Boolean,italic As Boolean,wrap As Boolean,boxWidth As Double,boxHeight As Double,alignment As String,linespace As Double,wordspace As Double,padding As Double,style As String,className As String,rotation As Double) As Double
	Dim result As HorizontalTextEngineResult
	result.Initialize
	result.fontsize = f.Size
	CreateTextFlow(result,parent,text,f,fontname,color,bold,italic,wrap,boxWidth,boxHeight,alignment,linespace,wordspace,padding,style,className,rotation)
	Dim height As Double = tfJO.RunMethod("prefHeight", Array(boxWidth))
	Return height
End Sub


private Sub calculateMinimumWidth(pane As Pane,s As String,f As Font) As Int
	Dim maxWordWidth As Int = 0
	s = Regex.Replace("\[.*?\]",s,"") 'remove bbcode
	Dim c As B4XCanvas
	c.Initialize(pane)
	For Each word As String In Regex.Split(" ",s)
		If word.Length > mMinWordLengthForBreak Then
			word = word.SubString2(0,mMinWordLengthForBreak)
		End If
		maxWordWidth = Max(c.MeasureText(word&" ",f).Width,maxWordWidth)
	Next
	Return maxWordWidth
End Sub

Public Sub AddTextFlow(parent As AnchorPane,text As String,f As Font,fontname As String,color As Paint,bold As Boolean,italic As Boolean,wrap As Boolean,boxWidth As Double,boxHeight As Double,alignment As String,linespace As Double,wordspace As Double,style As String,className As String,rotation As Double) As Pane
	parent.RemoveAllNodes
	parent.AddNode(tfJO,0,0,-1,-1)
	Utils.RotateNode(tfJO,rotation)	
	Dim tf As TextFlow
	tf.Initialize
	tfJO.RunMethod("setTextAlignment",Array(tf.TextAlignment.GetField(alignment)))
	If wrap = True Then
		If mDoNotBreakWords Then
			If (LanguageUtils.LanguageHasSpace(mTargetLang) And text.Contains(" ")) Then
				Dim desiredWidth As Int = calculateMinimumWidth(parent,text,f)
				Do While desiredWidth > boxWidth
					If f.Size >= Utils.getSetting("minFontSize",12) Then
						f = fx.CreateFont(f.FamilyName,f.Size-1,bold,italic)
						desiredWidth = calculateMinimumWidth(parent,text,f)
					Else
						boxWidth = desiredWidth
						Exit
					End If
				Loop
			End If
		End If
		tfJO.RunMethod("setMaxWidth",Array(boxWidth))
	End If
	tfJO.RunMethodJO("getChildren", Null).RunMethod("clear", Null)
	Dim texts As List = formatedText(text,color,f,fontname,bold,italic,linespace,wordspace,className)
	tfJO.RunMethod("setLineSpacing",Array(linespace))
	tfJO.RunMethodJO("getChildren", Null).RunMethod("addAll", Array(texts))
	parent.SetAnchors(tfJO,0,0,0,0)
	Dim p As Pane=tfJO
	If style <> "" Then
		p.Style = style
	End If
	Return tfJO
End Sub

Sub formatedText(Text As String,color As Paint,f As Font,fontname As String,bold As Boolean,italic As Boolean,linespace As Double,wordspace As Double,className As String) As List
	Dim tf As TextFlow
	tf.Initialize
	If Utils.getSetting("richtext",False) Then
		Dim parser As BBCodeParser
		parser.Initialize
		Try
			Dim runs As List = parser.Parse(Text)

			For Each run As TextRun In runs
				Dim texts As List
				texts.Initialize
				
				If mGlobalRun.IsInitialized Then
					run = mGlobalRun
				End If

				If run.tracking <> -999 Then
					For i = 0 To run.text.Length - 1
						Dim c As String = run.text.CharAt(i)
						texts.Add(c)
					Next
				Else
					run.tracking = wordspace
					If run.tracking = 0 Then
						texts.Add(run.text)
					Else
						For i = 0 To run.text.Length - 1
							Dim c As String = run.text.CharAt(i)
							texts.Add(c)
						Next
					End If
				End If
				Dim accumulatedOffset As Int
				Dim strIndex As Int = 0
				For Each str As String In texts
					tf.AddText(str)
					Dim inlineColor As Paint
					If run.color <> "" Then
						Dim r,g,b As Int
						r=Regex.Split(",",run.color)(0)
						g=Regex.Split(",",run.color)(1)
						b=Regex.Split(",",run.color)(2)
						inlineColor = fx.Colors.RGB(r,g,b)
						tf.SetColor(inlineColor)
					Else
						tf.SetColor(color)
					End If
					If bold = True And run.bold = False Then
						run.bold = True
					End If
					If italic = True And run.italic = False Then
						run.italic = True
					End If
					Dim name As String
					If run.fontname <> "" Then
						name = run.fontname
					Else
						name = fontname
					End If
					Dim size As Double
					If run.fontsize <> 0 Then
						size = run.fontsize
					Else
						size = f.Size
					End If
					Dim font As Font = fx.CreateFont(name,size,run.bold,run.italic)
					tf.SetFont(font)
					If run.fauxBold Then
						If inlineColor.IsInitialized Then
							tf.SetFauxBold(inlineColor,run.fauxBoldStrokeWidth)
						Else
							tf.SetFauxBold(color,run.fauxBoldStrokeWidth)
						End If
					End If
					If run.fauxItalic Then
						tf.SetFauxItalic(linespace,run.fauxItalicOffset,run.fauxItalicYDiff,run.fauxItalicHeightDiff)
					End If
					If run.underline Then
						tf.SetUnderline(True)
					End If
					If run.strikethrough Then
						tf.SetStrikethrough(True)
					End If
					If className <> "" Then
						tf.SetClassName(className)
					End If
					If run.className <> "" Then
						tf.SetClassName(run.className)
					End If
					If run.tracking > 0 Then
						tf.AddTextForTracking(run.tracking)
					else if run.tracking < 0 And run.tracking <> -999 And strIndex <> 0 Then
						accumulatedOffset = accumulatedOffset + run.tracking
						tf.SetTranslateX(accumulatedOffset)
					End If
					If run.offsetx <> 0 Then
						tf.SetTranslateX(run.offsetx)
					End If
					If run.offsety <> 0 Then
						tf.SetTranslateY(run.offsety)
					End If
					strIndex = strIndex + 1
                Next
			Next
		Catch
			Log(LastException)
			Dim accumulatedOffset As Int = 0
			Dim texts As List
			texts.Initialize
			If wordspace <> 0 Then
				For i = 0 To Text.Length - 1
					Dim c As String = Text.CharAt(i)
					texts.Add(c)
				Next
			Else
				texts.Add(Text)
			End If
			For Each str As String In texts
				tf.AddText(str)
				tf.SetColor(color)
				tf.SetFont(f)
				If className <> "" Then
					tf.SetClassName(className)
				End If
				If wordspace > 0 Then
					tf.AddTextForTracking(wordspace)
				else if wordspace < 0 Then
					accumulatedOffset = accumulatedOffset + wordspace
					tf.SetTranslateX(accumulatedOffset)
				End If
			Next
		End Try
	Else
		Dim accumulatedOffset As Int = 0
		Dim texts As List
		texts.Initialize
		If wordspace <> 0 Then
			For i = 0 To Text.Length - 1
				Dim c As String = Text.CharAt(i)
				texts.Add(c)
			Next
		Else
			texts.Add(Text)
		End If
		For Each str As String In texts
			tf.AddText(str)
			tf.SetColor(color)
			tf.SetFont(f)
			If className <> "" Then
				tf.SetClassName(className)
			End If
			If wordspace > 0 Then
				tf.AddTextForTracking(wordspace)
			else if wordspace < 0 Then
				accumulatedOffset = accumulatedOffset + wordspace
				tf.SetTranslateX(accumulatedOffset)
			End If
		Next
	End If
	Return tf.texts
End Sub
