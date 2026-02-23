Namespace Helpers
    Public Class CurrencyToLetters
        Private Shared ReadOnly Units As String() = {"", "واحد", "اثنان", "ثلاثة", "أربعة", "خمسة", "ستة", "سبعة", "ثمانية", "تسعة"}
        Private Shared ReadOnly Tens As String() = {"", "عشرة", "عشرون", "ثلاثون", "أربعون", "خمسون", "ستون", "سبعون", "ثمانون", "تسعون"}
        Private Shared ReadOnly Teens As String() = {"عشر", "أحد عشر", "اثنا عشر", "ثلاثة عشر", "أربعة عشر", "خمسة عشر", "ستة عشر", "سبعة عشر", "ثمانية عشر", "تسعة عشر"}
        Private Shared ReadOnly Hundreds As String() = {"", "مائة", "مائتان", "ثلاثمائة", "أربعمائة", "خمسمائة", "ستمائة", "سبعمائة", "ثمانمائة", "تسعمائة"}

        Public Shared Function Convert(amount As Decimal, Optional currencyName As String = "دينار كويتي", Optional subCurrencyName As String = "فلس", Optional decimalPlaces As Integer = 3) As String
            If amount = 0 Then Return "صفر " & currencyName
            
            Dim integerPart = Fix(amount)
            Dim multiplier = Math.Pow(10, decimalPlaces)
            Dim decimalPart = Math.Round((amount - integerPart) * multiplier)
            
            Dim result = ""
            
            If integerPart > 0 Then
                result = ConvertNumber(integerPart) & " " & currencyName
            End If
            
            If decimalPart > 0 Then
                If result <> "" Then result &= " و "
                result &= ConvertNumber(decimalPart) & " " & subCurrencyName
            End If
            
            Return "فقط " & result & " لا غير"
        End Function

        Private Shared Function ConvertNumber(number As Long) As String
            If number = 0 Then Return ""
            
            If number < 10 Then
                Return Units(number)
            ElseIf number = 10 Then
                Return Tens(1) ' عشرة
            ElseIf number < 20 Then
                Return Teens(number - 10)
            ElseIf number < 100 Then
                Dim unit = number Mod 10
                Dim ten = Fix(number / 10)
                Return If(unit > 0, Units(unit) & " و", "") & Tens(ten)
            ElseIf number < 1000 Then
                Dim hundred = Fix(number / 100)
                Dim rest = number Mod 100
                Return Hundreds(hundred) & If(rest > 0, " و" & ConvertNumber(rest), "")
            ElseIf number < 1000000 Then
                Dim thousand = Fix(number / 1000)
                Dim rest = number Mod 1000
                Dim thousandText = ""
                If thousand = 1 Then
                    thousandText = "ألف"
                ElseIf thousand = 2 Then
                    thousandText = "ألفين"
                ElseIf thousand < 11 Then
                    thousandText = ConvertNumber(thousand) & " آلاف"
                Else
                    thousandText = ConvertNumber(thousand) & " ألف"
                End If
                Return thousandText & If(rest > 0, " و" & ConvertNumber(rest), "")
            End If
            
            Return number.ToString() ' Fallback for millions+
        End Function
    End Class
End Namespace
