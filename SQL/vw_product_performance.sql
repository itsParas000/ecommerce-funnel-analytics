CREATE OR REPLACE VIEW `ecommerce-funnel-conversion.ecommerce_analytics.vw_product_performance` AS
WITH product_metrics AS (
  SELECT
    -- Primary Product Identifiers
    COALESCE(NULLIF(item_name, '(not set)'), item_id) AS product_name,
    MAX(NULLIF(item_id, '(not set)')) AS primary_item_id,
    MAX(NULLIF(item_brand, '(not set)')) AS item_brand,
    MAX(NULLIF(item_category, '(not set)')) AS item_category,

    -- Funnel progression per product
    COUNT(DISTINCT CASE WHEN event_name = 'view_item' THEN unique_session_id END) AS item_views,
    COUNT(DISTINCT CASE WHEN event_name = 'add_to_cart' THEN unique_session_id END) AS item_cart_adds,
    COUNT(DISTINCT CASE WHEN event_name = 'begin_checkout' THEN unique_session_id END) AS item_checkouts,
    COUNT(DISTINCT CASE WHEN event_name = 'purchase' THEN unique_session_id END) AS item_purchases,

    -- Volume and financial totals
    SUM(CASE WHEN event_name = 'purchase' THEN quantity ELSE 0 END) AS units_sold,
    ROUND(SUM(CASE WHEN event_name = 'purchase' THEN item_revenue_usd ELSE 0.0 END), 2) AS total_item_revenue,

    -- Average selling price
    ROUND(AVG(CASE WHEN event_name = 'purchase' AND quantity > 0 THEN item_price_usd END), 2) AS avg_item_price
  FROM
    `ecommerce-funnel-conversion.ecommerce_analytics.stg_clean_order_items`
  WHERE
    item_name IS NOT NULL 
    AND item_name NOT IN ('(not set)', '')
  GROUP BY
    1
)

SELECT
  primary_item_id AS item_id,
  product_name AS item_name,
  COALESCE(item_brand, 'Generic') AS item_brand,
  COALESCE(item_category, 'General') AS item_category,
  item_views,
  item_cart_adds,
  item_purchases,
  units_sold,
  avg_item_price,
  total_item_revenue,

  -- Key Merchandising Ratios
  -- 1. Cart-to-Detail Rate: How often a product detail view leads to a cart add
  ROUND(
    SAFE_DIVIDE(item_cart_adds, item_views) * 100, 
    2
  ) AS cart_to_detail_rate_pct,

  -- 2. Item Conversion Rate: How often a product view leads to a purchase
  ROUND(
    SAFE_DIVIDE(item_purchases, item_views) * 100, 
    2
  ) AS item_cvr_pct,

  -- 3. Product Abandonment Volume: Carts that never converted for this specific item
  GREATEST(item_cart_adds - item_purchases, 0) AS abandoned_item_sessions
FROM
  product_metrics;



-- verify records 
SELECT
  item_name,
  item_category,
  item_views,
  item_cart_adds,
  item_purchases,
  cart_to_detail_rate_pct,
  item_cvr_pct,
  total_item_revenue
FROM
  `ecommerce-funnel-conversion.ecommerce_analytics.vw_product_performance`
ORDER BY
  total_item_revenue DESC
LIMIT 10;



-- fetch item name and id
SELECT
  event_name,
  COUNT(1) AS total_rows,
  COUNT(DISTINCT unique_session_id) AS distinct_sessions,
  COUNTIF(item_name IS NOT NULL AND item_name != '(not set)') AS rows_with_item_name,
  COUNTIF(item_id IS NOT NULL AND item_id != '(not set)') AS rows_with_item_id
FROM
  `ecommerce-funnel-conversion.ecommerce_analytics.stg_clean_order_items`
GROUP BY
  event_name;