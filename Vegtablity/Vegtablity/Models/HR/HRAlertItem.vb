Imports System

Namespace Models.HR
    Public Class HRAlertItem
        Public Property ValueID As Integer
        Public Property EmployeeID As Integer
        Public Property EmployeeCode As String
        Public Property EmployeeName As String
        Public Property Department As String
        Public Property FieldID As Integer
        Public Property FieldKey As String
        Public Property FieldNameAr As String
        Public Property ExpiryDate As DateTime
        Public Property DaysRemaining As Integer
        Public Property AlertStatus As String ' Expired, ExpiringSoon, Valid

        Public ReadOnly Property StatusText As String
            Get
                If AlertStatus = "Expired" Then
                    Return $"منتهية منذ {Math.Abs(DaysRemaining)} يوم ⚠️"
                ElseIf AlertStatus = "ExpiringSoon" Then
                    Return $"تنتهي خلال {DaysRemaining} يوم"
                Else
                    Return "سارية"
                End If
            End Get
        End Property

        Public ReadOnly Property BadgeColor As String
            Get
                If AlertStatus = "Expired" Then
                    Return "#EF4444" ' Red
                ElseIf AlertStatus = "ExpiringSoon" Then
                    Return "#F59E0B" ' Amber
                Else
                    Return "#10B981" ' Green
                End If
            End Get
        End Property
    End Class
End Namespace
