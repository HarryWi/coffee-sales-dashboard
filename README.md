# Coffee Sales Analysis

This project analyzes coffee shop sales data using **PostgreSQL** for storage and transformation, and **Power BI** for interactive reporting.

## Features

- **Database setup**
  - Staging and analytics schemas
  - Typed fact table with transformations
  - Indexing for performance
  - Views for clean Power BI consumption ([SQL script](coffee_sales_db%20code.sql))

- **Power BI Dashboard** ([PBIX file](Coffee%20Sales%20Analysis.pbix))
  - KPIs (Total Sales, YTD Sales, YoY %, Distinct Coffees)
  - Sales trends over time
  - Top coffee products
  - Weekday × hour heatmap
  - Composition by payment type and time of day
  - Flexible slicers (Year/Month, Coffee Type, Time of Day, Weekday)

- **Documentation**
  - [Dashboard preview (PDF)](Default%20view%20dashboard.pdf)

## Project Goals

- Demonstrate end-to-end analytics workflow (PostgreSQL → Power BI)
- Optimize SQL for minimal transformations, keeping business logic in Power BI
- Provide insights into customer purchasing patterns and product performance

## Files

- `coffee_sales_db code.sql` → Database schema, ETL, indexes, views  
- `Coffee Sales Analysis.pbix` → Power BI dashboard  
- `Default view dashboard.pdf` → Screenshot/preview of dashboard  

## Getting Started

1. Run SQL script in PostgreSQL to create tables, load data, and build views
