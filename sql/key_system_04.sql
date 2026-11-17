with
-- 1. 各支付方式订单数
pay_orders as (select payment_type, count(distinct order_id) as order_cnt
from order_payments
group by payment_type),
-- 2. 有支付记录的总订单数
total_orders as (select count(distinct order_id) as total_order_cnt
from order_payments),
-- 3. 各支付方式支付金额，总数与平均
pay_amount as (select payment_type,count(*) as payment_record_cnt,
sum(payment_value) as total_payment_value,avg(payment_value) as avg_payment_value
from order_payments
group by payment_type),
-- 4. 平均分期期数
order_inst as (select order_id,max(payment_type) as payment_type,max(payment_installments) as installments
from order_payments
where payment_installments > 0
group by order_id),
inst_by_type as (select payment_type,count(*) as inst_order_cnt,avg(installments) as avg_installments_by_order
from order_inst
group by payment_type),
-- 5. 多次支付订单
multi_pay_orders as (select distinct order_id
from order_payments
where payment_sequential > 1),
multi_by_type as (select p.payment_type,count(distinct p.order_id) as multi_payment_order_cnt
from order_payments p
join multi_pay_orders m on p.order_id = m.order_id
group by p.payment_type),
-- 6. 支付审批时长（小时）
approval_time as (select order_id,timestampdiff(second, order_purchase_timestamp, order_approved_at) / 3600.0 as approval_hours
from orders
where order_approved_at is not null
and order_purchase_timestamp is not null),
approval_summary as (select count(*) as approval_order_cnt,avg(approval_hours) as avg_approval_hours
from approval_time),
-- 7. 发货等待时间（小时）
ship_wait as (select order_id,timestampdiff(second, order_approved_at, order_delivered_carrier_date) / 3600.0 as ship_wait_hours
from orders
where order_approved_at is not null
and order_delivered_carrier_date is not null),
ship_summary as (select count(*) as ship_order_cnt,avg(ship_wait_hours) as avg_ship_wait_hours
from ship_wait),
-- 8. 物流配送时长（天）
delivery_time as (select order_id,
timestampdiff(second, order_delivered_carrier_date, order_delivered_customer_date) / 86400.0 as delivery_days
from orders),
delivery_summary as (select count(*) as delivery_order_cnt,avg(delivery_days) as avg_delivery_days
from delivery_time),
-- 9. 配送延迟天数（正=延迟，负=提前）
delay_time as (select order_id,
timestampdiff(second, order_estimated_delivery_date, order_delivered_customer_date) / 86400.0 as delay_days,
	case
		when order_delivered_customer_date > order_estimated_delivery_date then 1
		else 0
	end as is_delayed
from orders),
delay_summary as (select count(*) as delivered_order_cnt,avg(delay_days) as avg_delay_days,
sum(is_delayed) * 100.0 / nullif(count(*), 0) as delayed_order_pct
from delay_time),
-- 10. 平均客户评分（按订单去重）
order_review as (select order_id,avg(review_score) as avg_score
from order_reviews
where review_score is not null
group by order_id),
review_summary as (select count(*) as review_order_cnt, avg(avg_score) as avg_review_score
from order_review)
-- 最终宽表：每行一个 payment_type
select
    p.payment_type,
    p.order_cnt,
    round(p.order_cnt * 100.0 / nullif(t.total_order_cnt, 0), 2) as usage_pct,
    round(a.total_payment_value, 2) as total_payment_value,
    round(a.avg_payment_value, 2) as avg_payment_value,
    round(i.avg_installments_by_order, 2) as avg_installments_by_order,
    coalesce(m.multi_payment_order_cnt, 0) as multi_payment_order_cnt,
    round(ap.avg_approval_hours, 2) as avg_approval_hours,
    round(sh.avg_ship_wait_hours, 2) as avg_ship_wait_hours,
    round(dl.avg_delivery_days, 2) as avg_delivery_days,
    round(de.avg_delay_days, 2) as avg_delay_days,
    round(de.delayed_order_pct, 2) as delayed_order_pct,
    round(rv.avg_review_score, 2) as avg_review_score
from pay_orders p
cross join total_orders t
cross join approval_summary ap
cross join ship_summary sh
cross join delivery_summary dl
cross join delay_summary de
cross join review_summary rv
left join pay_amount a on p.payment_type = a.payment_type
left join inst_by_type i on p.payment_type = i.payment_type
left join multi_by_type m on p.payment_type = m.payment_type
order by p.order_cnt desc;