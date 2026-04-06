-- ============================================
-- RFM CUSTOMER SEGMENTATION
-- Brazilian E-Commerce — Olist
-- Author: Simón Segovia
-- Description: Recency, Frequency and Monetary
--              analysis for customer segmentation
-- ============================================

-- 1. Reference Date (last order in dataset)
SELECT MAX(order_purchase_timestamp) AS last_date
FROM orders;

-- 2. Base RFM Calculation
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp)             AS last_purchase,
        COUNT(DISTINCT o.order_id)                  AS frequency,
        ROUND(SUM(op.payment_value)::numeric, 2)    AS monetary
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    EXTRACT(DAY FROM (
        '2018-08-29'::timestamp - last_purchase
    ))::int                                         AS recency_days,
    frequency,
    monetary
FROM rfm_base
ORDER BY monetary DESC
LIMIT 20;

-- 3. RFM Score Calculation
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        EXTRACT(DAY FROM (
            '2018-08-29'::timestamp - MAX(o.order_purchase_timestamp)
        ))::int                                     AS recency_days,
        COUNT(DISTINCT o.order_id)                  AS frequency,
        ROUND(SUM(op.payment_value)::numeric, 2)    AS monetary
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
    FROM rfm_base
)
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score)                   AS rfm_total
FROM rfm_scores
ORDER BY rfm_total DESC
LIMIT 20;

-- 4. Customer Segments
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        EXTRACT(DAY FROM (
            '2018-08-29'::timestamp - MAX(o.order_purchase_timestamp)
        ))::int                                     AS recency_days,
        COUNT(DISTINCT o.order_id)                  AS frequency,
        ROUND(SUM(op.payment_value)::numeric, 2)    AS monetary
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
    FROM rfm_base
)
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
            THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3
            THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2
            THEN 'Recent Customers'
        WHEN r_score >= 3 AND f_score <= 2 AND m_score >= 3
            THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3
            THEN 'At Risk'
        WHEN r_score <= 2 AND f_score >= 4
            THEN 'Cant Lose Them'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2
            THEN 'Lost'
        ELSE 'Needs Attention'
    END                                             AS segment
FROM rfm_scores
ORDER BY monetary DESC;

-- 5. Segment Summary
WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        EXTRACT(DAY FROM (
            '2018-08-29'::timestamp - MAX(o.order_purchase_timestamp)
        ))::int                                     AS recency_days,
        COUNT(DISTINCT o.order_id)                  AS frequency,
        ROUND(SUM(op.payment_value)::numeric, 2)    AS monetary
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
    FROM rfm_base
),
segments AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
                THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3
                THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2
                THEN 'Recent Customers'
            WHEN r_score >= 3 AND f_score <= 2 AND m_score >= 3
                THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3
                THEN 'At Risk'
            WHEN r_score <= 2 AND f_score >= 4
                THEN 'Cant Lose Them'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2
                THEN 'Lost'
            ELSE 'Needs Attention'
        END AS segment
    FROM rfm_scores
)
SELECT
    segment,
    COUNT(*)                                        AS total_customers,
    ROUND(AVG(recency_days)::numeric, 1)            AS avg_recency_days,
    ROUND(AVG(frequency)::numeric, 2)               AS avg_frequency,
    ROUND(AVG(monetary)::numeric, 2)                AS avg_monetary,
    ROUND(SUM(monetary)::numeric, 2)                AS total_revenue,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER()::numeric, 2) AS pct_customers
FROM segments
GROUP BY segment
ORDER BY total_revenue DESC;
