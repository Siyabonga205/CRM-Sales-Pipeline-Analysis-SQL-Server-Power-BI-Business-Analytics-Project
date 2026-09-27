/*==============================================================================
    Project: CRM Sales Pipeline Analysis
    File: 01_database_setup.sql
    Purpose:
        Create the project database, schemas, and raw staging tables.

    Platform:
        Microsoft SQL Server / T-SQL

    Notes:
        - The raw schema preserves source data before cleaning.
        - NVARCHAR is intentionally used in staging tables so source values
          can be imported before data-type validation and conversion.
        - The crm schema will contain the cleaned relational model.
==============================================================================*/

-- ============================================================================
-- 1. CREATE DATABASE
-- ============================================================================

IF DB_ID('CRM_Sales_Analytics') IS NULL
BEGIN
    CREATE DATABASE CRM_Sales_Analytics;
END;
GO


-- ============================================================================
-- 2. USE PROJECT DATABASE
-- ============================================================================

USE CRM_Sales_Analytics;
GO


-- ============================================================================
-- 3. CREATE SCHEMAS
-- ============================================================================

IF SCHEMA_ID('raw') IS NULL
BEGIN
    EXEC('CREATE SCHEMA raw');
END;
GO

IF SCHEMA_ID('crm') IS NULL
BEGIN
    EXEC('CREATE SCHEMA crm');
END;
GO


-- ============================================================================
-- 4. CREATE RAW ACCOUNTS TABLE
-- ============================================================================

IF OBJECT_ID('raw.accounts', 'U') IS NULL
BEGIN
    CREATE TABLE raw.accounts
    (
        account            NVARCHAR(255),
        sector             NVARCHAR(100),
        year_established   NVARCHAR(20),
        revenue            NVARCHAR(50),
        employees          NVARCHAR(50),
        office_location    NVARCHAR(150),
        subsidiary_of      NVARCHAR(255)
    );
END;
GO


-- ============================================================================
-- 5. CREATE RAW PRODUCTS TABLE
-- ============================================================================

IF OBJECT_ID('raw.products', 'U') IS NULL
BEGIN
    CREATE TABLE raw.products
    (
        product        NVARCHAR(255),
        series         NVARCHAR(100),
        sales_price    NVARCHAR(50)
    );
END;
GO


-- ============================================================================
-- 6. CREATE RAW SALES TEAMS TABLE
-- ============================================================================

IF OBJECT_ID('raw.sales_teams', 'U') IS NULL
BEGIN
    CREATE TABLE raw.sales_teams
    (
        sales_agent        NVARCHAR(255),
        manager            NVARCHAR(255),
        regional_office    NVARCHAR(150)
    );
END;
GO


-- ============================================================================
-- 7. CREATE RAW SALES PIPELINE TABLE
-- ============================================================================

IF OBJECT_ID('raw.sales_pipeline', 'U') IS NULL
BEGIN
    CREATE TABLE raw.sales_pipeline
    (
        opportunity_id    NVARCHAR(100),
        sales_agent       NVARCHAR(255),
        product           NVARCHAR(255),
        account           NVARCHAR(255),
        deal_stage        NVARCHAR(100),
        engage_date       NVARCHAR(50),
        close_date        NVARCHAR(50),
        close_value       NVARCHAR(50)
    );
END;
GO