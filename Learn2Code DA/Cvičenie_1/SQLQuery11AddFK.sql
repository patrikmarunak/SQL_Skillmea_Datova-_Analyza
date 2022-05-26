ALTER TABLE [csv].Supplier
ADD CONSTRAINT FK_Supplier_Contact
FOREIGN KEY (Supplier_Contact) REFERENCES csv.Contact(Contact_ID)