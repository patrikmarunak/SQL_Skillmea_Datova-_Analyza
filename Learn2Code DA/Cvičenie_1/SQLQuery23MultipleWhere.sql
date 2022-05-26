SELECT *
FROM csv.Customer
WHERE Date_Registered BETWEEN '2021-01-01' AND '2021-01-31'  AND City LIKE '%Praha%' AND Customer_Name = 'Lenka'
	