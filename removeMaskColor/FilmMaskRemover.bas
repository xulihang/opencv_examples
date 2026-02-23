B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=10
@EndOfDesignText@
Sub Class_Globals
	Private fx As JFX
End Sub

'Initializes the object. You can add parameters to this method if needed.
Public Sub Initialize
	
End Sub

' 统计数组中等于指定值的像素数量
Sub CountPixels(channel As cvMat, value As Int) As Int
	Dim mask As cvMat
	mask = cv2.matZeros(Array(channel.size, cv2.cvType("CV_8UC1")))
    
	' 创建掩码：等于指定值的像素设为255
	cv2.compare(channel, cv2.ScalarSingle(value), mask, cv2.coreEnum("CMP_EQ"))
    
	' 计算非零像素数量
	Return cv2.countNonZero(mask)
End Sub

' 对单个通道进行线性调整（去色罩）
Sub AdjustChannel(channel As cvMat) As cvMat
	Dim minVal As Double
	Dim maxVal As Double
	Dim minLoc As JavaObject
	Dim maxLoc As JavaObject
	Dim mask As cvMat = cv2.matZeros(Array(channel.size, cv2.cvType("CV_8UC1")))
    
	' 获取通道的最小值和最大值
	Dim minMaxLoc As JavaObject
	minMaxLoc.InitializeStatic("org.opencv.core.Core")
	Dim result As JavaObject = minMaxLoc.RunMethod("minMaxLoc", Array(channel.JO))
	minVal = result.GetField("minVal")
	maxVal =  result.GetField("maxVal")
	minLoc =  result.GetField("minLoc")
	maxLoc =  result.GetField("maxLoc")
    
	Dim x1 As Int = minVal
	Dim x2 As Int = maxVal
    
	' 忽略极少数异常像素点（少于100个像素的点被忽略）
	Do While True
		If CountPixels(channel, x1) <= 100 Then
			x1 = x1 + 2
		Else
			Log($"  下端点: ${x1}"$)
			Exit
		End If
	Loop
    
	Do While True
		If CountPixels(channel, x2) <= 100 Then
			x2 = x2 - 1
		Else
			Log($"  上端点: ${x2}"$)
			Exit
		End If
	Loop
    
	' 目标范围：黑色(0)到白色(255)
	Dim y1 As Double = 0  ' 黑色
	Dim y2 As Double = 255 ' 白色
    
	' 计算线性变换参数 y = kx + b
	Dim f_k As Double = (y2 - y1) / (x2 - x1)
	Dim f_b As Double = y1 - f_k * x1
    
	' 创建浮点格式的副本进行计算
	Dim channelFloat As cvMat = cv2.matZeros(Array(channel.size, cv2.cvType("CV_32FC1")))
	cv2.convertTo(channel, channelFloat, cv2.cvType("CV_32FC1"), 1.0, 0.0)
    
	' 应用线性变换：乘以系数然后加偏移
	Dim adjustedFloat As cvMat = cv2.matZeros(Array(channel.size, cv2.cvType("CV_32FC1")))
	cv2.multiplyScalar(channelFloat, f_k, adjustedFloat)
	Dim offsetMat As cvMat = cv2.matOnes(Array(channel.size, cv2.cvType("CV_32FC1")))
	cv2.multiplyScalar(offsetMat, f_b, offsetMat)
	cv2.add(adjustedFloat, offsetMat, adjustedFloat)
    
	' 转换回8位并裁剪值范围
	Dim adjusted As cvMat = cv2.matZeros(Array(channel.size, cv2.cvType("CV_8UC1")))
	cv2.convertTo(adjustedFloat, adjusted, cv2.cvType("CV_8UC1"), 1.0, 0.0)
    
	' 确保值在0-255范围内（convertTo会自动裁剪）
    
	Return adjusted
End Sub

' 处理单张图片
Sub Process(filePath As String, outputPath As String)
	' 读取图片
	Dim img As cvMat = cv2.imread(filePath)
    
	If img.JO.IsInitialized = False Then
		Log($"错误：无法读取图片 ${filePath}"$)
		Return
	End If
    
	' 检查图像深度，转换为8位图像
	Dim depth As Int = cv2.getDepth(img)
	If depth <> cv2.cvType("CV_8U") Then
		If depth = cv2.cvType("CV_16U") Then
			' 16位图像转换为8位
			cv2.convertTo(img, img, cv2.cvType("CV_8UC3"), 1.0/256.0, 0.0)
		Else
			' 归一化到8位
			cv2.normalize(img, img, 0, 255, cv2.coreEnum("NORM_MINMAX"), cv2.cvType("CV_8UC3"), Null)
		End If
	End If
    
	' 分离BGR通道
	Dim channels As List
	channels.Initialize
	cv2.split(img, channels)
    
	Dim b As cvMat = cv2.matJO2mat(channels.Get(0))
	Dim g As cvMat = cv2.matJO2mat(channels.Get(1))
	Dim r As cvMat = cv2.matJO2mat(channels.Get(2))
    
	' 对每个通道应用去色罩操作
	Log("  调整蓝色通道...")
	Dim b_adj As cvMat = AdjustChannel(b)
	Log("  调整绿色通道...")
	Dim g_adj As cvMat = AdjustChannel(g)
	Log("  调整红色通道...")
	Dim r_adj As cvMat = AdjustChannel(r)
    
	' 合并调整后的通道
	Dim adjustedChannels As List
	adjustedChannels.Initialize
	adjustedChannels.Add(b_adj.JO)
	adjustedChannels.Add(g_adj.JO)
	adjustedChannels.Add(r_adj.JO)
    
	Dim img_adjusted As cvMat = cv2.matZeros(Array(img.size, cv2.cvType("CV_8UC3")))
	cv2.merge(adjustedChannels, img_adjusted)
    
	' 保存结果
	cv2.imwrite(outputPath, img_adjusted)
	Log($"  已保存: ${outputPath}"$)
End Sub