# Power BI Measures and Calculated Columns

This document records the main DAX measures, calculated columns, and model elements used in the Power BI report for the CRM Sales Pipeline Analysis project.

---

## Data Model

The Power BI report connects to:

```text
crm.vw_opportunity_details
```

The imported table was renamed:

```text
Sales
```

A separate Date table was created and related to:

```text
Date[Date] → Sales[close_date]
```

The relationship is:

- One-to-many
- Single-direction
- Active

---

## Date Table

```DAX
Date =
CALENDAR(
    MIN(Sales[engage_date]),
    MAX(Sales[close_date])
)
```

### Year Month Column

```DAX
Year Month =
FORMAT('Date'[Date], "YYYY-MM")
```

The Date table was marked as a Date table using the `Date[Date]` column.

---

# Core KPI Measures

## Total Opportunities

```DAX
Total Opportunities =
DISTINCTCOUNT(Sales[opportunity_id])
```

Expected result:

```text
8,800
```

---

## Won Deals

```DAX
Won Deals =
CALCULATE(
    [Total Opportunities],
    Sales[deal_stage] = "Won"
)
```

Expected result:

```text
4,238
```

---

## Lost Deals

```DAX
Lost Deals =
CALCULATE(
    [Total Opportunities],
    Sales[deal_stage] = "Lost"
)
```

Expected result:

```text
2,473
```

---

## Closed Deals

```DAX
Closed Deals =
[Won Deals] + [Lost Deals]
```

Expected result:

```text
6,711
```

---

## Win Rate

```DAX
Win Rate =
DIVIDE(
    [Won Deals],
    [Closed Deals]
)
```

Formatted as a percentage with two decimal places.

Expected result:

```text
63.15%
```

---

## Won Revenue

```DAX
Won Revenue =
CALCULATE(
    SUM(Sales[close_value]),
    Sales[deal_stage] = "Won"
)
```

Expected result:

```text
$10,005,534
```

---

## Average Won Deal Value

```DAX
Average Won Deal Value =
CALCULATE(
    AVERAGE(Sales[close_value]),
    Sales[deal_stage] = "Won"
)
```

Expected result:

```text
$2,360.91
```

---

## Open Opportunities

```DAX
Open Opportunities =
[Total Opportunities] - [Closed Deals]
```

Expected result:

```text
2,089
```

---

# Sales Cycle Measures

## Average Sales Cycle Days

```DAX
Average Sales Cycle Days =
AVERAGE(Sales[sales_cycle_days])
```

Expected result:

```text
47.99
```

---

## Aged Engaging Opportunities

An aged Engaging opportunity is defined as an opportunity that remained in the Engaging stage for more than 90 days as of 31 December 2017.

```DAX
Aged Engaging Opportunities =
CALCULATE(
    [Total Opportunities],
    Sales[deal_stage] = "Engaging",
    FILTER(
        Sales,
        NOT ISBLANK(Sales[engage_date])
            && DATEDIFF(
                Sales[engage_date],
                DATE(2017, 12, 31),
                DAY
            ) > 90
    )
)
```

Expected result:

```text
1,479
```

---

## Aged Engaging %

```DAX
Aged Engaging % =
DIVIDE(
    [Aged Engaging Opportunities],
    CALCULATE(
        [Total Opportunities],
        Sales[deal_stage] = "Engaging"
    )
)
```

Formatted as a percentage with two decimal places.

Expected result:

```text
93.08%
```

---

# Sales Cycle Calculated Columns

## Sales Cycle Group

```DAX
Sales Cycle Group =
VAR CycleDays = Sales[sales_cycle_days]
RETURN
    SWITCH(
        TRUE(),
        ISBLANK(CycleDays), BLANK(),
        CycleDays <= 30, "1-30 Days",
        CycleDays <= 60, "31-60 Days",
        CycleDays <= 90, "61-90 Days",
        "91+ Days"
    )
```

---

## Sales Cycle Sort

```DAX
Sales Cycle Sort =
VAR CycleDays = Sales[sales_cycle_days]
RETURN
    SWITCH(
        TRUE(),
        ISBLANK(CycleDays), BLANK(),
        CycleDays <= 30, 1,
        CycleDays <= 60, 2,
        CycleDays <= 90, 3,
        4
    )
```

`Sales Cycle Group` was sorted by `Sales Cycle Sort` to display the groups in this order:

```text
1-30 Days
31-60 Days
61-90 Days
91+ Days
```

---

# Dashboard Pages

The final Power BI report contains four pages:

1. **Executive Overview**
   - Pipeline KPI cards
   - Pipeline stage distribution
   - Monthly won revenue
   - Region and product slicers

2. **Sales Performance**
   - Won revenue by region
   - Top 10 sales agents by won revenue

3. **Products & Customers**
   - Won revenue by product
   - Won revenue by sector
   - Top 10 accounts by won revenue

4. **Sales Cycle & Pipeline Aging**
   - Win rate by sales-cycle length
   - Average sales-cycle days
   - Aged Engaging opportunities

---

## Report Note

The Power BI `.pbix` file is not included in the public repository because the report uses Import mode and may contain copies of the underlying source data.

Dashboard screenshots are included separately for portfolio presentation.