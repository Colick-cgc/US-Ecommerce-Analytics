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
group by cohort_month),

rention as (select cohort_month,month_index,count(distinct customer_id) as retained_customers
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