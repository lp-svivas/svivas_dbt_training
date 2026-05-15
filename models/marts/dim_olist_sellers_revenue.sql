
/*
    Welcome to your first dbt model!
    Did you know that you can also configure models directly within SQL files?
    This will override configurations stated in dbt_project.yml

    Try changing "table" to "view" below
*/

-- {{ config(materialized='view') }}

WITH SELLERS_MONTHLY_REVENUE AS (
    select * from {{ ref('stg_snowflake_learnings__monthly_revenue') }}
),
SELLERS_METRICS AS (
    SELECT
        SELLER_ID,
        ORDER_MONTH,
        MONTHLY_REVENUE,
        AVG(MONTHLY_REVENUE) OVER (
            PARTITION BY SELLER_ID 
            ORDER BY ORDER_MONTH 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS ROLLING_3_MONTH_AVG
    FROM SELLERS_MONTHLY_REVENUE
),
SELLER_LATEST_TIER AS (
    SELECT
        SELLER_ID,
        CASE
            WHEN MONTHLY_REVENUE >= 5000 THEN 'High'
            WHEN MONTHLY_REVENUE >= 1000 THEN 'Medium'
            ELSE 'Low'
        END AS TIER
    FROM SELLERS_MONTHLY_REVENUE
    QUALIFY ORDER_MONTH = MAX(ORDER_MONTH) OVER (PARTITION BY SELLER_ID)
),
METRICS_WITH_TIER AS (
    SELECT
        M.SELLER_ID,
        M.ORDER_MONTH,
        M.MONTHLY_REVENUE,
        M.ROLLING_3_MONTH_AVG,
        T.TIER
    FROM SELLERS_METRICS M
    INNER JOIN SELLER_LATEST_TIER T
        ON M.SELLER_ID = T.SELLER_ID
),
ROLLUP_SUMMARY AS (
    SELECT
        COALESCE(TIER, 'GRAND TOTAL') AS TIER,
        -- ORDER_MONTH,
        SUM(MONTHLY_REVENUE) AS TOTAL_REVENUE,
        SUM(ROLLING_3_MONTH_AVG) AS TOTAL_3M_AVG
    FROM METRICS_WITH_TIER
    GROUP BY ROLLUP (TIER) -- , ORDER_MONTH)
)
SELECT *
FROM ROLLUP_SUMMARY
ORDER BY TIER NULLS LAST --, ORDER_MONTH NULLS LAST;