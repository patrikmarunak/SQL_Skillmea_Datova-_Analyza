SELECT 	 c.Gender
		,p.Product_Category
		,SUM(o.Quantity) AS SumaPoloziek
		,COUNT(o.Quantity) AS PocetObj
FROM [csv].[Order] o
INNER JOIN [csv].[Customer] c
ON o.Customer_ID = c.Customer_ID
INNER JOIN [csv].[Product] p
ON o.Product_ID = p.Product_ID
WHERE c.Gender IS NOT NULL AND c.City IS NOT NULL
GROUP BY p.Product_Category, c.Gender
ORDER BY c.Gender