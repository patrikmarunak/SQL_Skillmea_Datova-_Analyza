SELECT Customer_ID
	,Date_Registered
	,DATEDIFF(MONTH, Date_Registered, GETDATE()) AS PocetMesOdRegistracie
	,CASE WHEN DATEDIFF(MONTH, Date_Registered , GETDATE()) < 3 THEN 'Novy zakaznik,do 3 mesiacov'
		  WHEN DATEDIFF(MONTH, Date_Registered , GETDATE()) < 12 THEN 'Zakaznikom 3-12 mesiacov'
		  WHEN DATEDIFF(MONTH, Date_Registered , GETDATE()) < 24 THEN 'Zakaznikom 12-24 mesiacov'
		  WHEN DATEDIFF(MONTH, Date_Registered , GETDATE()) >= 24 THEN 'Zakaznikom 24 a viac mesiacov'
		  ELSE 'Neznamy datum registracie'
	END AS Segment
FROM [Lekcia_1].[csv].[Customer]
ORDER BY PocetMesOdRegistracie DESC