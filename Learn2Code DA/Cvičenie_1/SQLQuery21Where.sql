SELECT *
FROM csv.Product
WHERE (Currency = 'CZK' AND Unit_Price > 2800) OR (Currency = 'EUR' AND Unit_Price >= 110)
