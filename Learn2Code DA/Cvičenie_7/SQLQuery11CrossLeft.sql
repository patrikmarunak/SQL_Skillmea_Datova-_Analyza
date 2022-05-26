SELECT c.Customer_ID, p.Product_ID, COUNT(o.Order_ID) AS PocetObj
FROM [csv].[Product] p
CROSS JOIN [csv].[Customer] c
LEFT JOIN [csv].[Order] o
ON c.Customer_ID = o.Customer_ID AND p.Product_ID = o.Product_ID
GROUP BY c.Customer_ID, p.Product_ID
ORDER BY c.Customer_ID