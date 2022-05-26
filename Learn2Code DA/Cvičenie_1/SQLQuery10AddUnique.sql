ALTER TABLE [csv].Contact
ADD CONSTRAINT UK_NameSurnamePhone
UNIQUE (Contact_Name, Contact_Surname, Phone_Number);