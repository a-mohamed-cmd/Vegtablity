Imports System

Namespace Models.HR
    Public Class EmployeeCustomValue
        Public Property ValueID As Integer
        Public Property EmployeeID As Integer
        Public Property FieldID As Integer
        Public Property FieldKey As String
        Public Property FieldNameAr As String
        Public Property FieldType As String
        Public Property IsAlertable As Boolean
        Public Property AlertDaysBefore As Integer
        Public Property TextValue As String
        Public Property DateValue As DateTime?
        Public Property NumericValue As Decimal?
        Public Property UpdatedAt As DateTime = DateTime.Now
    End Class
End Namespace
