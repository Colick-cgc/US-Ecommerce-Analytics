with
-- 1. 有效订单
valid_orders as (select order_id
from orders
where order_status not in ('canceled', 'unavailable')),
-- 2. 卖家-订单销售额（每个卖家每个订单的商品金额）
seller_order_sales as (select oi.seller_id,oi.order_id,sum(oi.price) as order_sales
from order_items oi
join valid_orders vo on oi.order_id = vo.order_id
group by oi.seller_id, oi.order_id),
-- 3. 卖家汇总：订单量、销售额
seller_summary as (select seller_id,count(distinct order_id) as order_cnt,sum(order_sales) as total_sales
from seller_order_sales
group by seller_id),
-- 4. 卖家平均订单金额
seller_avg as (select seller_id,total_sales / nullif(order_cnt, 0) as avg_order_value
from seller_summary),
-- 5. 卖家总数
total_sellers as (select count(distinct seller_id) as total_seller_cnt
from sellers),
-- 6. 卖家区域分布
seller_by_state as (select seller_state,count(distinct seller_id) as seller_cnt
from sellers
group by seller_state),
-- 7. 客户区域分布（按 customer_unique_id 去重）
customer_by_state as (select customer_state,count(distinct customer_unique_id) as customer_cnt
from customers
group by customer_state),
-- 8. 订单级别：是否跨州（订单内任一卖家州与客户州不同即记为跨州）
order_cross_state as (
select oi.order_id,max(case when s.seller_state <> c.customer_state then 1 else 0 end) as is_cross_state
from order_items oi
join valid_orders vo on oi.order_id = vo.order_id
join orders o on oi.order_id = o.order_id
join customers c on o.customer_id = c.customer_id
join sellers s on oi.seller_id = s.seller_id
group by oi.order_id),
-- 9. 跨州订单占比
cross_state_pct as (select sum(is_cross_state) * 100.0 / nullif(count(*), 0) as cross_state_order_pct
from order_cross_state),
delivery_delay AS (
    SELECT
        AVG(
            TIMESTAMPDIFF(
                SECOND,
                order_estimated_delivery_date,
                order_delivered_customer_date
            ) / 86400.0
        ) AS avg_delay_days
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
-- 最终宽表：每行一个 seller
select
    s.seller_id,
    s.seller_state,
    ss.order_cnt,
    round(ss.total_sales, 2) as total_sales,
    ROUND(dd.avg_delay_days, 2) AS avg_delay_days,
    round(sa.avg_order_value, 2) as avg_order_value,
    sbs.seller_cnt as seller_cnt_in_state,
    cbs.customer_cnt as customer_cnt_in_state,
    round(csp.cross_state_order_pct, 2) as cross_state_order_pct,
    ts.total_seller_cnt
from sellers s
left join seller_summary ss on s.seller_id = ss.seller_id
left join seller_avg sa on s.seller_id = sa.seller_id
left join seller_by_state sbs on s.seller_state = sbs.seller_state
left join customer_by_state cbs on s.seller_state = cbs.customer_state
cross join cross_state_pct csp
cross join total_sellers ts
CROSS JOIN delivery_delay dd
order by ss.total_sales desc;