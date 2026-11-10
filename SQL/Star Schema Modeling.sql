-- Create dim_devices Dimension Table
CREATE OR REPLACE TABLE `ecommerce-funnel-conversion.ecommerce_analytics.dim_devices` AS
SELECT
  FARM_FINGERPRINT(CONCAT(
    IFNULL(device_category, ''), '|',
    IFNULL(operating_system, ''), '|',
    IFNULL(browser, '')
  )) AS device_id,
  device_category,
  operating_system,
  browser
FROM
  `ecommerce-funnel-conversion.ecommerce_analytics.stg_clean_events`
GROUP BY
  device_category,
  operating_system,
  browser;


-- Create dim_traffic_sources Dimension Table
CREATE OR REPLACE TABLE `ecommerce-funnel-conversion.ecommerce_analytics.dim_traffic_sources` AS
SELECT
  FARM_FINGERPRINT(CONCAT(
    IFNULL(traffic_source, ''), '|',
    IFNULL(traffic_medium, ''), '|',
    IFNULL(campaign_name, '')
  )) AS traffic_id,
  traffic_source,
  traffic_medium,
  campaign_name
FROM
  `ecommerce-funnel-conversion.ecommerce_analytics.stg_clean_events`
GROUP BY
  traffic_source,
  traffic_medium,
  campaign_name;


-- Create dim_users Dimension Table
CREATE OR REPLACE TABLE `ecommerce-funnel-conversion.ecommerce_analytics.dim_users` AS
SELECT
  user_pseudo_id,
  MIN(event_datetime_utc) AS first_seen_at_utc,
  -- Take earliest known country and acquisition channel
  ARRAY_AGG(country IGNORE NULLS ORDER BY event_timestamp ASC LIMIT 1)[OFFSET(0)] AS country,
  ARRAY_AGG(city ORDER BY event_timestamp ASC LIMIT 1)[OFFSET(0)] AS city,
  ARRAY_AGG(traffic_source IGNORE NULLS ORDER BY event_timestamp ASC LIMIT 1)[OFFSET(0)] AS first_traffic_source,
  ARRAY_AGG(traffic_medium IGNORE NULLS ORDER BY event_timestamp ASC LIMIT 1)[OFFSET(0)] AS first_traffic_medium
FROM
  `ecommerce-funnel-conversion.ecommerce_analytics.stg_clean_events`
GROUP BY
  user_pseudo_id;




-- Create fact_events Central Fact Table
CREATE OR REPLACE TABLE `ecommerce-funnel-conversion.ecommerce_analytics.fact_events` AS
SELECT
  -- Primary Keys & Identifiers
  e.event_timestamp,
  e.event_datetime_utc,
  PARSE_DATE('%Y%m%d', e.event_date) AS event_date,
  e.user_pseudo_id,
  e.ga_session_id,
  e.unique_session_id,
  
  -- Foreign Keys linking to Dimensions
  FARM_FINGERPRINT(CONCAT(
    IFNULL(e.device_category, ''), '|',
    IFNULL(e.operating_system, ''), '|',
    IFNULL(e.browser, '')
  )) AS device_id,
  
  FARM_FINGERPRINT(CONCAT(
    IFNULL(e.traffic_source, ''), '|',
    IFNULL(e.traffic_medium, ''), '|',
    IFNULL(e.campaign_name, '')
  )) AS traffic_id,

  -- Event Measures & Funnel Milestones
  e.event_name,
  e.purchase_revenue_usd,
  e.total_item_quantity

FROM
  `ecommerce-funnel-conversion.ecommerce_analytics.stg_clean_events` AS e;



-- Audit Star Schema Foreign Key Integrity
SELECT
  COUNT(*) AS total_fact_rows,
  COUNT(DISTINCT f.user_pseudo_id) AS fact_unique_users,
  COUNTIF(d.device_id IS NULL) AS unmapped_device_keys,
  COUNTIF(t.traffic_id IS NULL) AS unmapped_traffic_keys,
  COUNTIF(u.user_pseudo_id IS NULL) AS unmapped_user_keys
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
  ON f.user_pseudo_id = u.user_pseudo_id;

  