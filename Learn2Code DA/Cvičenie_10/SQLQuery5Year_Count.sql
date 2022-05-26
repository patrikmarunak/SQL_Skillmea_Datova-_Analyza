SELECT YEAR(o.Order_Date) AS Rok
	,s.OrderStatus_Name AS Stav
	,COUNT(o.Order_ID) AS PocetObj
FROM [Lekcia_1].[csv].[Order] o
LEFT JOIN [Lekcia_1].[csv].[OrderStatus] s
ON o.Order_Status = s.OrderStatus_ID
GROUP BY YEAR(o.Order_Date), s.OrderStatus_Name
ORDER BY Rok