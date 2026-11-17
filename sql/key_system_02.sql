# 2.1.2 商品经营分析指标
# 定义临时变量
SET @start_date = '2019-01-01';
SET @end_date   = '2026-01-01';
SET @as_of_date = '2026-01-01';
## 有效订单
with vaild_orders as (select o.order_id,c.customer_unique_id,date(o.order_purchase_timestamp) as purchase_date
from orders o
join customers c on c.customer_id = o.customer_id
where o.order_status not in ('canceled', 'unavailable')),
order_amt as (select order_items.order_id, sum(price) as item_amt
from order_items
group by order_id),
vaild_order_amt as (select v.order_id,v.customer_unique_id,v.purchase_date, coalesce(a.item_amt,0) as item_amount
from vaild_orders v
left join order_amt a on a.order_id = v.order_id),
period_order as (select * from vaild_order_amt
where purchase_date >= @start_date and purchase_date < @end_date),
period_customer as (select customer_unique_id,count(distinct order_id) as freq,sum(item_amount) as monetary
from period_order group by customer_unique_id),
first_purchase as(select customer_unique_id,min(purchase_date) as first_purchase_date
from vaild_order_amt group by customer_unique_id),
new_customer as (select customer_unique_id from first_purchase
where first_purchase_date >= @start_date
and first_purchase_date <= @end_date),
repurchase_customer as (select customer_unique_id from period_customer 
where freq >=2),
clv as (select customer_unique_id, sum(item_amount) as clv_amount, max(purchase_date) as lastest_pur_date
from vaild_order_amt
group by customer_unique_id)
# 1. 有效客户数
select count(*) as real_customers from period_customer
# 2. 新客户数
union all
select count(*) as new_customers from new_customer
# 3. 复购客户数
union all
select count(*) as repurchase_customers from repurchase_customer
# 4. 客户复购率
union all
select round((select count(*) as repurchase_customers from repurchase_customer)*100/
(select count(*) as real_customers from period_customer),2) as rep_per
# 5. 客户平均消费金额
union all
select round((select sum(monetary) from period_customer)/
(select count(*) as real_customers from period_customer),2) as ave_price
# 6. 客户平均购买频次
union all
select round((select sum(freq) from period_customer)/ 
nullif((select count(*) from period_customer), 0), 2);
# 7. 客户生命周期价值
SELECT
    p.customer_unique_id,
    DATEDIFF(@as_of_date, h.last_purchase_date) AS R,
    p.freq AS F,
    p.monetary AS M,
    h.clv_amount AS CLV
FROM period_customer p
JOIN clv h
    ON p.customer_unique_id = h.customer_unique_id
ORDER BY R ASC, F DESC, M DESC;