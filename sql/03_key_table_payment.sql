create or replace view vw_fact_payment as

select
    p.order_id,
    p.payment_sequential,
    p.payment_type,
    p.payment_installments,
    p.payment_value,

    -- 支付订单信息
    o.customer_id,
    c.customer_unique_id,
    o.order_status,
    o.order_purchase_timestamp,

    date_format(
        o.order_purchase_timestamp, '%Y-%m'
    ) as purchase_year_month,

    case
        when p.payment_sequential > 1
        then 1 else 0
    end as is_multiple_payment

from order_payments p

left join orders o
    on p.order_id = o.order_id

left join customers c
    on o.customer_id = c.customer_id;
