Imports System
Imports System.Collections.ObjectModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Helpers
Imports Vegtablity.Models.HR
Imports Vegtablity.Services

Namespace ViewModels
    Public Class HRSettingsViewModel
        Inherits BaseViewModel

        Private ReadOnly _hrService As New HRService()

        Public Property CustomFields As ObservableCollection(Of CustomFieldDefinition)
        Public Property LeaveTypesList As ObservableCollection(Of LeaveType)
        Public Property FieldTypesList As ObservableCollection(Of String)

        Private _selectedField As CustomFieldDefinition
        Public Property SelectedField As CustomFieldDefinition
            Get
                Return _selectedField
            End Get
            Set(value As CustomFieldDefinition)
                If SetProperty(_selectedField, value) AndAlso value IsNot Nothing Then
                    EditField = New CustomFieldDefinition With {
                        .FieldID = value.FieldID,
                        .FieldKey = value.FieldKey,
                        .FieldNameAr = value.FieldNameAr,
                        .FieldType = value.FieldType,
                        .IsAlertable = value.IsAlertable,
                        .AlertDaysBefore = value.AlertDaysBefore,
                        .IsRequired = value.IsRequired,
                        .SortOrder = value.SortOrder,
                        .IsActive = value.IsActive
                    }
                End If
            End Set
        End Property

        Private _editField As CustomFieldDefinition
        Public Property EditField As CustomFieldDefinition
            Get
                Return _editField
            End Get
            Set(value As CustomFieldDefinition)
                SetProperty(_editField, value)
            End Set
        End Property

        Public Property SaveCustomFieldCommand As ICommand
        Public Property NewCustomFieldCommand As ICommand
        Public Property DeleteCustomFieldCommand As ICommand
        Public Property RefreshCommand As ICommand

        Public Sub New()
            CustomFields = New ObservableCollection(Of CustomFieldDefinition)()
            LeaveTypesList = New ObservableCollection(Of LeaveType)()
            FieldTypesList = New ObservableCollection(Of String) From {"Text", "Date", "Number"}

            SaveCustomFieldCommand = New RelayCommand(AddressOf SaveCustomField)
            NewCustomFieldCommand = New RelayCommand(AddressOf NewCustomField)
            DeleteCustomFieldCommand = New RelayCommand(AddressOf DeleteCustomField)
            RefreshCommand = New RelayCommand(Sub() LoadData())

            LoadPermissions("HRSettings")
            NewCustomField(Nothing)
            LoadData()
        End Sub

        Private Sub LoadData()
            Try
                Dim fields = _hrService.GetCustomFields()
                CustomFields.Clear()
                For Each f In fields
                    CustomFields.Add(f)
                Next

                Dim lTypes = _hrService.GetLeaveTypes()
                LeaveTypesList.Clear()
                For Each lt In lTypes
                    LeaveTypesList.Add(lt)
                Next
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء جلب إعدادات الموارد: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' === Events ===
        Public Event RequestSnackbar As Action(Of String)

        Private Sub NewCustomField(parameter As Object)
            EditField = New CustomFieldDefinition With {
                .FieldKey = "Custom_" & DateTime.Now.Ticks.ToString().Substring(12),
                .FieldNameAr = String.Empty,
                .FieldType = "Date",
                .IsAlertable = True,
                .AlertDaysBefore = 30,
                .SortOrder = CustomFields.Count + 1,
                .IsActive = True
            }
            SelectedField = Nothing
            RaiseEvent RequestSnackbar("➕ تم فتح نموذج تعريف حقل مخصص جديد")
        End Sub

        Private Sub SaveCustomField(parameter As Object)
            If EditField Is Nothing Then Return
            If String.IsNullOrWhiteSpace(EditField.FieldNameAr) Then
                RaiseEvent RequestSnackbar("⚠️ يرجى إدخال اسم الحقل بالعربية")
                Return
            End If
            If String.IsNullOrWhiteSpace(EditField.FieldKey) Then
                EditField.FieldKey = "Custom_" & DateTime.Now.Ticks.ToString().Substring(12)
            End If

            Try
                Dim id = _hrService.SaveCustomField(EditField)
                EditField.FieldID = id
                RaiseEvent RequestSnackbar($"💾 تم حفظ تعريف الحقل المخصص ({EditField.FieldNameAr}) بنجاح!")
                LoadData()
                SelectedField = CustomFields.FirstOrDefault(Function(f) f.FieldID = id)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء حفظ الحقل المخصص: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Public Sub DeleteCustomField(parameter As Object)
            Dim target = If(TryCast(parameter, CustomFieldDefinition), EditField)
            If target Is Nothing OrElse target.FieldID <= 0 Then
                RaiseEvent RequestSnackbar("⚠️ يرجى اختيار حقل مخصص لحذفه")
                Return
            End If

            If MessageBox.Show($"هل أنت متأكد من حذف الحقل '{target.FieldNameAr}' وكافة القيم المسجلة له في ملفات الموظفين؟", "تأكيد الحذف", MessageBoxButton.YesNo, MessageBoxImage.Question) = MessageBoxResult.Yes Then
                Try
                    _hrService.DeleteCustomField(target.FieldID)
                    RaiseEvent RequestSnackbar($"🗑️ تم حذف الحقل المخصص ({target.FieldNameAr}) بنجاح!")
                    NewCustomField(Nothing)
                    LoadData()
                Catch ex As Exception
                    MessageBox.Show("خطأ أثناء حذف الحقل: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
                End Try
            End If
        End Sub
    End Class
End Namespace
