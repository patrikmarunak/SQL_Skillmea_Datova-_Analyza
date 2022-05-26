SELECT Customer_ID, Order_Date, COUNT(Order_ID) AS PocetObj
FROM [csv].[Order]
GROUP BY Customer_ID, Order_Date
HAVING COUNT(Order_ID) >2
ORDER BY Order_Date DESC