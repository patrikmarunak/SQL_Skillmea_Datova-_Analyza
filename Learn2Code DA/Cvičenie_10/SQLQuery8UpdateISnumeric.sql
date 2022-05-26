UPDATE [Lekcia_1].[csv].[Customer]
SET Phone = Email
WHERE ISNUMERIC(Email) = 1 AND Phone IS NULL