-- Change overtime analysis
select datetrunc(month, order_date) as order_date, 
sum(sales_amount) as total_sales,
sum(distinct customer_key) as total_customers 
from gold.fact_sales 
where order_date is not null group by datetrunc(month, order_date)
order by datetrunc(month, order_date)
/*
Cumulative analysis 
Aggregate the data progressively overtime to understand whether our business is growing or declining
*/
select order_date, total_sales,
sum(avg_price) over(order by order_date rows between unbounded preceding and current row) as moving_average_price,
sum(total_sales) over(order by order_date rows between unbounded preceding and current row) as running_total_sales from
(
select datetrunc(year, order_date) as order_date, 
sum(sales_amount) as total_sales,
avg(price) as avg_price
from gold.fact_sales 
where order_date is not null group by datetrunc(year, order_date)
) t

/*
Performance analysis 
Comparing a current value to a target value and this helps to measure the success
*/
-- Analyze the yearly performance of products by comparing their sales to both 
-- the average sales performance of the current and the previous years's sales
with yearly_product_sales as
(
select year(f.order_date) as order_year, p.product_name, sum(f.sales_amount) as current_sales from 
gold.fact_sales f left join gold.dim_products p on f.product_key = p.product_key
where f.order_date is not null
group by year(f.order_date), p.product_name
)
select order_year, product_name, current_sales,
avg(current_sales) over (partition by product_name) as avg_sales,
current_sales - avg(current_sales) over (partition by product_name) as avg_sales,
case when current_sales - avg(current_sales) over (partition by product_name) < 0 then 'Below avg'
     when current_sales - avg(current_sales) over (partition by product_name) > 0 then 'Above avg'
     else 'avg'
end avg_change,
-- Year over year analysis
lag(current_sales) over (partition by product_name order by order_year) as prev_year_sales,
current_sales - lag(current_sales) over (partition by product_name order by order_year) as prev_year_diff,
case when current_sales - lag(current_sales) over (partition by product_name order by order_year) < 0 then 'Decreasing'
     when current_sales - lag(current_sales) over (partition by product_name order by order_year) > 0 then 'Increasing'
     else 'No change'
end prev_year_change
from yearly_product_sales order by product_name, order_year 

/*
Part-to-whole analysis 
Analyze how an individual category performs compared to the overall
*/
-- Which category contribute most to the whole sales ?
with category_sales as (
select p.category, sum(f.sales_amount) as total_category_sales from gold.fact_sales f inner join gold.dim_products p 
on f.product_key = p.product_key
group by p.category
)

select category, total_category_sales,
concat(round((cast(total_category_sales as float) / sum (total_category_sales) over())*100,2), '%') as Percentage_of_total
from category_sales
order by total_category_sales desc

/*
Data segmentation 
Group the data based on a specific range.
Helps understand the correlation between two measures.
*/

-- Segment products into cost ranges and count how many products falls into each segment
with product_segment as (
select product_key, product_name, cost ,
case when cost < 100 then 'Below 100'
    when cost between 100 and 500 then '100-500'
    when cost between 500 and 1000 then '500-1000'
    else 'Above 1000'
end cost_range
from gold.dim_products
)
select cost_range, count(product_key) as total_products  from product_segment group by cost_range order by total_products desc

/*
Grouping customers into three segments based on their spending behavior:
	- VIP: Customers with at least 12 months of history and spending more than 5,000.
	- Regular: Customers with at least 12 months of history but spending 5,000 or less.
	- New: Customers with a lifespan less than 12 months.
to find the total number of customers by each group
*/
with customer_spending as (
select c.customer_key, 
sum(f.sales_amount) as total_spending,
min(order_date) as first_order, 
max(order_date) as last_order,
datediff(month, min(order_date),max(order_date)) as lifespan
from gold.fact_sales f inner join gold.dim_customers c on f.customer_key = c.customer_key 
group by c.customer_key
)
select customer_segment, count(customer_key) from 
(
select customer_key, total_spending, lifespan,
case when lifespan >= 12 and total_spending >=5000 then 'VIP'
    when lifespan >= 12 and total_spending <=5000 then 'Regular'
    else 'new'
    end customer_segment
from customer_spending
) t
group by customer_segment

/*
Customer report
1. Gathers essential fields such as names, ages, and transaction details.
2. Segments customers into categories (VIP, Regular, New) and age groups.
3. Aggregates customer-level metrics:
	- total orders
	- total sales
	- total quantity purchased
	- total products
	- lifespan (in months)
4. Calculates valuable KPIs:
	- recency (months since last order)
	- average order value
	- average monthly spend
*/
create view customer_report as
with base_query as (
-- 1. Gathers essential fields such as names, ages, and transaction details.

select f.order_number, f.product_key , f.order_date, f.sales_amount, f.quantity ,
c.customer_key, c.customer_number, concat(c.first_name,' ', c.last_name) as customer_name, datediff(year, c.birthdate, getdate()) age

from gold.fact_sales f inner join gold.dim_customers c
on f.customer_key = c.customer_key
where order_date is not null
)
, customer_aggregation as (
-- 3. Aggregates customer-level metrics

select customer_key, customer_number, customer_name,age,
count(distinct order_number) as total_orders, 
count(distinct product_key) as total_products, 
sum(sales_amount) as total_sales, 
sum(quantity) as total_quantity, 
min(order_date) as first_order,
max(order_date) as last_order,
datediff(month, min(order_date), max(order_date)) as lifespan

from base_query
group by customer_key, customer_number, customer_name, age
)
select customer_key, customer_number, customer_name, age,
case when age <20 then 'Under 20'
    when age between 20 and 29 then '20-29'
    when age between 30 and 39 then '30-39'
    when age between 40 and 49 then '40-49'
    else '50 and above'
end as age_group,
case when lifespan >= 12 and total_sales >=5000 then 'VIP'
    when lifespan >= 12 and total_sales <=5000 then 'Regular'
    else 'new'
    end customer_segment,
total_orders, 
total_products, 
total_sales, 
total_quantity, 
first_order,
last_order,
datediff(month, last_order, GETDATE()) as recency,

lifespan,
case when total_orders =0 then 0
     else total_sales / total_orders 
end as avg_order,
case when lifespan =0 then 0
     else total_sales / lifespan 
end as avg_monthly_spend

from customer_aggregation


/*
Product Report
1. Gathers essential fields such as product name, category, subcategory, and cost.
2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
3. Aggregates product-level metrics:
    - total orders
    - total sales
    - total quantity sold
    - total customers (unique)
    - lifespan (in months)
4. Calculates valuable KPIs:
    - recency (months since last sale)
    - average order revenue (AOR)
    - average monthly revenue
*/
create or alter view gold.product_report 
as

with product_sales_base_query as (
select p.product_key,p.product_name, p.cost,f.price, p.category, p.subcategory , f.customer_key,f.order_number,f.quantity, f.sales_amount, f.order_date
from gold.fact_sales f inner join gold.dim_products p on f.product_key = p.product_key
where f.order_date is not null
) , product_aggregation as (
select 
product_key, product_name,
sum(quantity) as total_quantity,
count(distinct customer_key) as total_customers,
count(distinct order_number) total_orders,
sum(sales_amount) as total_sales,
max(order_date) as last_order_date,
datediff(month, min(order_date),max(order_date)) as product_lifespan

from product_sales_base_query
group by product_key,product_name
)
select 
product_key, product_name, 
total_quantity,
total_customers,
total_orders,
total_sales,
last_order_date,
product_lifespan,
datediff(month, last_order_date, getdate()) as recency,
case when total_sales > 50000 then 'High performance'
    when total_sales between 30000 and 50000 then 'Mid performance'
    else 'Low performance'
    end as product_segmentation,
case when total_orders = 0 then 0
    else total_sales / total_orders 
end as avg_order_revenue,

case when product_lifespan = 0 then 0
    else total_sales / product_lifespan 
end as avg_monthly_revenue

from
product_aggregation;