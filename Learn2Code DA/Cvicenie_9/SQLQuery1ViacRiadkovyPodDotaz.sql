SELECT Customer_ID, Customer_Name, Customer_Surname, Date_Birth
FROM [csv].[Customer]
WHERE Customer_ID IN
(SELECT o.Customer_ID 
FROM [csv].[Order] o
LEFT JOIN [csv].[OrderStatus] ord
ON o.Order_Status = ord.OrderStatus_ID
WHERE ord.OrderStatus_Name = 'unpaid')
