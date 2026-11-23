create or replace view vw_fact_order_item as

select
    -- 订单与商品标识
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,

    -- 商品金额
    oi.price as item_price,
    oi.freight_value,

    -- 商品信息
    p.product_category_name,
    coalesce(
        pt.product_category_name_english,
        p.product_category_name
    ) as product_category_english,

    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,

    -- 卖家信息
    s.seller_city,
    s.seller_state,

    -- 买家信息
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,

    -- 订单时间与状态
    o.order_purchase_timestamp,
    date_format(
        o.order_purchase_timestamp, '%Y-%m'
    ) as purchase_year_month,

    o.order_status,

    case
        when o.order_status in ('canceled', 'unavailable')
        then 0 else 1
    end as is_valid_order,

    -- 是否跨州
    case
        when s.seller_state is null
          or c.customer_state is null
        then null
        when s.seller_state <> c.customer_state
        then 1
        else 0
    end as is_cross_state

from order_items oi

join orders o
    on oi.order_id = o.order_id

join customers c
    on o.customer_id = c.customer_id

left join products p
    on oi.product_id = p.product_id

left join product_category_name_translation pt
    on p.product_category_name = pt.product_category_name

left join sellers s
    on oi.seller_id = s.seller_id;