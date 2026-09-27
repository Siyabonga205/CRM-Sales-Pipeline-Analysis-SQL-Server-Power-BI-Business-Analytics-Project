/*==============================================================================
    Project: CRM Sales Pipeline Analysis
    File: 04_data_cleaning.sql
    Purpose:
        Transform the raw CRM staging data into cleaned, typed relational
        tables in the crm schema.

    Platform:
        Microsoft SQL Server / T-SQL

    Cleaning performed:
        - Trims unnecessary leading/trailing spaces.
        - Removes carriage-return characters from final CSV columns.
        - Converts blank values to NULL where appropriate.
        - Converts text values to correct numeric and date data types.
        - Reconciles the confirmed product-name spacing mismatch.
        - Creates primary and foreign key relationships.
        - Preserves all original source data in the raw schema.

    Safety:
        This script does NOT DROP, TRUNCATE, DELETE, or modify raw tables.
==============================================================================*/

USE CRM_Sales_Analytics;
GO


-- ============================================================================
-- 1. CREATE CLEAN ACCOUNTS TABLE
-- ============================================================================

IF OBJECT_ID('crm.accounts', 'U') IS NULL
BEGIN
    CREATE TABLE crm.accounts
    (
        account            NVARCHAR(255) NOT NULL,
        sector             NVARCHAR(100) NOT NULL,
        year_established   INT NOT NULL,
        revenue            DECIMAL(18, 2) NOT NULL,
        employees          INT NOT NULL,
        office_location    NVARCHAR(150) NOT NULL,
        subsidiary_of      NVARCHAR(255) NULL,

        CONSTRAINT PK_accounts
            PRIMARY KEY (account)
    );
END;
GO


-- ============================================================================
-- 2. LOAD CLEAN ACCOUNTS
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM crm.accounts)
BEGIN
    INSERT INTO crm.accounts
    (
        account,
        sector,
        year_established,
        revenue,
        employees,
        office_location,
        subsidiary_of
    )
    SELECT
        LTRIM(RTRIM(account)),

        LTRIM(RTRIM(sector)),

        TRY_CONVERT(
            INT,
            LTRIM(RTRIM(year_established))
        ),

        TRY_CONVERT(
            DECIMAL(18, 2),
            LTRIM(RTRIM(revenue))
        ),

        TRY_CONVERT(
            INT,
            LTRIM(RTRIM(employees))
        ),

        LTRIM(RTRIM(office_location)),

        NULLIF(
            LTRIM(
                RTRIM(
                    REPLACE(subsidiary_of, CHAR(13), '')
                )
            ),
            ''
        )

    FROM raw.accounts;
END;
GO


-- ============================================================================
-- 3. ADD ACCOUNT PARENT/SUBSIDIARY RELATIONSHIP
-- ============================================================================

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE name = 'FK_accounts_parent_account'
)
BEGIN
    ALTER TABLE crm.accounts
    ADD CONSTRAINT FK_accounts_parent_account
        FOREIGN KEY (subsidiary_of)
        REFERENCES crm.accounts(account);
END;
GO


-- ============================================================================
-- 4. CREATE CLEAN PRODUCTS TABLE
-- ============================================================================

IF OBJECT_ID('crm.products', 'U') IS NULL
BEGIN
    CREATE TABLE crm.products
    (
        product        NVARCHAR(255) NOT NULL,
        series         NVARCHAR(100) NOT NULL,
        sales_price    DECIMAL(18, 2) NOT NULL,

        CONSTRAINT PK_products
            PRIMARY KEY (product)
    );
END;
GO


-- ============================================================================
-- 5. LOAD CLEAN PRODUCTS
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM crm.products)
BEGIN
    INSERT INTO crm.products
    (
        product,
        series,
        sales_price
    )
    SELECT
        LTRIM(RTRIM(product)),

        LTRIM(RTRIM(series)),

        TRY_CONVERT(
            DECIMAL(18, 2),
            NULLIF(
                LTRIM(
                    RTRIM(
                        REPLACE(sales_price, CHAR(13), '')
                    )
                ),
                ''
            )
        )

    FROM raw.products;
END;
GO


-- ============================================================================
-- 6. CREATE CLEAN SALES TEAM TABLE
-- ============================================================================

IF OBJECT_ID('crm.sales_teams', 'U') IS NULL
BEGIN
    CREATE TABLE crm.sales_teams
    (
        sales_agent        NVARCHAR(255) NOT NULL,
        manager            NVARCHAR(255) NOT NULL,
        regional_office    NVARCHAR(150) NOT NULL,

        CONSTRAINT PK_sales_teams
            PRIMARY KEY (sales_agent)
    );
END;
GO


-- ============================================================================
-- 7. LOAD CLEAN SALES TEAM DATA
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM crm.sales_teams)
BEGIN
    INSERT INTO crm.sales_teams
    (
        sales_agent,
        manager,
        regional_office
    )
    SELECT
        LTRIM(RTRIM(sales_agent)),

        LTRIM(RTRIM(manager)),

        LTRIM(
            RTRIM(
                REPLACE(regional_office, CHAR(13), '')
            )
        )

    FROM raw.sales_teams;
END;
GO


-- ============================================================================
-- 8. CREATE CLEAN SALES PIPELINE TABLE
-- ============================================================================

IF OBJECT_ID('crm.sales_pipeline', 'U') IS NULL
BEGIN
    CREATE TABLE crm.sales_pipeline
    (
        opportunity_id    NVARCHAR(100) NOT NULL,
        sales_agent       NVARCHAR(255) NOT NULL,
        product           NVARCHAR(255) NOT NULL,
        account           NVARCHAR(255) NULL,
        deal_stage        NVARCHAR(100) NOT NULL,
        engage_date       DATE NULL,
        close_date        DATE NULL,
        close_value       DECIMAL(18, 2) NULL,

        CONSTRAINT PK_sales_pipeline
            PRIMARY KEY (opportunity_id),

        CONSTRAINT FK_sales_pipeline_sales_agent
            FOREIGN KEY (sales_agent)
            REFERENCES crm.sales_teams(sales_agent),

        CONSTRAINT FK_sales_pipeline_product
            FOREIGN KEY (product)
            REFERENCES crm.products(product),

        CONSTRAINT FK_sales_pipeline_account
            FOREIGN KEY (account)
            REFERENCES crm.accounts(account)
    );
END;
GO


-- ============================================================================
-- 9. LOAD CLEAN SALES PIPELINE
--
--    Product names are mapped back to the product master using a comparison
--    that ignores spaces. Exploration established that the unmatched product
--    records were caused by one spacing inconsistency rather than a genuinely
--    missing product.
--
--    The canonical product name stored in crm.products is retained.
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM crm.sales_pipeline)
BEGIN
    INSERT INTO crm.sales_pipeline
    (
        opportunity_id,
        sales_agent,
        product,
        account,
        deal_stage,
        engage_date,
        close_date,
        close_value
    )
    SELECT
        LTRIM(RTRIM(p.opportunity_id)),

        LTRIM(RTRIM(p.sales_agent)),

        pr.product,

        NULLIF(
            LTRIM(RTRIM(p.account)),
            ''
        ),

        LTRIM(RTRIM(p.deal_stage)),

        TRY_CONVERT(
            DATE,
            NULLIF(
                LTRIM(RTRIM(p.engage_date)),
                ''
            )
        ),

        TRY_CONVERT(
            DATE,
            NULLIF(
                LTRIM(RTRIM(p.close_date)),
                ''
            )
        ),

        TRY_CONVERT(
            DECIMAL(18, 2),
            NULLIF(
                LTRIM(
                    RTRIM(
                        REPLACE(p.close_value, CHAR(13), '')
                    )
                ),
                ''
            )
        )

    FROM raw.sales_pipeline AS p

    INNER JOIN crm.products AS pr
        ON REPLACE(LTRIM(RTRIM(p.product)), ' ', '')
           = REPLACE(pr.product, ' ', '');
END;
GO


-- ============================================================================
-- 10. VALIDATE CLEAN TABLE ROW COUNTS
-- ============================================================================

SELECT
    'crm.accounts' AS table_name,
    COUNT(*) AS row_count
FROM crm.accounts

UNION ALL

SELECT
    'crm.products',
    COUNT(*)
FROM crm.products

UNION ALL

SELECT
    'crm.sales_teams',
    COUNT(*)
FROM crm.sales_teams

UNION ALL

SELECT
    'crm.sales_pipeline',
    COUNT(*)
FROM crm.sales_pipeline;
GO


-- ============================================================================
-- 11. VALIDATE PIPELINE FOREIGN-KEY RELATIONSHIPS
-- ============================================================================

SELECT
    SUM(
        CASE
            WHEN t.sales_agent IS NULL
            THEN 1 ELSE 0
        END
    ) AS unmatched_sales_agents,

    SUM(
        CASE
            WHEN pr.product IS NULL
            THEN 1 ELSE 0
        END
    ) AS unmatched_products,

    SUM(
        CASE
            WHEN p.account IS NOT NULL
             AND a.account IS NULL
            THEN 1 ELSE 0
        END
    ) AS unmatched_accounts

FROM crm.sales_pipeline AS p

LEFT JOIN crm.sales_teams AS t
    ON p.sales_agent = t.sales_agent

LEFT JOIN crm.products AS pr
    ON p.product = pr.product

LEFT JOIN crm.accounts AS a
    ON p.account = a.account;
GO