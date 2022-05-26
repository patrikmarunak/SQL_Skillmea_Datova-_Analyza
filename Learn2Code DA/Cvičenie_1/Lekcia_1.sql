CREATE TABLE csv.Supplier (Supplier_Code CHAR(6) PRIMARY KEY
				,Supplier_Name NVARCHAR(150) NOT NULL
				,Country_Code CHAR(3) NOT NULL
				,Supplier_Contact CHAR(6) NOT NULL
				, Date_Start DATE DEFAULT '1900-01-01'
				, Date_End DATE DEFAULT '1900-01-01'
				,Product_Amount SMALLINT
				,Lowest_Price DECIMAL(6,1)
				,Highest_Price DECIMAL(6,1) CHECK (Highest_Price < 30000)
				,Supplier_Currency CHAR(3) NOT NULL
)