# E-Commerce 360: Customer, Sales and Operations Analytics

This is an end-to-end data analytics project based on the Olist Brazilian e-commerce public dataset. I built this to simulate the daily workflow of a Data Analyst—taking raw, messy data, building a model, validating it, and turning it into actionable business insights.

> **Note:** This is a self-initiated case study on a public dataset, not a client project. All monetary values are in Brazilian Real (R$).

## Business Problem

An e-commerce marketplace wants to understand its sales, customer retention, product performance, logistics, and customer satisfaction. Management needs to know: *Where are we losing money? Why are customers not returning? And what is hurting our reviews?*

## Tech Stack and Methodology

I followed a 4-step workflow to build this:
1. **Data Modeling (SQL Server):** Built a Star Schema in the `dw` schema. The biggest challenge here was preventing double-counting. Joining raw order_items to payments inflated the revenue by 4.5%, which I had to fix.
2. **Exploratory Data Analysis (Python):** Used Pandas to load the modeled data, handle missing values, and Matplotlib to generate 8 key charts for visual exploration.
3. **Cross-Validation (Excel):** I didn't just trust my SQL. I exported the modeled data and rebuilt the KPIs using Pivot Tables and `SUMIFS` to ensure the numbers matched perfectly.
4. **Visualization (Power BI):** Built a 5-page interactive dashboard using DAX to present findings to a non-technical audience.

## Dataset Overview

- **Source:** Olist Brazilian E-Commerce (Kaggle)
- **Scale:** ~99,000 orders, 112,000 order items, spanning from Sep 2016 to Aug 2018.
- **Data Quality Handling:** Dealt with duplicate reviews, multiple payment rows per order, and missing product categories. (Full details in `docs/` folder).

## Key Insights Found

1. **Delivery delays impact reviews heavily:** Late orders are only 6.7% of total orders but account for 32.5% of all 1-2 star reviews. Average review scores drop from 4.29 (on-time) to 1.70 (8+ days late).
2. **Customer retention is low:** 96.96% of customers only ordered once. Repeat customers bring in just 5.56% of total revenue.
3. **Geographic and seller concentration:** SP, RJ, and MG states bring 63.4% of revenue. The top 10% of sellers generate 67.5% of the revenue.
4. **Growth plateaued:** Monthly orders ramped up through 2017 but flattened out in 2018 (staying between 6,100 and 7,200 orders per month).

## Recommendations Provided

- Send proactive delay alerts and service recovery for orders running more than 7 days late.
- Review carrier performance in RJ and North-East states, and adjust delivery estimates.
- Run a post-purchase engagement test in the first 30 days to measure if it improves the repeat rate.
- Build a seller scorecard (review score + late rate) and address large sellers with poor ratings first.

## Repository Structure

```text
├── README.md
├── requirements.txt
├── docs/        Business understanding, data dictionary, insights
├── sql/         Data quality, model build, validation, business analysis
├── python/      Data understanding and EDA notebooks
├── excel/       KPI validation file
├── powerbi/     Interactive dashboard file
└── outputs/     Charts and screenshots
