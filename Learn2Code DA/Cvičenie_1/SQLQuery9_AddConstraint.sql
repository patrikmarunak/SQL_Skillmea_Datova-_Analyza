ALTER TABLE [csv].Contact
ADD CONSTRAINT DF_ContactEmail DEFAULT 'Unknown' FOR Email; 