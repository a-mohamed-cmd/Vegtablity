-- =============================================
-- Migration: 39_sp_Voucher_Unpost.sql
-- Description: إنشاء إجراء مخزن لإلغاء ترحيل سندات القبض والصرف
-- =============================================

IF OBJECT_ID('[Accounting].[sp_Voucher_Unpost]', 'P') IS NOT NULL 
    DROP PROCEDURE [Accounting].[sp_Voucher_Unpost];
GO

CREATE PROCEDURE [Accounting].[sp_Voucher_Unpost]
    @VoucherID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [Accounting].[Vouchers] WHERE VoucherID = @VoucherID)
    BEGIN
        RAISERROR(N'السند غير موجود', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM [Accounting].[Vouchers] WHERE VoucherID = @VoucherID AND IsPosted = 0)
    BEGIN
        RAISERROR(N'السند غير مرحّل بالفعل', 16, 1);
        RETURN;
    END

    -- تحديث IsPosted إلى 0 يُطلق تلقائياً Trigger [Accounting].[trg_Voucher_Post] لحذف القيود المحاسبية
    UPDATE [Accounting].[Vouchers] 
    SET IsPosted = 0 
    WHERE VoucherID = @VoucherID;
END
GO
