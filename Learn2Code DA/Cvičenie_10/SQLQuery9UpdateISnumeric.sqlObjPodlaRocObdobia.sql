SELECT CASE WHEN MONTH(Order_Date) IN (3, 4 ,5) THEN 'JAR'
			WHEN MONTH(Order_Date) IN (6, 7 ,8) THEN 'LETO'
			WHEN MONTH(Order_Date) IN (9, 10 ,11) THEN 'JESEN'
			WHEN MONTH(Order_Date) IN (12, 1 ,2) THEN 'ZIMA'
		END AS RocneObdobie
		,COUNT(*) AS PocetObj
FROM [Lekcia_1].[csv].[Order]
GROUP BY (CASE WHEN MONTH(Order_Date) IN (3, 4 ,5) THEN 'JAR'
		  WHEN MONTH(Order_Date) IN (6, 7 ,8) THEN 'LETO'
		  WHEN MONTH(Order_Date) IN (9, 10 ,11) THEN 'JESEN'
		  WHEN MONTH(Order_Date) IN (12, 1 ,2) THEN 'ZIMA'
	END)