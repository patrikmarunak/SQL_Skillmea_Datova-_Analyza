SELECT Customer_ID
	,MIN(Order_Date) AS PrvaObj
	,MAX(Order_Date) AS PoslObj
	,DATEDIFF(MONTH, MIN(Order_Date), MAX(Order_Date)) AS RozdielMedziObjMes
FROM [Lekcia_1].[csv].[Order]
GROUP BY Customer_ID