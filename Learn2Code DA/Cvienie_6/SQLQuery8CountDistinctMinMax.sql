SELECT Customer_ID
	,COUNT(Order_ID) AS PocetObj
	,SUM(Quantity) AS ObjMnoz
	,COUNT (DISTINCT Product_ID) AS RozneProdukty
	,MIN(Order_Date) AS PrvaObj
	,MAX(Order_Date) AS PosledObj
FROM [csv].[Order]
GROUP BY Customer_ID
ORDER BY PocetObj DESC