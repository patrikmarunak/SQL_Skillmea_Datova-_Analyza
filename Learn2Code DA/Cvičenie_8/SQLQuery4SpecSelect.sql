SELECT 'Priemer zo zaplatenych objenavok' AS PopisVypoctu, AVG(o.Quantity * p.Unit_Price ) AS SumaObj
FROM [csv].[Order] o
LEFT JOIN [csv].[Product] p
ON o.Product_ID = p.Product_ID
LEFT JOIN [csv].[OrderStatus] s
ON o.Order_Status = s.OrderStatus_ID
WHERE p.Currency = 'CZK' AND s.OrderStatus_Name = 'unpaid'


UNION

SELECT 'Priemer zo zaplatenych objenavok' AS PopisVypoctu, AVG(o.Quantity * p.Unit_Price ) AS SumaObj
FROM [csv].[Order] o
LEFT JOIN [csv].[Product] p
ON o.Product_ID = p.Product_ID
LEFT JOIN [csv].[OrderStatus] s
ON o.Order_Status = s.OrderStatus_ID
WHERE p.Currency = 'CZK' AND s.OrderStatus_Name = 'paid'
