-- Create the destination dataset inside project ecommerce-funnel-conversion
CREATE SCHEMA IF NOT EXISTS `ecommerce-funnel-conversion.ecommerce_analytics`
OPTIONS(
  location = 'US'
);


-- Create Flattened Staging Table
-- Clean, unnest, and flatten raw GA4 event logs for the 5 core funnel actions
CREATE OR REPLACE TABLE `ecommerce-funnel-conversion.ecommerce_analytics.stg_clean_events` AS
SELECT
  -- Event Identifiers & Timestamps
  event_date,
  event_timestamp,
  TIMESTAMP_MICROS(event_timestamp) AS event_datetime_utc,
  event_name,

  -- User & Session Keys
  user_pseudo_id,(
    SELECT value.int_value
    FROM UNNEST(event_params)
    WHERE key = 'ga_session_id'
  ) AS ga_session_id,

  CONCAT(
    user_pseudo_id,
    '-',
    CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING) 
  ) AS unique_session_id,

  -- Device Dimension Attributes
  device.category AS device_category,
  device.operating_system AS operating_system,
  device.web_info.browser AS browser,

  -- Traffic Source Dimension Attributes
  COALESCE(NULLIF(traffic_source.source, ''), '(direct)') AS traffic_source,
  COALESCE(NULLIF(traffic_source.medium, ''), '(none)') AS traffic_medium,
  COALESCE(NULLIF(traffic_source.name, ''), '(not set)') AS campaign_name,

  -- Geography
  COALESCE(NULLIF(geo.country, ''), '(Unknown)') AS country,
  COALESCE(NULLIF(NULLIF(geo.city, '(not set)'), ''), '(Unknown)') AS city,

  -- Financial / Ecommerce Metrics
  COALESCE(ecommerce.purchase_revenue_in_usd, 0.0) AS purchase_revenue_usd,
  COALESCE(ecommerce.total_item_quantity, 0) AS total_item_quantity

FROM 
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name IN(
    'session_start',
    'view_item',
    'add_to_cart',
    'begin_checkout',
    'purchase'
  )

  -- Ensure session ID exists for clean session-level funnel tracking
  AND(
    SELECT value.int_value
    FROM UNNEST(event_params)
    WHERE key = 'ga_session_id'
  ) IS NOT NULL;



-- Verify Clean Staging Table Integrity
SELECT
  COUNT(*) AS total_clean_rows,
  COUNT(DISTINCT user_pseudo_id) AS unique_users,
  COUNT(DISTINCT unique_session_id) AS unique_sessions,
  COUNTIF(ga_session_id IS NULL) AS null_session_count,
  ROUND(SUM(purchase_revenue_usd), 2) AS total_revenue_usd
FROM
  `ecommerce-funnel-conversion.ecommerce_analytics.stg_clean_events`;
