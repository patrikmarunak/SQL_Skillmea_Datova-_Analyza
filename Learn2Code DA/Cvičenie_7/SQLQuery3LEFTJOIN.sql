SELECT o.Order_ID, o.Order_Date, 
		o.Customer_ID, o.Quantity, 
		o.Product_ID, c.Customer_ID,
		c.Gender, c.City
FROM [csv].[Order] o
LEFT JOIN [csv].[Customer] c
ON o.Customer_ID = c.Customer_ID