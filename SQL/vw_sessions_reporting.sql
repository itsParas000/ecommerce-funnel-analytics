--view session level reporting
CREATE OR REPLACE VIEW `ecommerce-funnel-conversion.ecommerce_analytics.vw_sessions_reporting` AS
WITH session_events AS (
  SELECT
    f.unique_session_id,

    -- 1. Unified Date Anchor: aligns purchases across all views
    COALESCE(
      MAX(CASE WHEN f.event_name = 'purchase' THEN f.event_date END),
      MIN(f.event_date)
    ) AS event_date,

    MIN(f.event_datetime_utc) AS session_start_utc,
    
    -- Dimensional Attributes (taking the first non-null per session)
    ARRAY_AGG(f.user_pseudo_id IGNORE NULLS ORDER BY f.event_timestamp ASC LIMIT 1)[OFFSET(0)] AS user_pseudo_id,
    ARRAY_AGG(d.device_category IGNORE NULLS ORDER BY f.event_timestamp ASC LIMIT 1)[OFFSET(0)] AS device_category,
    ARRAY_AGG(d.operating_system IGNORE NULLS ORDER BY f.event_timestamp ASC LIMIT 1)[OFFSET(0)] AS operating_system,
    ARRAY_AGG(d.browser IGNORE NULLS ORDER BY f.event_timestamp ASC LIMIT 1)[OFFSET(0)] AS browser,
    
    ARRAY_AGG(t.traffic_source IGNORE NULLS ORDER BY f.event_timestamp ASC LIMIT 1)[OFFSET(0)] AS traffic_source,
    ARRAY_AGG(t.traffic_medium IGNORE NULLS ORDER BY f.event_timestamp ASC LIMIT 1)[OFFSET(0)] AS traffic_medium,
    ARRAY_AGG(t.campaign_name IGNORE NULLS ORDER BY f.event_timestamp ASC LIMIT 1)[OFFSET(0)] AS campaign_name,
    
    ARRAY_AGG(u.country IGNORE NULLS ORDER BY f.event_timestamp ASC LIMIT 1)[OFFSET(0)] AS country,
    ARRAY_AGG(u.city IGNORE NULLS ORDER BY f.event_timestamp ASC LIMIT 1)[OFFSET(0)] AS city,
    ARRAY_AGG(CONCAT(u.city, ', ', u.country) IGNORE NULLS ORDER BY f.event_timestamp ASC LIMIT 1)[OFFSET(0)] AS full_location,

    -- Milestone Booleans (1 if event occurred in this session, 0 if not)
    MAX(CASE WHEN f.event_name = 'session_start' THEN 1 ELSE 0 END) AS has_session_start,
    MAX(CASE WHEN f.event_name = 'view_item' THEN 1 ELSE 0 END) AS has_view_item,
    MAX(CASE WHEN f.event_name = 'add_to_cart' THEN 1 ELSE 0 END) AS has_cart,
    MAX(CASE WHEN f.event_name = 'begin_checkout' THEN 1 ELSE 0 END) AS has_checkout,
    MAX(CASE WHEN f.event_name = 'purchase' THEN 1 ELSE 0 END) AS has_purchase,

    -- Session Revenue
    SUM(COALESCE(f.purchase_revenue_usd, 0.0)) AS session_revenue
  FROM
    `ecommerce-funnel-conversion.ecommerce_analytics.fact_events` AS f
  LEFT JOIN
    `ecommerce-funnel-conversion.ecommerce_analytics.dim_devices` AS d
    ON f.device_id = d.device_id
  LEFT JOIN
    `ecommerce-funnel-conversion.ecommerce_analytics.dim_traffic_sources` AS t
    ON f.traffic_id = t.traffic_id
  LEFT JOIN
    `ecommerce-funnel-conversion.ecommerce_analytics.dim_users` AS u
    ON f.user_pseudo_id = u.user_pseudo_id
  GROUP BY
    f.unique_session_id
)

SELECT
  unique_session_id,
  user_pseudo_id,
  event_date,
  session_start_utc,
  device_category,
  operating_system,
  browser,
  traffic_source,
  traffic_medium,
  campaign_name,
  country,
  city,
  full_location,
  
  -- Milestone Flags
  has_session_start,
  has_view_item,
  has_cart,
  has_checkout,
  has_purchase,

  -- Realized Session Revenue
  session_revenue,

  -- Business Logic: Abandoned Cart Session Flag (Carted but never completed purchase)
  CASE WHEN has_cart = 1 AND has_purchase = 0 THEN 1 ELSE 0 END AS is_cart_abandoned,

  -- Business Logic: Dynamic Lost Revenue ($74.70 baseline AOV for every abandoned session)
  -- CASE WHEN has_cart = 1 AND has_purchase = 0 THEN 74.70 ELSE 0.0 END AS lost_pipeline_revenue

FROM
  session_events;




-- verify the results
SELECT 
  COUNT(1) AS total_rows,
  COUNT(DISTINCT unique_session_id) AS distinct_sessions,
  SUM(is_cart_abandoned) AS total_abandoned_flag,
  COUNT(DISTINCT CASE WHEN is_cart_abandoned = 1 THEN unique_session_id END) AS distinct_abandoned_sessions
FROM 
  `ecommerce-funnel-conversion.ecommerce_analytics.vw_sessions_reporting`;




-- only 2848 made purchase and 12340 are abandoned
SELECT
  COUNT(DISTINCT CASE WHEN has_cart = 1 THEN unique_session_id END) AS total_cart_sessions,
  COUNT(DISTINCT CASE WHEN has_cart = 1 AND has_purchase = 1 THEN unique_session_id END) AS cart_and_purchased_sessions,
  COUNT(DISTINCT CASE WHEN has_cart = 1 AND has_purchase = 0 THEN unique_session_id END) AS abandoned_cart_sessions
FROM
  `ecommerce-funnel-conversion.ecommerce_analytics.vw_sessions_reporting`;




-- verify purchases with cart vs without cart
SELECT
  COUNT(DISTINCT CASE WHEN has_purchase = 1 THEN unique_session_id END) AS total_purchase_sessions,
  COUNT(DISTINCT CASE WHEN has_purchase = 1 AND has_cart = 1 THEN unique_session_id END) AS purchases_with_cart,
  COUNT(DISTINCT CASE WHEN has_purchase = 1 AND has_cart = 0 THEN unique_session_id END) AS purchases_without_cart
FROM
  `ecommerce-funnel-conversion.ecommerce_analytics.vw_sessions_reporting`;

