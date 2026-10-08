# Gaming Publishers: Financial Health Analysis

A financial analysis of three video game publishers — **Capcom**, **Take-Two Interactive**, and **Ubisoft** — covering fiscal years 2023–2026. The project compares their profitability, liquidity, debt, cash generation, and growth, using an end-to-end pipeline from data extraction to an interactive Power BI dashboard.

![Overview page](images/overview.png)

## Key findings

**Capcom is consistently profitable, debt-free, and growing.**
- Operating margin stayed between 37% and 40% in every year, with net margin around 28–29%.
- Revenue grew every year (+21%, +11%, +15%), reaching ¥195.4bn (~$1.3bn) in FY2026.
- Holds far more cash than debt (about $0.9bn in net cash in FY2026) and is the only one of the three with positive free cash flow in all four years.
- Return on equity above 20% every year.

**Take-Two is the largest publisher and is recovering from write-off-driven losses.**
- Revenue reached $6.7bn in FY2026 (+18%), the fastest growth of the three that year.
- Operating margin improved from -21% to -2%, close to break-even.
- Its largest net losses (e.g. -$4.5bn in FY2025) came mainly from write-downs of acquired assets, not only from day-to-day operations.
- Net debt fell from $2.8bn to $1.4bn, and FY2026 was its first year of positive free cash flow in the period.

**Ubisoft is shrinking, loss-making, and funding itself with debt.**
- Revenue fell by about 22% in both FY2025 and FY2026.
- Its FY2026 net loss (€1.5bn) was larger than its remaining shareholders' equity.
- Debt exceeded equity in every year, and operating cash flow was negative in FY2026.
- In FY2024, its only profitable year, it reported €158M in profit while its operations consumed €393M in cash.

## Tools

| Stage | Tools |
|---|---|
| Extraction & cleaning | Python, pandas, yfinance |
| Storage | Supabase (PostgreSQL), SQLAlchemy |
| Analysis | SQL views (joins, window functions) |
| Visualization | Power BI |

## Pipeline

```
Yahoo Finance → Python (pandas) → Supabase (PostgreSQL) → SQL views → Power BI
```

1. **Extraction**: annual income statements, balance sheets, and cash flow statements are pulled with `yfinance`, along with daily EUR/USD and JPY/USD exchange rates.
2. **Cleaning**: selected line items are reshaped into one row per company per year, column names are standardized, empty years are removed, and net debt is calculated consistently for all companies.
3. **Storage**: the data is loaded into Supabase, with primary keys, foreign keys, and Row Level Security.
4. **Analysis**: five SQL views calculate the ratios and USD conversions.
5. **Visualization**: Power BI imports the views and presents them across five report pages plus a methodology page.

## Data model

- **Dimension table**: `companies` (ticker, name, country, currency, fiscal year-end month)
- **Fact tables**: `income_statement`, `balance_sheet`, `cash_flow` (one row per company per fiscal year)
- **Lookup table**: `fx_rates` (average and closing exchange rate per currency and fiscal year)
- **Views**: `profitability`, `liquidity_leverage`, `cash_flow_quality`, `returns_growth`, `amounts_usd`

In Power BI, `companies` and a shared `Years` table filter all views through one-to-many relationships.

## Dashboard pages

| Page | Question | Main metrics |
|---|---|---|
| Overview | How do the three companies compare at a glance? | Revenue (USD), net margin, free cash flow margin, current ratio, ROE |
| Profitability | How much revenue turns into profit? | Gross, operating, and net margin |
| Liquidity & Leverage | Can they pay their bills, and how much do they owe? | Current ratio, net debt (USD), debt-to-equity, intangibles share of assets |
| Cash Flow | Are the profits backed by real cash? | Free cash flow margin, net income vs. operating cash flow |
| Returns & Growth | Are they using their resources well, and growing? | Revenue growth, ROE, ROA |
| Methodology & Notes | How was this built, and what are the limits? | Sources, definitions, caveats |

| | |
|---|---|
| ![Profitability](images/profitability.png) | ![Liquidity & Leverage](images/liquidity_leverage.png) |
| ![Cash Flow](images/cash_flow.png) | ![Returns & Growth](images/returns_growth.png) |

## Methodology

**Company selection.** All three companies have fiscal years ending on March 31, so each year covers the same period. CD Projekt was included in an earlier version but replaced with Capcom, because its calendar fiscal year made year-by-year comparisons misleading.

**Currency conversion.** Amounts are converted to USD only where companies are compared by size. Income statement and cash flow items use the average exchange rate over each fiscal year; balance sheet items use the closing rate on the fiscal year-end date. Ratios and growth rates are calculated in each company's own currency, so exchange rate movements don't affect them. For example, Capcom's revenue grew 55% in yen between FY2023 and FY2026, but only about 36% in USD because the yen weakened.

**Key definitions.**
- Net debt = total debt − cash (negative = net cash)
- Current ratio = current assets ÷ current liabilities
- Free cash flow = operating cash flow − capital expenditure
- ROE = net income ÷ year-end equity
- ROA = net income ÷ year-end total assets

## Caveats

- **Gross margin isn't comparable across companies**, because each classifies development and platform costs differently. Operating and net margin are the fairer comparisons.
- **Game development costs are recorded differently.** Capcom (Japanese accounting) records games in development as current assets, which boosts its current ratio and shifts the timing of its cash flow relative to profit.
- **ROE uses year-end equity**, which exaggerates results when equity changes sharply. Take-Two's FY2025 ROE of -209% reflects write-offs shrinking its equity from $9.0bn to $2.1bn.
- **Ubisoft's FY2023 capital expenditure** is unusually high compared with its other years and may reflect a reporting change.
- **Yahoo Finance is an unofficial source.** Key figures were checked for internal consistency, but the companies' annual reports remain the authoritative reference. Data retrieved October 2026.

## Repository structure

```
├── README.md
├── notebook/
│   └── data_pipeline.ipynb    # extraction, cleaning, FX rates, loading into Supabase
├── sql/
│   └── views.sql              # keys, Row Level Security, and the five analysis views
├── report/
│   ├── gaming_financials.pbix # Power BI report
│   └── gaming_financials.pdf  # PDF export
└── images/                    # report screenshots
```

## How to reproduce

1. Install the Python packages: `pip install yfinance pandas sqlalchemy psycopg2-binary`
2. Create a free Supabase project and copy its **Session pooler** connection string.
3. Run the notebook from top to bottom. It asks for the database password when connecting and loads the five base tables.
4. Run `sql/views.sql` in the Supabase SQL Editor to add the keys, Row Level Security, and views.
5. Open the `.pbix` file in Power BI Desktop and point the data source to your own Supabase project.

To analyze different companies, change the `tickers` list and the `companies` table in the notebook and rerun it. The SQL views and Power BI model work unchanged.
