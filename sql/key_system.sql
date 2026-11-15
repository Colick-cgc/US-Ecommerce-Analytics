# 2.2.1整体经营指标体系
# 1. 商品销售额
select sum(order_items.price) as total_price
from order_items;
# 2. 订单总量
select count(distinct orders.order_id) as total_orders
from orders;
# 3. 有效订单量
select count(distinct orders.order_id) as vaild_orders
from orders
where order_status in ('shipped', 'delivered');
# 4. 取消订单量
select count(distinct orders.order_id) as vaild_orders
from orders
where order_status in ('canceled');
# 5. 订单取消率
select round(count(distinct case when orders.order_status = 'canceled' then order_id end)*100/
count(distinct orders.order_id),2) as vaild_per
from orders;
# 6. 客户总数
select count(distinct customers.customer_unique_id) as total_cus
from customers;
# 7. 客单价
with sales as(select sum(order_items.price) as total_price
from order_items),

vaildorders as (select count(distinct orders.order_id) as vaild_orders
from orders
where order_status in ('shipped', 'delivered'))
select round(s.total_price/v.vaild_orders,2) as aov
from sales s
cross join vaildorders v;

# 8. 平均订单商品总数
with num_items as (select count(*) as total_items from order_items),
vaildorders as (select count(distinct orders.order_id) as vaild_orders
from orders
where order_status in ('shipped', 'delivered'))
select round(n.total_items/v.vaild_orders,0) as ave_item
from num_items n
cross join vaildorders v;

# 9. 月度销售增长率

with monthlysales as(select date_format(o.order_purchase_timestamp, '%Y-%m') as sales_month,
sum(oi.price) as monthly_price
from orders o 
join order_items oi on o.order_id = oi.order_id
where o.order_status not in ('canceled', 'unavailable')
group by date_format(o.order_purchase_timestamp, '%Y-%m')),
saleswithlag as (select sales_month,monthly_price,lag(monthly_price) over (order by sales_month) as prev_month_sales
from monthlysales)
select round((monthly_price - prev_month_sales) / prev_month_sales * 100, 2) as growth_rate_percentage
FROM saleswithlag;

# 10.平均订单支付额

SELECT 
    ROUND(SUM(payment_value) / COUNT(DISTINCT order_id), 2) AS avg_order_payment
FROM order_payments;