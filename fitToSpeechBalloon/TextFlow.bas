B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=3.71
@EndOfDesignText@
'Class module
Sub Class_Globals
	Private fx As JFX
	Public texts As List
	Private lastItem As JavaObject
	Private allText As StringBuilder
	Private textInDisplay As StringBuilder
	Public TextAlignment As JavaObject
End Sub

Public Sub Initialize
	texts.Initialize
	allText.Initialize
	textInDisplay.Initialize
	TextAlignment.InitializeStatic("javafx.scene.text.TextAlignment")
End Sub

Public Sub AddText(Text As String) As TextFlow
	Dim lastItem As JavaObject
	lastItem.InitializeNewInstance("javafx.scene.text.Text", Array(Text))
	texts.Add(lastItem)
	allText.Append(Text)
	textInDisplay.Append(Text)
	Return Me
End Sub

Public Sub AddTextForTracking(space As Int) As TextFlow
	Dim lastItem As JavaObject
	lastItem.InitializeNewInstance("javafx.scene.text.Text", Array(" "))
	CSSUtils.SetStyleProperty(lastItem,"-fx-font-family","monospace")
	CSSUtils.SetStyleProperty(lastItem,"-fx-font-size",space&"px")
	texts.Add(lastItem)
	Return Me
End Sub

Public Sub AddTextWithStrikethrough(text As String,realText As String) As TextFlow
	Dim lastItem As JavaObject
	lastItem.InitializeNewInstance("javafx.scene.text.Text", Array(text))
	textInDisplay.Append(text)
	texts.Add(lastItem)
	allText.Append(realText)
	lastItem.RunMethod("setStrikethrough", Array(True))
	Return Me
End Sub

Public Sub AddMonoText(text As String) As TextFlow
	allText.Append(text)
	textInDisplay.Append(text)
	Dim lastItem As JavaObject
	lastItem.InitializeNewInstance("javafx.scene.text.Text", Array(text))
	CSSUtils.SetStyleProperty(lastItem," -fx-font-family","monospace")
	texts.Add(lastItem)
	Return Me
End Sub

Public Sub getText As String
	Return allText.ToString
End Sub

Public Sub getTextInDisplay As String
	Return textInDisplay.ToString
End Sub

Public Sub SetFontWithCSS(weight As String,size As Double,familyName As String,style As String) As TextFlow
	Dim sb As StringBuilder
	sb.Initialize
	sb.Append(style).Append(" ")
	sb.Append(weight).Append(" ")
	sb.Append(size).Append(" ")
	sb.Append($"""$&familyName&$"""$)
	'sb.Append($""Helvetica""$)
	'Log(sb.ToString)
	lastItem.RunMethod("setStyle",Array("-fx-font: "&sb.ToString))
	'lastItem.RunMethod("setStyle",Array("-fx-font-size: "&size&"px"))
	'lastItem.RunMethod("setStyle",Array("-fx-font-family: "&familyName))
	'lastItem.RunMethod("setStyle",Array("-fx-font-style: "&style))
	Return Me
End Sub

Public Sub SetStroke(rgb As String,width As Int) As TextFlow
	lastItem.RunMethod("setStyle",Array("-fx-stroke: rgb("&rgb&")"))
	lastItem.RunMethod("setStyle",Array("-fx-stroke-width: "&width))
	Return Me
End Sub

public Sub SetTranslateX(space As Int) As TextFlow
	CSSUtils.SetStyleProperty(lastItem,"-fx-translate-x",space)
	Return Me
End Sub

public Sub SetTranslateY(space As Int) As TextFlow
	CSSUtils.SetStyleProperty(lastItem,"-fx-translate-y",space)
	Return Me
End Sub

Public Sub SetItalic(bold As Boolean) As TextFlow
	Dim Font As Font=lastItem.RunMethod("getFont", Null)
	Font=fx.CreateFont(Font.FamilyName,Font.Size,bold,True)
	lastItem.RunMethod("setFont", Array(Font))
	Return Me
End Sub

Public Sub SetFont(Font As Font) As TextFlow
	lastItem.RunMethod("setFont", Array(Font))
	Return Me
End Sub

Public Sub SetColor(Color As Paint) As TextFlow
	lastItem.RunMethod("setFill", Array(Color))
	Return Me	
End Sub


Public Sub SetClassName(className As String) As TextFlow
	Dim n As Node = lastItem
	n.StyleClasses.Add(className)
	Return Me
End Sub


Public Sub SetUnderline(Underline As Boolean) As TextFlow
	lastItem.RunMethod("setUnderline", Array(Underline))
	Return Me
End Sub

Public Sub SetStrikethrough(Strikethrough As Boolean) As TextFlow
	lastItem.RunMethod("setStrikethrough", Array(Strikethrough))
	Return Me
End Sub

Public Sub SetFauxItalic(linespace As Double,offset As Double,YDiff As Double,heightDiff As Double) As TextFlow
	Dim item As JavaObject = lastItem
    
	' 先获取原始边界
	Dim Bounds As B4XRect = GetLayoutBounds(item)
	Dim originalWidth As Double = Bounds.Width
	Dim originalHeight As Double = Bounds.Height
	Dim ratio As Double = originalHeight / 10
	' 计算斜体变换
	Dim shearValue As Double = -(offset / originalHeight) * ratio ' 倾斜值，可根据需要调整
    
	' 应用AffineTransform
	Dim AT As JavaObject
	AT.InitializeNewInstance("javafx.scene.transform.Affine", Null)
	AT.RunMethod("appendShear", Array(shearValue, 0.0))
    
	' 清除之前的变换
	'item.RunMethodJO("getTransforms", Null).RunMethod("clear", Null)
	item.RunMethodJO("getTransforms", Null).RunMethod("add", Array(AT))
    
	' 计算变换后的新尺寸
	' 倾斜后的宽度会增加：新宽度 = 原宽度 + 原高度 * 倾斜值
	Dim newWidth As Double = originalWidth + (originalHeight * shearValue)
	
	' 应用Y轴偏移
	item.RunMethod("setTranslateY", Array(YDiff))
    
	' 如果需要水平偏移来补偿倾斜
	Dim xOffset As Double = (newWidth - originalWidth) / 2
	item.RunMethod("setTranslateX", Array(-xOffset))
    
	Return Me
End Sub

Public Sub SetFauxBold(color As Paint,strokeWidth As Double) As TextFlow
	Dim item As JavaObject = lastItem
	item.RunMethod("setStroke",Array(color))
	item.RunMethod("setStrokeWidth",Array(strokeWidth))
	'Dim pixel As Int  = fx.Colors.To32Bit(color)
	'Dim rgba(4) As Int = Utils.GetRGBA(pixel)
	'Dim sb As StringBuilder
	'sb.Initialize
	'sb.Append(rgba(0))
	'sb.Append(",")
	'sb.Append(rgba(1))
	'sb.Append(",")
	'sb.Append(rgba(2))
	'sb.Append(",")
	'sb.Append(1)
	'CSSUtils.SetStyleProperty(item,"-fx-effect","dropshadow( three-pass-box , rgba("&sb.ToString&") , "&strokeWidth&" , 1 , 0 , 0 )")
	Return Me
End Sub

Public Sub GetLayoutBounds(TextClass As JavaObject) As B4XRect
	Dim Bounds As JavaObject = TextClass.RunMethod("getLayoutBounds",Null)
	Dim R As B4XRect
	R.Initialize(Bounds.RunMethod("getMinX",Null),Bounds.RunMethod("getMinY",Null),Bounds.RunMethod("getMaxX",Null),Bounds.RunMethod("getMaxY",Null))
	Return R
End Sub

Public Sub Reset As TextFlow
	texts.Initialize
	Return Me
End Sub


Public Sub CreateTextFlowWithWidth(width As Double) As Pane
	Dim tf As JavaObject
	tf.InitializeNewInstance("javafx.scene.text.TextFlow", Null)
	tf.RunMethodJO("getChildren", Null).RunMethod("addAll", Array(texts))
	tf.RunMethod("setMaxWidth",Array(width))
	Return tf
End Sub

Public Sub CreateTextFlow As Pane
	Dim tf As JavaObject
	tf.InitializeNewInstance("javafx.scene.text.TextFlow", Null)
	tf.RunMethodJO("getChildren", Null).RunMethod("addAll", Array(texts))
	Return tf
End Sub

' LEFT,CENTER,RIGHT,JUSTIFY
Public Sub CreateTextFlowWithAlignmentAndWidth(alignment As String,width As Double) As Pane
	Dim tf As JavaObject
	tf.InitializeNewInstance("javafx.scene.text.TextFlow", Null)
	tf.RunMethod("setTextAlignment",Array(TextAlignment.GetField(alignment)))
	tf.RunMethodJO("getChildren", Null).RunMethod("addAll", Array(texts))
	tf.RunMethod("setMaxWidth",Array(width))
	Return tf
End Sub