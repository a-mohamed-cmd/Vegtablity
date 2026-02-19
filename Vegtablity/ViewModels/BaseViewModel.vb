Imports System.ComponentModel
Imports System.Runtime.CompilerServices

Namespace ViewModels
    Public Class BaseViewModel
        Implements INotifyPropertyChanged

        Public Event PropertyChanged As PropertyChangedEventHandler Implements INotifyPropertyChanged.PropertyChanged

        Protected Sub OnPropertyChanged(<CallerMemberName> Optional propertyName As String = Nothing)
            RaiseEvent PropertyChanged(Me, New PropertyChangedEventArgs(propertyName))
        End Sub

        Protected Function SetProperty(Of T)(ByRef field As T, value As T, <CallerMemberName> Optional propertyName As String = Nothing) As Boolean
            If EqualityComparer(Of T).Default.Equals(field, value) Then Return False
            field = value
            OnPropertyChanged(propertyName)
            Return True
        End Function
    End Class
End Namespace
