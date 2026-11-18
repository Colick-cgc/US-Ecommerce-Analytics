with vaild_order as (select o.order_id,c.customer_unique_id,date(o.order_purchase_timestamp) as purchase_date
from orders o
join customers c on c.customer_id = o.customer_id
where o.order_status not in ('canceled', 'unavailable')),

first_month as (select customer_unique_id, min(purchase_date) as first_purchase_date, 
date_format(min(purchase_date),'%Y-%m-01') as cohort_month
from vaild_order
group by customer_unique_id),

customer_order_month as(select v.customer_unique_id,f.cohort_month,date_format(v.purchase_date,'%Y-%m-01') as order_month,
timestampdiff(month,str_to_date(f.cohort_month,'%Y-%m-%d'),str_to_date(date_format(v.purchase_date,'%Y-%m-01'),'%Y-%m-%d')) as month_index
from vaild_order v
join first_month f on v.customer_unique_id = f.customer_unique_id),

cohort_size as(select cohort_month, count(distinct customer_unique_id) as first_buy_customers
from first_month
WITH customer_month AS (
    -- 1. 提取每个客户实际购买过的月份，同一客户同一月份只保留一条
    SELECT DISTINCT
        c.customer_unique_id,
        DATE_SUB(
            DATE(o.order_purchase_timestamp),
            INTERVAL (DAYOFMONTH(o.order_purchase_timestamp) - 1) DAY
        ) AS order_month
    FROM orders o
    JOIN customers c
        ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),

first_month AS (
    -- 2. 计算每个客户的首次购买月份
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM customer_month
    GROUP BY customer_unique_id
),

cohort_size AS (
    -- 3. 计算每个月首次购买的客户数
    SELECT
        cohort_month,
        COUNT(*) AS first_buy_customers
    FROM first_month
    GROUP BY cohort_month
),

cohort_activity AS (
    -- 4. 计算客户购买月份距离首次购买月份的间隔
    SELECT
        cm.customer_unique_id,
        fm.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            fm.cohort_month,
            cm.order_month
        ) AS month_index
    FROM customer_month cm
    JOIN first_month fm
        ON cm.customer_unique_id = fm.customer_unique_id
),

retention AS (
    -- 5. 统计每个 Cohort 在各月份的留存客户数
    SELECT
        cohort_month,
        month_index,
        COUNT(*) AS retained_customers
    FROM cohort_activity
    GROUP BY cohort_month, month_index
)

-- 6. 计算留存率
SELECT
    r.cohort_month,
    r.month_index,
    r.retained_customers,
    c.first_buy_customers,
    ROUND(
        r.retained_customers * 100.0 /
        NULLIF(c.first_buy_customers, 0),
        2
    ) AS retention_rate
FROM retention r
JOIN cohort_size c
    ON r.cohort_month = c.cohort_month
ORDER BY r.cohort_month, r.month_index;

group by cohort_month),

retention as (select cohort_month,month_index,count(distinct customer_unique_id) as retained_customers
from customer_order_month
group by cohort_month, month_index)

select
    r.cohort_month,
    r.month_index,
    r.retained_customers,
    c.first_buy_customers,
    round(r.retained_customers* 100 / nullif(c.first_buy_customers,0) , 2) AS retention_rate
from retention r
join cohort_size c
  on r.cohort_month = c.cohort_month
order by r.cohort_month, r.month_index;