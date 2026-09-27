/*==============================================================================
    Project: CRM Sales Pipeline Analysis
    File: 03_data_exploration.sql
    Purpose:
        Profile the raw CRM data before cleaning and identify data-quality,
        relationship, formatting, and validity issues.

    Platform:
        Microsoft SQL Server / T-SQL

    Notes:
        - All checks are performed against the raw staging tables.
        - No source data is modified by this script.
==============================================================================*/

USE CRM_Sales_Analytics;
GO


-- ============================================================================
-- 1. ROW COUNTS
-- ============================================================================

SELECT 'raw.accounts' AS table_name, COUNT(*) AS row_count
FROM raw.accounts

UNION ALL

SELECT 'raw.products', COUNT(*)
FROM raw.products

UNION ALL

SELECT 'raw.sales_teams', COUNT(*)
FROM raw.sales_teams

UNION ALL

SELECT 'raw.sales_pipeline', COUNT(*)
FROM raw.sales_pipeline;
GO


-- ============================================================================
-- 2. SAMPLE RAW DATA
-- ============================================================================

SELECT TOP (10) *
FROM raw.accounts;

SELECT TOP (10) *
FROM raw.products;

SELECT TOP (10) *
FROM raw.sales_teams;

SELECT TOP (10) *
FROM raw.sales_pipeline;
GO


-- ============================================================================
-- 3. CHECK FOR CARRIAGE-RETURN CHARACTERS
--    ROWTERMINATOR = 0x0A can leave CHAR(13) in the final column.
-- ============================================================================

SELECT
    SUM(CASE WHEN CHARINDEX(CHAR(13), subsidiary_of) > 0 THEN 1 ELSE 0 END)
        AS accounts_rows_with_carriage_return
FROM raw.accounts;

SELECT
    SUM(CASE WHEN CHARINDEX(CHAR(13), sales_price) > 0 THEN 1 ELSE 0 END)
        AS products_rows_with_carriage_return
FROM raw.products;

SELECT
    SUM(CASE WHEN CHARINDEX(CHAR(13), regional_office) > 0 THEN 1 ELSE 0 END)
        AS sales_team_rows_with_carriage_return
FROM raw.sales_teams;

SELECT
    SUM(CASE WHEN CHARINDEX(CHAR(13), close_value) > 0 THEN 1 ELSE 0 END)
        AS pipeline_rows_with_carriage_return
FROM raw.sales_pipeline;
GO


-- ============================================================================
-- 4. MISSING VALUES — ACCOUNTS
-- ============================================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(account)), '') IS NULL THEN 1 ELSE 0 END)
        AS missing_account,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(sector)), '') IS NULL THEN 1 ELSE 0 END)
        AS missing_sector,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(year_established)), '') IS NULL THEN 1 ELSE 0 END)
        AS missing_year_established,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(revenue)), '') IS NULL THEN 1 ELSE 0 END)
        AS missing_revenue,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(employees)), '') IS NULL THEN 1 ELSE 0 END)
        AS missing_employees,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(office_location)), '') IS NULL THEN 1 ELSE 0 END)
        AS missing_office_location
FROM raw.accounts;
GO


-- ============================================================================
-- 5. MISSING VALUES — PRODUCTS
-- ============================================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(product)), '') IS NULL THEN 1 ELSE 0 END)
        AS missing_product,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(series)), '') IS NULL THEN 1 ELSE 0 END)
        AS missing_series,
    SUM(
        CASE
            WHEN NULLIF(
                LTRIM(RTRIM(REPLACE(sales_price, CHAR(13), ''))),
                ''
            ) IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_sales_price
FROM raw.products;
GO


-- ============================================================================
-- 6. MISSING VALUES — SALES TEAMS
-- ============================================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(sales_agent)), '') IS NULL THEN 1 ELSE 0 END)
        AS missing_sales_agent,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(manager)), '') IS NULL THEN 1 ELSE 0 END)
        AS missing_manager,
    SUM(
        CASE
            WHEN NULLIF(
                LTRIM(RTRIM(REPLACE(regional_office, CHAR(13), ''))),
                ''
            ) IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_regional_office
FROM raw.sales_teams;
GO


-- ============================================================================
-- 7. MISSING VALUES — SALES PIPELINE
-- ============================================================================

SELECT
    COUNT(*) AS total_rows,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(opportunity_id)), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_opportunity_id,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(sales_agent)), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_sales_agent,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(product)), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_product,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(account)), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_account,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(deal_stage)), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_deal_stage,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(engage_date)), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_engage_date,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(close_date)), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_close_date,

    SUM(
        CASE
            WHEN NULLIF(
                LTRIM(RTRIM(REPLACE(close_value, CHAR(13), ''))),
                ''
            ) IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_close_value

FROM raw.sales_pipeline;
GO


-- ============================================================================
-- 8. DUPLICATE KEY CHECKS
--    These queries should return zero rows when candidate keys are unique.
-- ============================================================================

SELECT
    LTRIM(RTRIM(account)) AS account,
    COUNT(*) AS duplicate_count
FROM raw.accounts
GROUP BY LTRIM(RTRIM(account))
HAVING COUNT(*) > 1;


SELECT
    LTRIM(RTRIM(product)) AS product,
    COUNT(*) AS duplicate_count
FROM raw.products
GROUP BY LTRIM(RTRIM(product))
HAVING COUNT(*) > 1;


SELECT
    LTRIM(RTRIM(sales_agent)) AS sales_agent,
    COUNT(*) AS duplicate_count
FROM raw.sales_teams
GROUP BY LTRIM(RTRIM(sales_agent))
HAVING COUNT(*) > 1;


SELECT
    LTRIM(RTRIM(opportunity_id)) AS opportunity_id,
    COUNT(*) AS duplicate_count
FROM raw.sales_pipeline
GROUP BY LTRIM(RTRIM(opportunity_id))
HAVING COUNT(*) > 1;
GO


-- ============================================================================
-- 9. DEAL-STAGE DISTRIBUTION
-- ============================================================================

SELECT
    LTRIM(RTRIM(deal_stage)) AS deal_stage,
    COUNT(*) AS opportunity_count
FROM raw.sales_pipeline
GROUP BY LTRIM(RTRIM(deal_stage))
ORDER BY opportunity_count DESC;
GO


-- ============================================================================
-- 10. MISSING VALUES BY DEAL STAGE
--     Helps determine whether missing values follow business-process logic.
-- ============================================================================

SELECT
    LTRIM(RTRIM(deal_stage)) AS deal_stage,
    COUNT(*) AS opportunity_count,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(account)), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_account,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(engage_date)), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_engage_date,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(close_date)), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_close_date,

    SUM(
        CASE
            WHEN NULLIF(
                LTRIM(RTRIM(REPLACE(close_value, CHAR(13), ''))),
                ''
            ) IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_close_value

FROM raw.sales_pipeline
GROUP BY LTRIM(RTRIM(deal_stage))
ORDER BY opportunity_count DESC;
GO


-- ============================================================================
-- 11. SALES-AGENT RELATIONSHIP CHECK
--     Expected result after trimming: zero unmatched records.
-- ============================================================================

SELECT COUNT(*) AS unmatched_sales_agents
FROM raw.sales_pipeline AS p
LEFT JOIN raw.sales_teams AS t
    ON LTRIM(RTRIM(p.sales_agent)) = LTRIM(RTRIM(t.sales_agent))
WHERE t.sales_agent IS NULL;
GO


-- ============================================================================
-- 12. ACCOUNT RELATIONSHIP CHECK
--     Missing pipeline accounts are excluded because they are legitimate
--     for some open opportunities.
-- ============================================================================

SELECT COUNT(*) AS unmatched_populated_accounts
FROM raw.sales_pipeline AS p
LEFT JOIN raw.accounts AS a
    ON LTRIM(RTRIM(p.account)) = LTRIM(RTRIM(a.account))
WHERE NULLIF(LTRIM(RTRIM(p.account)), '') IS NOT NULL
  AND a.account IS NULL;
GO


-- ============================================================================
-- 13. PRODUCT RELATIONSHIP CHECK — EXACT MATCH
--     This exposed a product-name spacing inconsistency during profiling.
-- ============================================================================

SELECT
    LTRIM(RTRIM(p.product)) AS pipeline_product,
    COUNT(*) AS affected_opportunities
FROM raw.sales_pipeline AS p
LEFT JOIN raw.products AS pr
    ON LTRIM(RTRIM(p.product)) = LTRIM(RTRIM(pr.product))
WHERE pr.product IS NULL
GROUP BY LTRIM(RTRIM(p.product))
ORDER BY affected_opportunities DESC;
GO


-- ============================================================================
-- 14. PRODUCT RELATIONSHIP CHECK — IGNORING SPACES
--     Used diagnostically to confirm that spacing caused the mismatch.
-- ============================================================================

SELECT COUNT(*) AS unmatched_products_after_space_normalization
FROM raw.sales_pipeline AS p
LEFT JOIN raw.products AS pr
    ON REPLACE(LTRIM(RTRIM(p.product)), ' ', '')
       = REPLACE(LTRIM(RTRIM(pr.product)), ' ', '')
WHERE pr.product IS NULL;
GO


-- ============================================================================
-- 15. ACCOUNT SUBSIDIARY RELATIONSHIP CHECK
-- ============================================================================

SELECT
    COUNT(*) AS unmatched_parent_accounts
FROM raw.accounts AS child
LEFT JOIN raw.accounts AS parent
    ON LTRIM(RTRIM(REPLACE(child.subsidiary_of, CHAR(13), '')))
       = LTRIM(RTRIM(parent.account))
WHERE NULLIF(
        LTRIM(RTRIM(REPLACE(child.subsidiary_of, CHAR(13), ''))),
        ''
      ) IS NOT NULL
  AND parent.account IS NULL;
GO


-- ============================================================================
-- 16. ACCOUNT NUMERIC VALIDITY
-- ============================================================================

SELECT
    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(year_established)), '') IS NOT NULL
             AND TRY_CONVERT(INT, LTRIM(RTRIM(year_established))) IS NULL
            THEN 1 ELSE 0
        END
    ) AS invalid_year_established,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(revenue)), '') IS NOT NULL
             AND TRY_CONVERT(DECIMAL(18, 2), LTRIM(RTRIM(revenue))) IS NULL
            THEN 1 ELSE 0
        END
    ) AS invalid_revenue,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(employees)), '') IS NOT NULL
             AND TRY_CONVERT(INT, LTRIM(RTRIM(employees))) IS NULL
            THEN 1 ELSE 0
        END
    ) AS invalid_employees

FROM raw.accounts;
GO


-- ============================================================================
-- 17. PRODUCT PRICE VALIDITY
-- ============================================================================

SELECT
    SUM(
        CASE
            WHEN NULLIF(
                LTRIM(RTRIM(REPLACE(sales_price, CHAR(13), ''))),
                ''
            ) IS NOT NULL
             AND TRY_CONVERT(
                    DECIMAL(18, 2),
                    LTRIM(RTRIM(REPLACE(sales_price, CHAR(13), '')))
                 ) IS NULL
            THEN 1
            ELSE 0
        END
    ) AS invalid_sales_price
FROM raw.products;
GO


-- ============================================================================
-- 18. PIPELINE DATE AND VALUE VALIDITY
-- ============================================================================

SELECT
    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(engage_date)), '') IS NOT NULL
             AND TRY_CONVERT(DATE, LTRIM(RTRIM(engage_date))) IS NULL
            THEN 1 ELSE 0
        END
    ) AS invalid_engage_dates,

    SUM(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(close_date)), '') IS NOT NULL
             AND TRY_CONVERT(DATE, LTRIM(RTRIM(close_date))) IS NULL
            THEN 1 ELSE 0
        END
    ) AS invalid_close_dates,

    SUM(
        CASE
            WHEN NULLIF(
                LTRIM(RTRIM(REPLACE(close_value, CHAR(13), ''))),
                ''
            ) IS NOT NULL
             AND TRY_CONVERT(
                    DECIMAL(18, 2),
                    LTRIM(RTRIM(REPLACE(close_value, CHAR(13), '')))
                 ) IS NULL
            THEN 1 ELSE 0
        END
    ) AS invalid_close_values

FROM raw.sales_pipeline;
GO


-- ============================================================================
-- 19. CHECK FOR CLOSE DATES BEFORE ENGAGEMENT DATES
-- ============================================================================

SELECT COUNT(*) AS close_date_before_engage_date
FROM raw.sales_pipeline
WHERE TRY_CONVERT(DATE, LTRIM(RTRIM(engage_date))) IS NOT NULL
  AND TRY_CONVERT(DATE, LTRIM(RTRIM(close_date))) IS NOT NULL
  AND TRY_CONVERT(DATE, LTRIM(RTRIM(close_date)))
      < TRY_CONVERT(DATE, LTRIM(RTRIM(engage_date)));
GO


-- ============================================================================
-- 20. DATE RANGE
-- ============================================================================

SELECT
    MIN(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(engage_date)), '')))
        AS earliest_engage_date,

    MAX(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(engage_date)), '')))
        AS latest_engage_date,

    MIN(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(close_date)), '')))
        AS earliest_close_date,

    MAX(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(close_date)), '')))
        AS latest_close_date

FROM raw.sales_pipeline;
GO


-- ============================================================================
-- 21. COMPLETED SALES-CYCLE LENGTH
-- ============================================================================

SELECT
    MIN(
        DATEDIFF(
            DAY,
            TRY_CONVERT(DATE, LTRIM(RTRIM(engage_date))),
            TRY_CONVERT(DATE, LTRIM(RTRIM(close_date)))
        )
    ) AS minimum_sales_cycle_days,

    MAX(
        DATEDIFF(
            DAY,
            TRY_CONVERT(DATE, LTRIM(RTRIM(engage_date))),
            TRY_CONVERT(DATE, LTRIM(RTRIM(close_date)))
        )
    ) AS maximum_sales_cycle_days,

    CAST(
        AVG(
            CAST(
                DATEDIFF(
                    DAY,
                    TRY_CONVERT(DATE, LTRIM(RTRIM(engage_date))),
                    TRY_CONVERT(DATE, LTRIM(RTRIM(close_date)))
                ) AS DECIMAL(18, 2)
            )
        ) AS DECIMAL(18, 2)
    ) AS average_sales_cycle_days

FROM raw.sales_pipeline
WHERE TRY_CONVERT(DATE, LTRIM(RTRIM(engage_date))) IS NOT NULL
  AND TRY_CONVERT(DATE, LTRIM(RTRIM(close_date))) IS NOT NULL;
GO