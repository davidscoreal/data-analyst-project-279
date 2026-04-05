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
)

SELECT
    lp.visitor_id,
    lp.visit_date,
    lp.utm_source,
    lp.utm_medium,
    lp.utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
FROM last_paid_visits AS lp
LEFT JOIN leads AS l
    ON lp.visitor_id = l.visitor_id
WHERE lp.rn = 1
ORDER BY
    lp.utm_source NULLS LAST,
    lp.visit_date,
    l.lead_id NULLS LAST;
