B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=StaticCode
Version=7.8
@EndOfDesignText@
'Static code module
Sub Process_Globals
	Private fx As JFX
End Sub

Sub ContainsJapaneseGana(text As String) As Boolean
	' 定义日文假名的正则表达式
	' 包括平假名（\u3040-\u309F）和片假名（\u30A0-\u30FF）
	Dim hiraganaPattern As String = "[\u3040-\u309F]"
	Dim katakanaPattern As String = "[\u30A0-\u30FF]"
    
	' 编译正则表达式
	Dim hiraganaMatcher As Matcher = Regex.Matcher(hiraganaPattern, text)
	Dim katakanaMatcher As Matcher = Regex.Matcher(katakanaPattern, text)
    
	' 如果找到假名，则判定为日文
	If hiraganaMatcher.Find Or katakanaMatcher.Find Then
		Return True
	End If
    Return False
End Sub

Sub LanguageCanBeVertical(lang As String) As Boolean
	Dim languagesCanBeVertical As List
	languagesCanBeVertical=File.ReadList(File.DirAssets,"languagesCanBeVertical.txt")
	For Each code As String In languagesCanBeVertical
		If lang.ToLowerCase.StartsWith(code) Then
			Return True
		End If
	Next
	Return False
End Sub

Sub LanguageHasSpace(lang As String) As Boolean
	Dim languagesWithoutSpaceList As List
	languagesWithoutSpaceList=File.ReadList(File.DirAssets,"languagesWithoutSpace.txt")
	For Each code As String In languagesWithoutSpaceList
		If lang.ToLowerCase.StartsWith(code) Then
			Return False
		End If
	Next
	Return True
End Sub

Sub LanguageIsRight2Left(langcode As String) As Boolean
	'arabic,hebrew,kurdish,persian,urdu
	For Each lang As String In Array As String("ar","he","ku","fa","ur")
		If langcode.StartsWith(lang) Then
			Return True
		End If
	Next
	Return False
End Sub

Sub TokenizedList(text As String,sourceLang As String) As List
	text=text.ToLowerCase
	Dim words As List
	words.Initialize
	If LanguageHasSpace(sourceLang) Then
		text=removePunctuation(text," ")
		words.AddAll(Regex.Split(" ",text))
	Else
		text=removePunctuation(text,"")
		words.AddAll(Regex.Split("",text))
	End If
    'Utils.removeDuplicated(words)
	Dim newList As List
	newList.Initialize
	For Each word As String In words
		If word.Trim="" Then
			Continue
		End If
		newList.Add(word)
	Next
	Return newList
End Sub

Sub addPhrases(words As List)
	Dim iterateList As List
	iterateList.Initialize
	iterateList.AddAll(words)
	For i=1 To 8
		Dim endnum As Int=iterateList.Size-i
		If endnum<=0 Then
			Exit
		End If
		For j=0 To endnum
			Dim word As String
			If j+i>iterateList.Size-1 Then
				Exit
			End If
			For k=j To j+i
				word=word&" "&iterateList.Get(k)
			Next
			word=word.Trim
			If words.IndexOf(word)=-1 Then
				words.Add(word)
			End If
		Next
	Next
End Sub

Sub addHanziWords(source As String) As List
	Dim words As List
	words.Initialize
	For i=1 To 8
		If source.Length-i<=0 Then
			Exit
		End If
		For j=0 To source.Length-i
			If j+i>source.Length Then
				Exit
			End If
			Dim word As String
			word=source.SubString2(j,j+i)
			words.Add(word)
		Next
	Next
	Return words
End Sub

Sub removePunctuation(source As String,replacement As String) As String
	source=Regex.Replace($"[。！？，“”'",\.\!\?\*\^\-]"$,source," ")
	Return source
End Sub

Sub removeMultiBytesWords(words As List)
	Dim newList As List
	newList.Initialize
	For Each word As String In words
		If word.Length>1 Then
			If getBytesLength(word.CharAt(0))>1 Then
				Continue
			End If
		End If
		newList.Add(word)
	Next
	words.Clear
	words.AddAll(newList)
End Sub

Sub removeCharacters(source As List)
	Dim newList As List
	newList.Initialize
	For Each text As String In source
		If text.Length=1 Then
			If Regex.IsMatch("[a-z]",text.ToLowerCase)=True Then
				Continue
			End If
		End If
		newList.Add(text)
	Next
	source.Clear
	source.AddAll(newList)
End Sub

Sub getBytesLength(singleString As String) As Int
	Dim bytes() As Byte
	bytes=singleString.GetBytes("UTF-8")
	Return bytes.Length
End Sub
