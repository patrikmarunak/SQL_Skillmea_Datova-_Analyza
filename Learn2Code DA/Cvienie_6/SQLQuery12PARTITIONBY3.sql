SELECT *
	, COUNT(Order_ID) OVER (PARTITION BY Customer_ID ORDER BY Customer_ID) AS Pocet_Obj
FROM [csv].[Order]