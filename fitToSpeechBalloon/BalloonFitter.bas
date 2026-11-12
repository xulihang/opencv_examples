B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=StaticCode
Version=8.8
@EndOfDesignText@
'Static code module
'根据气泡掩膜调整文字框，避免框超出气泡

Sub Process_Globals
End Sub

'传入boxes（每个元素为包含geometry的Map）和掩膜图像，返回调整后的boxes。
'对每个box，找到与其重叠像素最多的气泡，再把box收缩为该气泡掩膜内的最大矩形。
'未匹配到气泡的box保持原样。返回新的List和新的Map，不会修改传入的boxes。
Public Sub FitBoxes(boxes As List,mask As cvMat) As List
	Dim result As List
	result.Initialize
	Dim bubbleData As Map = BubbleDataFromMask(mask)
	For i = 0 To boxes.Size - 1
		Dim box As Map = boxes.Get(i)
		Dim newBox As Map = CopyMap(box)
		If box.ContainsKey("geometry") Then
			Dim fitted As Map = FitGeometry(box.Get("geometry"),bubbleData)
			If fitted <> Null Then
				newBox.Put("geometry",fitted)
			End If
		End If
		result.Add(newBox)
	Next
	Return result
End Sub

'把掩膜图像转换成二值气泡掩膜，再统计连通区域
Private Sub BubbleDataFromMask(mask As cvMat) As Map
	Dim gray As cvMat
	If mask.Channels = 1 Then
		gray = mask.cloneMat
	Else
		gray.Initialize(Null)
		cv2.cvtColor(mask,gray,"COLOR_BGR2GRAY")
	End If
	Dim bubbles As cvMat
	bubbles.Initialize(Null)
	cv2.threshold(gray,bubbles,30,255,cv2.procEnum("THRESH_BINARY"))
	Dim bubbleData As Map = ConnectedBubbles(bubbles)
	gray.release
	bubbles.release
	Return bubbleData
End Sub

'计算气泡连通区域，返回每个气泡的外接框以及完整的labels数据
Private Sub ConnectedBubbles(bubbles As cvMat) As Map
	Dim labels As cvMat
	labels.Initialize(Null)
	Dim stats As cvMat
	stats.Initialize(Null)
	Dim centroids As cvMat
	centroids.Initialize(Null)
	Dim count As Int = cv2.connectedComponentsWithStats(bubbles,labels,stats,centroids)
	Dim cols As Int = labels.Cols
	Dim rows As Int = labels.Rows
	Dim size As Int = rows * cols
	Dim labelData(size) As Int
	labels.getJO.RunMethodJO("get",Array(0,0,labelData))
	Dim statsJO As JavaObject = stats.getJO
	Dim bubbleList As List
	bubbleList.Initialize
	For i = 1 To count - 1
		'0: x, 1: y, 2: w, 3: h, 4: area
		Dim info(5) As Int
		statsJO.RunMethodJO("get",Array(i,0,info))
		If info(4) > 20 Then
			Dim bubble As Map = MakeGeometry(info(0),info(1),info(2),info(3))
			bubble.Put("label",i)
			bubbleList.Add(bubble)
		End If
	Next
	labels.release
	stats.release
	centroids.release
	Dim result As Map
	result.Initialize
	result.Put("labels",labelData)
	result.Put("cols",cols)
	result.Put("rows",rows)
	result.Put("bubbles",bubbleList)
	Return result
End Sub

'先找出box内像素最多的气泡，再把box收缩到该气泡掩膜内
Private Sub FitGeometry(geometry As Map,bubbleData As Map) As Map
	Dim bubble As Map = BestBubbleForBox(geometry,bubbleData)
	If bubble = Null Then Return Null
	Return LargestRectInBubble(geometry,bubble,bubbleData)
End Sub

'统计box内各气泡的像素数，返回像素数最多的气泡
Private Sub BestBubbleForBox(geometry As Map,bubbleData As Map) As Map
	Dim X As Int = geometry.Get("X")
	Dim Y As Int = geometry.Get("Y")
	Dim width As Int = geometry.Get("width")
	Dim height As Int = geometry.Get("height")
	Dim labelData() As Int = bubbleData.Get("labels")
	Dim cols As Int = bubbleData.Get("cols")
	Dim rows As Int = bubbleData.Get("rows")
	Dim left As Int = Max(X,0)
	Dim top As Int = Max(Y,0)
	Dim right As Int = Min(X+width,cols)
	Dim bottom As Int = Min(Y+height,rows)
	Dim counts As Map
	counts.Initialize
	For yy = top To bottom - 1
		For xx = left To right - 1
			Dim label As Int = labelData(yy*cols+xx)
			If label > 0 Then
				If counts.ContainsKey(label) Then
					Dim current As Int = counts.Get(label)
					counts.Put(label,current+1)
				Else
					counts.Put(label,1)
				End If
			End If
		Next
	Next
	Dim bestLabel As Int = 0
	Dim bestCount As Int = 0
	For Each key As Object In counts.Keys
		Dim c As Int = counts.Get(key)
		If c > bestCount Then
			bestCount = c
			bestLabel = key
		End If
	Next
	If bestLabel = 0 Then Return Null
	Dim bubbleList As List = bubbleData.Get("bubbles")
	For i = 0 To bubbleList.Size - 1
		Dim bubble As Map = bubbleList.Get(i)
		Dim bubbleLabel As Int = bubble.Get("label")
		If bubbleLabel = bestLabel Then Return bubble
	Next
	Return Null
End Sub

'在box和气泡外接框的交集范围内，用直方图法求完全落在气泡掩膜内的最大矩形
Private Sub LargestRectInBubble(geometry As Map,bubble As Map,bubbleData As Map) As Map
	Dim X As Int = geometry.Get("X")
	Dim Y As Int = geometry.Get("Y")
	Dim width As Int = geometry.Get("width")
	Dim height As Int = geometry.Get("height")
	Dim bubbleX As Int = bubble.Get("X")
	Dim bubbleY As Int = bubble.Get("Y")
	Dim bubbleWidth As Int = bubble.Get("width")
	Dim bubbleHeight As Int = bubble.Get("height")
	Dim bubbleLabel As Int = bubble.Get("label")
	Dim left As Int = Max(X,bubbleX)
	Dim top As Int = Max(Y,bubbleY)
	Dim right As Int = Min(X+width,bubbleX+bubbleWidth)
	Dim bottom As Int = Min(Y+height,bubbleY+bubbleHeight)
	If right <= left Or bottom <= top Then Return Null
	Dim regionWidth As Int = right - left
	Dim regionHeight As Int = bottom - top
	Dim labelData() As Int = bubbleData.Get("labels")
	Dim cols As Int = bubbleData.Get("cols")
	Dim heights(regionWidth) As Int
	Dim stackX(regionWidth+1) As Int
	Dim stackH(regionWidth+1) As Int
	Dim bestArea As Int = 0
	Dim bestX As Int = 0
	Dim bestY As Int = 0
	Dim bestWidth As Int = 0
	Dim bestHeight As Int = 0
	For ly = 0 To regionHeight - 1
		Dim row As Int = top + ly
		For lx = 0 To regionWidth - 1
			If labelData(row*cols+left+lx) = bubbleLabel Then
				heights(lx) = heights(lx) + 1
			Else
				heights(lx) = 0
			End If
		Next
		Dim stackTop As Int = 0
		For lx = 0 To regionWidth
			Dim h As Int = 0
			If lx < regionWidth Then h = heights(lx)
			Dim start As Int = lx
			Do While stackTop > 0
				Dim sh As Int = stackH(stackTop-1)
				If sh <= h Then Exit
				stackTop = stackTop - 1
				Dim sx As Int = stackX(stackTop)
				Dim area As Int = (lx - sx) * sh
				If area > bestArea Then
					bestArea = area
					bestX = left + sx
					bestY = row - sh + 1
					bestWidth = lx - sx
					bestHeight = sh
				End If
				start = sx
			Loop
			stackX(stackTop) = start
			stackH(stackTop) = h
			stackTop = stackTop + 1
		Next
	Next
	If bestArea = 0 Then Return Null
	Return MakeGeometry(bestX,bestY,bestWidth,bestHeight)
End Sub

Private Sub MakeGeometry(X As Int,Y As Int,width As Int,height As Int) As Map
	Dim geometry As Map
	geometry.Initialize
	geometry.Put("X",X)
	geometry.Put("Y",Y)
	geometry.Put("width",width)
	geometry.Put("height",height)
	Return geometry
End Sub

Private Sub CopyMap(source As Map) As Map
	Dim result As Map
	result.Initialize
	For Each key As Object In source.Keys
		result.Put(key,source.Get(key))
	Next
	Return result
End Sub
