use EuroMartDB;
select * from EachOrderBreakdown
select * from OrderList
-- 1. List the top 10 orders with the highest sales from the EachOrderBreakdown table. 
select top 10 * from EachOrderBreakdown order by sales desc

-- 2. Show the number of orders for each product category in the EachOrderBreakdown table. 

select Category, count(*) as TotalOrders from  EachOrderBreakdown group by Category

-- 3. Find the total profit for each sub-category in the EachOrderBreakdown table. 

select SubCategory, sum(Profit) from  EachOrderBreakdown group by SubCategory

-- 4. Identify the customer with the highest total sales across all orders. 
select top 1 l.CustomerName, sum(o.sales) as TotalSales from EachOrderBreakdown o inner join OrderList l on o.OrderID = l.OrderID group by CustomerName order by TotalSales desc

-- 5. Find the month with the highest average sales in the OrdersList table. 
select top 1 month(l.OrderDate) as Month_Orders, avg(o.sales) as AverageSales from EachOrderBreakdown o inner join OrderList l on o.OrderID = l.OrderID group by month(l.OrderDate) order by AverageSales desc

-- 6. Find out the average quantity ordered by customers whose first name starts with an alphabet 's'? 
select avg(o.quantity) as Averagequantity from EachOrderBreakdown o inner join OrderList l on o.OrderID = l.OrderID where left(l.CustomerName, 1) = 's'

-- 7. Find out how many new customers were acquired in the year 2014?
select count(*) As NumberOfNewCustomers from (
select CustomerName, min(OrderDate) as first_order_date from OrderList group by CustomerName having year(min(OrderDate)) = '2014'
) as 2014NewCustomers

-- 8. Calculate the percentage of total profit contributed by each sub-category to the overall profit.
select SubCategory, sum(Profit) as TotalProfit,sum(Profit) /(select sum(Profit) from EachOrderBreakdown)*100 as ProfitPercent from EachOrderBreakdown group by SubCategory

-- 9. Find the average sales per customer, considering only customers who have made more than one order. 
select l.CustomerName, count(distinct o.OrderID) as Orders, avg(o.sales) as AvgSales from EachOrderBreakdown o inner join OrderList l on o.OrderID = l.OrderID group by CustomerName having count(distinct o.OrderID) > 2
-- 10. Identify the top-performing subcategory in each category based on total sales. Include the sub category name, total sales, and a ranking of sub-category within each category.
with TopPerformers as (
select Category, SubCategory, sum(Sales) as TotalSales ,
rank() over(partition by Category order by sum(Sales) desc) as SubCategoryRank
from EachOrderBreakdown group by Category, SubCategory
)
select * from TopPerformers where SubCategoryRank = 1