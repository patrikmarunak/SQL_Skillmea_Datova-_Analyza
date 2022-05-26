SELECT *
FROM csv.Product
WHERE Weight BETWEEN 1000 AND 2000 AND Product_Category NOT IN ('Homeware', 'Furniture')