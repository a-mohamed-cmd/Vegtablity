IF OBJECT_ID('[Inventory].[sp_Inventory_GetAvgCostByProduct]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Inventory_GetAvgCostByProduct];
GO
CREATE PROCEDURE [Inventory].[sp_Inventory_GetAvgCostByProduct]
    @ProductID INT,
    @WarehouseID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(AvgCostPrice, 0) 
    FROM [Inventory].[ProductStock] 
    WHERE ProductID = @ProductID AND WarehouseID = @WarehouseID;
END
GO
