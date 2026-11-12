CREATE OR REPLACE TABLE `ecommerce-funnel-conversion.ecommerce_analytics.stg_clean_order_items` AS
SELECT
  -- Session & Event Keys
  CONCAT(user_pseudo_id, '-', CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)) AS unique_session_id,
  user_pseudo_id,
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  TIMESTAMP_MICROS(event_timestamp) AS event_timestamp_utc,
  event_name,

  -- Item / Product Fields
  item.item_id,
  item.item_name,
  item.item_brand,
  item.item_category,
  item.item_category2,
  
  -- Metrics
  COALESCE(item.quantity, 1) AS quantity,
  COALESCE(item.price_in_usd, item.price, 0.0) AS item_price_usd,
  COALESCE(item.item_revenue_in_usd, item.price_in_usd * item.quantity, 0.0) AS item_revenue_usd

FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
  UNNEST(items) AS item
WHERE
  _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')
  AND item.item_name IS NOT NULL
  AND item.item_name NOT IN ('(not set)', '');