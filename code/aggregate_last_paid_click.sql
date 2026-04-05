WITH last_paid_visits AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY s.visitor_id
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM sessions AS s
    WHERE s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

last_paid AS (
    SELECT
        visitor_id,
        visit_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign
    FROM last_paid_visits
    WHERE rn = 1
),

joined AS (
    SELECT
        lp.visitor_id,
        lp.visit_date,
        lp.utm_source,
        lp.utm_medium,
        lp.utm_campaign,
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM last_paid AS lp
    LEFT JOIN leads AS l
        ON lp.visitor_id = l.visitor_id
),

ad_costs AS (
    SELECT
        campaign_date AS cost_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM (
        SELECT campaign_date, utm_source, utm_medium, utm_campaign, daily_spent
        FROM ya_ads
        UNION ALL
        SELECT campaign_date, utm_source, utm_medium, utm_campaign, daily_spent
        FROM vk_ads
    ) AS combined_ads
    GROUP BY campaign_date, utm_source, utm_medium, utm_campaign
),

aggregated AS (
    SELECT
        j.visit_date,
        j.utm_source,
        j.utm_medium,
        j.utm_campaign,
        COUNT(DISTINCT j.visitor_id) AS visitors_count,
        COUNT(j.lead_id) AS leads_count,
        COUNT(
            CASE
                WHEN j.closing_reason = 'Completado con éxito'
                    OR j.status_id = 142
                    THEN 1
            END
        ) AS purchases_count,
        SUM(
            CASE
                WHEN j.closing_reason = 'Completado con éxito'
                    OR j.status_id = 142
                    THEN j.amount
                ELSE 0
            END
        ) AS revenue
    FROM joined AS j
    GROUP BY j.visit_date, j.utm_source, j.utm_medium, j.utm_campaign
)

SELECT
    a.visit_date,
    a.visitors_count,
    a.utm_source,
    a.utm_medium,
    a.utm_campaign,
    COALESCE(ac.total_cost, 0) AS total_cost,
    a.leads_count,
    a.purchases_count,
    a.revenue
FROM aggregated AS a
LEFT JOIN ad_costs AS ac
    ON a.visit_date = ac.cost_date
    AND a.utm_source = ac.utm_source
    AND a.utm_medium = ac.utm_medium
    AND a.utm_campaign = ac.utm_campaign
ORDER BY a.visit_date, a.utm_source, a.utm_medium, a.utm_campaign;
