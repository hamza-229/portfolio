-- 1. Establish the rela onship between the tables as per the ER diagram. 

alter table OrderList add constraint pk_orderid primary key (OrderID)

alter table EachOrderBreakdown add constraint fk_orderid foreign key (OrderID) references OrderList (OrderID)

select * from OrderList
select * from EachOrderBreakdown
-- 2. Split City State Country into 3 individual columns namely ‘City’, ‘State’, ‘Country’. 

alter table OrderList add City nvarchar(50), State nvarchar(50), Country nvarchar(50)

update OrderList set Country = parsename(replace(City_State_Country, ',','.'),1),
State = parsename(replace(City_State_Country, ',','.'),2),
City = parsename(replace(City_State_Country, ',','.'),3)

alter table OrderList drop column City_State_country

/*
3. Add a new Category Column using the following mapping as per the first 3 characters in the 
Product Name Column:  
a. TEC- Technology 
b. OFS – Office Supplies 
c. FUR - Furniture 
*/
alter table EachOrderBreakdown add Category nvarchar(50)

update EachOrderBreakdown set Category = case when left(ProductName, 3) = 'OFS' then 'Office supplies'
											when left(ProductName, 3) = 'FUR' then 'Furniture'
											when left(ProductName, 3) = 'TEC' then 'Technology'
										end
-- 4. Extract Characters after '-'
update EachOrderBreakdown set ProductName = right (ProductName, len(ProductName) - CHARINDEX('-',ProductName))

-- 5. Remove duplicate rows

with cte_duplicate as (
select *, ROW_NUMBER() OVER(partition by OrderID, ProductName, Discount, Sales, Profit, Quantity, SubCategory, Category Order by OrderID) as rn
from EachOrderBreakdown
)
delete from cte_duplicate where rn > 1

-- 6. Replace blank with NA in OrderPriority Column in OrdersList table  
update OrderList set OrderPriority = 'NA' where OrderPriority is null