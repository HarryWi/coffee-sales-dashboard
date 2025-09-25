------------------------------------------------
-- Create schemas and delete the public schema
------------------------------------------------

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS analytics;
DROP SCHEMA public;

------------------------------------------------
-- CREATE STAGING TABLE (ALL TEXT; 1:1 WITH CSV)
------------------------------------------------

CREATE TABLE IF NOT EXISTS staging.coffee_sales_raw (
  hour_of_day   TEXT,
  cash_type     TEXT,
  money         TEXT,
  coffee_name   TEXT,
  time_of_day   TEXT,
  weekday       TEXT,
  month_name    TEXT,
  weekdaysort   TEXT,
  monthsort     TEXT,
  "Date"        TEXT,
  "Time"        TEXT
);

------------------------------------------------
-- CREATE FINAL, TYPED FACT TABLE (ANALYTICS)
------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.coffee_sales (
  sale_id        BIGSERIAL PRIMARY KEY,
  hour_of_day    SMALLINT,
  cash_type      TEXT,
  sales_amount   NUMERIC(10,2) CHECK (sales_amount >= 0),
  coffee_name    TEXT,
  time_of_day    TEXT,
  weekday        TEXT,
  month_name     TEXT,
  weekday_sort   SMALLINT,
  month_sort     SMALLINT,
  sale_date      DATE NOT NULL,
  sale_time      TIME,
  sale_ts        TIMESTAMP,
  created_at     TIMESTAMP DEFAULT NOW()
);

------------------------------------------------
-- TRANSFORM & LOAD FROM STAGING → ANALYTICS
------------------------------------------------

INSERT INTO analytics.coffee_sales (
  hour_of_day, cash_type, sales_amount, coffee_name, time_of_day,
  weekday, month_name, weekday_sort, month_sort, sale_date, sale_time, sale_ts
)
SELECT
  NULLIF(TRIM(hour_of_day), '')::SMALLINT,
  NULLIF(TRIM(cash_type), '')::TEXT,
  CASE
    WHEN TRIM(money) IN ('', 'NULL') THEN NULL
    ELSE REPLACE(REPLACE(money, ',', ''), ' ', '')::NUMERIC(10,2)
  END AS sales_amount,
  NULLIF(TRIM(coffee_name), '')::TEXT,
  NULLIF(TRIM(time_of_day), '')::TEXT,
  NULLIF(TRIM(weekday), '')::TEXT,
  NULLIF(TRIM(month_name), '')::TEXT,
  NULLIF(TRIM(weekdaysort), '')::SMALLINT,
  NULLIF(TRIM(monthsort), '')::SMALLINT,

  -- DATE: YYYY-MM-DD
  TO_DATE(TRIM("Date"), 'YYYY-MM-DD') AS sale_date,

  -- TIME: CHANGE TO 'HH24:MI' IF YOUR CSV HAS NO SECONDS
  TO_TIMESTAMP(TRIM("Time"), 'HH24:MI:SS')::TIME AS sale_time,

  -- TIMESTAMP
  CASE
    WHEN "Date" IS NOT NULL AND "Time" IS NOT NULL
      THEN TO_TIMESTAMP(TRIM("Date") || ' ' || TRIM("Time"), 'YYYY-MM-DD HH24:MI:SS')
    WHEN "Date" IS NOT NULL
      THEN TO_TIMESTAMP(TRIM("Date"), 'YYYY-MM-DD')
    ELSE NULL
  END AS sale_ts
FROM staging.coffee_sales_raw;

------------------------------------------------
-- ADD PRACTICAL INDICES
------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_sales_date      ON analytics.coffee_sales (sale_date);
CREATE INDEX IF NOT EXISTS idx_sales_coffee    ON analytics.coffee_sales (coffee_name);
CREATE INDEX IF NOT EXISTS idx_sales_cash_type ON analytics.coffee_sales (cash_type);
CREATE INDEX IF NOT EXISTS idx_sales_ts        ON analytics.coffee_sales (sale_ts);

-- OPTIONAL FOR LARGE, APPEND-ONLY TABLES
CREATE INDEX IF NOT EXISTS brin_sales_date ON analytics.coffee_sales USING BRIN (sale_date);

------------------------------------------------
-- CREATE VIEWS FOR POWER BI
------------------------------------------------

-- PRESENTATION VIEW
CREATE OR REPLACE VIEW analytics.v_coffee_sales AS
SELECT
  sale_id,
  sale_date,
  sale_time,
  sale_ts,
  coffee_name,
  cash_type,
  time_of_day,
  weekday,
  month_name,
  weekday_sort,
  month_sort,
  hour_of_day,
  sales_amount
FROM analytics.coffee_sales;

-- DATE DIMENSION VIEW
CREATE OR REPLACE VIEW analytics.v_dim_date AS
WITH bounds AS (
  SELECT MIN(sale_date) AS dmin, MAX(sale_date) AS dmax FROM analytics.coffee_sales
),
d AS (
  SELECT GENERATE_SERIES(dmin, dmax, INTERVAL '1 day')::DATE AS d
  FROM bounds
)
SELECT
  d                               AS date,
  EXTRACT(ISODOW FROM d)::INT     AS iso_weekday,
  TO_CHAR(d, 'Day')               AS weekday_name,
  EXTRACT(MONTH FROM d)::INT      AS month_num,
  TO_CHAR(d, 'Mon')               AS month_abbr,
  EXTRACT(YEAR FROM d)::INT       AS year,
  DATE_TRUNC('month', d)::DATE    AS first_of_month
FROM d;

------------------------------------------------
-- MAINTENANCE AFTER LOADS
------------------------------------------------

ANALYZE analytics.coffee_sales;
VACUUM (ANALYZE) analytics.coffee_sales;

------------------------------------------------
-- READ-ONLY SECURITY FOR POWER BI
------------------------------------------------

CREATE ROLE pbi_reader NOINHERIT;
GRANT USAGE ON SCHEMA analytics TO pbi_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO pbi_reader;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA analytics TO pbi_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics GRANT SELECT ON TABLES TO pbi_reader;

-- CHECK YOUR CURRENT LOGIN ROLE
SELECT current_user;

-- ASSIGN THAT ROLE TO pbi_reader
GRANT pbi_reader TO postgres;

-- IF YOU NEED A NEW DEDICATED POWER BI USER
-- Create login role (with password for PBI to connect)
CREATE ROLE pbi_user WITH LOGIN PASSWORD 'StrongPassword123';

-- Assign it to the read-only group
GRANT pbi_reader TO pbi_user;

