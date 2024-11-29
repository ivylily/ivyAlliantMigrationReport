CREATE SCHEMA [Audit];
GO

/* Tables to hold the logging information */
/* Quite simple approach I need to know what happened and this I save here, all details of WHAT was changed is stripped into a separate table. 
	I'm using JSON values as they are very versatile, 
	now I do not need to worry about the implementation for any new table o changes to the table schema.
	(though I would need to when querying this results)*/
CREATE TABLE [Audit].[Log](
	[LogID] [INT] IDENTITY(1,1) PRIMARY KEY,
	[TableName] NVARCHAR(50) NOT NULL, 
	[Operation] CHAR(1) NOT NULL, -- 1 on 3 posible values: 'I' for insert, 'U' for update, 'D' for delete
	[KeyValues] NVARCHAR(MAX) NOT NULL, -- JSON representation of the primary key(s)
	[ChangeDate] DateTime2  NOT NULL DEFAULT GETDATE(),
	[ChangedBy] NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER
);
GO

/* Tables to hold the logging information */
CREATE TABLE [Audit].[LogValues](	
	[LogValuesID] [INT] IDENTITY(1,1) PRIMARY KEY,
	[LogID] [INT] NOT NULL,
	[OldValues] NVARCHAR(MAX) NULL, -- JSON representation of the old data (for UPDATE/DELETE)
    [NewValues] NVARCHAR(MAX) NULL -- JSON representation of the new data (for INSERT/UPDATE)
);
GO

CREATE TRIGGER [dbo].[trg_Customers_Insert]
ON [dbo].[Customers]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [Audit].[Log] (TableName, Operation, KeyValues, ChangeDate, ChangedBy)
    SELECT 
        'Customers' AS TableName,
        'I' AS Operation,
        JSON_QUERY((
            SELECT CustomerID FROM inserted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS KeyValues,
        GETDATE() AS ChangeDate,
        SYSTEM_USER AS ChangedBy;

	INSERT INTO [Audit].[LogValues] (LogID, [NewValues])
    SELECT 
        SCOPE_IDENTITY()  ,
        JSON_QUERY((
            SELECT * FROM inserted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS NewValues

END;
GO

CREATE TRIGGER [dbo].[trg_Customers_Update]
ON [dbo].[Customers]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [Audit].[Log] (TableName, Operation, KeyValues, ChangeDate, ChangedBy)
    SELECT 
        'Customers' AS TableName,
        'U' AS Operation,
        JSON_QUERY((
            SELECT CustomerID FROM deleted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS KeyValues,        
        GETDATE() AS ChangeDate,
        SYSTEM_USER AS ChangedBy;

	INSERT INTO [Audit].[LogValues] (LogID, OldValues, NewValues)
    SELECT 
        SCOPE_IDENTITY(),
        JSON_QUERY((
            SELECT * FROM deleted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS OldValues,
        JSON_QUERY((
            SELECT * FROM inserted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS NewValues;
END;
GO

CREATE TRIGGER [dbo].[trg_Customers_Delete]
ON [dbo].[Customers]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [Audit].[Log] (TableName, Operation, KeyValues, ChangeDate, ChangedBy)
    SELECT 
        'Customers' AS TableName,
        'D' AS Operation,
        JSON_QUERY((
            SELECT CustomerID FROM deleted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS KeyValues,
        GETDATE() AS ChangeDate,
        SYSTEM_USER AS ChangedBy;

	INSERT INTO [Audit].[LogValues] (LogID, OldValues)
    SELECT 
        SCOPE_IDENTITY()  ,
        JSON_QUERY((
            SELECT * FROM deleted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS OldValues
END;
GO

CREATE TRIGGER [dbo].[trg_Products_Insert]
ON [dbo].[Products]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [Audit].[Log] (TableName, Operation, KeyValues, ChangeDate, ChangedBy)
    SELECT 
        'Products' AS TableName,
        'I' AS Operation,
        JSON_QUERY((
            SELECT ProductID FROM inserted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS KeyValues,
        GETDATE() AS ChangeDate,
        SYSTEM_USER AS ChangedBy;

	INSERT INTO [Audit].[LogValues] (LogID, NewValues)
    SELECT 
        SCOPE_IDENTITY(),
        JSON_QUERY((
            SELECT * FROM inserted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS NewValues;
END;
GO

CREATE TRIGGER [dbo].[trg_Products_Update]
ON [dbo].[Products]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [Audit].[Log] (TableName, Operation, KeyValues, ChangeDate, ChangedBy)
    SELECT 
        'Products' AS TableName,
        'U' AS Operation,
        JSON_QUERY((
            SELECT ProductID FROM deleted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS KeyValues,
        GETDATE() AS ChangeDate,
        SYSTEM_USER AS ChangedBy;

	INSERT INTO [Audit].[LogValues] (LogID, OldValues, NewValues)
    SELECT 
        SCOPE_IDENTITY(),
        JSON_QUERY((
            SELECT * FROM deleted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS OldValues,
        JSON_QUERY((
            SELECT * FROM inserted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS NewValues;
END;
GO

CREATE TRIGGER [dbo].[trg_Products_Delete]
ON [dbo].[Products]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [Audit].[Log] (TableName, Operation, KeyValues, ChangeDate, ChangedBy)
    SELECT 
        'Products' AS TableName,
        'D' AS Operation,
        JSON_QUERY((
            SELECT ProductID FROM deleted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS KeyValues,
        GETDATE() AS ChangeDate,
        SYSTEM_USER AS ChangedBy;

	INSERT INTO [Audit].[LogValues] (LogID, OldValues)
    SELECT 
        SCOPE_IDENTITY(),
        JSON_QUERY((
            SELECT * FROM deleted FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS OldValues;
END;
GO
