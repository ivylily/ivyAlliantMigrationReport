/* CREATE INDEXES IF THEY DO NOT EXISTS */
/* This tables have very little data so indexing is really optional*/
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID_OrderID
ON Orders (CustomerID, OrderID);

CREATE NONCLUSTERED INDEX IX_Order_Details_OrderID_ProductID
ON [Order Details] (OrderID, ProductID);

/* REPORTING QUERY */
/* Now onto this query even though we are seeing the same data it is sliced in very no inclusive ways
   I abstracted all common operations by using Commont Table Expressions for readability and reuse in later steps
   They idea is to do the slices separately and then joining taking adavantage of the CTE optimizations (vs complex subqueries)
*/
WITH LastYearOrders AS (
	SELECT 
	o.OrderID
	, CustomerID
	, OrderDate
	FROM [Orders] o
	LEFT JOIN [Order Details] od on o.OrderID = od.OrderID
	WHERE o.OrderDate BETWEEN DATEADD(year, -1, GETDATE()) and GETDATE()
), 
CustomersWithOrders AS (
	SELECT 
	c.CustomerID
	, c.CompanyName
	, COUNT(DISTINCT od.ProductID) as DistinctProductCount
	FROM LastYearOrders o
	JOIN Customers c ON o.CustomerId = c.CustomerID
	JOIN [Order Details] od ON o.OrderID = od.OrderID
	GROUP BY c.CustomerID, c.CompanyName
	HAVING COUNT(DISTINCT o.OrderID) >= 5
), 
CustomerMonthOrders AS (
	SELECT 
	c.CustomerID
	, YEAR(o.OrderDate) AS [Year]
	, MONTH(o.OrderDate) AS [Month]
	, COUNT(o.OrderId) AS OrderCount
	FROM CustomersWithOrders c
	JOIN LastYearOrders o ON o.CustomerID = c.CustomerID
	GROUP BY c.CustomerID, YEAR(o.OrderDate), MONTH(o.OrderDate)
)
SELECT 
cmo.CustomerID,
cwo.CompanyName,
AVG(OrderCount) AS [Average number of order per month],
MAX(cwo.DistinctProductCount) AS [Distinct count of products ordered]
FROM CustomerMonthOrders cmo
JOIN CustomersWithOrders cwo ON cmo.CustomerID = cwo.CustomerID
GROUP BY cmo.CustomerID, cwo.CompanyName
