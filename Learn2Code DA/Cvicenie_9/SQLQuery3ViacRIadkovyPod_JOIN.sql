SELECT o.Order_ID
		,o.Quantity
		,p.Unit_Price
		,p.Product_ID
		,o.Quantity * p.Unit_Price AS CenaObj

		,(SELECT AVG(o.Quantity * p.Unit_Price) 
		FROM [csv].[Order] o
		LEFT JOIN [csv].[Product] p
		ON o.Product_ID = p.Product_ID) AS PriemCenaObj

		,o.Quantity * p.Unit_Price - 
			(SELECT AVG(o.Quantity * p.Unit_Price) 
			FROM [csv].[Order] o
			LEFT JOIN [csv].[Product] p
			ON o.Product_ID = p.Product_ID) AS RozdielCenyObj
FROM [csv].[Order] o
LEFT JOIN [csv].[Product] p
ON o.Product_ID = p.Product_ID

