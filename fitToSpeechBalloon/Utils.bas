B4J=true
Group=Default Group
ModulesStructureVersion=1
Type=StaticCode
Version=8.8
@EndOfDesignText@
'Static code module
Sub Process_Globals
	Private fx As JFX
End Sub

Sub RotateNode(n As Node, Degree As Double)
	Dim jo As JavaObject = n
	jo.RunMethod("setRotate", Array(Degree))
End Sub

Sub isChinese(text As String) As Boolean
	Dim jo As JavaObject
	jo=Me
	Return jo.RunMethod("isChinese",Array As String(text))
End Sub

Sub getSetting(key As String,default As Object) As Object
	Dim settings As Map
	settings.Initialize
	If settings.ContainsKey(key) Then
		Return settings.Get(key)
	End If
	Return default
End Sub


#If JAVA
import java.util.regex.Pattern;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import javafx.scene.text.Font;
import javafx.scene.text.TextBoundsType;

public static double MeasureMultilineTextHeight(Font f, String text, double width) throws Exception {
    Method m = Class.forName("com.sun.javafx.scene.control.skin.Utils").getDeclaredMethod("computeTextHeight",
    Font.class, String.class, double.class, TextBoundsType.class);
    m.setAccessible(true);
    return (Double)m.invoke(null, f, text, width, TextBoundsType.LOGICAL);
}
  
// 日语字符的正则表达式模式
private static final Pattern JAPANESE_PATTERN = Pattern.compile(
    "[\\u3040-\\u309F\\u30A0-\\u30FF\\u4E00-\\u9FFF\\uFF00-\\uFFEF]+"
);

/**
 * 使用正则表达式检测是否包含日语字符
 */
public static boolean isJapanese(String text) {
    if (text == null || text.trim().isEmpty()) {
        return false;
    }
    return JAPANESE_PATTERN.matcher(text).find();
}

private static boolean isChinese(char c) {

    Character.UnicodeBlock ub = Character.UnicodeBlock.of(c);

    if (ub == Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS || ub == Character.UnicodeBlock.CJK_COMPATIBILITY_IDEOGRAPHS

            || ub == Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS_EXTENSION_A || ub == Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS_EXTENSION_B

            || ub == Character.UnicodeBlock.CJK_SYMBOLS_AND_PUNCTUATION || ub == Character.UnicodeBlock.HALFWIDTH_AND_FULLWIDTH_FORMS) {

        return true;

    }

    return false;

}



// 完整的判断中文汉字和符号

public static boolean isChinese(String strName) {

    char[] ch = strName.toCharArray();

    for (int i = 0; i < ch.length; i++) {

        char c = ch[i];

        if (isChinese(c)) {

            return true;

        }

    }

    return false;

}  
#End If
