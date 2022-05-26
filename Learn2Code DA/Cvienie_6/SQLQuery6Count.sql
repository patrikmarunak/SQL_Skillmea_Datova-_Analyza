SELECT TOP(10) Customer_ID, COUNT(Order_ID) AS Number_Of_Orders
FROM [csv].[Order]
GROUP BY Customer_ID
ORDER BY Number_Of_Orders DESC