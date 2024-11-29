/* Merge was used instead of Insert to be able to output both sourcee and destination tables ids (for the mapping verification) */
MERGE INTO [dbo].[Customers] AS Target
USING (
    SELECT
		e.[entity_id],
        dbo.GenerateCustomerID(e.[entity_label]) AS CustomerID,
        e.[entity_label] AS CompanyName, 
        e.[contact_info] AS Phone, 
        l.[street_addr] AS [Address], 
        l.[municipality] AS City, 
        l.[region_code] AS Region, 
        l.[postal_code] AS PostalCode,
        'USA' AS Country --Assumed all cliennts/customers are from USA
    FROM [Migration].[Stage_Entities] e
    JOIN [Migration].[Stage_Locations] l ON l.[location_id] = e.location_ref
    WHERE UPPER(type_flag) = 'A' AND e.is_valid = 1
) AS Source
ON Target.CustomerID = Source.CustomerID
WHEN NOT MATCHED THEN
    INSERT (CustomerID, CompanyName, Phone, [Address], City, Region, PostalCode, Country)
    VALUES (Source.CustomerID, Source.CompanyName, Source.Phone, Source.[Address], Source.City, Source.Region, Source.PostalCode, Source.Country)
OUTPUT 
	JSON_OBJECT('CustomerID': INSERTED.CustomerID), 
	JSON_OBJECT('entity_id': Source.[entity_id]),
	'Customers'   
INTO [Migration].[InsertLog] ([NorthwindTableID], [AlliantTableID], [TableName]); --Logs information for future use
GO


MERGE INTO [dbo].[Suppliers] AS Target
USING (
    SELECT
		e.[entity_id],
        e.[entity_label] AS CompanyName, 
        e.[contact_info] AS Phone, 
        l.[street_addr] AS [Address], 
        l.[municipality] AS City, 
        l.[region_code] AS Region, 
        l.[postal_code] AS PostalCode,
        'USA' AS Country --Assumed all cliennts/customers are from USA
    FROM [Migration].[Stage_Entities] e
    JOIN [Migration].[Stage_Locations] l ON l.[location_id] = e.location_ref
    WHERE UPPER(type_flag) = 'B' AND e.is_valid = 1
) AS Source
ON Target.CompanyName = Source.CompanyName
WHEN NOT MATCHED THEN
    INSERT (CompanyName, Phone, [Address], City, Region, PostalCode, Country)
    VALUES (Source.CompanyName, Source.Phone, Source.[Address], Source.City, Source.Region, Source.PostalCode, Source.Country)
OUTPUT 
    JSON_OBJECT('SupplierID': INSERTED.SupplierID),
	JSON_OBJECT('entity_id': Source.[entity_id] ),
	'Suppliers'   
INTO [Migration].[InsertLog] ([NorthwindTableID], [AlliantTableID], [TableName]); --Logs information for future use
GO

MERGE INTO [dbo].[Products] AS Target
USING (
    SELECT 		
        [label] AS [ProductName], 
        s.SupplierID AS SupplierID,
        TRY_CAST(REPLACE(cost, '$', '') AS MONEY) AS UnitPrice, -- Clean up the field then cast the value to the correct datatype
        qty_available AS UnitsInStock,
        i.item_id
    FROM [Migration].[Stage_Items] i
    JOIN [Migration].[Stage_Entities] e ON i.source_ref = e.[entity_id]
    JOIN [dbo].[Suppliers] s ON e.[entity_label] = s.CompanyName
    WHERE i.is_valid = 1
) AS Source
ON 1 = 0  -- Ensures this always results in an INSERT
WHEN NOT MATCHED THEN
    INSERT (ProductName, SupplierID, UnitPrice, UnitsInStock)
    VALUES (Source.ProductName, Source.SupplierID, Source.UnitPrice, Source.UnitsInStock)
OUTPUT 
JSON_OBJECT('ProductID':INSERTED.ProductID),
JSON_OBJECT('item_id':Source.item_id ),
'Products'   
INTO [Migration].[InsertLog] ([NorthwindTableID], [AlliantTableID], [TableName]); --Logs information for future use


/*
    In this case we need to keep the references for batches before loading transactions as the Batches tables has no natural key.
*/
CREATE TABLE #InsertedOrders (
    OrderID INT NOT NULL,
    batch_id INT NOT NULL,
    TotalValue MONEY NOT NULL
);
GO

MERGE INTO [dbo].[Orders] AS Target
USING (
    SELECT 
        b.batch_id,
        TRY_CAST(REPLACE(b.[total_value], 'USD', '') AS money) AS TotalValue,
        DATEADD(S, CONVERT(int, LEFT(batch_date, 10)), '1970-01-01') AS OrderDate,
        c.CustomerID AS CustomerID
    FROM [Migration].[Stage_Batches] b
    JOIN [Migration].[Stage_Entities] e ON b.[reference_id] = e.[entity_id]
    JOIN [dbo].[Customers] c ON e.[entity_label] = c.CompanyName
    WHERE b.is_valid = 1
) AS Source
ON 1 = 0 -- Ensures all rows are treated as new inserts
WHEN NOT MATCHED THEN
    INSERT (OrderDate, CustomerID)
    VALUES (Source.OrderDate, Source.CustomerID)
OUTPUT 
    INSERTED.OrderID, 
    Source.batch_id, 
    Source.TotalValue
INTO #InsertedOrders; -- Temporary table to store inserted orders
GO

MERGE INTO [dbo].[Order Details] AS Target
USING (
    SELECT
		STRING_AGG(CAST(t.transaction_id as NVARCHAR(100)), ',') as transaction_ids,
        io.OrderID,
        p.ProductID,
        SUM(t.qty) AS Quantity,
        io.TotalValue * SUM(CAST(REPLACE(t.amount, '%', '') AS money) / 100) / SUM(t.qty) AS UnitPrice
    FROM [Migration].[Stage_Transactions] t
    JOIN [Migration].[Stage_Items] i ON t.item_ref = i.item_id
    JOIN [dbo].[Products] p ON i.[label] = p.ProductName
    JOIN #InsertedOrders io ON io.batch_id = t.batch_ref -- Map transactions to their batch's inserted order
    WHERE t.is_valid = 1
    GROUP BY io.OrderID, p.ProductID, io.TotalValue
) AS Source
ON 1 = 0 -- Ensures all rows are treated as new inserts
WHEN NOT MATCHED THEN
    INSERT (OrderID, ProductID, Quantity, UnitPrice)
    VALUES (Source.OrderID, Source.ProductID, Source.Quantity, Source.UnitPrice)
OUTPUT 
    JSON_OBJECT('OrderID':INSERTED.OrderID, 'ProductID':INSERTED.ProductID),
    JSON_OBJECT('transaction_ids': SOURCE.transaction_ids),
    '[Order Details]'
INTO [Migration].[InsertLog]([NorthwindTableID], [AlliantTableID], [TableName]);


INSERT INTO [Migration].[InsertLog] ([NorthwindTableID], [AlliantTableID], [TableName])
SELECT JSON_OBJECT('OrderID':OrderID),
    JSON_OBJECT('batch_id': batch_id),
    'Orders'FROM #InsertedOrders;
GO

-- Clean up temporary table
DROP TABLE #InsertedOrders;
GO