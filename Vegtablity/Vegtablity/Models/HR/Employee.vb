Imports System
Imports System.Collections.ObjectModel
Imports System.ComponentModel

Namespace Models.HR
    Public Class Employee
        Implements INotifyPropertyChanged

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged

        Private Sub OnPropertyChanged(propName As String)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propName))
        End Sub

        Private _basicSalary As Decimal = 0
        Private _housingAllowance As Decimal = 0
        Private _transportAllowance As Decimal = 0
        Private _otherAllowances As Decimal = 0

        Public Property EmployeeID As Integer
        Public Property EmployeeCode As String
        Public Property FullName As String
        Public Property NationalID As String
        Public Property CivilID As String
        Public Property PassportNumber As String
        Public Property Nationality As String
        Public Property Gender As String
        Public Property BirthDate As DateTime?
        Public Property JobTitle As String
        Public Property Department As String
        Public Property HireDate As DateTime
        Public Property ContractType As String

        Public Property BasicSalary As Decimal
            Get
                Return _basicSalary
            End Get
            Set(value As Decimal)
                If _basicSalary <> value Then
                    _basicSalary = value
                    OnPropertyChanged(NameOf(BasicSalary))
                    OnPropertyChanged(NameOf(TotalSalary))
                End If
            End Set
        End Property

        Public Property HousingAllowance As Decimal
            Get
                Return _housingAllowance
            End Get
            Set(value As Decimal)
                If _housingAllowance <> value Then
                    _housingAllowance = value
                    OnPropertyChanged(NameOf(HousingAllowance))
                    OnPropertyChanged(NameOf(TotalSalary))
                End If
            End Set
        End Property

        Public Property TransportAllowance As Decimal
            Get
                Return _transportAllowance
            End Get
            Set(value As Decimal)
                If _transportAllowance <> value Then
                    _transportAllowance = value
                    OnPropertyChanged(NameOf(TransportAllowance))
                    OnPropertyChanged(NameOf(TotalSalary))
                End If
            End Set
        End Property

        Public Property OtherAllowances As Decimal
            Get
                Return _otherAllowances
            End Get
            Set(value As Decimal)
                If _otherAllowances <> value Then
                    _otherAllowances = value
                    OnPropertyChanged(NameOf(OtherAllowances))
                    OnPropertyChanged(NameOf(TotalSalary))
                End If
            End Set
        End Property

        Public Property BankName As String
        Public Property IBAN As String
        Public Property Status As String = "Active"
        Public Property Notes As String
        Public Property CreatedAt As DateTime
        Public Property CreatedBy As String
        Public Property UpdatedAt As DateTime?
        Public Property UpdatedBy As String

        Public ReadOnly Property TotalSalary As Decimal
            Get
                Return BasicSalary + HousingAllowance + TransportAllowance + OtherAllowances
            End Get
        End Property

        Public ReadOnly Property DisplayText As String
            Get
                If String.IsNullOrWhiteSpace(EmployeeCode) Then
                    Return If(FullName, String.Empty)
                Else
                    Return $"{FullName} ({EmployeeCode})"
                End If
            End Get
        End Property

        Public Property CustomValues As ObservableCollection(Of EmployeeCustomValue)

        Public Sub New()
            CustomValues = New ObservableCollection(Of EmployeeCustomValue)()
            HireDate = DateTime.Today
            BasicSalary = 0
            HousingAllowance = 0
            TransportAllowance = 0
            OtherAllowances = 0
            Status = "Active"
        End Sub
    End Class
End Namespace
