Imports System.Data
Imports Dapper
Imports Vegtablity.Models
Imports Vegtablity.Helpers

Namespace Services
    Public Class DashboardService
        Private ReadOnly dbHelper As DatabaseHelper

        Public Sub New()
            dbHelper = New DatabaseHelper()
        End Sub

        ''' <summary>
        ''' تجلب ملخص أرقام الداشبورد (المبيعات، المشتريات، عدد الأصناف، عدد العملاء)
        ''' </summary>
        Public Function GetDashboardSummary() As DashboardSummary
            Try
                Using conn = dbHelper.GetConnection()
                    Return conn.QueryFirstOrDefault(Of DashboardSummary)(
                        StoredProcedures.SP_DASHBOARD_GETSUMMARY,
                        Nothing,
                        commandType:=CommandType.StoredProcedure
                    )
                End Using
            Catch ex As Exception
                Throw New Exception("خطأ في جلب بيانات لوحة المعلومات الأساسية", ex)
            End Try
        End Function

        ''' <summary>
        ''' تجلب بيانات المبيعات للأيام القليلة الماضية لرسم المخطط البياني
        ''' </summary>
        Public Function GetSalesChartData(Optional days As Integer = 7) As IEnumerable(Of DashboardSalesChart)
            Try
                Dim parameters = New DynamicParameters()
                parameters.Add("@Days", days, DbType.Int32)

                Using conn = dbHelper.GetConnection()
                    Return conn.Query(Of DashboardSalesChart)(
                        StoredProcedures.SP_DASHBOARD_GETSALESCHART,
                        parameters,
                        commandType:=CommandType.StoredProcedure
                    )
                End Using
            Catch ex As Exception
                Throw New Exception("خطأ في جلب بيانات المخطط البياني المالي", ex)
            End Try
        End Function

        ''' <summary>
        ''' تجلب الأصناف التي تجاوزت حد الطلب (تنبيه المخزون)
        ''' </summary>
        Public Function GetAlertProducts() As IEnumerable(Of DashboardAlertProduct)
            Try
                Using conn = dbHelper.GetConnection()
                    Return conn.Query(Of DashboardAlertProduct)(
                        StoredProcedures.SP_DASHBOARD_GETALERTPRODUCTS,
                        Nothing,
                        commandType:=CommandType.StoredProcedure
                    )
                End Using
            Catch ex As Exception
                Throw New Exception("خطأ في جلب تنبيهات المخزون", ex)
            End Try
        End Function

        ''' <summary>
        ''' تجلب تفاصيل مديونيات العملاء النشطين
        ''' </summary>
        Public Function GetCustomerDebts() As IEnumerable(Of DashboardPartnerDebt)
            Try
                Using conn = dbHelper.GetConnection()
                    Return conn.Query(Of DashboardPartnerDebt)(
                        StoredProcedures.SP_DASHBOARD_GETCUSTOMERDEBTS,
                        Nothing,
                        commandType:=CommandType.StoredProcedure
                    )
                End Using
            Catch ex As Exception
                Throw New Exception("خطأ في جلب بيانات مديونيات العملاء", ex)
            End Try
        End Function

        ''' <summary>
        ''' تجلب تفاصيل مديونيات الموردين النشطين
        ''' </summary>
        Public Function GetSupplierDebts() As IEnumerable(Of DashboardPartnerDebt)
            Try
                Using conn = dbHelper.GetConnection()
                    Return conn.Query(Of DashboardPartnerDebt)(
                        StoredProcedures.SP_DASHBOARD_GETSUPPLIERDEBTS,
                        Nothing,
                        commandType:=CommandType.StoredProcedure
                    )
                End Using
            Catch ex As Exception
                Throw New Exception("خطأ في جلب بيانات مديونيات الموردين", ex)
            End Try
        End Function

    End Class
End Namespace
