CREATE OR ALTER FUNCTION [dbo].[GenerateCustomerID](@CompanyName NVARCHAR(255))
RETURNS CHAR(5)
AS
BEGIN
    DECLARE @Code CHAR(5)

    -- Ensure the company name is trimmed and handle null/empty input
    SET @CompanyName = LTRIM(RTRIM(ISNULL(@CompanyName, '')))

    IF LEN(@CompanyName) <> 0
    BEGIN
        -- Generate the 5-character code
        -- Use substrings, ASCII values, and a checksum for uniqueness
        SET @Code = 
            SUBSTRING(@CompanyName, 1, 1) +  --first characters 
			LEFT(CONVERT(VARCHAR(50), HASHBYTES('SHA1', @CompanyName), 2), 4)
    END

    RETURN upper(@Code)
END
GO

IF 
 ( NOT EXISTS (select [name] from sys.schemas where [name] = N'Migration') )
BEGIN
	EXEC ('CREATE SCHEMA [Migration]')
END
GO

/*
    The staging tables are mostly the same as in Alliant customer
    is_valid and validation_error fields were added to reduce querying time
    doing verifications during and after the process.
*/
CREATE TABLE [Migration].[Stage_Batches](
	[batch_id] [int] IDENTITY(1,1) NOT NULL,
	[batch_date] [bigint] NOT NULL,
	[reference_id] [int] NULL,
	[total_value] [varchar](15) NULL,
    is_valid BIT DEFAULT 1,
    validation_error VARCHAR(MAX),
    load_timestamp DATETIME DEFAULT GETDATE()
)
GO

CREATE TABLE [Migration].[Stage_Entities](
	[entity_id] [int] IDENTITY(1,1) NOT NULL,
	[entity_label] [varchar](100) NOT NULL,
	[type_flag] [char](1) NULL,
	[location_ref] [int] NULL,
	[contact_info] [varchar](20) NULL,
    is_valid BIT DEFAULT 1,
    validation_error VARCHAR(MAX),
    load_timestamp DATETIME DEFAULT GETDATE()
)
GO

CREATE TABLE [Migration].[Stage_Items](
	[item_id] [int] IDENTITY(1,1) NOT NULL,
	[label] [varchar](100) NOT NULL,
	[source_ref] [int] NULL,
	[group_ref] [int] NULL,
	[cost] [varchar](10) NULL,
	[qty_available] [int] NULL,
    is_valid BIT DEFAULT 1,
    validation_error VARCHAR(MAX),
    load_timestamp DATETIME DEFAULT GETDATE()
)
GO

CREATE TABLE [Migration].[Stage_Locations](
	[location_id] [int] IDENTITY(1,1) NOT NULL,
	[street_addr] [varchar](100) NULL,
	[municipality] [varchar](50) NULL,
	[region_code] [char](2) NULL,
	[postal_code] [varchar](10) NULL,
    is_valid BIT DEFAULT 1,
    validation_error VARCHAR(MAX),
    load_timestamp DATETIME DEFAULT GETDATE()
)
GO

CREATE TABLE [Migration].[Stage_Transactions](
	[transaction_id] [int] IDENTITY(1,1) NOT NULL,
	[batch_ref] [int] NULL,
	[item_ref] [int] NULL,
	[partner_ref] [int] NULL,
	[qty] [int] NULL,
	[date_key] [bigint] NULL,
	[amount] [varchar](10) NULL,
    is_valid BIT DEFAULT 1,
    validation_error VARCHAR(MAX),
    load_timestamp DATETIME DEFAULT GETDATE()
)
GO

/* A log table to hold the mapping between tables for verification */
IF 
 ( NOT EXISTS 
   (select object_id from sys.objects where object_id = OBJECT_ID(N'[Migration].[InsertLog]') and type = 'U')
 )
BEGIN
	CREATE TABLE [Migration].[InsertLog] (
		[AlliantTableID] NVARCHAR(200) NOT NULL,
		[NorthwindTableID] NVARCHAR(200) NOT NULL,
		[TableName] NVARCHAR(50) NOT NULL,        
        [InsertDate] DATETIME DEFAULT GETDATE()
	)
END
GO
