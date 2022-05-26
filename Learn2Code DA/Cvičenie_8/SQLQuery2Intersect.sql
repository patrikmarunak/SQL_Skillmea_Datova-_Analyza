SELECT Product_ID 
FROM [csv].[Product]

INTERSECT 

SELECT Product_ID 
FROM [csv].[Order]