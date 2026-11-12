B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=8.8
@EndOfDesignText@
Sub Class_Globals
	Private fx As JFX
	Private previousText As String
	Private previousLines As List
	Private presetRotationRules As String = "[…—~]"
	Private presetZeroWordspaceRules As String = "[—]"
	Private presetRightAlignRules As String = "[\.,。，、っッ]"
	Private presetCenterAlignRules As String = "[\!\?！？⁉‼…—~⋮0-9a-zA-Z]"
	Private presetReplaceJSON As String = $"{"（":"︵","）":"︶","「":"﹁","」":"﹂","『":"﹃","』":"﹄"}"$
	Private mRotationRules As String
	Private mZeroWordspaceRules As String
	Private mRightAlignRules As String
	Private mCenterAlignRules As String
	Private mFirstCharToMoveUpRules As String
	Private mFreeHeightRules As String
	Private mReplacingMap As Map
	Private mTargetLang As String
	Private mDoNotBreakWords As String
	Private mMinWordLengthForBreak As Int
	Public upscaleRatioForRotation As Double = 1.414
	Private mOffsetRulesMap As Map ' {"！":{"y":0,"x":0,"fontsize":16}}
	Private mBalloonMask As cvMat
	Private mHasBalloonMask As Boolean
	Private mBalloonMaskOffsetX As Int
	Private mBalloonMaskOffsetY As Int
	'计算气泡掩膜时额外的x偏移（像素），正值表示文字相对掩膜往左偏。由调用方（TextBox）设置，和框宽无关。
	Public horizontalMaskOffsetX As Int
	'计算气泡掩膜时额外的y偏移（像素），正值表示文字相对掩膜往下偏（垂直居中时文字图下移的量）。由调用方设置。
	Public verticalMaskOffsetY As Int
	Type VerticalTextEngineChar (f As Font,run As TextRun,color As Paint,horizontal As Boolean,runWordspace As Double,text As String,rect As B4XRect,zeroWordspace As Boolean,imgWidth As Double,imgHeight As Double,textImage As B4XBitmap,offsetX As Double,offsetY As Double,fixedRectForRun As B4XRect,fixedWidth As Boolean,fixedHeight As Boolean,padding As Double)
End Sub

'Initializes the object. You can add parameters to this method if needed.
Public Sub Initialize(targetLang As String,doNotBreakWords As Boolean,minWordLengthForBreak As Int)
	mOffsetRulesMap.Initialize
	mRotationRules = presetRotationRules
	mRightAlignRules = presetRightAlignRules
	mCenterAlignRules = presetCenterAlignRules
	mZeroWordspaceRules = presetZeroWordspaceRules
	mTargetLang = targetLang
	mDoNotBreakWords = doNotBreakWords
	mMinWordLengthForBreak = minWordLengthForBreak
	Dim json As JSONParser
	json.Initialize(presetReplaceJSON)
	mReplacingMap = json.NextObject
End Sub

Public Sub Draw(parent As Pane,text As String,f As Font,fontname As String,color As Paint,bold As Boolean,italic As Boolean,wordspace As Int,linespace As Double,padding As Int,wrap As Boolean,boxWidth As Int,boxHeight As Int, left2right As Boolean, style As String,rotation As Double,alignment As String,verticalCenter As Boolean) As B4XBitmap
	Dim bitmap As B4XBitmap = Draw2(text,f,fontname,color,bold,italic,wordspace,linespace,padding,wrap,boxWidth,boxHeight,left2right,rotation,alignment,verticalCenter)
	If style <> "" Then
		Dim iv As ImageView
		iv.Initialize("")
		parent.AddNode(iv,0,0,-1,-1)
		iv.SetImage(bitmap)
		If style<>"" Then
			iv.Style = style
		End If
		If rotation <> 0 Then
			Utils.RotateNode(iv,rotation)
		End If
		Dim img As B4XBitmap = iv.Snapshot2(fx.Colors.ARGB(0,255,255,255))
		iv.RemoveNodeFromParent
		If rotation <> 0 Then
			img = img.Resize(img.Width/upscaleRatioForRotation,img.Height/upscaleRatioForRotation,True)
		End If
		Return img
	Else
		If rotation <> 0 Then
			Dim iv As ImageView
			iv.Initialize("")
			parent.AddNode(iv,0,0,-1,-1)
			iv.SetImage(bitmap)
			Utils.RotateNode(iv,rotation)
			Dim img As B4XBitmap = iv.Snapshot2(fx.Colors.ARGB(0,255,255,255))
			iv.RemoveNodeFromParent
			img = img.Resize(img.Width/upscaleRatioForRotation,img.Height/upscaleRatioForRotation,True)
			Return img
		Else
			Return bitmap
		End If
		
	End If
End Sub

public Sub CalculateLayout(text As String,f As Font,fontname As String,color As Paint,bold As Boolean,italic As Boolean,wordspace As Int,linespace As Double,padding As Int,wrap As Boolean,boxWidth As Int,boxHeight As Int, left2right As Boolean,rotation As Double,alignment As String,verticalCenter As Boolean) As Map
	Dim emptyPane As Pane
	emptyPane.Initialize("")
	Dim cvs1 As B4XCanvas
	cvs1.Initialize(emptyPane)
	If rotation <> 0 Then
		f = fx.CreateFont(f.FamilyName,f.Size*upscaleRatioForRotation,bold,italic)
		boxWidth = boxWidth * upscaleRatioForRotation
		boxHeight = boxHeight * upscaleRatioForRotation
		' linespace is a ratio — (linespace-1)*lineWidth already upscaled via lineWidth, no need to scale linespace
		wordspace = wordspace * upscaleRatioForRotation
		padding = padding * upscaleRatioForRotation
	End If
	Dim vteCharLines As List

	If text=previousText And text<>"" Then
		vteCharLines=previousLines
	Else
		vteCharLines.Initialize
		Dim runs As List
		Dim useRichText As Boolean = Utils.getSetting("richtext",False)
		If useRichText Then
			Dim parser As BBCodeParser
			parser.Initialize
			runs = parser.Parse(text)
		Else
			runs.Initialize
			Dim run As TextRun
			run.Initialize
			run.text = text
			runs.Add(run)
		End If
		Dim vteChars As List
		vteChars.Initialize
		Dim totalTextSB As StringBuilder
		totalTextSB.Initialize
		For Each run As TextRun In runs
			totalTextSB.Append(run.text)
		Next
		Dim totalText As String = totalTextSB.ToString
		
		Dim offsetIndex As Int
		For Each run As TextRun In runs
			Dim fixedRectForRun As B4XRect
			fixedRectForRun.Initialize(0,0,f.Size,f.Size)
			Dim offsetX,offsetY As Double
			Dim horizontal As Boolean
			Dim runFont As Font
			Dim runColor As Paint = color
			Dim runSize As Double = f.Size
			Dim runWordspace As Int = wordspace
			If useRichText Then
				offsetX = run.offsetX * upscaleRatioForRotation
				offsetY = run.offsetY * upscaleRatioForRotation
				run.fontsize = run.fontsize * upscaleRatioForRotation
				horizontal = run.horizontal
				If run.color <> "" Then
					Dim r,g,b As Int
					r=Regex.Split(",",run.color)(0)
					g=Regex.Split(",",run.color)(1)
					b=Regex.Split(",",run.color)(2)
					runColor = fx.Colors.RGB(r,g,b)
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
				If run.fontsize <> 0 And run.fontsize <> f.Size Then
					runSize = run.fontsize
					fixedRectForRun.Initialize(0,0,run.fontsize,run.fontsize)
				End If
				If run.tracking <> -999 Then
					runWordspace=run.tracking
				End If
				runFont = fx.CreateFont(name,runSize,run.bold,run.italic)
			Else
				runFont = f
			End If
			If horizontal Then
				Dim c As String = Replace(run.text)
				Dim hte As HorizontalTextEngine
				hte.Initialize(mTargetLang,mDoNotBreakWords,mMinWordLengthForBreak)
				hte.GlobalRun = run
				Dim textImage As B4XBitmap = hte.Draw(emptyPane,c,runFont,name,runColor,bold,italic,False,fixedRectForRun.Width,fixedRectForRun.Height,"CENTER",0,0,0,"","",0).img
				
				Dim charItem As VerticalTextEngineChar
				charItem.Initialize
				charItem.text = c
				charItem.rect = fixedRectForRun
				charItem.runWordspace = runWordspace
				charItem.horizontal = True
				charItem.textImage = textImage
				charItem.imgHeight = textImage.Height
				charItem.imgWidth = textImage.Width
				charItem.offsetX = offsetX
				charItem.offsetY = offsetY
				vteChars.Add(charItem)
			Else
				For i=0 To run.text.Length-1
					Dim c As String=run.text.CharAt(i)
					If Regex.IsMatch("\n",c) Then
						vteCharLines.Add(vteChars)
						Dim vteChars As List
						vteChars.Initialize
					Else
						c = Replace(c)
						Dim charItem As VerticalTextEngineChar
						charItem.Initialize
						charItem.text = c
						charItem.rect = fixedRectForRun
						If IsZeroWordspaceChar(c) Then
							Dim previousCharIndex As Int = offsetIndex + i - 1
							If previousCharIndex >= 0 Then
								Dim previousChar As String = totalText.CharAt(previousCharIndex)
								If previousChar == c Then
									charItem.zeroWordspace = True
								End If
							End If
						End If
						
						If charItem.zeroWordspace = False Then
							charItem.runWordspace = runWordspace
						Else
							charItem.runWordspace = 0
						End If
						
						Dim metrices As Map
						If CharIsFreeHeight(c) Then
							charItem.fixedHeight = False
							metrices = GetCharImageSize(charItem,runFont,runWordspace,False,True,fixedRectForRun,padding)
						Else
							charItem.fixedHeight = True
							metrices = GetCharImageSize(charItem,runFont,runWordspace,True,True,fixedRectForRun,padding)
						End If
						'Dim out As OutputStream = File.OpenOutput(File.DirApp,i&".png",False)
						'textImage.WriteToStream(out,100,"PNG")
						'out.Close
						charItem.color = runColor
						charItem.f = runFont
						charItem.imgHeight = metrices.Get("imgHeight")
						charItem.imgWidth = metrices.Get("width")
						charItem.offsetX = offsetX
						charItem.offsetY = offsetY
						charItem.fixedWidth = True
						charItem.fixedRectForRun = fixedRectForRun
						charItem.padding = padding
						vteChars.Add(charItem)
					End If
				Next
			End If
			offsetIndex = offsetIndex + run.text.Length
		Next
		If vteChars.Size > 0 Then 'last line
			vteCharLines.Add(vteChars)
		End If
		previousLines=vteCharLines
		previousText=text
	End If
	
	If wrap Then
		vteCharLines=WrapText(vteCharLines,boxHeight,wordspace,boxWidth)
		previousLines=vteCharLines
	End If
	Dim result As Map=GetWidthAndHeight(vteCharLines,wordspace,linespace)
	result.Put("vteCharLines",vteCharLines)
	Return result
End Sub

Private Sub Draw2(text As String,f As Font,fontname As String,color As Paint,bold As Boolean,italic As Boolean,wordspace As Int,linespace As Double,padding As Int,wrap As Boolean,boxWidth As Int,boxHeight As Int, left2right As Boolean,rotation As Double,alignment As String,verticalCenter As Boolean) As B4XBitmap
	Dim result As Map = CalculateLayout(text,f,fontname,color,bold,italic,wordspace,linespace,padding,wrap,boxWidth,boxHeight,left2right,rotation,alignment,verticalCenter)
	Dim width,height As Double
	Dim WHs As List
	Dim vteCharLines As List = result.Get("vteCharLines")
	width=result.Get("width")
	height=Max(boxHeight,result.Get("height"))
	WHs=result.Get("WHs")
	Dim globalVerticalCenterOffset As Double = 0
	If alignment.Contains("LEFT") And verticalCenter Then
		globalVerticalCenterOffset = Max(0, (height - result.Get("height"))) / 2
	End If
	Dim bc As BitmapCreator
	bc.Initialize(width,height)
	Dim lineIndex As Int=0
	Dim previousWidth As Double
	For Each vteChars As List In vteCharLines
		Dim WH As Map=WHs.Get(lineIndex)
		Dim lineWidth As Double = WH.Get("width")
		Dim lineSpaceOffset As Double = 0
		If lineIndex <> vteCharLines.Size - 1 Then
			lineSpaceOffset = lineWidth*(linespace-1)
		End If
		lineIndex=lineIndex+1
		If vteChars.Size = 0 Then
			previousWidth=previousWidth+WH.Get("width")+lineSpaceOffset
			Continue
		End If
		Dim offsetY As Double = 0
		Dim firstChar As VerticalTextEngineChar = vteChars.Get(0)
		If CharMovingUpNeeded(firstChar.text) Then
			Dim emptyPane As Pane
			emptyPane.Initialize("")
			Dim canvas1 As B4XCanvas
			canvas1.Initialize(emptyPane)
			Dim fr As B4XRect=canvas1.MeasureText(firstChar.text,f)
			'offset = Max(Abs(fr.CenterY),fr.Height) - fixedRect.Height + wordspace
			offsetY = fr.Height - firstChar.rect.Height - fr.CenterY + wordspace
			If offsetY > 0 Then
				offsetY = 0
			End If
		End If
		
		If alignment.Contains("LEFT") = False Then
			Dim charsHeight As Int
			For Each charItem As VerticalTextEngineChar In vteChars
				charsHeight = charsHeight + charItem.imgHeight - Ceil(charItem.rect.Height)
			Next
			If alignment.Contains("CENTER") Then
				offsetY = offsetY + Max(0,(height - charsHeight)) / 2
			else if alignment.Contains("RIGHT") Then
				offsetY = offsetY + Max(0,height - charsHeight)
			End If
		End If
		offsetY = offsetY + globalVerticalCenterOffset
		
		Dim X As Double
		If left2right Then
			X = previousWidth
		Else
			X = previousWidth + lineSpaceOffset
		End If
		
		Dim Y As Double=offsetY
		Dim index As Int=0
		For Each charItem As VerticalTextEngineChar In vteChars
			Dim img As B4XBitmap
			If charItem.textImage.IsInitialized Then
				img = charItem.textImage
			Else
				img = Text2Image(charItem,charItem.f,charItem.run,charItem.color,charItem.runWordspace,charItem.fixedHeight,charItem.fixedWidth,charItem.fixedRectForRun,charItem.padding,charItem.offsetX,charItem.offsetY)
			End If
			If left2right == False Then
				X = width-(previousWidth+WH.Get("width"))
				If img.Width <> WH.Get("width")  Then
					X = X + WH.Get("width")/2 - img.Width/2
				End If
			Else
				X = previousWidth
				If img.Width <> WH.Get("width")  Then
					X = X + WH.Get("width")/2 - img.Width/2
				End If
			End If
			Dim YForDrawing As Int
			If charItem.horizontal Then
				YForDrawing = Y
			Else
				YForDrawing = Y - Ceil(charItem.rect.Height)
				If index = 0 Then
					YForDrawing = YForDrawing - charItem.runWordspace
					Y = Y + img.Height - Ceil(charItem.rect.Height) - charItem.runWordspace
				Else
					Y = Y + img.Height - Ceil(charItem.rect.Height)
				End If
			End If
			Dim rect As B4XRect
			rect.Initialize(X,YForDrawing,X+img.Width,YForDrawing+img.Height)

			bc.DrawBitmap(img,rect,False)
			
			index=index+1
		Next
		
		previousWidth=previousWidth+WH.Get("width")+lineSpaceOffset
	Next
	Return bc.Bitmap
End Sub

public Sub Replace(character As String) As String
	If mReplacingMap.IsInitialized Then
		If mReplacingMap.ContainsKey(character) Then
			Return mReplacingMap.Get(character)
		End If
	End If
	Return character
End Sub

Public Sub getText As String
	Dim sb As StringBuilder
	sb.Initialize
	For Each vteChars As List In previousLines
		For Each charItem As VerticalTextEngineChar In vteChars
			sb.Append(charItem.text)
		Next
		sb.Append(CRLF)
	Next
	Return sb.ToString.Trim
End Sub

Sub GetWidthAndHeight(lines As List,wordspace As Int,linespace As Double) As Map
	Dim lineSpaceAdded As Double
	Dim result As Map
	result.Initialize
	Dim width,height As Double
	Dim WHs As List
	WHs.Initialize
	Dim index As Int = 0
	Dim maxLineWidth As Double
	
	For Each vteChars As List In lines
		Dim WH As Map
		WH.Initialize
		Dim lineHeight As Double
		Dim lineWidth As Double
		If vteChars.Size > 0 Then
			Dim imageIndex As Int = 0
			For Each charItem As VerticalTextEngineChar In vteChars
				lineHeight=lineHeight+charItem.imgHeight - Ceil(charItem.rect.Height)
				
				If charItem.zeroWordspace Then
					lineHeight = lineHeight + wordspace
				Else
					If imageIndex = 0 Then
						lineHeight = lineHeight - charItem.runWordspace
					End If
				End If
				
				lineWidth=Max(lineWidth,charItem.imgWidth)
				imageIndex = imageIndex + 1
			Next
		End If
		width=width+Ceil(lineWidth)
		height=Max(lineHeight,height)
		maxLineWidth = Max(lineWidth,maxLineWidth)
		WH.Put("width",lineWidth)
		WH.Put("height",lineHeight)
		WHs.Add(WH)
		If index <> lines.Size -1 Then
			lineSpaceAdded = lineSpaceAdded + Ceil((linespace-1) * lineWidth)
		End If
		index = index + 1
	Next
	Dim index As Int
	For Each WH As Map In WHs
		Dim lineWidth As Double = WH.Get("width")
		If lineWidth = 0 Then 'empty text line
			WH.put("width",maxLineWidth)
			width = width + maxLineWidth
			If index <> lines.Size -1 Then
				lineSpaceAdded = lineSpaceAdded + Ceil((linespace-1) * maxLineWidth)
			End If
		End If
		index = index + 1
	Next
	width = width + lineSpaceAdded
	result.Put("width",width)
	result.Put("height",height)
	result.Put("WHs",WHs)
	Return result
End Sub

Sub WrapText(lines As List,boxHeight As Int,wordspace As Int,boxWidth As Int) As List
	Dim newLines As List
	newLines.Initialize
	Dim noPunctuationAtLineStart As Boolean = Utils.getSetting("no_punctuation_at_line_start",True)
	Dim previousWidth As Double = 0 '已经排好的列的总宽度，用于定位当前列在掩膜中的位置
	For i=0 To lines.Size-1
		Dim vteChars As List=lines.Get(i)
		If vteChars.Size = 0 Then
			newLines.Add(vteChars)
			Continue
		End If
		Dim splitedLines As List
		splitedLines.Initialize
		Dim heightSum As Int
		Dim index As Int=0
		Dim nextlineStartIndex As Int=0
		Dim columnWidth As Double = 0
		Dim columnLimit As Double = boxHeight
		Dim limitStartIndex As Int = -1
		For Each charItem As VerticalTextEngineChar In vteChars 'text line
			'进入新的一列时，计算这一列可用的高度。有气泡掩膜时用掩膜在该列处的实际高度
			If nextlineStartIndex <> limitStartIndex Then
				limitStartIndex = nextlineStartIndex
				Dim columnFirstChar As VerticalTextEngineChar = vteChars.Get(nextlineStartIndex)
				columnWidth = columnFirstChar.imgWidth
				columnLimit = boxHeight
				If mHasBalloonMask Then
					Dim maskHeight As Double = MaskColumnHeight(previousWidth,columnWidth,boxWidth,boxHeight)
					If maskHeight > 0 And maskHeight < columnLimit Then
						columnLimit = maskHeight
					End If
				End If
			End If
			Dim imgHeight As Double = charItem.imgHeight - Ceil(charItem.rect.Height)

			If charItem.zeroWordspace Then
				imgHeight = imgHeight + wordspace
			Else
				If index = 0 Then
					imgHeight = imgHeight - charItem.runWordspace
				End If
			End If

			heightSum=imgHeight+heightSum

			Dim shouldWrap As Boolean = False
			If index = vteChars.Size - 1 Then
				If heightSum > columnLimit Then shouldWrap = True
			Else
				If heightSum > columnLimit - imgHeight * 2 / 3 Then shouldWrap = True
			End If
			If shouldWrap Then
				Dim actualSplitEnd As Int = index
				If noPunctuationAtLineStart Then
					If index + 1 < vteChars.Size Then
						Dim nextChar As VerticalTextEngineChar = vteChars.Get(index + 1)
						If IsForbiddenLineStartChar(nextChar.text) Then
							' 确保上一行至少有2个字，避免上一行只剩1个字还为了避头标点把字符推到下一行
							If index > nextlineStartIndex + 1 Then
								If index + 1 < vteChars.Size - 1 Then 'not last char
									actualSplitEnd = index - 1
								End If
							End If
						End If
					End If
				End If
				Dim splittedChars As List
				splittedChars.Initialize
				For j=nextlineStartIndex To actualSplitEnd
					splittedChars.Add(vteChars.Get(j))
				Next
				splitedLines.Add(splittedChars)
				nextlineStartIndex=actualSplitEnd+1
				previousWidth = previousWidth + columnWidth
				If actualSplitEnd < index Then
					Dim movedChar As VerticalTextEngineChar = vteChars.Get(index)
					heightSum = movedChar.imgHeight - Ceil(movedChar.rect.Height)
					If movedChar.zeroWordspace Then
						heightSum = heightSum + wordspace
					End If
				Else
					heightSum=0
				End If
			End If
			index=index+1
		Next

		If nextlineStartIndex<=vteChars.Size-1 Then
			Dim splittedChars As List
			splittedChars.Initialize
			For j=nextlineStartIndex To vteChars.Size-1
				splittedChars.Add(vteChars.Get(j))
			Next
			splitedLines.Add(splittedChars)
		End If
		newLines.AddAll(splitedLines)
	Next
	' Push forbidden-start chars at last line back to previous line (no borrowing)
	If noPunctuationAtLineStart Then
		Do While newLines.Size > 1
			Dim lastLine As List = newLines.Get(newLines.Size - 1)
			If lastLine.Size = 0 Then
				newLines.RemoveAt(newLines.Size - 1)
				Continue
			End If
			Dim firstItem As VerticalTextEngineChar = lastLine.Get(0)
			If IsForbiddenLineStartChar(firstItem.text) = False Then Exit
			Dim prevLine As List = newLines.Get(newLines.Size - 2)
			If prevLine.Size = 1 Then Exit
			prevLine.Add(firstItem)
			lastLine.RemoveAt(0)
			If lastLine.Size = 0 Then
				newLines.RemoveAt(newLines.Size - 1)
			End If
		Loop
	End If

	Return newLines
End Sub

'设置气泡掩膜。offsetX/offsetY为文字框左上角在掩膜图像中的坐标。
'mask可以是彩色掩膜图像或二值掩膜。
Public Sub setBalloonMask(mask As cvMat,offsetX As Int,offsetY As Int)
	Dim gray As cvMat
	If mask.Channels = 1 Then
		gray = mask.cloneMat
	Else
		gray.Initialize(Null)
		cv2.cvtColor(mask,gray,"COLOR_BGR2GRAY")
	End If
	Dim binary As cvMat
	binary.Initialize(Null)
	cv2.threshold(gray,binary,30,255,cv2.procEnum("THRESH_BINARY"))
	gray.release
	If mHasBalloonMask Then
		mBalloonMask.release
	End If
	mBalloonMask = binary
	mBalloonMaskOffsetX = offsetX
	mBalloonMaskOffsetY = offsetY
	mHasBalloonMask = True
End Sub

'释放气泡掩膜
Public Sub releaseBalloonMask
	If mHasBalloonMask Then
		mBalloonMask.release
		mHasBalloonMask = False
	End If
End Sub

'量一下当前列在气泡掩膜里的实际高度。
'竖排文字从文字框右边开始往左排，previousWidth为已经排好的列总宽度。
'当前列最右边的一条线在掩膜中的x = 框的右边 - previousWidth（再减1是因为框的右边这个像素本身不属于列内）。
'maskX用来取这一列的可用高度（中心线），maskRightX是最右那条线：
'只有最右这条线所在的行也在掩膜内，字才不会从列右边（也就是朝向气泡外侧的那一边）露出去。
'horizontalMaskOffsetX / verticalMaskOffsetY为调用方设置的额外偏移（像素，正值表示文字相对掩膜往左/往下偏），
'所以量掩膜时x/y都要往右/往下加，这样算出来的可用高度与文字实际画的位置一致。
Private Sub MaskColumnHeight(previousWidth As Double,columnWidth As Double,boxWidth As Int,boxHeight As Int) As Double
	Dim maskX As Int = mBalloonMaskOffsetX + boxWidth - Floor(previousWidth) - Floor(columnWidth/2) + horizontalMaskOffsetX
	Dim maskRightX As Int = mBalloonMaskOffsetX + boxWidth - Floor(previousWidth) - 1 + horizontalMaskOffsetX
	Dim cols As Int = mBalloonMask.Cols
	Dim rows As Int = mBalloonMask.Rows
	If maskX < 0 Or maskX >= cols Then Return 0
	If maskRightX < 0 Or maskRightX >= cols Then Return 0
	Dim top As Int = -1
	Dim bottom As Int = -1
	Dim yStart As Int = Max(mBalloonMaskOffsetY,0) + verticalMaskOffsetY
	Dim yEnd As Int = Min(mBalloonMaskOffsetY+boxHeight,rows)-1 + verticalMaskOffsetY
	If yEnd > rows - 1 Then yEnd = rows - 1
	If yStart > yEnd Then Return 0
	For y = yStart To yEnd
		Dim value() As Double = mBalloonMask.get(Array As Int(y,maskX))
		Dim rightValue() As Double = mBalloonMask.get(Array As Int(y,maskRightX))
		If value(0) > 0 And rightValue(0) > 0 Then
			If top = -1 Then top = y
			bottom = y
		End If
	Next
	If top = -1 Then Return 0
	Return bottom - top + 1
End Sub

Private Sub GetCharImageSize(c As VerticalTextEngineChar,f As Font,wordspace As Int,fixedHeight As Boolean,fixedWidth As Boolean,fixedRect As B4XRect,padding As Double) As Map
	wordspace = wordspace + 5
	
	Dim emptyPane As Pane
	emptyPane.Initialize("")
	
	If c.zeroWordspace Then
		wordspace = 0
	End If
	
	Dim cvs1 As B4XCanvas
	cvs1.Initialize(emptyPane)
	
	Dim r As B4XRect = cvs1.MeasureText(c.text,f)
	
	Dim width,height As Double
	
	If fixedWidth Then
		width = Ceil(fixedRect.Width)
	Else
		width = Ceil(r.Width)
	End If
	
	If fixedHeight Then
		height = Ceil(fixedRect.Height)
	Else
		height = Ceil(r.Height)
	End If
	
	Dim upperRoom As Double = Ceil(fixedRect.Height)
	height = height + upperRoom
	
	Dim m As Map
	m.Initialize
	m.Put("width",width)
	m.Put("height",height)
	m.Put("upperRoom",upperRoom)
	m.Put("rect",r)
	m.Put("wordspace",wordspace)
	m.Put("imgHeight",height + wordspace + padding)
	Return m
End Sub

Private Sub DrawTextImage(c As VerticalTextEngineChar,f As Font,color As Paint,wordspace As Int,fixedHeight As Boolean,fixedWidth As Boolean,fixedRect As B4XRect,padding As Double,shiftX As Double,shiftY As Double) As B4XBitmap
	Dim metrics As Map = GetCharImageSize(c,f,wordspace,fixedHeight,fixedWidth,fixedRect,padding)
	Dim r As B4XRect = metrics.Get("rect")
	Dim width,height,upperRoom As Double
	width = metrics.Get("width")
	height = metrics.Get("height")
	upperRoom = metrics.Get("upperRoom")
	wordspace = metrics.Get("wordspace")
	
	If mOffsetRulesMap.ContainsKey(c.text) Then
		Dim offsetRule As Map = mOffsetRulesMap.Get(c.text)
		Dim offsetX,offsetY,fontSize As Double
		offsetX = offsetRule.Get("x")
		offsetY = offsetRule.Get("y")
		fontSize = offsetRule.Get("fontsize")
		shiftX = shiftX + f.Size/fontSize*offsetX
		shiftY = shiftY + f.Size/fontSize*offsetY
	End If
	
	Dim X,Y As Double
	
	'默认左对齐（基于字格）
	X = shiftX
	
	Y = height + wordspace + padding + shiftY
	
	Dim Canvas1 As Canvas
	Canvas1.Initialize("")
	Canvas1.SetSize(width,height + wordspace + padding)
	
	Dim jo As JavaObject
	jo = Canvas1
	
	Dim enum As EnumClass
	enum.Initialize("javafx.geometry.VPos")
	
	Dim context As JavaObject = jo.RunMethod("getGraphicsContext2D",Null)
	context.RunMethod("setTextBaseline",Array(enum.ValueOf("BOTTOM")))
	
	'================================
	' 手动视觉对齐（基于 fixedRect）
	'================================
	
	If CharIsCenterAligned(c.text) Then
		'视觉居中
		X = (fixedRect.Width - r.Width) / 2 - r.Left + shiftX
	Else If CharIsRightAligned(c.text) Then
		'视觉右上对齐
		X = fixedRect.Width - Ceil(r.Width) - Ceil(r.Left) + shiftX
		Y = r.Height + Abs(r.Top) + shiftY + upperRoom + wordspace + padding
	End If
	
	'================================
	' 旋转字符
	'================================
	
	If CharNeedRotation(c.text) Then
		Y = r.Width + r.Left + shiftY + upperRoom
		If CharIsCenterAligned(c.text) Then
			X = shiftX - r.Height/2
			Y = Y + wordspace + padding
			Canvas1.DrawTextRotated(c.text,X,Y,f,color,"RIGHT",90)
		Else
			Canvas1.DrawTextRotated(c.text,X,Y,f,color,"RIGHT",-90)
		End If
	Else
		If fixedHeight = True And fixedWidth = False Then
			Y = fixedRect.Height + shiftY + upperRoom
		End If
		Canvas1.DrawText(c.text,X,Y,f,color,"LEFT")
	End If
	
	Dim m As B4XBitmap = Canvas1.Snapshot2(fx.Colors.Transparent)
	Return m
End Sub

Sub Text2Image(c As VerticalTextEngineChar,f As Font,run As TextRun,color As Paint,wordspace As Int,fixedHeight As Boolean,fixedWidth As Boolean,fixedRect As B4XRect,padding As Double,shiftX As Double,shiftY As Double) As B4XBitmap
	Dim m As B4XBitmap = DrawTextImage(c,f,color,wordspace,fixedHeight,fixedWidth,fixedRect,padding,shiftX,shiftY)
	If Utils.getSetting("smart_alignment_correction",True) Then
		If CharNeedRotation(c.text) And CharIsCenterAligned(c.text) Then
			Dim calcSize As Int
			Dim fixedSizeImage As B4XBitmap
			If f.Size > 50 Then
				calcSize = 50
				Dim fixedRectForRun As B4XRect
				fixedRectForRun.Initialize(0,0,calcSize,calcSize)
				Dim fixedFont As Font = fx.CreateFont(f.FamilyName,calcSize,run.bold,run.italic)
				fixedSizeImage = DrawTextImage(c,fixedFont,color,wordspace,fixedHeight,fixedWidth,fixedRectForRun,padding,shiftX,shiftY)
			Else
				calcSize = f.Size
				fixedSizeImage = m
			End If
			Dim bounds As B4XRect = GetContentBounds(fixedSizeImage)
			Dim offset As Double = fixedSizeImage.Width/2 - bounds.CenterX
			Dim offsetY As Double = 0
			If c.zeroWordspace And f.Size > 50 Then
				offsetY = 0 - bounds.Top + calcSize
			Else If c.zeroWordspace Then
				offsetY = 0 - bounds.Top + fixedRect.Height
			End If
			If Abs(offset) > 0.5 Or Abs(offsetY) > 0.5 Then
				offset = (offset * f.Size / calcSize + shiftX)
				offsetY = (offsetY * f.Size / calcSize + shiftY)
				Dim bc As BitmapCreator
				bc.Initialize(m.Width, m.Height)
				Dim rr As B4XRect
				rr.Initialize(offset,offsetY,m.Width+offset,m.Height+offsetY)
				' 绘制一些内容（例如红色矩形）
				bc.DrawBitmap(m,rr,True)
				m = bc.Bitmap
			End If
		End If
	End If
	Return m
End Sub


' 检测图像内容的实际边界（跳过透明区域）
Sub GetContentBounds(m As B4XBitmap) As B4XRect
	Dim bc As BitmapCreator
	bc.Initialize(m.Width, m.Height)
	Dim rr As B4XRect
	rr.Initialize(0,0,m.Width,m.Height)
	' 绘制一些内容（例如红色矩形）
	bc.DrawBitmap(m,rr,True)
	Dim Left As Int = bc.mWidth, Top As Int = bc.mHeight
	Dim Right As Int = 0, Bottom As Int = 0
	Dim HasContent As Boolean = False
	Dim xui As XUI
	For x = 0 To bc.mWidth - 1
		For y = 0 To bc.mHeight - 1
			Dim Color As Int = bc.GetColor(x, y)
			If Color <> xui.Color_Transparent  Then  ' 非完全透明
				HasContent = True
				If x < Left Then Left = x
				If x > Right Then Right = x
				If y < Top Then Top = y
				If y > Bottom Then Bottom = y
			End If
		Next
	Next
    
	Dim rect As B4XRect
	If HasContent Then
		rect.Initialize(Left, Top, Right + 1, Bottom + 1)
	Else
		' 如果没有内容，返回整个画布
		rect.Initialize(0, 0, bc.mWidth, bc.mHeight)
	End If
	Return rect
End Sub

Sub IsZeroWordspaceChar(c As String) As Boolean
	Try
		Return Regex.IsMatch(mZeroWordspaceRules,c)
	Catch
		Log(LastException)
		Return False
	End Try
End Sub

Sub CharNeedRotation(c As String) As Boolean
	Try
		Return Regex.IsMatch(mRotationRules,c)
	Catch
		Log(LastException)
		Return Regex.IsMatch(presetRotationRules,c)
	End Try
End Sub

Sub CharIsCenterAligned(c As String) As Boolean
	Try
		Return Regex.IsMatch(mCenterAlignRules,c)
	Catch
		Log(LastException)
		Return Regex.IsMatch(presetCenterAlignRules,c)
	End Try
End Sub

Sub CharMovingUpNeeded(c As String) As Boolean
	If mFirstCharToMoveUpRules = "" Then
		Return False
	End If
	Try
		Return Regex.IsMatch(mFirstCharToMoveUpRules,c)
	Catch
		Return False
	End Try
End Sub

Sub CharISNumberCharacter(c As String) As Boolean
	Return Regex.IsMatch("[⁉0-9a-zA-Z]",c)
End Sub

Sub CharISEnglishPuctuations(c As String) As Boolean
	Return Regex.IsMatch("[\.,!?]",c)
End Sub

Sub CharIsRightAligned(c As String) As Boolean
	Try
		Return Regex.IsMatch(mRightAlignRules,c)
	Catch
		Log(LastException)
		Return Regex.IsMatch(presetRightAlignRules,c)
	End Try
End Sub

private Sub CharIsFreeHeight(c As String) As Boolean
	Try
		Return Regex.IsMatch(mFreeHeightRules,c)
	Catch
		Log(LastException)
	End Try
	Return False
End Sub


Private Sub IsForbiddenLineStartChar(c As String) As Boolean
	Return Regex.IsMatch("[︵︶」﹂﹄”，。！？：；、》」』】〕〉）］｝．〃々.,;:!?)\]}]", c)
End Sub

Public Sub setOffsetRulesMap(rules As Map)
	mOffsetRulesMap = rules
End Sub

Public Sub setFreeHeightRules(rules As String)
	mFreeHeightRules = rules
End Sub

Public Sub setRightAlignRules(rules As String)
	mRightAlignRules = rules
End Sub

Public Sub setCenterAlignRules(rules As String)
	mCenterAlignRules = rules
End Sub

Public Sub setRotationRules(rules As String)
	mRotationRules = rules
End Sub

Public Sub setZeroWordspaceRules(rules As String)
	mZeroWordspaceRules = rules
End Sub

Public Sub setFirstCharToMoveUpRules(rules As String)
	mFirstCharToMoveUpRules = rules
End Sub

Public Sub setReplacingJSON(json As String)
	If json = "" Then
		Return
	End If
	Try
		Dim parser As JSONParser
		parser.Initialize(json)
		mReplacingMap = parser.NextObject
	Catch
		Log(LastException)
	End Try
End Sub
