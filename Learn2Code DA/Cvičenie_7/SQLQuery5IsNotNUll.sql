SELECT o.Order_ID, o.Order_Date
		, o.Customer_ID, o.Quantity
		, o.Product_ID
		,c.Gender, c.City
		,p.Product_Category
FROM [csv].[Order] o
INNER JOIN [csv].[Customer] c
ON o.Customer_ID = c.Customer_ID
INNER JOIN [csv].[Product] p
ON o.Product_ID = p.Product_ID
WHERE c.Gender IS NOT NULL AND c.City IS NOT NULL