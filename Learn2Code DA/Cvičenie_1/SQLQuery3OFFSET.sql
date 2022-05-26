SELECT Product_ID, Product_Name, Product_Category 
FROM csv.Product
ORDER BY Weight
OFFSET 4 ROWS
FETCH NEXT 7 ROWS ONLY
