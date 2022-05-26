SELECT o.Order_ID
		,o.Product_ID
		,o.Quantity
		,p.Unit_Price
		,p.Currency
		,(o.Quantity * p.Unit_Price) AS SumaObj
		,e.ExchangeRate
		,(o.Quantity * p.Unit_Price) * (e.ExchangeRate) AS SumaObjCZK
FROM [csv].[Order] o
INNER JOIN [csv].[Product] p
ON o.Product_ID = p.Product_ID
INNER JOIN [csv].[Exchange_Rate] e
ON p.Currency = e.Currency_1