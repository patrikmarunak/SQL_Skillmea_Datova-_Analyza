SELECT Product_ID
	  ,Product_Category
	  ,Date_Start
	  ,Date_End
	  ,CASE WHEN Product_Category <> 'Unknown' AND Date_End IS NOT NULL THEN 'Ukonceny produkt so znamou kategoriou'
			WHEN Product_Category = 'Unknown' AND Date_End IS NOT NULL THEN 'Ukonceny produkt s neznamou kategoriou'
			WHEN Product_Category <> 'Unknown' AND Date_End IS NULL THEN 'Neukonceny produkt s neznamou kategoriou'
			WHEN Product_Category = 'Unknown' AND Date_End IS NULL THEN 'Neukonceny produkt s neznamou kategoriou'
			ELSE 'Neznamy produkt'
	  END AS Product_Type

FROM [Lekcia_1].[csv].[Product]