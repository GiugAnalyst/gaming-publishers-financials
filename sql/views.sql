-- =====================================================================
-- Gaming Publishers: Financial Health Analysis
-- Database setup for Supabase (PostgreSQL)
--
-- Run this AFTER the notebook has loaded the five base tables
-- (companies, income_statement, balance_sheet, cash_flow, fx_rates).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Keys
-- ---------------------------------------------------------------------
-- pandas' to_sql() creates the tables but not their keys, so they are
-- added here. Each statement row is identified by ticker + fiscal year end.

alter table companies        add primary key (ticker);
alter table income_statement add primary key (ticker, fiscal_year_end);
alter table balance_sheet    add primary key (ticker, fiscal_year_end);
alter table cash_flow        add primary key (ticker, fiscal_year_end);
alter table fx_rates         add primary key (currency, fiscal_year_end);

alter table income_statement add foreign key (ticker) references companies (ticker);
alter table balance_sheet    add foreign key (ticker) references companies (ticker);
alter table cash_flow        add foreign key (ticker) references companies (ticker);


-- ---------------------------------------------------------------------
-- 2. Row Level Security
-- ---------------------------------------------------------------------
-- Blocks access through Supabase's public API. Direct database
-- connections with the database password keep full access.

alter table companies        enable row level security;
alter table income_statement enable row level security;
alter table balance_sheet    enable row level security;
alter table cash_flow        enable row level security;
alter table fx_rates         enable row level security;


-- ---------------------------------------------------------------------
-- 3. Profitability
-- ---------------------------------------------------------------------
-- How much of each unit of revenue the company keeps at each stage.

create or replace view profitability
with (security_invoker = true) as
select
    i.ticker,
    c.company_name,
    i.fiscal_year,
    i.total_revenue,
    round((i.gross_profit     / nullif(i.total_revenue, 0))::numeric, 4) as gross_margin,
    round((i.operating_income / nullif(i.total_revenue, 0))::numeric, 4) as operating_margin,
    round((i.ebitda           / nullif(i.total_revenue, 0))::numeric, 4) as ebitda_margin,
    round((i.net_income       / nullif(i.total_revenue, 0))::numeric, 4) as net_margin
from income_statement i
join companies c on c.ticker = i.ticker;


-- ---------------------------------------------------------------------
-- 4. Liquidity & leverage
-- ---------------------------------------------------------------------
-- Can the company pay its short-term bills, and how much does it owe?

create or replace view liquidity_leverage
with (security_invoker = true) as
select
    b.ticker,
    c.company_name,
    b.fiscal_year,
    b.fiscal_year_end,
    round((b.current_assets            / nullif(b.current_liabilities, 0))::numeric, 4)  as current_ratio,
    round((b.cash_and_cash_equivalents / nullif(b.current_liabilities, 0))::numeric, 4)  as cash_ratio,
    round((coalesce(b.total_debt, 0)   / nullif(b.stockholders_equity, 0))::numeric, 4)  as debt_to_equity,
    round((b.total_liabilities_net_minority_interest / nullif(b.total_assets, 0))::numeric, 4) as liabilities_to_assets,
    round((b.goodwill_and_other_intangible_assets    / nullif(b.total_assets, 0))::numeric, 4) as intangibles_to_assets,
    b.net_debt  -- calculated in the notebook as total debt - cash (negative = net cash)
from balance_sheet b
join companies c on c.ticker = b.ticker;


-- ---------------------------------------------------------------------
-- 5. Cash flow quality
-- ---------------------------------------------------------------------
-- Are reported profits backed by real cash?

create or replace view cash_flow_quality
with (security_invoker = true) as
select
    cf.ticker,
    c.company_name,
    cf.fiscal_year,
    cf.fiscal_year_end,
    round((cf.operating_cash_flow  / nullif(i.total_revenue, 0))::numeric, 4) as operating_cf_margin,
    round((cf.free_cash_flow       / nullif(i.total_revenue, 0))::numeric, 4) as free_cf_margin,
    round((-cf.capital_expenditure / nullif(i.total_revenue, 0))::numeric, 4) as capex_intensity,
    case
        when i.net_income > 0   -- only meaningful when the company is profitable
        then round((cf.operating_cash_flow / i.net_income)::numeric, 4)
    end                                                                        as cash_conversion,
    -(cf.repurchase_of_capital_stock + cf.cash_dividends_paid)                 as shareholder_returns
from cash_flow cf
join income_statement i
    on  i.ticker = cf.ticker
    and i.fiscal_year_end = cf.fiscal_year_end
join companies c on c.ticker = cf.ticker;


-- ---------------------------------------------------------------------
-- 6. Returns & growth
-- ---------------------------------------------------------------------
-- Efficiency (ROE, ROA) and year-over-year revenue growth.
-- Growth uses the company's own currency to exclude exchange rate effects.

create or replace view returns_growth
with (security_invoker = true) as
select
    i.ticker,
    c.company_name,
    i.fiscal_year,
    i.fiscal_year_end,
    round((i.net_income / nullif(b.stockholders_equity, 0))::numeric, 4) as roe,
    round((i.net_income / nullif(b.total_assets, 0))::numeric, 4)        as roa,
    round((i.total_revenue
           / nullif(lag(i.total_revenue) over (partition by i.ticker order by i.fiscal_year_end), 0)
           - 1)::numeric, 4)                                              as revenue_growth
from income_statement i
join balance_sheet b
    on  b.ticker = i.ticker
    and b.fiscal_year_end = i.fiscal_year_end
join companies c on c.ticker = i.ticker;


-- ---------------------------------------------------------------------
-- 7. Amounts in USD
-- ---------------------------------------------------------------------
-- Converts key amounts to USD for size comparisons.
-- Income statement and cash flow: average rate over the fiscal year.
-- Balance sheet: closing rate on the fiscal year-end date.

create or replace view amounts_usd
with (security_invoker = true) as
select
    i.ticker,
    c.company_name,
    i.fiscal_year,
    i.fiscal_year_end,
    -- income statement & cash flow: average rate
    round((i.total_revenue        * f.avg_rate)::numeric, 0) as total_revenue_usd,
    round((i.gross_profit         * f.avg_rate)::numeric, 0) as gross_profit_usd,
    round((i.operating_income     * f.avg_rate)::numeric, 0) as operating_income_usd,
    round((i.net_income           * f.avg_rate)::numeric, 0) as net_income_usd,
    round((cf.operating_cash_flow * f.avg_rate)::numeric, 0) as operating_cash_flow_usd,
    round((cf.free_cash_flow      * f.avg_rate)::numeric, 0) as free_cash_flow_usd,
    -- balance sheet: closing rate
    round((b.total_assets              * f.closing_rate)::numeric, 0) as total_assets_usd,
    round((b.stockholders_equity       * f.closing_rate)::numeric, 0) as equity_usd,
    round((b.cash_and_cash_equivalents * f.closing_rate)::numeric, 0) as cash_usd,
    round((b.total_debt                * f.closing_rate)::numeric, 0) as total_debt_usd,
    round((b.net_debt                  * f.closing_rate)::numeric, 0) as net_debt_usd
from income_statement i
join balance_sheet b
    on  b.ticker = i.ticker
    and b.fiscal_year_end = i.fiscal_year_end
join cash_flow cf
    on  cf.ticker = i.ticker
    and cf.fiscal_year_end = i.fiscal_year_end
join companies c on c.ticker = i.ticker
join fx_rates f
    on  f.currency = c.currency
    and f.fiscal_year_end = i.fiscal_year_end;
