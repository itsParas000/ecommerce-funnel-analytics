-- Create Reporting View
CREATE OR REPLACE VIEW `ecommerce-funnel-conversion.ecommerce_analytics.vw_funnel_reporting` AS
SELECT
  -- Fact Measures & Identifiers
  f.event_timestamp,
  f.event_datetime_utc,
  f.event_date,
  f.user_pseudo_id,
  f.ga_session_id,
  f.unique_session_id,
  f.event_name,
  f.purchase_revenue_usd,
  f.total_item_quantity,

  -- Device Dimension Attributes
  d.device_category,
  d.operating_system,
  d.browser,

  -- Traffic Source Dimension Attributes
  t.traffic_source,
  t.traffic_medium,
  t.campaign_name,

  -- User Dimension Attributes
  u.first_seen_at_utc,
  u.country,
  u.city,
  u.first_traffic_source,
  u.first_traffic_medium

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