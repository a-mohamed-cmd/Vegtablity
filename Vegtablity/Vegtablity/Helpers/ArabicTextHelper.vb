Imports System.Text
Imports System.Collections.Generic
Imports System.Text.RegularExpressions

Namespace Helpers
    ''' <summary>
    ''' Advanced Arabic Text Support for PDF (PdfSharp).
    ''' Corrects shaping and isolates Arabic words for reversal in mixed-language text.
    ''' </summary>
    Public Class ArabicTextHelper
        
        ' Map: Isolated -> Form (Initial, Medial, Final, Isolated)
        Private Shared ReadOnly ShapingMap As New Dictionary(Of Char, Char()) From {
            {ChrW(&H621), {ChrW(&H621), ChrW(&H621), ChrW(&H621), ChrW(&H621)}}, ' Hamza
            {ChrW(&H622), {ChrW(&H622), ChrW(&H622), ChrW(&HFE82), ChrW(&HFE81)}}, ' Alef Mad
            {ChrW(&H623), {ChrW(&H623), ChrW(&H623), ChrW(&HFE84), ChrW(&HFE83)}}, ' Alef Hamza Above
            {ChrW(&H624), {ChrW(&H624), ChrW(&H624), ChrW(&HFE86), ChrW(&HFE85)}}, ' Waw Hamza
            {ChrW(&H625), {ChrW(&H625), ChrW(&H625), ChrW(&HFE88), ChrW(&HFE87)}}, ' Alef Hamza Below
            {ChrW(&H626), {ChrW(&HFE8B), ChrW(&HFE8C), ChrW(&HFE8A), ChrW(&HFE89)}}, ' Yeh Hamza
            {ChrW(&H627), {ChrW(&H627), ChrW(&H627), ChrW(&HFE8E), ChrW(&HFE8D)}}, ' Alef
            {ChrW(&H628), {ChrW(&HFE91), ChrW(&HFE92), ChrW(&HFE90), ChrW(&HFE8F)}}, ' Beh
            {ChrW(&H629), {ChrW(&H629), ChrW(&H629), ChrW(&HFE94), ChrW(&HFE93)}}, ' Teh Marbuta
            {ChrW(&H62A), {ChrW(&HFE97), ChrW(&HFE98), ChrW(&HFE96), ChrW(&HFE95)}}, ' Teh
            {ChrW(&H62B), {ChrW(&HFE9B), ChrW(&HFE9C), ChrW(&HFE9A), ChrW(&HFE99)}}, ' Theh
            {ChrW(&H62C), {ChrW(&HFE9F), ChrW(&HFEA0), ChrW(&HFE9E), ChrW(&HFE9D)}}, ' Jeem
            {ChrW(&H62D), {ChrW(&HFEA3), ChrW(&HFEA4), ChrW(&HFEA2), ChrW(&HFEA1)}}, ' Hah
            {ChrW(&H62E), {ChrW(&HFEA7), ChrW(&HFEA8), ChrW(&HFEA6), ChrW(&HFEA5)}}, ' Khah
            {ChrW(&H62F), {ChrW(&H62F), ChrW(&H62F), ChrW(&HFEAA), ChrW(&HFEA9)}}, ' Dal
            {ChrW(&H630), {ChrW(&H630), ChrW(&H630), ChrW(&HFEAC), ChrW(&HFEAB)}}, ' Thal
            {ChrW(&H631), {ChrW(&H631), ChrW(&H631), ChrW(&HFEAE), ChrW(&HFEAD)}}, ' Reh
            {ChrW(&H632), {ChrW(&H632), ChrW(&H632), ChrW(&HFEB0), ChrW(&HFEAF)}}, ' Zain
            {ChrW(&H633), {ChrW(&HFEB3), ChrW(&HFEB4), ChrW(&HFEB2), ChrW(&HFEB1)}}, ' Seen
            {ChrW(&H634), {ChrW(&HFEB7), ChrW(&HFEB8), ChrW(&HFEB6), ChrW(&HFEB5)}}, ' Sheen
            {ChrW(&H635), {ChrW(&HFEBB), ChrW(&HFEBC), ChrW(&HFEBA), ChrW(&HFEB9)}}, ' Sad
            {ChrW(&H636), {ChrW(&HFEBF), ChrW(&HFEC0), ChrW(&HFEBE), ChrW(&HFEBD)}}, ' Dad
            {ChrW(&H637), {ChrW(&HFEC3), ChrW(&HFEC4), ChrW(&HFEC2), ChrW(&HFEC1)}}, ' Tah
            {ChrW(&H638), {ChrW(&HFEC7), ChrW(&HFEC8), ChrW(&HFEC6), ChrW(&HFEC5)}}, ' Zah
            {ChrW(&H639), {ChrW(&HFECB), ChrW(&HFECC), ChrW(&HFECA), ChrW(&HFEC9)}}, ' Ain
            {ChrW(&H63A), {ChrW(&HFECF), ChrW(&HFED0), ChrW(&HFECE), ChrW(&HFECD)}}, ' Ghain
            {ChrW(&H641), {ChrW(&HFED3), ChrW(&HFED4), ChrW(&HFED2), ChrW(&HFED1)}}, ' Feh
            {ChrW(&H642), {ChrW(&HFED7), ChrW(&HFED8), ChrW(&HFED6), ChrW(&HFED5)}}, ' Qaf
            {ChrW(&H643), {ChrW(&HFEDB), ChrW(&HFEDC), ChrW(&HFEDA), ChrW(&HFED9)}}, ' Kaf
            {ChrW(&H644), {ChrW(&HFEDF), ChrW(&HFEE0), ChrW(&HFEDE), ChrW(&HFEDD)}}, ' Lam
            {ChrW(&H645), {ChrW(&HFEE3), ChrW(&HFEE4), ChrW(&HFEE2), ChrW(&HFEE1)}}, ' Meem
            {ChrW(&H646), {ChrW(&HFEE7), ChrW(&HFEE8), ChrW(&HFEE6), ChrW(&HFEE5)}}, ' Noon
            {ChrW(&H647), {ChrW(&HFEEB), ChrW(&HFEEC), ChrW(&HFEEA), ChrW(&HFEE9)}}, ' Heh
            {ChrW(&H648), {ChrW(&H648), ChrW(&H648), ChrW(&HFEEE), ChrW(&HFEED)}}, ' Waw
            {ChrW(&H649), {ChrW(&H649), ChrW(&H649), ChrW(&HFEF0), ChrW(&HFE9F)}}, ' Alef Maksura
            {ChrW(&H64A), {ChrW(&HFEF3), ChrW(&HFEF4), ChrW(&HFEF2), ChrW(&HFEF1)}}  ' Yeh
        }

        ''' <summary>
        ''' Fixes mixed Arabic/English text for PDF rendering.
        ''' Only shaped and reverses Arabic parts.
        ''' </summary>
        Public Shared Function Fix(text As String) As String
            If String.IsNullOrEmpty(text) Then Return ""

            ' Regex pattern to match Arabic blocks including common Arabic punctuation/diacritics
            Dim pattern As String = "([\u0600-\u06FF\uFB50-\uFEFC\u0750-\u077F]+)"
            Dim segments As String() = Regex.Split(text, pattern)
            
            Dim result As New StringBuilder()
            
            ' Process from right to left as a whole if the whole string is Arabic? 
            ' No, let's process segments and join them. 
            ' For true RTL mixed support, reversal should happen within Arabic blocks.
            
            For i As Integer = 0 To segments.Length - 1
                Dim segment = segments(i)
                If String.IsNullOrEmpty(segment) Then Continue For
                
                If Regex.IsMatch(segment, pattern) Then
                    ' It's Arabic: Shape and Reverse
                    result.Append(ShapeAndReverse(segment))
                Else
                    ' It's non-Arabic: Keep as is
                    result.Append(segment)
                End If
            Next
            
            Return result.ToString()
        End Function

        Private Shared Function ShapeAndReverse(text As String) As String
            Dim shapedText As New StringBuilder()
            For i As Integer = 0 To text.Length - 1
                Dim curr As Char = text(i)
                
                If ShapingMap.ContainsKey(curr) Then
                    Dim prev As Char = If(i > 0, text(i - 1), " "c)
                    Dim [next] As Char = If(i < text.Length - 1, text(i + 1), " "c)

                    Dim canConnectBefore As Boolean = CanConnectForward(prev)
                    Dim canConnectAfter As Boolean = CanConnectBackward([next])

                    Dim forms = ShapingMap(curr)
                    If canConnectBefore AndAlso canConnectAfter Then
                        shapedText.Append(forms(1)) ' Medial
                    ElseIf canConnectBefore Then
                        shapedText.Append(forms(2)) ' Final
                    ElseIf canConnectAfter Then
                        shapedText.Append(forms(0)) ' Initial
                    Else
                        shapedText.Append(forms(3)) ' Isolated
                    End If
                Else
                    shapedText.Append(curr)
                End If
            Next

            ' Reverse for RTL display in LTR environment
            Dim chars = shapedText.ToString().ToCharArray()
            Array.Reverse(chars)
            Return New String(chars)
        End Function

        Private Shared Function CanConnectForward(c As Char) As Boolean
            If Not ShapingMap.ContainsKey(c) Then Return False
            Dim noForward = {ChrW(&H622), ChrW(&H623), ChrW(&H625), ChrW(&H627), ChrW(&H62F), ChrW(&H630), ChrW(&H631), ChrW(&H632), ChrW(&H648)}
            Return Not noForward.Contains(c)
        End Function

        Private Shared Function CanConnectBackward(c As Char) As Boolean
            Return ShapingMap.ContainsKey(c)
        End Function

    End Class
End Namespace
