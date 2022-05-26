SELECT TOP(5) YEAR(o.Order_Date) AS Rok
	,MONTH(o.Order_Date) AS Mesiac
	,COUNT(o.Order_ID) AS PocetObj
FROM [Lekcia_1].[csv].[Order] o
GROUP BY YEAR(o.Order_Date), MONTH(o.Order_Date)
ORDER BY PocetObj DESC