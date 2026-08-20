Imports System.IO
Imports System.Net.Http
Imports System.Threading.Tasks
Imports System.Diagnostics
Imports System.Text.RegularExpressions

Namespace Services
    Public Class UpdateInfo
        Public Property HasUpdate As Boolean
        Public Property CurrentVersion As String
        Public Property LatestVersion As String
        Public Property DownloadUrl As String
        Public Property ReleaseNotes As String
        Public Property InstallerName As String
        Public Property IsMandatory As Boolean
    End Class

    Public Class AutoUpdateService
        Private Const DEFAULT_API_BASE_URL As String = "http://185.216.203.50:8000"
        Private ReadOnly _dbHelper As DatabaseHelper
        Private ReadOnly _apiBaseUrl As String

        Public Sub New(Optional dbHelper As DatabaseHelper = Nothing, Optional apiBaseUrl As String = Nothing)
            _dbHelper = If(dbHelper, New DatabaseHelper())
            _apiBaseUrl = If(String.IsNullOrWhiteSpace(apiBaseUrl), DEFAULT_API_BASE_URL, apiBaseUrl.TrimEnd("/"c))
        End Sub

        ''' <summary>
        ''' الفحص من السيرفر عما إذا كان هناك تحديث متوفر لهذه النسخة وقاعدة البيانات
        ''' </summary>
        Public Async Function CheckForUpdateAsync() As Task(Of UpdateInfo)
            Dim currentVer As String = My.Application.Info.Version.ToString()
            Dim flavor As String = _dbHelper.TenantFlavor

            Dim checkUrl As String = $"{_apiBaseUrl}/updates/check?platform=wpf&flavor={flavor}&current_version={currentVer}"

            Try
                Using client As New HttpClient()
                    client.Timeout = TimeSpan.FromSeconds(10)
                    Dim jsonResponse As String = Await client.GetStringAsync(checkUrl)
                    Return ParseUpdateResponse(jsonResponse, currentVer)
                End Using
            Catch ex As Exception
                Debug.WriteLine("Error checking for updates: " & ex.Message)
                Return New UpdateInfo() With {
                    .HasUpdate = False,
                    .CurrentVersion = currentVer
                }
            End Try
        End Function

        ''' <summary>
        ''' تنزيل ملف Inno Setup وتشغيله بالوضع الصامت لإتمام التحديث التلقائي
        ''' </summary>
        Public Async Function DownloadAndInstallAsync(updateInfo As UpdateInfo, Optional progressCallback As Action(Of Integer) = Nothing) As Task(Of Boolean)
            If updateInfo Is Nothing OrElse String.IsNullOrWhiteSpace(updateInfo.DownloadUrl) Then
                Return False
            End If

            Dim fullUrl As String = updateInfo.DownloadUrl
            If Not fullUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then
                fullUrl = $"{_apiBaseUrl}{If(fullUrl.StartsWith("/"), "", "/")}{fullUrl}"
            End If

            Dim installerFileName As String = If(String.IsNullOrWhiteSpace(updateInfo.InstallerName), "UpdateSetup.exe", updateInfo.InstallerName)
            Dim tempFilePath As String = Path.Combine(Path.GetTempPath(), installerFileName)

            Try
                Using client As New HttpClient()
                    Using response As HttpResponseMessage = Await client.GetAsync(fullUrl, HttpCompletionOption.ResponseHeadersRead)
                        response.EnsureSuccessStatusCode()

                        Dim totalBytes As Long? = response.Content.Headers.ContentLength
                        Using contentStream As Stream = Await response.Content.ReadAsStreamAsync(),
                              fileStream As New FileStream(tempFilePath, FileMode.Create, FileAccess.Write, FileShare.None, 8192, True)

                            Dim buffer(8191) As Byte
                            Dim bytesRead As Integer
                            Dim totalRead As Long = 0

                            Do
                                bytesRead = Await contentStream.ReadAsync(buffer, 0, buffer.Length)
                                If bytesRead = 0 Then Exit Do

                                Await fileStream.WriteAsync(buffer, 0, bytesRead)
                                totalRead += bytesRead

                                If totalBytes.HasValue AndAlso totalBytes.Value > 0 Then
                                    Dim percentage As Integer = CInt((totalRead * 100) / totalBytes.Value)
                                    progressCallback?.Invoke(percentage)
                                End If
                            Loop
                        End Using
                    End Using
                End Using

                progressCallback?.Invoke(100)

                ' تشغيل ملف Inno Setup بالمعاملات الصامتة
                Dim startInfo As New ProcessStartInfo() With {
                    .FileName = tempFilePath,
                    .Arguments = "/VERYSILENT /SUPPRESSMSGBOXES /CLOSEAPPLICATIONS /NORESTART",
                    .UseShellExecute = True
                }

                Process.Start(startInfo)

                ' إغلاق التطبيق الحالي للسماح لـ Inno Setup باستبدال الملفات
                System.Windows.Application.Current.Shutdown()
                Return True
            Catch ex As Exception
                Debug.WriteLine("Error downloading and applying update: " & ex.Message)
                Return False
            End Try
        End Function

        ''' <summary>
        ''' تحليل استجابة السيرفر النصية JSON بدون الحاجة لمكتبات خارجية معقدة
        ''' </summary>
        Private Function ParseUpdateResponse(json As String, currentVersion As String) As UpdateInfo
            Dim info As New UpdateInfo() With {
                .CurrentVersion = currentVersion,
                .HasUpdate = False
            }

            Try
                info.HasUpdate = ExtractJsonBool(json, "has_update")
                info.LatestVersion = ExtractJsonString(json, "latest_version")
                info.DownloadUrl = ExtractJsonString(json, "download_url")
                info.ReleaseNotes = ExtractJsonString(json, "release_notes")
                info.InstallerName = ExtractJsonString(json, "installer_name")
                info.IsMandatory = ExtractJsonBool(json, "is_mandatory")
            Catch ex As Exception
                Debug.WriteLine("Error parsing update JSON: " & ex.Message)
            End Try

            Return info
        End Function

        Private Function ExtractJsonString(json As String, key As String) As String
            Dim match = Regex.Match(json, $"""{key}""\s*:\s*""([^""]*)""")
            If match.Success Then
                Return Regex.Unescape(match.Groups(1).Value)
            End If
            Return ""
        End Function

        Private Function ExtractJsonBool(json As String, key As String) As Boolean
            Dim match = Regex.Match(json, $"""{key}""\s*:\s*(true|false)", RegexOptions.IgnoreCase)
            If match.Success Then
                Return Boolean.Parse(match.Groups(1).Value)
            End If
            Return False
        End Function
    End Class
End Namespace
