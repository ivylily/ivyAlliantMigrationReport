CREATE PROCEDURE [dbo].[GetCustomerPurchaseReport]
    @StartDate DATETIME, -- Start of the date range
    @EndDate DATETIME,   -- End of the date range
    @CategoryName VARCHAR(15) = NULL -- Product category (optional, NULL for all categories)
AS
BEGIN
    BEGIN TRY
        -- Start of the procedure
        SET NOCOUNT ON;

        -- Validate date range
        IF @StartDate IS NULL OR @EndDate IS NULL
        BEGIN
            RAISERROR('StartDate and EndDate cannot be NULL.', 16, 1);
            RETURN;
        END

        IF @StartDate > @EndDate
        BEGIN
            RAISERROR('StartDate cannot be greater than EndDate.', 16, 1);
            RETURN;
        END

        -- Select data based on parameters
        SELECT 
        C.CustomerID AS [Customer identifier],
        C.CompanyName AS [Company name],
        C.ContactName AS [Customer contact name],
        O.OrderID AS [Order identifier],
        O.OrderDate AS [Order date],
        P.ProductName AS [Product name],
        OD.Quantity,
        OD.UnitPrice AS [Item Unit price],
        (OD.Quantity * OD.UnitPrice * (1 - OD.Discount)) AS [Total price],
        Cat.CategoryName AS [Category name]
        FROM [Orders] O
        INNER JOIN [Customers] C ON O.CustomerID = C.CustomerID
        INNER JOIN [Order Details] OD ON O.OrderID = OD.OrderID
        INNER JOIN [Products] P ON OD.ProductID = P.ProductID
        INNER JOIN [Categories] Cat ON P.CategoryID = Cat.CategoryID
        WHERE O.OrderDate BETWEEN @StartDate AND @EndDate
            AND (@CategoryName IS NULL OR CAT.CategoryName = @CategoryName)
        ORDER BY O.OrderDate, C.CompanyName;

    END TRY
    BEGIN CATCH
        -- Error handling
        DECLARE @ErrorMessage NVARCHAR(4000);
        DECLARE @ErrorSeverity INT;
        DECLARE @ErrorState INT;

        SELECT 
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO
