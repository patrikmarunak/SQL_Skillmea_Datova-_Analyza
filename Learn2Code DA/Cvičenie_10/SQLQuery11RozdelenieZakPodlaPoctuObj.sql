SELECT c.Customer_ID
	,sub.PocetObjZak
	,CASE WHEN sub.PocetObjZak IS NULL THEN '0 objednavok'
		  WHEN sub.PocetObjZak = 1 THEN '1 objednavka'
		  WHEN sub.PocetObjZak BETWEEN 2 AND 50 THEN '2 - 50 objednavok'
		  WHEN sub.PocetObjZak BETWEEN 51 AND 100 THEN '51 - 100 objednavok'
		  WHEN sub.PocetObjZak > 100 THEN '100 + objednavok'
		  END AS SegmentPocetObj
FROM [Lekcia_1].[csv].[Customer] c
LEFT JOIN
(SELECT Customer_ID, COUNT(Order_ID) AS PocetObjZak
FROM [Lekcia_1].[csv].[Order]
GROUP BY Customer_ID) sub
ON c.Customer_ID = sub.Customer_ID
WHERE sub.PocetObjZak IS NOT NULL
ORDER BY sub.PocetObjZak 