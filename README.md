# Retail Sales Pipeline: Excel → Python → MySQL → Power BI

An end-to-end data pipeline that takes a UK online retailer's raw transaction history — delivered as a messy multi-sheet Excel export — and turns it into a queryable, indexed database and an interactive business dashboard.

## The question this answers

A retailer running its reporting off manual Excel exports has no fast way to answer basic questions: which products actually drive revenue, which months need extra staffing, and how much of that revenue is quietly being eaten by returns and cancelled orders. This project builds the pipeline that answers those questions on demand instead of by hand.

## Data

**Source:** [Online Retail II](https://archive.ics.uci.edu/dataset/502/online+retail+ii), UCI Machine Learning Repository
**Size:** 1,067,371 transaction line items, December 2009 – December 2011, one UK-based online giftware wholesaler
**Format as received:** a single `.xlsx` file with two sheets, one per year

## Architecture

```
Excel (raw, 2 sheets)
   │
   ▼
Python — split into 25 monthly files (simulates a real monthly source system)
   │
   ▼
Python — extract → transform → load
   │  • combine 25 files back into one table
   │  • clean dates, flag cancellations, remove non-product line items
   │  • calculate revenue per line
   │
   ▼
MySQL — star schema (dim_customer, dim_product, fact_sales)
   │
   ▼
Power BI — executive dashboard, live connection
```

Each stage is its own Jupyter notebook, numbered in run order:

| Notebook | Purpose |
|---|---|
| `01_explore.ipynb` | First look at the raw data; identifies the data quality issues below |
| `02_split_months.ipynb` | Splits the two-sheet source file into 25 monthly files |
| `03_extract.ipynb` | Recombines the 25 monthly files into one table |
| `04_transform.ipynb` | Cleans dates, separates non-product rows, flags cancellations, calculates line revenue |
| `05_load.ipynb` | Builds and inserts the three MySQL tables |

## Database design

A star schema: one fact table holding every transaction, surrounded by two lookup tables.

```
<img width="887" height="326" alt="model-view" src="https://github.com/user-attachments/assets/52c50c52-87b9-4f51-a59b-06b938f3ef26" />

```



## Data quality issues found and how each was handled

This dataset looks clean at a glance and isn't. Every issue below was found by inspecting the data directly, not assumed.

| Issue | Found | Handled by |
|---|---|---|
| **Cancelled orders** mixed in with normal sales | 18,657 of 1,062,280 rows have an invoice number starting with "C" | Flagged with a dedicated `is_cancellation` column rather than removed, so cancelled revenue can still be reported on separately |
| **Returns** recorded as negative quantities | 22,114 rows | Left as-is — negative quantities already net correctly into revenue totals |
| **Non-product line items** (postage, bank charges, manual adjustments) mixed into the product data | 5,091 rows using codes like `POST`, `M`, `DOT`, `BANK CHARGES` | Removed from the main pipeline and saved separately (`non_product_rows.csv`) rather than silently discarded |
| **Missing customer IDs** (guest checkouts) | 241,104 of 1,062,280 rows (~23%) | Kept in `fact_sales` with a blank `customer_id` — dropping them would have discarded a quarter of all real revenue |
| **Duplicate product codes differing only in letter case and trailing whitespace** (e.g. `72349B` vs `72349b`; `'47503J '` vs `'47503J'`) | Both caught by Power BI's relationship validation rejecting the `dim_product` primary key — MySQL's own constraint had silently accepted both as distinct rows | Fixed by uppercasing and stripping whitespace from every `StockCode` before deduplication — reduced 5,301 "unique" codes to 5,128 genuinely unique ones |
| **Missing product descriptions** | 486 rows | Filled with `"UNKNOWN"` rather than left blank, so it's clear the gap was noticed and handled deliberately — later excluded from the top-products chart, since grouping 486 unrelated products under one label would misrepresent them as a single best-seller |
| **Generic shared descriptions masking distinct products** (e.g. "mailout" used by 6 different stock codes) | Discovered when a chart category appeared unexpectedly large | Excluded from the top-products ranking for the same reason as "UNKNOWN" |
| **Guest checkouts lost their country on join** | `dim_customer.country` only exists for the ~77% of transactions with a real `customer_id` — the 23% of guest-checkout rows had no way to join to a country, even though the original data had one for every row | Added `country` directly onto `fact_sales` at load time instead of relying on the `dim_customer` join, so all 1,062,280 rows carry a country with zero blanks |

The last two issues are the most interesting finding of this project: two silent duplicate-key bugs that a flat spreadsheet analysis would never surface, and that even MySQL's own primary key constraint didn't catch — they only became visible once a second tool (Power BI) with stricter comparison rules was layered on top. That's a genuine argument for why a proper relational model, not just a spreadsheet, is worth building.

## Dashboard

Built in Power BI Desktop, connected live to MySQL (not a static export — the report re-queries the database on refresh).

**Executive Summary page:**
- Total Revenue, Average Order Value, Return Rate %, and Cancelled Revenue (KPI cards)
- Revenue by month, December 2009 – December 2011 (line chart, using a custom chronological `Month Year` sort so the timeline reads correctly across both years)
- Top 10 products by revenue (bar chart, Top N filter, with the "UNKNOWN" and "mailout" generic-label categories excluded — see Data Quality notes)
- Revenue by country (bar chart), with markets earning under £10,000 grouped into a single "Other" category via a DAX calculated column, and the United Kingdom excluded from the chart so the remaining international markets are actually visible on a readable scale

**Data Quality page:**
- Note on the 5,091 excluded non-product line items
- Guest Checkout % measure (11.92% of revenue comes from orders with no linked customer account, despite guest checkouts making up ~23% of individual transactions — guest orders skew smaller on average)
- Write-up of the case-sensitivity and whitespace duplicate-key bugs found and fixed during the build

<img width="776" height="435" alt="executive-summary" src="https://github.com/user-attachments/assets/fe5d7a4b-4061-48a3-9051-c36e3ef63175" />

<img width="756" height="314" alt="data-quality" src="https://github.com/user-attachments/assets/9fa6d20e-b6ba-4b23-bbbb-c91510f0abb9" />



## Key findings

Across two years and just over a million transactions, this UK-based online wholesaler generated **£18,970,621** in gross revenue, at an average order value of **£361.19**. That headline number already accounts for two real leaks: returns account for **5.54%** of revenue, and a further **£1.05 million** is tied to orders that were cancelled outright.

Guest checkouts — orders with no linked customer account — made up roughly 23% of individual transactions but only **11.92%** of total revenue, meaning unregistered customers tend to place smaller orders than repeat, identifiable customers.

Revenue shows a clear, repeating seasonal pattern: it peaks sharply every **November** (both November 2010 and November 2011), consistent with retailers stocking up ahead of the holiday season, before dropping off sharply into December — a useful signal for staffing and inventory planning. *(The final data point in the series is a partial month, so the December 2011 drop should be read with that in mind rather than as a pure demand collapse.)*

Outside the UK, **EIRE (Ireland)** is the largest international market, followed by the Netherlands, Germany, France, and Australia. Markets earning under £10,000 individually were grouped into a single "Other" category to keep the breakdown readable rather than cluttered with two dozen near-invisible bars.

The single highest-revenue product is the **Regency Cakestand 3 Tier**, earning roughly **£330,000** — clearly ahead of the second-place White Hanging Heart T-Light Holder at around £270,000. Two generic-label categories, "UNKNOWN" (486 products with missing descriptions) and "mailout" (six distinct promotional stock codes sharing one label), were excluded from this ranking, since treating them as single products would have misleadingly combined unrelated revenue into one bar.

Two hidden data quality issues were found and corrected during this build: product codes differing only in letter case, and codes differing only in trailing whitespace. Both passed silently through MySQL's own primary key constraint and were only caught when Power BI's relationship validation rejected them — reducing the product count from 5,301 to 5,128 genuinely unique items, a reminder that referential integrity checks in one tool can catch what another tool misses.

## Limitations

- This is transaction data from a single UK wholesaler over two years — findings don't necessarily generalize to other retail contexts.
- No customer demographic data exists beyond country, so customer segmentation is limited to purchase behavior alone.
- Product descriptions come directly from the original seller's own free-text entry and were not standardized beyond fixing the case/whitespace duplicates described above — near-duplicate but not identical product names may still exist.
- The country grouping threshold (£10,000) was chosen for chart readability, not a business-defined cutoff — a different threshold would change which countries appear individually versus in "Other."

## How to run this project

**Requirements:** Anaconda (Python 3.11), MySQL 8.0+, Power BI Desktop (Windows)

1. Clone this repository.
2. Create the conda environment and install dependencies:
   ```
   conda create -n retail-pipeline python=3.11
   conda activate retail-pipeline
   conda install jupyter pandas openpyxl sqlalchemy
   pip install pymysql
   ```
3. Download the dataset from the [UCI link above](https://archive.ics.uci.edu/dataset/502/online+retail+ii) and place `online_retail_II.xlsx` in the project root.
4. In MySQL Workbench, run `schema.sql` to create the `retail_db` database and its three tables.
5. Launch Jupyter (`jupyter notebook`) and run the five notebooks in order, top to bottom: `01` → `02` → `03` → `04` → `05`.
6. Open `retail_dashboard.pbix` in Power BI Desktop, update the MySQL connection credentials to your own if needed, and click Refresh.

## Project structure

```
retail-pipeline/
├── README.md
├── schema.sql
├── online_retail_II.xlsx
├── clean_template.xlsx          # the data-entry form deliverable
├── monthly_files/               # 25 simulated monthly source files
├── non_product_rows.csv         # excluded postage/fee/adjustment rows
├── combined_raw.csv             # output of 03_extract.ipynb
├── combined_clean.csv           # output of 04_transform.ipynb
├── 01_explore.ipynb
├── 02_split_months.ipynb
├── 03_extract.ipynb
├── 04_transform.ipynb
├── 05_load.ipynb
└── retail_dashboard.pbix
```
