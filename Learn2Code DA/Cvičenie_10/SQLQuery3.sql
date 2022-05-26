SELECT Customer_ID, Customer_Name, Customer_Surname, LEFT([Customer_Name],1) AS First_Letter_Name, LEFT([Customer_Surname],1) AS First_Letter_Sur
FROM [csv].Customer