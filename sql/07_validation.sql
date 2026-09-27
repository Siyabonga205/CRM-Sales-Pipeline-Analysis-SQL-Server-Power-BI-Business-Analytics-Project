/*==============================================================================
    Project: CRM Sales Pipeline Analysis
    File: 07_validation.sql
    Purpose:
        Perform final quality-control checks on the cleaned CRM model and
        confirm that analytical totals reconcile correctly.

    Platform:
        Microsoft SQL Server / T-SQL

    Validation Areas:
        1. Raw vs cleaned row counts
        2. Primary-key uniqueness
        3. Foreign-key relationships
        4. Deal-stage totals
        5. Revenue reconciliation
        6. Date logic
        7. Close-value business rules
        8. View row-count validation

    Safety:
        This script is read-only. It does not modify or delete data.
==============================================================================*/

USE CRM_Sales_Analytics;
GO


-- ============================================================================
-- 1. RAW VS CLEANED ROW COUNTS
-- ============================================================================

SELECT
    'accounts' AS dataset,
    (SELECT COUNT(*) FROM raw.accounts) AS raw_rows,
    (SELECT COUNT(*) FROM crm.accounts) AS clean_rows

UNION ALL

SELECT
    'products',
    (SELECT COUNT(*) FROM raw.products),
    (SELECT COUNT(*) FROM crm.products)

UNION ALL

SELECT
    'sales_teams',
    (SELECT COUNT(*) FROM raw.sales_teams),
    (SELECT COUNT(*) FROM crm.sales_teams)

UNION ALL

SELECT
    'sales_pipeline',
    (SELECT COUNT(*) FROM raw.sales_pipeline),
    (SELECT COUNT(*) FROM crm.sales_pipeline);
GO


-- ============================================================================
-- 2. PRIMARY-KEY UNIQUENESS CHECKS
--
-- Each duplicate count should equal 0.
-- ============================================================================

SELECT
    'crm.accounts' AS table_name,
    COUNT(*) - COUNT(DISTINCT account) AS duplicate_key_count
FROM crm.accounts

UNION ALL

SELECT
    'crm.products',
    COUNT(*) - COUNT(DISTINCT product)
FROM crm.products

UNION ALL

SELECT
    'crm.sales_teams',
    COUNT(*) - COUNT(DISTINCT sales_agent)
FROM crm.sales_teams

UNION ALL

SELECT
    'crm.sales_pipeline',
    COUNT(*) - COUNT(DISTINCT opportunity_id)
FROM crm.sales_pipeline;
GO


-- ============================================================================
-- 3. FOREIGN-KEY RELATIONSHIP VALIDATION
--
-- All three results should equal 0.
-- ============================================================================

SELECT
    SUM(
        CASE
            WHEN t.sales_agent IS NULL
            THEN 1
            ELSE 0
        END
    ) AS unmatched_sales_agents,

    SUM(
        CASE
            WHEN pr.product IS NULL
            THEN 1
            ELSE 0
        END
    ) AS unmatched_products,

    SUM(
        CASE
            WHEN p.account IS NOT NULL
             AND a.account IS NULL
            THEN 1
            ELSE 0
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


-- ============================================================================
-- 4. ACCOUNT PARENT RELATIONSHIP VALIDATION
--
-- Expected result: 0 unmatched parent accounts.
-- ============================================================================

SELECT
    COUNT(*) AS unmatched_parent_accounts

FROM crm.accounts AS child

LEFT JOIN crm.accounts AS parent
    ON child.subsidiary_of = parent.account

WHERE child.subsidiary_of IS NOT NULL
  AND parent.account IS NULL;
GO


-- ============================================================================
-- 5. DEAL-STAGE TOTALS
--
-- Expected project results:
-- Won:         4,238
-- Lost:        2,473
-- Engaging:    1,589
-- Prospecting:   500
-- Total:       8,800
-- ============================================================================

SELECT
    deal_stage,
    COUNT(*) AS opportunity_count

FROM crm.sales_pipeline

GROUP BY deal_stage
ORDER BY opportunity_count DESC;
GO


-- ============================================================================
-- 6. CORE PIPELINE KPI RECONCILIATION
--
-- Expected project results:
-- Total Opportunities: 8,800
-- Won Deals:           4,238
-- Lost Deals:          2,473
-- Closed Deals:        6,711
-- Open Opportunities:  2,089
-- Won Revenue:         10,005,534.00
-- ============================================================================

SELECT
    COUNT(*) AS total_opportunities,

    SUM(
        CASE
            WHEN deal_stage = 'Won'
            THEN 1
            ELSE 0
        END
    ) AS won_deals,

    SUM(
        CASE
            WHEN deal_stage = 'Lost'
            THEN 1
            ELSE 0
        END
    ) AS lost_deals,

    SUM(
        CASE
            WHEN deal_stage IN ('Won', 'Lost')
            THEN 1
            ELSE 0
        END
    ) AS closed_deals,

    SUM(
        CASE
            WHEN deal_stage IN ('Engaging', 'Prospecting')
            THEN 1
            ELSE 0
        END
    ) AS open_opportunities,

    CAST(
        SUM(
            CASE
                WHEN deal_stage = 'Won'
                THEN close_value
                ELSE 0
            END
        )
        AS DECIMAL(18, 2)
    ) AS won_revenue

FROM crm.sales_pipeline;
GO


-- ============================================================================
-- 7. REVENUE RECONCILIATION — PIPELINE VS REGIONS
--
-- The difference should equal 0.00.
-- ============================================================================

WITH pipeline_total AS
(
    SELECT
        SUM(close_value) AS won_revenue
    FROM crm.sales_pipeline
    WHERE deal_stage = 'Won'
),

regional_total AS
(
    SELECT
        SUM(p.close_value) AS won_revenue

    FROM crm.sales_pipeline AS p

    INNER JOIN crm.sales_teams AS t
        ON p.sales_agent = t.sales_agent

    WHERE p.deal_stage = 'Won'
)

SELECT
    CAST(p.won_revenue AS DECIMAL(18, 2))
        AS pipeline_won_revenue,

    CAST(r.won_revenue AS DECIMAL(18, 2))
        AS regional_won_revenue,

    CAST(
        p.won_revenue - r.won_revenue
        AS DECIMAL(18, 2)
    ) AS difference

FROM pipeline_total AS p
CROSS JOIN regional_total AS r;
GO


-- ============================================================================
-- 8. REVENUE RECONCILIATION — PIPELINE VS CUSTOMER SECTORS
--
-- The difference should equal 0.00 for this dataset.
-- ============================================================================

WITH pipeline_total AS
(
    SELECT
        SUM(close_value) AS won_revenue
    FROM crm.sales_pipeline
    WHERE deal_stage = 'Won'
),

sector_total AS
(
    SELECT
        SUM(p.close_value) AS won_revenue

    FROM crm.sales_pipeline AS p

    INNER JOIN crm.accounts AS a
        ON p.account = a.account

    WHERE p.deal_stage = 'Won'
)

SELECT
    CAST(p.won_revenue AS DECIMAL(18, 2))
        AS pipeline_won_revenue,

    CAST(s.won_revenue AS DECIMAL(18, 2))
        AS sector_won_revenue,

    CAST(
        p.won_revenue - s.won_revenue
        AS DECIMAL(18, 2)
    ) AS difference

FROM pipeline_total AS p
CROSS JOIN sector_total AS s;
GO


-- ============================================================================
-- 9. DATE-LOGIC VALIDATION
--
-- No completed opportunity should close before its engagement date.
-- Expected result: 0.
-- ============================================================================

SELECT
    COUNT(*) AS invalid_date_sequence_count

FROM crm.sales_pipeline

WHERE engage_date IS NOT NULL
  AND close_date IS NOT NULL
  AND close_date < engage_date;
GO


-- ============================================================================
-- 10. CLOSED-DEAL DATE VALIDATION
--
-- Won and Lost opportunities should have both engagement and close dates.
-- Expected result: 0.
-- ============================================================================

SELECT
    COUNT(*) AS closed_deals_missing_required_dates

FROM crm.sales_pipeline

WHERE deal_stage IN ('Won', 'Lost')
  AND (
        engage_date IS NULL
        OR close_date IS NULL
      );
GO


-- ============================================================================
-- 11. WON-DEAL VALUE VALIDATION
--
-- Won opportunities should have positive close values.
-- Expected result: 0.
-- ============================================================================

SELECT
    COUNT(*) AS won_deals_without_positive_value

FROM crm.sales_pipeline

WHERE deal_stage = 'Won'
  AND (
        close_value IS NULL
        OR close_value <= 0
      );
GO


-- ============================================================================
-- 12. LOST-DEAL VALUE VALIDATION
--
-- In this dataset, Lost opportunities have close_value = 0.
-- Expected result: 0.
-- ============================================================================

SELECT
    COUNT(*) AS lost_deals_with_unexpected_value

FROM crm.sales_pipeline

WHERE deal_stage = 'Lost'
  AND (
        close_value IS NULL
        OR close_value <> 0
      );
GO


-- ============================================================================
-- 13. OPEN-OPPORTUNITY VALUE VALIDATION
--
-- Prospecting and Engaging opportunities should not have a close value.
-- Expected result: 0.
-- ============================================================================

SELECT
    COUNT(*) AS open_deals_with_close_value

FROM crm.sales_pipeline

WHERE deal_stage IN ('Prospecting', 'Engaging')
  AND close_value IS NOT NULL;
GO


-- ============================================================================
-- 14. OPEN-OPPORTUNITY CLOSE-DATE VALIDATION
--
-- Prospecting and Engaging opportunities should not have a close date.
-- Expected result: 0.
-- ============================================================================

SELECT
    COUNT(*) AS open_deals_with_close_date

FROM crm.sales_pipeline

WHERE deal_stage IN ('Prospecting', 'Engaging')
  AND close_date IS NOT NULL;
GO


-- ============================================================================
-- 15. VALIDATE ANALYTICAL VIEW
--
-- The view should preserve all 8,800 pipeline opportunities.
-- ============================================================================

SELECT
    (SELECT COUNT(*) FROM crm.sales_pipeline)
        AS pipeline_rows,

    (SELECT COUNT(*) FROM crm.vw_opportunity_details)
        AS view_rows,

    (SELECT COUNT(*) FROM crm.sales_pipeline)
    -
    (SELECT COUNT(*) FROM crm.vw_opportunity_details)
        AS row_difference;
GO