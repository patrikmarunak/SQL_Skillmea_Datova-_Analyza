SELECT CONCAT(UPPER(Customer_Name), ' ', UPPER(Customer_Surname),  ',', CONVERT(VARCHAR(10), Date_Birth, 104)) AS Zoznam
FROM [csv].[Customer]