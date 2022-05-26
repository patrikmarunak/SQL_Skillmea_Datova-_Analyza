SELECT Order_Status, COUNT(*) AS Kvantita
FROM [csv].[Order]
GROUP BY Order_Status
ORDER BY Order_Status