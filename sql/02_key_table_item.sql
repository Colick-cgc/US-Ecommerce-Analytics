CREATE OR REPLACE VIEW vw_fact_order_item AS

SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,

    -- 订单商品金额
    oi.price AS item_price,
    oi.freight_value,

    -- 商品信息
    p.product_category_name,
    p.product_name,
    p.product_brand,
    p.cost AS product_cost,
    p.price AS product_list_price,

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
    DATE_FORMAT(
        o.order_purchase_timestamp, '%Y-%m'
    ) AS purchase_year_month,

    o.order_status,

    CASE
        WHEN o.order_status IN ('canceled', 'unavailable')
        THEN 0
        ELSE 1
    END AS is_valid_order,

    -- 是否跨州
    CASE
        WHEN s.seller_state IS NULL
          OR c.customer_state IS NULL
        THEN NULL
        WHEN s.seller_state <> c.customer_state
        THEN 1
        ELSE 0
    END AS is_cross_state

FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN customers c
    ON o.customer_id = c.customer_id
LEFT JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id;