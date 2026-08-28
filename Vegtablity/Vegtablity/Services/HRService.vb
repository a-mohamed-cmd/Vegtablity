Imports System
Imports System.Data
Imports Dapper
Imports Vegtablity.Models.HR

Namespace Services
    Public Class HRService
        Private ReadOnly _dbHelper As New DatabaseHelper()

        ' ============================================================
        ' 1. Employees
        ' ============================================================
        Public Function GetEmployeesPaged(pageNumber As Integer, pageSize As Integer, Optional searchText As String = Nothing, Optional department As String = Nothing, Optional status As String = Nothing) As (Data As List(Of Employee), TotalCount As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@PageNumber", pageNumber)
                p.Add("@PageSize", pageSize)
                p.Add("@SearchText", searchText)
                p.Add("@Department", department)
                p.Add("@Status", status)

                Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_HR_EMPLOYEE_GETALL, p, commandType:=CommandType.StoredProcedure)
                    Dim totalCount = multi.Read(Of Integer)().FirstOrDefault()
                    Dim data = multi.Read(Of Employee)().ToList()
                    Return (data, totalCount)
                End Using
            End Using
        End Function

        Public Function GetEmployeeById(employeeID As Integer) As Employee
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@EmployeeID", employeeID)

                Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_HR_EMPLOYEE_GETBYID, p, commandType:=CommandType.StoredProcedure)
                    Dim emp = multi.Read(Of Employee)().FirstOrDefault()
                    If emp IsNot Nothing Then
                        Dim customValues = multi.Read(Of EmployeeCustomValue)().ToList()
                        emp.CustomValues = New System.Collections.ObjectModel.ObservableCollection(Of EmployeeCustomValue)(customValues)
                    End If
                    Return emp
                End Using
            End Using
        End Function

        Public Function SaveEmployee(emp As Employee, Optional user As String = Nothing) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@EmployeeID", emp.EmployeeID, dbType:=DbType.Int32, direction:=ParameterDirection.InputOutput)
                p.Add("@EmployeeCode", emp.EmployeeCode)
                p.Add("@FullName", emp.FullName)
                p.Add("@NationalID", emp.NationalID)
                p.Add("@CivilID", emp.CivilID)
                p.Add("@PassportNumber", emp.PassportNumber)
                p.Add("@Nationality", emp.Nationality)
                p.Add("@Gender", emp.Gender)
                p.Add("@BirthDate", emp.BirthDate)
                p.Add("@JobTitle", emp.JobTitle)
                p.Add("@Department", emp.Department)
                p.Add("@HireDate", emp.HireDate)
                p.Add("@ContractType", emp.ContractType)
                p.Add("@BasicSalary", emp.BasicSalary)
                p.Add("@HousingAllowance", emp.HousingAllowance)
                p.Add("@TransportAllowance", emp.TransportAllowance)
                p.Add("@OtherAllowances", emp.OtherAllowances)
                p.Add("@BankName", emp.BankName)
                p.Add("@IBAN", emp.IBAN)
                p.Add("@Status", emp.Status)
                p.Add("@Notes", emp.Notes)
                p.Add("@User", user)

                conn.Execute(Helpers.StoredProcedures.SP_HR_EMPLOYEE_SAVE, p, commandType:=CommandType.StoredProcedure)
                Dim savedId = p.Get(Of Integer)("@EmployeeID")

                ' Save custom values
                If emp.CustomValues IsNot Nothing Then
                    For Each cv In emp.CustomValues
                        SaveEmployeeCustomValue(savedId, cv.FieldID, cv.TextValue, cv.DateValue, cv.NumericValue)
                    Next
                End If

                Return savedId
            End Using
        End Function

        Public Sub SaveEmployeeCustomValue(employeeID As Integer, fieldID As Integer, textVal As String, dateVal As DateTime?, numVal As Decimal?)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@EmployeeID", employeeID)
                p.Add("@FieldID", fieldID)
                p.Add("@TextValue", textVal)
                p.Add("@DateValue", dateVal)
                p.Add("@NumericValue", numVal)

                conn.Execute(Helpers.StoredProcedures.SP_HR_EMPLOYEE_SAVECUSTOMVALUE, p, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Sub DeleteEmployee(employeeID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(Helpers.StoredProcedures.SP_HR_EMPLOYEE_DELETE, New With {.EmployeeID = employeeID}, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        ' ============================================================
        ' 2. Custom Fields & Alerts
        ' ============================================================
        Public Function GetCustomFields() As List(Of CustomFieldDefinition)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of CustomFieldDefinition)(Helpers.StoredProcedures.SP_HR_CUSTOMFIELD_GETALL, commandType:=CommandType.StoredProcedure).ToList()
            End Using
        End Function

        Public Function SaveCustomField(field As CustomFieldDefinition) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@FieldID", field.FieldID, dbType:=DbType.Int32, direction:=ParameterDirection.InputOutput)
                p.Add("@FieldKey", field.FieldKey)
                p.Add("@FieldNameAr", field.FieldNameAr)
                p.Add("@FieldType", field.FieldType)
                p.Add("@OptionsJson", field.OptionsJson)
                p.Add("@IsAlertable", field.IsAlertable)
                p.Add("@AlertDaysBefore", field.AlertDaysBefore)
                p.Add("@IsRequired", field.IsRequired)
                p.Add("@SortOrder", field.SortOrder)
                p.Add("@IsActive", field.IsActive)

                conn.Execute(Helpers.StoredProcedures.SP_HR_CUSTOMFIELD_SAVE, p, commandType:=CommandType.StoredProcedure)
                Return p.Get(Of Integer)("@FieldID")
            End Using
        End Function

        Public Sub DeleteCustomField(fieldID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(Helpers.StoredProcedures.SP_HR_CUSTOMFIELD_DELETE, New With {.FieldID = fieldID}, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Function GetActiveAlerts() As List(Of HRAlertItem)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of HRAlertItem)(Helpers.StoredProcedures.SP_HR_ALERTS_GETACTIVE, commandType:=CommandType.StoredProcedure).ToList()
            End Using
        End Function

        ' ============================================================
        ' 3. Leaves & Resumption
        ' ============================================================
        Public Function GetLeaveTypes() As List(Of LeaveType)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of LeaveType)(Helpers.StoredProcedures.SP_HR_LEAVETYPE_GETALL, commandType:=CommandType.StoredProcedure).ToList()
            End Using
        End Function

        Public Function GetLeavesPaged(pageNumber As Integer, pageSize As Integer, Optional employeeID As Integer? = Nothing, Optional status As String = Nothing) As (Data As List(Of EmployeeLeave), TotalCount As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@PageNumber", pageNumber)
                p.Add("@PageSize", pageSize)
                p.Add("@EmployeeID", employeeID)
                p.Add("@Status", status)

                Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_HR_LEAVE_GETALL, p, commandType:=CommandType.StoredProcedure)
                    Dim totalCount = multi.Read(Of Integer)().FirstOrDefault()
                    Dim data = multi.Read(Of EmployeeLeave)().ToList()
                    Return (data, totalCount)
                End Using
            End Using
        End Function

        Public Function SaveLeave(leave As EmployeeLeave) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@LeaveID", leave.LeaveID, dbType:=DbType.Int32, direction:=ParameterDirection.InputOutput)
                p.Add("@EmployeeID", leave.EmployeeID)
                p.Add("@LeaveTypeID", leave.LeaveTypeID)
                p.Add("@StartDate", leave.StartDate)
                p.Add("@EndDate", leave.EndDate)
                p.Add("@DaysCount", leave.DaysCount)
                p.Add("@Reason", leave.Reason)
                p.Add("@Status", leave.Status)
                p.Add("@ExpectedReturnDate", leave.ExpectedReturnDate)
                p.Add("@ApprovedBy", leave.ApprovedBy)

                conn.Execute(Helpers.StoredProcedures.SP_HR_LEAVE_SAVE, p, commandType:=CommandType.StoredProcedure)
                Return p.Get(Of Integer)("@LeaveID")
            End Using
        End Function

        Public Sub RecordResumption(leaveID As Integer, actualReturnDate As DateTime, resumptionDate As DateTime, Optional notes As String = Nothing)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@LeaveID", leaveID)
                p.Add("@ActualReturnDate", actualReturnDate)
                p.Add("@ResumptionDate", resumptionDate)
                p.Add("@ResumptionNotes", notes)

                conn.Execute(Helpers.StoredProcedures.SP_HR_LEAVE_RECORDRESUMPTION, p, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Function GetLeaveBalance(employeeID As Integer) As (AccruedDays As Decimal, UsedDays As Integer, RemainingBalance As Decimal)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim row = conn.QueryFirstOrDefault(Helpers.StoredProcedures.SP_HR_LEAVE_GETBALANCE, New With {.EmployeeID = employeeID}, commandType:=CommandType.StoredProcedure)
                If row IsNot Nothing Then
                    Return (CDec(row.AccruedDays), CInt(row.UsedDays), CDec(row.RemainingBalance))
                End If
                Return (0, 0, 0)
            End Using
        End Function

        ' ============================================================
        ' 4. Attendance
        ' ============================================================
        Public Function GetAttendanceByDate(attDate As DateTime) As List(Of AttendanceRecord)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of AttendanceRecord)(Helpers.StoredProcedures.SP_HR_ATTENDANCE_GETBYDATE, New With {.AttendanceDate = attDate}, commandType:=CommandType.StoredProcedure).ToList()
            End Using
        End Function

        Public Sub SaveAttendanceRecord(record As AttendanceRecord)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@EmployeeID", record.EmployeeID)
                p.Add("@AttendanceDate", record.AttendanceDate)
                p.Add("@CheckIn", record.CheckIn)
                p.Add("@CheckOut", record.CheckOut)
                p.Add("@WorkHours", record.WorkHours)
                p.Add("@OvertimeHours", record.OvertimeHours)
                p.Add("@OvertimeDays", record.OvertimeDays)
                p.Add("@DelayMinutes", record.DelayMinutes)
                p.Add("@AbsenceDeductionDays", record.AbsenceDeductionDays)
                p.Add("@Status", record.Status)
                p.Add("@Notes", record.Notes)

                conn.Execute(Helpers.StoredProcedures.SP_HR_ATTENDANCE_SAVE, p, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        ' ============================================================
        ' 5. Payroll
        ' ============================================================
        Public Function GetPayrollBatchesPaged(pageNumber As Integer, pageSize As Integer) As (Data As List(Of PayrollBatch), TotalCount As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@PageNumber", pageNumber)
                p.Add("@PageSize", pageSize)

                Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_HR_PAYROLL_GETBATCHES, p, commandType:=CommandType.StoredProcedure)
                    Dim totalCount = multi.Read(Of Integer)().FirstOrDefault()
                    Dim data = multi.Read(Of PayrollBatch)().ToList()
                    Return (data, totalCount)
                End Using
            End Using
        End Function

        Public Function GetPayrollBatchDetails(batchID As Integer) As PayrollBatch
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@BatchID", batchID)

                Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_HR_PAYROLL_GETBATCHDETAILS, p, commandType:=CommandType.StoredProcedure)
                    Dim batch = multi.Read(Of PayrollBatch)().FirstOrDefault()
                    If batch IsNot Nothing Then
                        Dim details = multi.Read(Of PayrollDetail)().ToList()
                        batch.Details = New System.Collections.ObjectModel.ObservableCollection(Of PayrollDetail)(details)
                    End If
                    Return batch
                End Using
            End Using
        End Function

        Public Function GeneratePayrollBatch(month As Integer, year As Integer, Optional user As String = Nothing) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@Month", month)
                p.Add("@Year", year)
                p.Add("@User", user)

                Return conn.ExecuteScalar(Of Integer)(Helpers.StoredProcedures.SP_HR_PAYROLL_GENERATEBATCH, p, commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub SavePayrollDetail(detail As PayrollDetail)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@PayrollDetailID", detail.PayrollDetailID)
                p.Add("@OvertimeHours", detail.OvertimeHours)
                p.Add("@OvertimeAmount", detail.OvertimeAmount)
                p.Add("@DeductionAmount", detail.DeductionAmount)
                p.Add("@AdvancesDeductions", detail.AdvancesDeductions)
                p.Add("@NetSalary", detail.NetSalary)
                p.Add("@Notes", detail.Notes)

                conn.Execute(Helpers.StoredProcedures.SP_HR_PAYROLL_SAVEDETAIL, p, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Sub ApprovePayrollBatch(batchID As Integer, Optional user As String = Nothing)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(Helpers.StoredProcedures.SP_HR_PAYROLL_APPROVEBATCH, New With {.BatchID = batchID, .ApprovedBy = user}, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Sub UnapprovePayrollBatch(batchID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(Helpers.StoredProcedures.SP_HR_PAYROLL_UNAPPROVEBATCH, New With {.BatchID = batchID}, commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        ' ============================================================
        ' 6. End of Service
        ' ============================================================
        Public Function GetEndOfServiceSettlementsPaged(pageNumber As Integer, pageSize As Integer) As (Data As List(Of EndOfServiceSettlement), TotalCount As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@PageNumber", pageNumber)
                p.Add("@PageSize", pageSize)

                Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_HR_ENDOFSERVICE_GETALL, p, commandType:=CommandType.StoredProcedure)
                    Dim totalCount = multi.Read(Of Integer)().FirstOrDefault()
                    Dim data = multi.Read(Of EndOfServiceSettlement)().ToList()
                    Return (data, totalCount)
                End Using
            End Using
        End Function

        Public Function SaveEndOfServiceSettlement(s As EndOfServiceSettlement, Optional user As String = Nothing) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Dim p As New DynamicParameters()
                p.Add("@SettlementID", s.SettlementID, dbType:=DbType.Int32, direction:=ParameterDirection.InputOutput)
                p.Add("@EmployeeID", s.EmployeeID)
                p.Add("@HireDate", s.HireDate)
                p.Add("@EndDate", s.EndDate)
                p.Add("@ServiceYears", s.ServiceYears)
                p.Add("@ServiceMonths", s.ServiceMonths)
                p.Add("@ServiceDays", s.ServiceDays)
                p.Add("@DepartureReason", s.DepartureReason)
                p.Add("@LastBasicSalary", s.LastBasicSalary)
                p.Add("@LastAllowances", s.LastAllowances)
                p.Add("@IndemnityAmount", s.IndemnityAmount)
                p.Add("@UnpaidLeaveBalanceDays", s.UnpaidLeaveBalanceDays)
                p.Add("@UnpaidLeaveCompensation", s.UnpaidLeaveCompensation)
                p.Add("@OtherEntitlements", s.OtherEntitlements)
                p.Add("@DeductionsLoans", s.DeductionsLoans)
                p.Add("@NetSettlementAmount", s.NetSettlementAmount)
                p.Add("@Status", s.Status)
                p.Add("@Notes", s.Notes)
                p.Add("@ApprovedBy", user)

                conn.Execute(Helpers.StoredProcedures.SP_HR_ENDOFSERVICE_SAVE, p, commandType:=CommandType.StoredProcedure)
                Return p.Get(Of Integer)("@SettlementID")
            End Using
        End Function

    End Class
End Namespace
