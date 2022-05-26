SELECT * FROM
(SELECT TOP(3) Product_Name
		,Weight
		,'Najtazsie produkty' AS Popis
FROM [csv].[Product]
ORDER BY Weight DESC) a 


UNION ALL

SELECT * FROM
(SELECT TOP(3) Product_Name
		,Weight
		,'Najlahsie produkty' AS Popis
FROM [csv].[Product]
ORDER BY Weight) b
