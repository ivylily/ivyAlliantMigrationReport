UPDATE [Northwind].[dbo].[Orders]
SET 
[OrderDate] = DATEADD(year, 26, [OrderDate])
,[RequiredDate] = DATEADD(year, 26, [RequiredDate])
,[ShippedDate] =DATEADD(year, 26, [ShippedDate])
