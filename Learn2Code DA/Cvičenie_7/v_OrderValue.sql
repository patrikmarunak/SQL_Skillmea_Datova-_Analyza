/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP (1000) [ExchangeRate_ID]
      ,[Currency_1]
      ,[Currency_2]
      ,[ExchangeRate]
  FROM [Lekcia_1].[csv].[Exchange_Rate]