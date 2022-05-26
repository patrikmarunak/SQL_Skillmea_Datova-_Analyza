UPDATE csv.Product
SET Product_Category = 'Unknown'
WHERE Product_Category IS NULL;