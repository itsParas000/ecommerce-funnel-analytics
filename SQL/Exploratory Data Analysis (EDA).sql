-- Chronological Session Funnel Progression & Drop-off Rates
WITH session_event_timestamps AS (
  SELECT
    unique_session_id,
    user_pseudo_id,
    -- Earliest occurrence timestamp of each milestone per session
    MIN(CASE WHEN event_name = 'session_start' THEN event_timestamp END) AS t_session_start,
    MIN(CASE WHEN event_name = 'view_item' THEN event_timestamp END) AS t_view_item,
    MIN(CASE WHEN event_name = 'add_to_cart' THEN event_timestamp END) AS t_add_to_cart,
    MIN(CASE WHEN event_name = 'begin_checkout' THEN event_timestamp END) AS t_begin_checkout,
    MIN(CASE WHEN event_name = 'purchase' THEN event_timestamp END) AS t_purchase
  FROM
    `ecommerce-funnel-conversion.ecommerce_analytics.fact_events`
  GROUP BY
    unique_session_id,
    user_pseudo_id
),

chronological_funnel_flags AS (
  SELECT
    unique_session_id,
    user_pseudo_id,
    -- Step 1: Session initiated
    IF(t_session_start IS NOT NULL, 1, 0) AS step_1_session,
    -- Step 2: Item viewed after session start
    IF(t_view_item IS NOT NULL AND t_view_item >= t_session_start, 1, 0) AS step_2_view_item,
    -- Step 3: Item added to cart after viewing item
    IF(t_add_to_cart IS NOT NULL AND t_add_to_cart >= t_view_item, 1, 0) AS step_3_add_to_cart,
    -- Step 4: Checkout started after adding to cart
    IF(t_begin_checkout IS NOT NULL AND t_begin_checkout >= t_add_to_cart, 1, 0) AS step_4_checkout,
    -- Step 5: Purchase completed after initiating checkout
    IF(t_purchase IS NOT NULL AND t_purchase >= t_begin_checkout, 1, 0) AS step_5_purchase
  FROM
    session_event_timestamps
)

SELECT
  -- Session Volume across each funnel milestone
  SUM(step_1_session) AS s1_sessions,
  SUM(step_2_view_item) AS s2_view_item,
  SUM(step_3_add_to_cart) AS s3_add_to_cart,
  SUM(step_4_checkout) AS s4_begin_checkout,
  SUM(step_5_purchase) AS s5_purchase,

  -- End-to-End Funnel Conversion Rate (%)
  ROUND(SAFE_DIVIDE(SUM(step_5_purchase), SUM(step_1_session)) * 100, 2) AS overall_conversion_rate_pct,

  -- Stage-by-Stage Drop-Off Percentages (%)
  ROUND((1 - SAFE_DIVIDE(SUM(step_2_view_item), SUM(step_1_session))) * 100, 2) AS dropoff_session_to_view_pct,
  ROUND((1 - SAFE_DIVIDE(SUM(step_3_add_to_cart), SUM(step_2_view_item))) * 100, 2) AS dropoff_view_to_cart_pct,
  ROUND((1 - SAFE_DIVIDE(SUM(step_4_checkout), SUM(step_3_add_to_cart))) * 100, 2) AS dropoff_cart_to_checkout_pct,
  ROUND((1 - SAFE_DIVIDE(SUM(step_5_purchase), SUM(step_4_checkout))) * 100, 2) AS dropoff_checkout_to_purchase_pct
FROM
  chronological_funnel_flags;



-- Chronological Funnel Breakdown by Device Category
WITH session_device_timestamps AS (
  SELECT
    f.unique_session_id,
    d.device_category,
    MIN(CASE WHEN f.event_name = 'session_start' THEN f.event_timestamp END) AS t_session_start,
    MIN(CASE WHEN f.event_name = 'view_item' THEN f.event_timestamp END) AS t_view_item,
    MIN(CASE WHEN f.event_name = 'add_to_cart' THEN f.event_timestamp END) AS t_add_to_cart,
    MIN(CASE WHEN f.event_name = 'begin_checkout' THEN f.event_timestamp END) AS t_begin_checkout,
    MIN(CASE WHEN f.event_name = 'purchase' THEN f.event_timestamp END) AS t_purchase
  FROM
    `ecommerce-funnel-conversion.ecommerce_analytics.fact_events` AS f
  JOIN
    `ecommerce-funnel-conversion.ecommerce_analytics.dim_devices` AS d
    ON f.device_id = d.device_id
  GROUP BY
    f.unique_session_id,
    d.device_category
),

chronological_device_flags AS (
  SELECT
    device_category,
    IF(t_session_start IS NOT NULL, 1, 0) AS step_1_session,
    IF(t_view_item IS NOT NULL AND t_view_item >= t_session_start, 1, 0) AS step_2_view_item,
    IF(t_add_to_cart IS NOT NULL AND t_add_to_cart >= t_view_item, 1, 0) AS step_3_add_to_cart,
    IF(t_begin_checkout IS NOT NULL AND t_begin_checkout >= t_add_to_cart, 1, 0) AS step_4_checkout,
    IF(t_purchase IS NOT NULL AND t_purchase >= t_begin_checkout, 1, 0) AS step_5_purchase
  FROM
    session_device_timestamps
)

SELECT
  device_category,
  SUM(step_1_session) AS total_sessions,
  SUM(step_2_view_item) AS product_views,
  SUM(step_3_add_to_cart) AS cart_adds,
  SUM(step_4_checkout) AS checkouts_initiated,
  SUM(step_5_purchase) AS purchases,
  
  -- Overall Conversion Rate by Device
  ROUND(SAFE_DIVIDE(SUM(step_5_purchase), SUM(step_1_session)) * 100, 2) AS conversion_rate_pct,
  
  -- Stage Drop-offs by Device
  ROUND((1 - SAFE_DIVIDE(SUM(step_2_view_item), SUM(step_1_session))) * 100, 2) AS dropoff_session_to_view_pct,
  ROUND((1 - SAFE_DIVIDE(SUM(step_3_add_to_cart), SUM(step_2_view_item))) * 100, 2) AS dropoff_view_to_cart_pct,
  ROUND((1 - SAFE_DIVIDE(SUM(step_4_checkout), SUM(step_3_add_to_cart))) * 100, 2) AS dropoff_cart_to_checkout_pct,
  ROUND((1 - SAFE_DIVIDE(SUM(step_5_purchase), SUM(step_4_checkout))) * 100, 2) AS dropoff_checkout_to_purchase_pct
FROM
  chronological_device_flags
GROUP BY
  device_category
ORDER BY
  total_sessions DESC;




-- Chronological Funnel Breakdown by Traffic Medium
WITH session_traffic_timestamps AS (
  SELECT
    f.unique_session_id,
    t.traffic_medium,
    MIN(CASE WHEN f.event_name = 'session_start' THEN f.event_timestamp END) AS t_session_start,
    MIN(CASE WHEN f.event_name = 'view_item' THEN f.event_timestamp END) AS t_view_item,
    MIN(CASE WHEN f.event_name = 'add_to_cart' THEN f.event_timestamp END) AS t_add_to_cart,
    MIN(CASE WHEN f.event_name = 'begin_checkout' THEN f.event_timestamp END) AS t_begin_checkout,
    MIN(CASE WHEN f.event_name = 'purchase' THEN f.event_timestamp END) AS t_purchase
  FROM
    `ecommerce-funnel-conversion.ecommerce_analytics.fact_events` AS f
  JOIN
    `ecommerce-funnel-conversion.ecommerce_analytics.dim_traffic_sources` AS t
    ON f.traffic_id = t.traffic_id
  GROUP BY
    f.unique_session_id,
    t.traffic_medium
),

chronological_traffic_flags AS (
  SELECT
    traffic_medium,
    IF(t_session_start IS NOT NULL, 1, 0) AS step_1_session,
    IF(t_view_item IS NOT NULL AND t_view_item >= t_session_start, 1, 0) AS step_2_view_item,
    IF(t_add_to_cart IS NOT NULL AND t_add_to_cart >= t_view_item, 1, 0) AS step_3_add_to_cart,
    IF(t_begin_checkout IS NOT NULL AND t_begin_checkout >= t_add_to_cart, 1, 0) AS step_4_checkout,
    IF(t_purchase IS NOT NULL AND t_purchase >= t_begin_checkout, 1, 0) AS step_5_purchase
  FROM
    session_traffic_timestamps
)

SELECT
  traffic_medium,
  SUM(step_1_session) AS total_sessions,
  SUM(step_2_view_item) AS product_views,
  SUM(step_3_add_to_cart) AS cart_adds,
  SUM(step_4_checkout) AS checkouts_initiated,
  SUM(step_5_purchase) AS purchases,
  
  -- Channel Conversion Rate
  ROUND(SAFE_DIVIDE(SUM(step_5_purchase), SUM(step_1_session)) * 100, 2) AS conversion_rate_pct,
  
  -- Stage Drop-offs by Channel
  ROUND((1 - SAFE_DIVIDE(SUM(step_2_view_item), SUM(step_1_session))) * 100, 2) AS dropoff_session_to_view_pct,
  ROUND((1 - SAFE_DIVIDE(SUM(step_4_checkout), SUM(step_3_add_to_cart))) * 100, 2) AS dropoff_cart_to_checkout_pct
FROM
  chronological_traffic_flags
GROUP BY
  traffic_medium
ORDER BY
  total_sessions DESC;



-- Lost Revenue & Cart Abandonment Pipeline Sizing
WITH session_intent_status AS (
  SELECT
    unique_session_id,
    -- Session milestones
    MAX(IF(event_name = 'session_start', 1, 0)) AS has_session,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS has_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS has_checkout,
    MAX(IF(event_name = 'purchase', 1, 0)) AS has_purchase,
    -- Actual transaction revenue
    MAX(purchase_revenue_usd) AS revenue
  FROM
    `ecommerce-funnel-conversion.ecommerce_analytics.fact_events`
  GROUP BY
    unique_session_id
),

financial_metrics AS (
  SELECT
    ROUND(SAFE_DIVIDE(SUM(revenue), COUNTIF(has_purchase = 1)), 2) AS benchmark_aov,
    -- Sessions that added to cart but never purchased
    COUNTIF(has_cart = 1 AND has_purchase = 0) AS abandoned_cart_sessions,
    -- Sessions that made it all the way to checkout but never purchased
    COUNTIF(has_checkout = 1 AND has_purchase = 0) AS abandoned_checkout_sessions
  FROM
    session_intent_status
)

SELECT
  benchmark_aov AS average_order_value_usd,
  abandoned_cart_sessions,
  abandoned_checkout_sessions,

  -- Total Pipeline Revenue Lost to Cart Abandonment
  ROUND(abandoned_cart_sessions * benchmark_aov, 2) AS lost_cart_revenue_pipeline_usd,
  
  -- Total Pipeline Revenue Lost to Checkout Abandonment
  ROUND(abandoned_checkout_sessions * benchmark_aov, 2) AS lost_checkout_revenue_pipeline_usd,

  -- Realistic Recovery Projections (10% and 15% recovery rates)
  ROUND(abandoned_cart_sessions * benchmark_aov * 0.10, 2) AS recoverable_revenue_at_10pct_usd,
  ROUND(abandoned_cart_sessions * benchmark_aov * 0.15, 2) AS recoverable_revenue_at_15pct_usd
FROM
  financial_metrics;
