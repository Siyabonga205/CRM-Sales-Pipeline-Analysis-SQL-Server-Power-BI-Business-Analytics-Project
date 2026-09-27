/*==============================================================================
    Project: CRM Sales Pipeline Analysis
    File: 05_analysis.sql
    Purpose:
        Answer the main business questions using the cleaned CRM model.

    Platform:
        Microsoft SQL Server / T-SQL

    Analysis Areas:
        1. Overall pipeline performance
        2. Monthly and quarterly revenue
        3. Sales-agent performance
        4. Regional performance
        5. Product performance
        6. Sector performance
        7. Customer concentration
        8. Customer revenue segments
        9. Sales-cycle performance
       10. Pipeline aging
==============================================================================*/

USE CRM_Sales_Analytics;
GO


-- ============================================================================
-- BUSINESS QUESTION 1:
-- What is the overall performance of the sales pipeline?
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
            WHEN deal_stage IN ('Prospecting', 'Engaging')
            THEN 1
            ELSE 0
        END
    ) AS open_opportunities,

    SUM(
        CASE
            WHEN deal_stage IN ('Won', 'Lost')
            THEN 1
            ELSE 0
        END
    ) AS closed_deals,

    CAST(
        100.0
        * SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END)
        / NULLIF(
            SUM(
                CASE
                    WHEN deal_stage IN ('Won', 'Lost')
                    THEN 1
                    ELSE 0
                END
            ),
            0
        )
        AS DECIMAL(6, 2)
    ) AS closed_deal_win_rate_percent,

    CAST(
        SUM(
            CASE
                WHEN deal_stage = 'Won'
                THEN close_value
                ELSE 0
            END
        )
        AS DECIMAL(18, 2)
    ) AS won_revenue,

    CAST(
        AVG(
            CASE
                WHEN deal_stage = 'Won'
                THEN close_value
            END
        )
        AS DECIMAL(18, 2)
    ) AS average_won_deal_value

FROM crm.sales_pipeline;
GO


-- ============================================================================
-- PIPELINE STAGE DISTRIBUTION
-- ============================================================================

SELECT
    deal_stage,
    COUNT(*) AS opportunity_count,

    CAST(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER ()
        AS DECIMAL(6, 2)
    ) AS opportunity_share_percent

FROM crm.sales_pipeline
GROUP BY deal_stage
ORDER BY opportunity_count DESC;
GO


-- ============================================================================
-- BUSINESS QUESTION 2:
-- How did won revenue and conversion change by month?
--
-- Demonstrates:
--     CTEs
--     Date functions
--     Window functions
--     RANK
--     Running totals
-- ============================================================================

WITH monthly_performance AS
(
    SELECT
        DATEFROMPARTS(
            YEAR(close_date),
            MONTH(close_date),
            1
        ) AS month_start,

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

    FROM crm.sales_pipeline

    WHERE close_date >= '2017-01-01'
      AND close_date < '2018-01-01'
      AND deal_stage IN ('Won', 'Lost')

    GROUP BY
        DATEFROMPARTS(
            YEAR(close_date),
            MONTH(close_date),
            1
        )
)

SELECT
    month_start,
    won_deals,
    lost_deals,
    won_deals + lost_deals AS closed_deals,

    CAST(
        100.0 * won_deals
        / NULLIF(won_deals + lost_deals, 0)
        AS DECIMAL(6, 2)
    ) AS win_rate_percent,

    won_revenue,

    RANK() OVER (
        ORDER BY won_revenue DESC
    ) AS revenue_rank,

    CAST(
        SUM(won_revenue) OVER (
            ORDER BY month_start
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )
        AS DECIMAL(18, 2)
    ) AS running_won_revenue

FROM monthly_performance
ORDER BY month_start;
GO


-- ============================================================================
-- QUARTERLY WON REVENUE
--
-- Note:
-- Q1 contains only March closed-deal activity in this dataset, so direct
-- comparisons with full Q2-Q4 periods should be made cautiously.
-- ============================================================================

SELECT
    YEAR(close_date) AS sales_year,
    DATEPART(QUARTER, close_date) AS sales_quarter,

    COUNT(*) AS won_deals,

    CAST(
        SUM(close_value)
        AS DECIMAL(18, 2)
    ) AS won_revenue

FROM crm.sales_pipeline
WHERE deal_stage = 'Won'
  AND close_date >= '2017-01-01'
  AND close_date < '2018-01-01'

GROUP BY
    YEAR(close_date),
    DATEPART(QUARTER, close_date)

ORDER BY
    sales_year,
    sales_quarter;
GO


-- ============================================================================
-- BUSINESS QUESTION 3:
-- Which sales agents generated the strongest sales results?
--
-- Includes both company-wide and regional revenue ranking.
-- ============================================================================

WITH agent_performance AS
(
    SELECT
        t.sales_agent,
        t.manager,
        t.regional_office,

        COUNT(*) AS total_opportunities,

        SUM(
            CASE
                WHEN p.deal_stage = 'Won'
                THEN 1
                ELSE 0
            END
        ) AS won_deals,

        SUM(
            CASE
                WHEN p.deal_stage = 'Lost'
                THEN 1
                ELSE 0
            END
        ) AS lost_deals,

        CAST(
            SUM(
                CASE
                    WHEN p.deal_stage = 'Won'
                    THEN p.close_value
                    ELSE 0
                END
            )
            AS DECIMAL(18, 2)
        ) AS won_revenue,

        CAST(
            AVG(
                CASE
                    WHEN p.deal_stage = 'Won'
                    THEN p.close_value
                END
            )
            AS DECIMAL(18, 2)
        ) AS average_won_deal_value

    FROM crm.sales_pipeline AS p

    INNER JOIN crm.sales_teams AS t
        ON p.sales_agent = t.sales_agent

    GROUP BY
        t.sales_agent,
        t.manager,
        t.regional_office
)

SELECT
    sales_agent,
    manager,
    regional_office,
    total_opportunities,
    won_deals,
    lost_deals,

    CAST(
        100.0 * won_deals
        / NULLIF(won_deals + lost_deals, 0)
        AS DECIMAL(6, 2)
    ) AS win_rate_percent,

    won_revenue,
    average_won_deal_value,

    RANK() OVER (
        ORDER BY won_revenue DESC
    ) AS company_revenue_rank,

    RANK() OVER (
        PARTITION BY regional_office
        ORDER BY won_revenue DESC
    ) AS regional_revenue_rank

FROM agent_performance
ORDER BY won_revenue DESC;
GO


-- ============================================================================
-- MANAGER PERFORMANCE
-- ============================================================================

SELECT
    t.manager,
    t.regional_office,

    COUNT(*) AS total_opportunities,

    SUM(
        CASE
            WHEN p.deal_stage = 'Won'
            THEN 1
            ELSE 0
        END
    ) AS won_deals,

    CAST(
        SUM(
            CASE
                WHEN p.deal_stage = 'Won'
                THEN p.close_value
                ELSE 0
            END
        )
        AS DECIMAL(18, 2)
    ) AS won_revenue

FROM crm.sales_pipeline AS p

INNER JOIN crm.sales_teams AS t
    ON p.sales_agent = t.sales_agent

GROUP BY
    t.manager,
    t.regional_office

ORDER BY won_revenue DESC;
GO


-- ============================================================================
-- BUSINESS QUESTION 4:
-- How does sales performance compare across regions?
-- ============================================================================

SELECT
    t.regional_office,

    COUNT(*) AS total_opportunities,

    SUM(
        CASE
            WHEN p.deal_stage = 'Won'
            THEN 1
            ELSE 0
        END
    ) AS won_deals,

    SUM(
        CASE
            WHEN p.deal_stage = 'Lost'
            THEN 1
            ELSE 0
        END
    ) AS lost_deals,

    CAST(
        100.0
        * SUM(CASE WHEN p.deal_stage = 'Won' THEN 1 ELSE 0 END)
        / NULLIF(
            SUM(
                CASE
                    WHEN p.deal_stage IN ('Won', 'Lost')
                    THEN 1
                    ELSE 0
                END
            ),
            0
        )
        AS DECIMAL(6, 2)
    ) AS win_rate_percent,

    CAST(
        SUM(
            CASE
                WHEN p.deal_stage = 'Won'
                THEN p.close_value
                ELSE 0
            END
        )
        AS DECIMAL(18, 2)
    ) AS won_revenue,

    CAST(
        AVG(
            CASE
                WHEN p.deal_stage = 'Won'
                THEN p.close_value
            END
        )
        AS DECIMAL(18, 2)
    ) AS average_won_deal_value

FROM crm.sales_pipeline AS p

INNER JOIN crm.sales_teams AS t
    ON p.sales_agent = t.sales_agent

GROUP BY t.regional_office
ORDER BY won_revenue DESC;
GO


-- ============================================================================
-- BUSINESS QUESTION 5:
-- Which products contribute the most revenue and how do they convert?
-- ============================================================================

WITH product_performance AS
(
    SELECT
        pr.product,
        pr.series,
        pr.sales_price,

        COUNT(*) AS total_opportunities,

        SUM(
            CASE
                WHEN p.deal_stage = 'Won'
                THEN 1
                ELSE 0
            END
        ) AS won_deals,

        SUM(
            CASE
                WHEN p.deal_stage = 'Lost'
                THEN 1
                ELSE 0
            END
        ) AS lost_deals,

        CAST(
            SUM(
                CASE
                    WHEN p.deal_stage = 'Won'
                    THEN p.close_value
                    ELSE 0
                END
            )
            AS DECIMAL(18, 2)
        ) AS won_revenue,

        CAST(
            AVG(
                CASE
                    WHEN p.deal_stage = 'Won'
                    THEN p.close_value
                END
            )
            AS DECIMAL(18, 2)
        ) AS average_won_value

    FROM crm.sales_pipeline AS p

    INNER JOIN crm.products AS pr
        ON p.product = pr.product

    GROUP BY
        pr.product,
        pr.series,
        pr.sales_price
)

SELECT
    product,
    series,
    sales_price,
    total_opportunities,
    won_deals,
    lost_deals,

    CAST(
        100.0 * won_deals
        / NULLIF(won_deals + lost_deals, 0)
        AS DECIMAL(6, 2)
    ) AS win_rate_percent,

    won_revenue,

    CAST(
        100.0 * won_revenue
        / NULLIF(SUM(won_revenue) OVER (), 0)
        AS DECIMAL(6, 2)
    ) AS revenue_share_percent,

    average_won_value

FROM product_performance
ORDER BY won_revenue DESC;
GO


-- ============================================================================
-- TOP THREE PRODUCT REVENUE CONCENTRATION
-- ============================================================================

WITH product_revenue AS
(
    SELECT
        product,
        SUM(close_value) AS won_revenue
    FROM crm.sales_pipeline
    WHERE deal_stage = 'Won'
    GROUP BY product
),

ranked_products AS
(
    SELECT
        product,
        won_revenue,

        ROW_NUMBER() OVER (
            ORDER BY won_revenue DESC
        ) AS revenue_rank

    FROM product_revenue
)

SELECT
    CAST(
        100.0
        * SUM(
            CASE
                WHEN revenue_rank <= 3
                THEN won_revenue
                ELSE 0
            END
        )
        / NULLIF(SUM(won_revenue), 0)
        AS DECIMAL(6, 2)
    ) AS top_three_product_revenue_share_percent

FROM ranked_products;
GO


-- ============================================================================
-- BUSINESS QUESTION 6:
-- Which customer sectors generate the most revenue?
-- ============================================================================

SELECT
    a.sector,

    COUNT(*) AS total_opportunities,

    SUM(
        CASE
            WHEN p.deal_stage = 'Won'
            THEN 1
            ELSE 0
        END
    ) AS won_deals,

    SUM(
        CASE
            WHEN p.deal_stage = 'Lost'
            THEN 1
            ELSE 0
        END
    ) AS lost_deals,

    CAST(
        100.0
        * SUM(CASE WHEN p.deal_stage = 'Won' THEN 1 ELSE 0 END)
        / NULLIF(
            SUM(
                CASE
                    WHEN p.deal_stage IN ('Won', 'Lost')
                    THEN 1
                    ELSE 0
                END
            ),
            0
        )
        AS DECIMAL(6, 2)
    ) AS win_rate_percent,

    CAST(
        SUM(
            CASE
                WHEN p.deal_stage = 'Won'
                THEN p.close_value
                ELSE 0
            END
        )
        AS DECIMAL(18, 2)
    ) AS won_revenue,

    CAST(
        AVG(
            CASE
                WHEN p.deal_stage = 'Won'
                THEN p.close_value
            END
        )
        AS DECIMAL(18, 2)
    ) AS average_won_deal_value

FROM crm.sales_pipeline AS p

INNER JOIN crm.accounts AS a
    ON p.account = a.account

GROUP BY a.sector
ORDER BY won_revenue DESC;
GO


-- ============================================================================
-- BUSINESS QUESTION 7:
-- How concentrated is won revenue among customer accounts?
-- ============================================================================

WITH account_performance AS
(
    SELECT
        account,
        COUNT(*) AS won_deals,
        CAST(SUM(close_value) AS DECIMAL(18, 2)) AS won_revenue

    FROM crm.sales_pipeline

    WHERE deal_stage = 'Won'
      AND account IS NOT NULL

    GROUP BY account
),

account_rankings AS
(
    SELECT
        account,
        won_deals,
        won_revenue,

        ROW_NUMBER() OVER (
            ORDER BY won_revenue DESC
        ) AS revenue_rank,

        SUM(won_revenue) OVER () AS total_won_revenue

    FROM account_performance
)

SELECT TOP (10)
    revenue_rank,
    account,
    won_deals,
    won_revenue,

    CAST(
        100.0 * won_revenue
        / NULLIF(total_won_revenue, 0)
        AS DECIMAL(6, 2)
    ) AS total_revenue_share_percent

FROM account_rankings
ORDER BY revenue_rank;
GO


-- ============================================================================
-- TOP 10 ACCOUNT REVENUE CONCENTRATION
-- ============================================================================

WITH account_revenue AS
(
    SELECT
        account,
        SUM(close_value) AS won_revenue

    FROM crm.sales_pipeline

    WHERE deal_stage = 'Won'
      AND account IS NOT NULL

    GROUP BY account
),

ranked_accounts AS
(
    SELECT
        account,
        won_revenue,

        ROW_NUMBER() OVER (
            ORDER BY won_revenue DESC
        ) AS revenue_rank

    FROM account_revenue
)

SELECT
    CAST(
        100.0
        * SUM(
            CASE
                WHEN revenue_rank <= 10
                THEN won_revenue
                ELSE 0
            END
        )
        / NULLIF(SUM(won_revenue), 0)
        AS DECIMAL(6, 2)
    ) AS top_10_account_revenue_share_percent

FROM ranked_accounts;
GO


-- ============================================================================
-- CUSTOMER COMPANY REVENUE QUARTILES
--
-- Accounts are segmented using the revenue attribute from the account master.
-- This tests whether larger customer companies are associated with different
-- sales activity or conversion patterns.
-- ============================================================================

WITH account_segments AS
(
    SELECT
        account,
        revenue AS company_revenue,

        NTILE(4) OVER (
            ORDER BY revenue
        ) AS revenue_quartile

    FROM crm.accounts
)

SELECT
    s.revenue_quartile,

    COUNT(DISTINCT s.account) AS account_count,

    COUNT(p.opportunity_id) AS opportunity_count,

    SUM(
        CASE
            WHEN p.deal_stage = 'Won'
            THEN 1
            ELSE 0
        END
    ) AS won_deals,

    SUM(
        CASE
            WHEN p.deal_stage = 'Lost'
            THEN 1
            ELSE 0
        END
    ) AS lost_deals,

    CAST(
        100.0
        * SUM(CASE WHEN p.deal_stage = 'Won' THEN 1 ELSE 0 END)
        / NULLIF(
            SUM(
                CASE
                    WHEN p.deal_stage IN ('Won', 'Lost')
                    THEN 1
                    ELSE 0
                END
            ),
            0
        )
        AS DECIMAL(6, 2)
    ) AS win_rate_percent,

    CAST(
        SUM(
            CASE
                WHEN p.deal_stage = 'Won'
                THEN p.close_value
                ELSE 0
            END
        )
        AS DECIMAL(18, 2)
    ) AS won_revenue

FROM account_segments AS s

LEFT JOIN crm.sales_pipeline AS p
    ON s.account = p.account

GROUP BY s.revenue_quartile
ORDER BY s.revenue_quartile;
GO


-- ============================================================================
-- BUSINESS QUESTION 8:
-- How does sales-cycle duration differ between won and lost deals?
-- ============================================================================

SELECT
    deal_stage,

    COUNT(*) AS completed_deals,

    CAST(
        AVG(
            CAST(
                DATEDIFF(
                    DAY,
                    engage_date,
                    close_date
                )
                AS DECIMAL(18, 2)
            )
        )
        AS DECIMAL(18, 2)
    ) AS average_sales_cycle_days

FROM crm.sales_pipeline

WHERE deal_stage IN ('Won', 'Lost')
  AND engage_date IS NOT NULL
  AND close_date IS NOT NULL

GROUP BY deal_stage
ORDER BY deal_stage;
GO


-- ============================================================================
-- WIN RATE BY SALES-CYCLE LENGTH
--
-- This describes historical association only. It does not establish that
-- longer sales cycles cause higher win rates.
-- ============================================================================

WITH completed_deals AS
(
    SELECT
        opportunity_id,
        deal_stage,

        DATEDIFF(
            DAY,
            engage_date,
            close_date
        ) AS sales_cycle_days

    FROM crm.sales_pipeline

    WHERE deal_stage IN ('Won', 'Lost')
      AND engage_date IS NOT NULL
      AND close_date IS NOT NULL
),

cycle_groups AS
(
    SELECT
        opportunity_id,
        deal_stage,
        sales_cycle_days,

        CASE
            WHEN sales_cycle_days <= 30 THEN '1-30 Days'
            WHEN sales_cycle_days <= 60 THEN '31-60 Days'
            WHEN sales_cycle_days <= 90 THEN '61-90 Days'
            ELSE '91+ Days'
        END AS sales_cycle_group,

        CASE
            WHEN sales_cycle_days <= 30 THEN 1
            WHEN sales_cycle_days <= 60 THEN 2
            WHEN sales_cycle_days <= 90 THEN 3
            ELSE 4
        END AS sort_order

    FROM completed_deals
)

SELECT
    sales_cycle_group,

    COUNT(*) AS closed_deals,

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

    CAST(
        100.0
        * SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(6, 2)
    ) AS win_rate_percent

FROM cycle_groups

GROUP BY
    sales_cycle_group,
    sort_order

ORDER BY sort_order;
GO


-- ============================================================================
-- WON VS LOST SALES-CYCLE LENGTH BY PRODUCT
-- ============================================================================

SELECT
    product,

    CAST(
        AVG(
            CASE
                WHEN deal_stage = 'Won'
                THEN CAST(
                    DATEDIFF(DAY, engage_date, close_date)
                    AS DECIMAL(18, 2)
                )
            END
        )
        AS DECIMAL(18, 2)
    ) AS average_won_cycle_days,

    CAST(
        AVG(
            CASE
                WHEN deal_stage = 'Lost'
                THEN CAST(
                    DATEDIFF(DAY, engage_date, close_date)
                    AS DECIMAL(18, 2)
                )
            END
        )
        AS DECIMAL(18, 2)
    ) AS average_lost_cycle_days

FROM crm.sales_pipeline

WHERE deal_stage IN ('Won', 'Lost')
  AND engage_date IS NOT NULL
  AND close_date IS NOT NULL

GROUP BY product
ORDER BY product;
GO


-- ============================================================================
-- BUSINESS QUESTION 9:
-- How much of the historical Engaging pipeline was aged?
--
-- Snapshot date:
--     31 December 2017
--
-- An aged Engaging opportunity is defined as one that had remained in the
-- pipeline for more than 90 days since its engagement date.
-- ============================================================================

DECLARE @SnapshotDate DATE = '2017-12-31';

SELECT
    COUNT(*) AS engaging_opportunities,

    SUM(
        CASE
            WHEN engage_date IS NOT NULL
             AND DATEDIFF(
                    DAY,
                    engage_date,
                    @SnapshotDate
                 ) > 90
            THEN 1
            ELSE 0
        END
    ) AS aged_engaging_opportunities,

    CAST(
        100.0
        * SUM(
            CASE
                WHEN engage_date IS NOT NULL
                 AND DATEDIFF(
                        DAY,
                        engage_date,
                        @SnapshotDate
                     ) > 90
                THEN 1
                ELSE 0
            END
        )
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(6, 2)
    ) AS aged_engaging_percent

FROM crm.sales_pipeline

WHERE deal_stage = 'Engaging';
GO