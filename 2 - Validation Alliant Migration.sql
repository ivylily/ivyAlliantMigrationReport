/* 	Customers Validation 
	Check the Company Name is not empty
*/
CREATE OR ALTER VIEW [Migration].[vw_IncorrectEntityCustomers] AS
SELECT 
[entity_id],
'Entity and dependent tables cannot be imported due to insufficient data. Error: no entity name found.' as ErrorMessage
FROM [Migration].[Stage_Entities] e
WHERE UPPER(type_flag) = 'A'
AND entity_label is null or trim(entity_label) = ''
GO

/* 	Suppliers Validation 
	Check the Company Name is not empty
*/
CREATE OR ALTER VIEW [Migration].[vw_IncorrectEntitySuppliers] AS
SELECT 
[entity_id],
'Entity and dependent tables cannot be imported due to insufficient data. Error: no entity name found.' as ErrorMessage
FROM [Migration].[Stage_Entities] e
WHERE UPPER(type_flag) = 'B'
AND entity_label is null or trim(entity_label) = ''
GO

/* 	Products Validation
	Check the Company Name is not empty
	Check the Unit Cost has value and can be parsed
 */
CREATE OR ALTER VIEW [Migration].[vw_IncorrectItemProducts] AS
SELECT
[item_id],
CASE WHEN [label] is null or trim([label]) = '' THEN 'Product and dependent tables cannot be imported due to insufficient data. Error: no product name found.' 
WHEN TRY_CAST(REPLACE(cost, '$', '') as money) is NULL THEN 'Product and dependent tables cannot be imported due to insufficient data. Error: no product cost found.'
END AS ErrorMessage
FROM [Migration].[Stage_Items] i
WHERE [label] is null or trim([label]) = '' or TRY_CAST(REPLACE(cost, '$', '') as money) is NULL
GO

/* 	Orders Validation 
	Check the total_amount is not null and can be parsed
	Check the sum(amount) for all VALID transactions totals 100
*/
CREATE OR ALTER VIEW [Migration].[vw_IncorrectBatcheOrders] AS
WITH BatchTransactionInfo AS (
    SELECT 
        b.batch_id,
        b.total_value,
        SUM(TRY_CAST(REPLACE(t.amount, '%', '') AS INT)) AS total_amount,
        TRY_CAST(REPLACE(b.total_value, 'USD', '') AS money) AS parsed_total_value
    FROM [Migration].[Stage_Batches] b
    JOIN [Migration].[Stage_Transactions] t ON b.batch_id = t.batch_ref
	WHERE t.is_valid = 1 -- if invalid the total amount will not meet the criteria
    GROUP BY b.batch_id, b.total_value
)
SELECT 
    batch_id,
    STRING_AGG(CASE 
        WHEN parsed_total_value IS NULL THEN 'Batch and dependent tables cannot be imported due to insufficient data. Error: total value cannot be ascertained.' 
        WHEN total_amount > 100 THEN 'Batch and dependent tables cannot be imported due to insufficient data. Error: the batch transaction amount surpasses 100%.'
        WHEN total_amount < 100 THEN 'Batch and dependent tables cannot be imported due to insufficient data. Error: the batch transaction amount is below 100%.'
        END, ',') AS ErrorMessage
FROM BatchTransactionInfo
WHERE parsed_total_value IS NULL OR total_amount <> 100 OR total_amount is null
GROUP BY batch_id
GO



/* Order Details Validation 
	Check the amount is not empty and can be parsed
	Checks the transaction is not a duplicate (all columns except transacion_id are the same)
*/
CREATE OR ALTER VIEW [Migration].[vw_IncorrectTransactionOrderDetails] AS

-- Markup the transactions so that we know which one have duplicates and should not be used 
WITH TransactionRank AS (
    SELECT transaction_id,
    [batch_ref],
    [item_ref],
    [amount],
    ROW_NUMBER() OVER (PARTITION BY [batch_ref], [item_ref], [date_key] ORDER BY [date_key]) AS row_id,
    TRY_CAST(REPLACE(amount, '%', '') AS money) AS parsed_amount --Parsing the transaction amount
    FROM [Migration].[Stage_Transactions] t
)
SELECT 
    transaction_id, 
    STRING_AGG(CASE WHEN row_id > 1 THEN 'Transaction will not be imported as it is a duplicate.'
            WHEN parsed_amount IS NULL THEN 'Transaction cannot be imported due to insufficient data. Error: amount percent cannot be ascertained.'
            ELSE NULL END, ';') AS ErrorMessage
FROM TransactionRank
WHERE row_id > 1  -- Filter for duplicates and invalid amounts only
   OR parsed_amount IS NULL
GROUP BY transaction_id;
GO


/* In case you need to see all table errors in a single report */
CREATE VIEW Migration.vw_IncorrectTableInfo AS
SELECT batch_id as TableId, 'Batches' as TableName, ErrorMessage FROM [Migration].[vw_IncorrectBatcheOrders] 
UNION
SELECT [entity_id] as TableId, 'Entity' as TableName, ErrorMessage FROM [Migration].[vw_IncorrectEntityCustomers] 
UNION
SELECT [entity_id] as TableId, 'Entity' as TableName, ErrorMessage FROM [Migration].[vw_IncorrectEntitySuppliers] 
UNION
SELECT [item_id] as TableId, 'Items' as TableName, ErrorMessage FROM [Migration].[vw_IncorrectItemProducts] 
UNION
SELECT transaction_id as TableId, 'Transactions' as TableName, ErrorMessage FROM [Migration].[vw_IncorrectTransactionOrderDetails]
GO



/* Use the views to update the data. We need to cascade errors from one table to another so the Reference Checks are done in the updates. */
UPDATE e
SET [is_valid] = 0
, [validation_error] = ec.[ErrorMessage]
FROM [Migration].[Stage_Entities] e
JOIN [Migration].[vw_IncorrectEntityCustomers] ec ON e.[entity_id] = ec.[entity_id]
GO 

UPDATE e
SET [is_valid] = 0
, [validation_error] = es.[ErrorMessage]
FROM [Migration].[Stage_Entities] e
JOIN [Migration].[vw_IncorrectEntitySuppliers] es ON e.[entity_id] = es.[entity_id]
GO

UPDATE i
SET [is_valid] = CASE WHEN iip.[item_id] IS NOT NULL OR e.[entity_id] is NULL OR e.[is_valid] = 0 THEN 0 ELSE 1 END
, [validation_error] = CASE 
						WHEN iip.[item_id] IS NOT NULL THEN iip.[ErrorMessage] 
						WHEN e.[entity_id] is NULL OR e.[is_valid] = 0 THEN 'Invalid supplier reference.' END
FROM [Migration].[Stage_Items] i
LEFT JOIN [Migration].[vw_IncorrectItemProducts] iip ON i.[item_id] = iip.[item_id]
LEFT JOIN [Migration].[Stage_Entities] e ON i.[source_ref] = e.[entity_id] and e.[type_flag] = 'B'
GO


UPDATE b
SET [is_valid] = CASE WHEN e.[entity_id] is NULL OR e.[is_valid] = 0 THEN 0 ELSE 1 END
, [validation_error] = CASE 					
						WHEN e.[entity_id] is NULL OR e.[is_valid] = 0 THEN 'Invalid customer reference.' END
FROM [Migration].[Stage_Batches] as b 
LEFT JOIN [Migration].[Stage_Entities] e ON b.[reference_id] = e.[entity_id] 
GO

UPDATE t
SET [is_valid] = CASE WHEN tod.[transaction_id] IS NOT NULL OR i.[is_valid] = 0 THEN 0 ELSE 1 END
, [validation_error] = CASE 
						WHEN tod.[transaction_id] IS NOT NULL THEN tod.[ErrorMessage] 						
						WHEN i.[is_valid] = 0 THEN 'Invalid item reference.' END
FROM [Migration].[Stage_Transactions] as t 
LEFT JOIN [Migration].[vw_IncorrectTransactionOrderDetails] tod ON t.[transaction_id] = tod.[transaction_id]
LEFT JOIN [Migration].[Stage_Items] i ON t.item_ref = i.item_id
GO
