-- ==========================================================
-- CUSTOMER SEGMENTATION - RFM QUERIES
-- DATABASE: retail_segmentation
-- TABLES: online_retail | rfm_scores | rfm_segments
-- ==========================================================

-- ==========================================================
-- Q1: Row Count & Date Range
-- PURPOSE: Confirm the raw dataset loaded correctly and
-- 			understand the fulll time span of transactions.
-- ==========================================================

select
	count(*) as total_rows,
	min("InvoiceDate")::date as earliest_invoice,
	max("InvoiceDate")::date as latest_invoice,
	max("InvoiceDate")::date - min("InvoiceDate")::DATE as date_span_days
from online_retail t;

-- ==========================================================
-- Q2: Unique Customers & Countries
-- PURPOSE: Understand the breadth of the customer base
-- 			before segmentation
-- ==========================================================

select
	count(distinct "CustomerID") as unique_customers,
	count(distinct "Country") as unique_countries,
	count(distinct "StockCode") as unique_products
from online_retail t;

-- ==========================================================
-- Q3: Revenue by Country - Top 10
-- PURPOSE: Identify which markets generate the most revenue.
-- 			Informs where segmentation insights are most
-- 			valuable.
-- NOTE: Clean data only - nulls, cancellations and negative
-- 		 quantities excluded.
-- ==========================================================

select
	"Country",
	round(sum("Quantity" * "UnitPrice")::numeric, 2) as total_revenue,
	count(distinct "CustomerID") as customers
from online_retail t 
where
	t."CustomerID" is not null
	and t."InvoiceNo" not like 'C%'
	and t."Quantity" > 0
	and t."UnitPrice" > 0
group by "Country" 
order by total_revenue desc 
limit 10;

-- ==========================================================
-- Q4: Monthly Revenue Trend
-- PURPOSE: Identify seasonal patterns and revenue
--			trajectory across the 13-month window.
-- ==========================================================

select
	to_char(date_trunc('month', "InvoiceDate"), 'YYYY-MM') as year_month,
	round(SUM("Quantity" * "UnitPrice")::numeric, 2) as monthly_revenue,
	count(distinct "InvoiceNo") as invoices,
	count(distinct "CustomerID") as active_customers
from online_retail t 
where
	t."CustomerID" is not null
	and t."InvoiceNo"  not like 'C%'
	and t."Quantity" > 0
	and t."UnitPrice" > 0
group by date_trunc('month', t."InvoiceDate" )
order by date_trunc('month', t."InvoiceDate" );

-- ==========================================================
-- Q5: Top 20 Products by Revenue
-- PURPOSE: Identify which products drive the most value - 
--			useful for understanding what Champions are
--			buying.
-- ==========================================================

select
	"Description",
	round(sum("Quantity" * "UnitPrice")::numeric, 2) as total_revenue,
	sum("Quantity") as units_sold,
	count(distinct "CustomerID") as buying_customers
from online_retail t 
where
	t."CustomerID" is not null
	and t."InvoiceNo" not like 'C%'
	and t."Quantity" > 0
	and t."UnitPrice" > 0
	and t."Description" is not null
group by "Description" 
order by total_revenue desc
limit 20;

-- ==========================================================
-- Q6: Cancellation Rate by Country
-- PURPOSE: Identify which markets have the highest
-- 			proportion of cancelled orders - a signal of
-- 			dissatisfaction or fulfilment issues.
-- ==========================================================

select
	"Country",
	count(*) as total_transactions,
	sum(case when "InvoiceNo" like 'C%' then 1 else 0 end) as cancellations,
	round(sum(case when "InvoiceNo" like 'C%' then 1 else 0 end)::numeric / count(*) * 100, 2) as cancel_rate_pct
from online_retail t 
group by "Country" 
having count(*) > 100
order by total_transactions desc
limit 10;

-- ==========================================================
-- Q7: RFM Summary Statistics by Segment
-- PURPOSE: Validate cluster profiles and confirm segment
--			separation is meaningful and interpretable.
-- ==========================================================

select
	"Segment",
	count(*) as customers,
	round(avg("Recency")::numeric, 1) as avg_recency_days,
	round(avg("Frequency")::numeric, 2) as avg_frequency,
	round(avg("Monetary")::numeric, 2) as avg_monetary_gbp,
	round(sum("Monetary")::numeric, 2) as total_revenue_gbp
from rfm_segments rs 
group by rs."Segment" 
order by avg_monetary_gbp desc;

-- ==========================================================
-- Q8: Cluster Size Distribution
-- PURPOSE: Understand the proportion of customers in each
--			segment to assess business impact and priority.
-- ==========================================================

select
	"Segment",
	count(*) as customers,
	round(count(*) * 100 / sum(count(*)) over (), 1) as share_pct
from rfm_segments rs 
group by rs."Segment" 
order by customers desc;

-- ==========================================================
-- Q9: Champions Segment - High-Value Customer Profile
-- PURPOSE: Deep-dive into the most valuable customer group.
--			Champions represent 16.4% of customers but
--			contribute 64.9% of total segmented revenue.
-- ==========================================================

select
	s."Segment",
	count(*) as customers,
	round(avg(s."Recency")::numeric, 1) as avg_recency_days,
	round(avg(s."Frequency")::numeric, 1) as avg_frequency,
	round(avg(s."Monetary")::numeric, 2) as avg_monetary_gbp,
	round(sum(s."Monetary")::numeric, 2) as total_revenue_gbp,
	round(sum(s."Monetary"::numeric) * 100.0 / t.total_revenue, 2) as revenue_share_pct
from rfm_segments s
cross join (
	select sum("Monetary")::numeric as total_revenue
	from rfm_segments) t
where s."Segment" = 'Champions'
group by s."Segment", t.total_revenue;

-- ==========================================================
-- Q10: At-Risk Customer Identification
-- PURPOSE: Surface customers who were previously engaged
--			but have started to lapse - the highest-priority
--			retention target after champions.
-- ==========================================================

select
	s."Segment",
	count(*) as customers,
	round(avg(s."Recency")::numeric, 1) as avg_recency_days,
	round(avg(s."Frequency")::numeric, 1) as avg_frequency,
	round(avg(s."Monetary")::numeric, 2) as avg_monetary_gbp,
	round(sum(s."Monetary")::numeric, 2) as total_revenue_gbp,
	round(sum(s."Monetary"::numeric) * 100.0 / t.total_revenue, 2) as revenue_share_pct
from rfm_segments s
cross join (
	select sum("Monetary")::numeric as total_revenue
	from rfm_segments) t
where s."Segment" = 'At Risk'
group by s."Segment", t.total_revenue;