create or replace view vw_fact_order as

with

-- 1. 商品汇总：每笔订单只保留一行
item_summary as (
    select
        order_id,
        sum(price) as item_amount,
        sum(freight_value) as freight_amount,
        sum(price + freight_value) as item_freight_amount,
        count(*) as item_count,
        count(distinct product_id) as product_count,
        count(distinct seller_id) as seller_count
    from order_items
    group by order_id
),

-- 2. 支付汇总：每笔订单只保留一行
payment_summary as (
    select
        order_id,
        sum(payment_value) as payment_amount,
        count(*) as payment_record_count,
        count(distinct payment_type) as payment_type_count,
        max(payment_installments) as max_installments,
        avg(payment_installments) as avg_installments,
        group_concat(
            distinct payment_type
            order by payment_type
            separator ','
        ) as payment_types
    from order_payments
    group by order_id
),

-- 3. 评价汇总：避免一笔订单多条评价造成重复
review_summary as (
    select
        order_id,
        avg(review_score) as avg_review_score,
        count(review_score) as review_count
    from order_reviews
    group by order_id
),

-- 4. 计算客户首次有效购买日期
first_purchase as (
    select
        c.customer_unique_id,
        min(o.order_purchase_timestamp) as first_purchase_time
    from orders o
    join customers c
        on o.customer_id = c.customer_id
    where o.order_status not in ('canceled', 'unavailable')
    group by c.customer_unique_id
)

-- 5. 形成最终订单级宽表
select
    -- 订单基础信息
    o.order_id,
    o.customer_id,
    c.customer_unique_id,

    -- 订单状态
    o.order_status,

    case
        when o.order_status = 'delivered' then '已完成'
        when o.order_status in ('shipped', 'invoiced',
                                'approved', 'processing',
                                'created') then '处理中'
        when o.order_status = 'canceled' then '已取消'
        when o.order_status = 'unavailable' then '不可用'
        else '其他'
    end as order_status_group,

    case
        when o.order_status in ('canceled', 'unavailable')
        then 0
        else 1
    end as is_valid_order,

    case
        when o.order_status = 'delivered'
        then 1 else 0
    end as is_delivered,

    -- 下单时间
    o.order_purchase_timestamp,
    date(o.order_purchase_timestamp) as purchase_date,
    year(o.order_purchase_timestamp) as purchase_year,
    month(o.order_purchase_timestamp) as purchase_month,
    date_format(
        o.order_purchase_timestamp, '%Y-%m'
    ) as purchase_year_month,
    week(o.order_purchase_timestamp, 3) as purchase_week,

    -- 客户地区
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,

    -- 客户首购信息
    fp.first_purchase_time,
    date(fp.first_purchase_time) as first_purchase_date,

    case
        when date(o.order_purchase_timestamp)
             = date(fp.first_purchase_time)
        then '首购日'
        else '非首购日'
    end as customer_purchase_stage,

    -- 商品信息汇总
    coalesce(i.item_amount, 0) as item_amount,
    coalesce(i.freight_amount, 0) as freight_amount,
    coalesce(i.item_freight_amount, 0)
        as item_freight_amount,
    coalesce(i.item_count, 0) as item_count,
    coalesce(i.product_count, 0) as product_count,
    coalesce(i.seller_count, 0) as seller_count,

    -- 支付信息汇总
    coalesce(p.payment_amount, 0) as payment_amount,
    coalesce(p.payment_record_count, 0)
        as payment_record_count,
    coalesce(p.payment_type_count, 0)
        as payment_type_count,
    p.payment_types,
    p.max_installments,
    p.avg_installments,

    -- 支付及履约时间
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    timestampdiff(
        second,
        o.order_purchase_timestamp,
        o.order_approved_at
    ) / 3600.0 as approval_hours,

    timestampdiff(
        second,
        o.order_approved_at,
        o.order_delivered_carrier_date
    ) / 3600.0 as ship_wait_hours,

    timestampdiff(
        second,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date
    ) / 86400.0 as delivery_days,

    timestampdiff(
        second,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date
    ) / 86400.0 as delay_days,

    case
        when o.order_delivered_customer_date is null
         or o.order_estimated_delivery_date is null
        then null
        when o.order_delivered_customer_date
             > o.order_estimated_delivery_date
        then 1
        else 0
    end as is_delayed,

    -- 评价信息
    r.avg_review_score,
    coalesce(r.review_count, 0) as review_count

from orders o

join customers c
    on o.customer_id = c.customer_id

left join item_summary i
    on o.order_id = i.order_id

left join payment_summary p
    on o.order_id = p.order_id

left join review_summary r
    on o.order_id = r.order_id

left join first_purchase fp
    on c.customer_unique_id = fp.customer_unique_id;
