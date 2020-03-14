B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=7.8
@EndOfDesignText@
Sub Class_Globals
	Private fx As JFX
	Private frm As Form
	Public iv As ImageView
	Public Tag As Object
	Private ScrollPane1 As ScrollPane
End Sub

'Initializes the object. You can add parameters to this method if needed.
Public Sub Initialize(title As String)
	frm.Initialize("frm",600,200)
	frm.RootPane.LoadLayout("ImageWindow")
	ScrollPane1.LoadLayout("iv",600,1000)
	ScrollPane1.InnerNode.PrefHeight=iv.Height
	ScrollPane1.InnerNode.PrefWidth=iv.Width
	frm.Title=title
End Sub

Public Sub Show
	frm.Show
End Sub

Public Sub setImage(img As Image)
	iv.SetImage(img)
End Sub

Sub frm_Resize (Width As Double, Height As Double)
	Try
		iv.Width=Width
		iv.Height=Width/(iv.GetImage.Width/iv.GetImage.Height)
		ScrollPane1.InnerNode.PrefHeight=iv.Height
		ScrollPane1.InnerNode.PrefWidth=iv.Width
	Catch
		Log(LastException)
	End Try

End Sub