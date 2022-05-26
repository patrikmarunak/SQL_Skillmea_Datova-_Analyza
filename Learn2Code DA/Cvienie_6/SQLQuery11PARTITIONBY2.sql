SELECT Product_Name
	,Product_Category
	,Weight
	,MAX(Weight) OVER (PARTITION BY Product_Category) AS SUM_Product_Weight
	,MAX(Weight) Over (PARTITION BY Product_Category) - Weight AS Rozdiel_Vahy
	,AVG(Weight) OVER (PARTITION BY Product_Category) AS AVG_Product_Weight
FROM [csv].[Product]