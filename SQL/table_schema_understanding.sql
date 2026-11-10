-- Audit Funnel Event Volume & Timestamp Sequence
-- Verify volume of all 5 funnel events and confirm chronological ordering using event_timestamp across full 3 months
SELECT
  event_name,
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_pseudo_id) AS unique_users,
  TIMESTAMP_MICROS(MIN(event_timestamp)) AS earliest_event_time_utc,
  TIMESTAMP_MICROS(MAX(event_timestamp)) AS latest_event_time_utc
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
GROUP BY event_name
ORDER BY total_events DESC;



-- Verify Session ID Extraction & Timestamp Integrity
SELECT
  COUNT(*) AS total_session_starts,
  COUNT(
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id')
    ) AS valid_session_ids,
  ROUND(
    SAFE_DIVIDE(
      COUNT((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id')),
      COUNT(*)
    )* 100, 
    2
  ) AS session_id_fill_rate_pct,
  COUNT(DISTINCT CONCAT(
    user_pseudo_id,
    '-',
    CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
  )) AS unique_total_sessions
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'session_start';
  


-- Verify Purchase Chronology & Revenue Integrity
SELECT
  COUNT(*) total_purchases,
  COUNT(DISTINCT user_pseudo_id) AS paying_customers,
  COUNT(ecommerce.purchase_revenue_in_usd) AS purchases_with_revenue,
  ROUND(SUM(ecommerce.purchase_revenue_in_usd), 2) AS total_revenue_usd,
  ROUND(AVG(ecommerce.purchase_revenue_in_usd), 2) AS avg_order_value_usd,
  TIMESTAMP_MICROS(MIN(event_timestamp)) AS first_purchase_time_utc,
  TIMESTAMP_MICROS(MAX(event_timestamp)) AS last_purchase_time_utc
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase';




-- Check Chronological User Session Path
SELECT
  user_pseudo_id,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
  event_name,
  event_timestamp,
  TIMESTAMP_MICROS(event_timestamp) AS event_time_utc
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name IN ('session_start', 'view_item', 'add_to_cart', 'begin_checkout', 'purchase')
ORDER BY
  event_timestamp ASC
LIMIT 20;








