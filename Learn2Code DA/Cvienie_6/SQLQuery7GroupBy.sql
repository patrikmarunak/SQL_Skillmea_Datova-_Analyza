SELECT Quantity AS Mnozstvo, COUNT(Product_ID) AS Times_Ordered
FROM [csv].[Order]
GROUP BY Quantity
ORDER BY Times_Ordered DESC