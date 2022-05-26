

SELECT AVG(PocetKs) AS PriemPocOBJKus
			,AVG(PocetObjProd) AS PriemPocOBJ
FROM (SELECT Customer_ID
		,Product_ID
		,SUM(Quantity) AS PocetKs
		,COUNT(Product_ID) AS PocetObjProd
FROM [csv].[Order]
WHERE Customer_ID NOT IN ('C204', 'C104', 'C180', 'C190', 'C120')
GROUP BY Customer_ID, Product_ID) zdroj