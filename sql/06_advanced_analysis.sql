/*==============================================================================
    Project: CRM Sales Pipeline Analysis
    File: 06_advanced_analysis.sql
    Purpose:
        Create reusable analytical objects and demonstrate SQL Server
        performance optimization techniques.

    Platform:
        Microsoft SQL Server / T-SQL

    Demonstrates:
        - Views
        - Stored procedures
        - Parameters
        - Nonclustered indexes
        - Covering indexes
        - Sargable filtering
        - Execution-plan analysis
==============================================================================*/

USE CRM_Sales_Analytics;
GO


-- ============================================================================
-- 1. ANALYTICAL VIEW
--
-- Combines pipeline, sales-team, product, and account information into a
-- reusable reporting dataset.
--
-- LEFT JOIN is used for accounts because some legitimate open opportunities
-- do not yet have an assigned account.
-- ============================================================================

CREATE OR ALTER VIEW crm.vw_opportunity_details
AS

SELECT
    p.opportunity_id,
    p.sales_agent,
    t.manager,
    t.regional_office,

    p.product,
    pr.series,
    pr.sales_price,

    p.account,
    a.sector,
    a.year_established,
    a.revenue AS account_revenue,
    a.employees AS account_employees,
    a.office_location,
    a.subsidiary_of,

    p.deal_stage,
    p.engage_date,
    p.close_date,
    p.close_value,

    CASE
        WHEN p.deal_stage IN ('Won', 'Lost')
        THEN 'Closed'
        ELSE 'Open'
    END AS pipeline_status,

    CASE
        WHEN p.engage_date IS NOT NULL
         AND p.close_date IS NOT NULL
        THEN DATEDIFF(
            DAY,
            p.engage_date,
            p.close_date
        )
        ELSE NULL
    END AS sales_cycle_days

FROM crm.sales_pipeline AS p

INNER JOIN crm.sales_teams AS t
    ON p.sales_agent = t.sales_agent

INNER JOIN crm.products AS pr
    ON p.product = pr.product

LEFT JOIN crm.accounts AS a
    ON p.account = a.account;
GO


-- ============================================================================
-- 2. VALIDATE VIEW ROW COUNT
--
-- Expected project result:
-- 8,800 rows
-- ============================================================================

SELECT
    COUNT(*) AS view_row_count
FROM crm.vw_opportunity_details;
GO


-- ============================================================================
-- 3. CREATE NONCLUSTERED INDEX
--
-- Supports frequent analysis of deal stage and close date.
-- close_value is included so revenue calculations can often be satisfied
-- directly from the index without additional table lookups.
-- ============================================================================

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_sales_pipeline_deal_stage_close_date'
      AND object_id = OBJECT_ID('crm.sales_pipeline')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_sales_pipeline_deal_stage_close_date
        ON crm.sales_pipeline
        (
            deal_stage,
            close_date
        )
        INCLUDE
        (
            close_value
        );
END;
GO


-- ============================================================================
-- 4. STORED PROCEDURE
--
-- Returns won-deal KPIs for a user-defined date range.
-- ============================================================================

CREATE OR ALTER PROCEDURE crm.usp_won_sales_summary
    @StartDate DATE,
    @EndDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        @StartDate AS start_date,
        @EndDate AS end_date,

        COUNT(*) AS won_deals,

        CAST(
            SUM(close_value)
            AS DECIMAL(18, 2)
        ) AS won_revenue,

        CAST(
            AVG(close_value)
            AS DECIMAL(18, 2)
        ) AS average_won_deal_value

    FROM crm.sales_pipeline

    WHERE deal_stage = 'Won'
      AND close_date BETWEEN @StartDate AND @EndDate;
END;
GO


-- ============================================================================
-- 5. TEST STORED PROCEDURE
--
-- Expected result for June 2017:
-- Won Deals:              531
-- Won Revenue:            1,338,466.00
-- Average Won Deal Value: 2,520.65
-- ============================================================================

EXEC crm.usp_won_sales_summary
    @StartDate = '2017-06-01',
    @EndDate   = '2017-06-30';
GO


-- ============================================================================
-- 6. SARGABLE DATE FILTER
--
-- SARGABLE = Search ARGument ABLE.
--
-- The close_date column is compared directly to a date range, allowing SQL
-- Server to use the index efficiently.
--
-- During project testing:
--     Rows returned: 531
--     Rows read:     531
--     Access method: Index Seek
-- ============================================================================

SELECT
    opportunity_id,
    close_date,
    close_value

FROM crm.sales_pipeline

WHERE deal_stage = 'Won'
  AND close_date >= '2017-06-01'
  AND close_date < '2017-07-01';
GO


-- ============================================================================
-- 7. NON-SARGABLE COMPARISON
--
-- Applying YEAR() and MONTH() directly to close_date requires SQL Server to
-- evaluate functions against qualifying rows instead of using the date range
-- as efficiently.
--
-- During project testing:
--     Rows returned: 531
--     Rows read:     4,238
--
-- This query is included for performance-comparison purposes.
-- ============================================================================

SELECT
    opportunity_id,
    close_date,
    close_value

FROM crm.sales_pipeline

WHERE deal_stage = 'Won'
  AND YEAR(close_date) = 2017
  AND MONTH(close_date) = 6;
GO