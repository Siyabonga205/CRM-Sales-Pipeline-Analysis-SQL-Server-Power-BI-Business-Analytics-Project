# Data

The original CRM source files are not included in this repository.

The project was built using four semicolon-delimited CSV files:

- `accounts.csv` — 85 customer accounts
- `products.csv` — 7 products
- `sales_teams.csv` — 35 sales agents
- `sales_pipeline.csv` — 8,800 sales opportunities

## Source Structure

### accounts.csv

Contains customer account information, including:

- account
- sector
- year established
- revenue
- employees
- office location
- parent/subsidiary relationship

### products.csv

Contains product information, including:

- product
- series
- sales price

### sales_teams.csv

Contains sales-team information, including:

- sales agent
- manager
- regional office

### sales_pipeline.csv

Contains CRM opportunity data, including:

- opportunity ID
- sales agent
- product
- account
- deal stage
- engagement date
- close date
- close value

## Data Availability

The raw source files are intentionally excluded from the public repository.

The SQL scripts use a placeholder path:

```text
<DATA_FOLDER>
