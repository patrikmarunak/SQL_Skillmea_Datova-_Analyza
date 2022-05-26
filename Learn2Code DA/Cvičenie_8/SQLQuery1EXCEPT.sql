SELECT  Customer_ID
FROM [csv].[Customer]

EXCEPT

SELECT  Customer_ID
FROM [csv].[Order]