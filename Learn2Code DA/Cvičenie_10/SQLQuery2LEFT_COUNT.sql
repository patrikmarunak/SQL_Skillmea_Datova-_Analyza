SELECT COUNT(*) AS Pocet_Zak, LEFT(Customer_Name, 1) AS First_Letter
FROM [csv].[Customer]
GROUP BY LEFT(Customer_Name, 1)
ORDER BY Pocet_Zak DESC