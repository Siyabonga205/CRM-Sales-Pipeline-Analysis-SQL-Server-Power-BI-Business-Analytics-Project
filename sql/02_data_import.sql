/*==============================================================================
    Project: CRM Sales Pipeline Analysis
    File: 02_data_import.sql
    Purpose:
        Import the four CRM source files into the raw staging tables.

    Platform:
        Microsoft SQL Server / T-SQL

    Important:
        Replace <DATA_FOLDER> below with the folder containing the CSV files.

        Example:
        C:\Data\CRM_Sales_Opportunities\

    Source-file notes:
        - Files use semicolon (;) delimiters.
        - The first row contains column headers.
        - Files use UTF-8 encoding.
        - ROWTERMINATOR = 0x0A handles the line-feed character.
        - Carriage-return characters remaining in final columns are handled
          later during the data-cleaning stage.

    Safety:
        Imports only occur when the corresponding raw table is empty.
==============================================================================*/

USE CRM_Sales_Analytics;
GO


-- ============================================================================
-- 1. IMPORT ACCOUNTS
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM raw.accounts)
BEGIN
    BULK INSERT raw.accounts
    FROM '<DATA_FOLDER>\accounts.csv'
    WITH
    (
        DATAFILETYPE = 'char',
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0A',
        CODEPAGE = '65001',
        TABLOCK
    );
END;
GO


-- ============================================================================
-- 2. IMPORT PRODUCTS
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM raw.products)
BEGIN
    BULK INSERT raw.products
    FROM '<DATA_FOLDER>\products.csv'
    WITH
    (
        DATAFILETYPE = 'char',
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0A',
        CODEPAGE = '65001',
        TABLOCK
    );
END;
GO


-- ============================================================================
-- 3. IMPORT SALES TEAMS
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM raw.sales_teams)
BEGIN
    BULK INSERT raw.sales_teams
    FROM '<DATA_FOLDER>\sales_teams.csv'
    WITH
    (
        DATAFILETYPE = 'char',
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0A',
        CODEPAGE = '65001',
        TABLOCK
    );
END;
GO


-- ============================================================================
-- 4. IMPORT SALES PIPELINE
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM raw.sales_pipeline)
BEGIN
    BULK INSERT raw.sales_pipeline
    FROM '<DATA_FOLDER>\sales_pipeline.csv'
    WITH
    (
        DATAFILETYPE = 'char',
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0A',
        CODEPAGE = '65001',
        TABLOCK
    );
END;
GO


-- ============================================================================
-- 5. VALIDATE IMPORTED ROW COUNTS
-- ============================================================================

SELECT
    'raw.accounts' AS table_name,
    COUNT(*) AS row_count
FROM raw.accounts

UNION ALL

SELECT
    'raw.products',
    COUNT(*)
FROM raw.products

UNION ALL

SELECT
    'raw.sales_teams',
    COUNT(*)
FROM raw.sales_teams

UNION ALL

SELECT
    'raw.sales_pipeline',
    COUNT(*)
FROM raw.sales_pipeline;
GO
