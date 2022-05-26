CREATE TABLE csv.OrderStatus (
	OrderStatus_ID CHAR(1) PRIMARY KEY
	,OrderStatus_Name NVARCHAR(20)
);
INSERT INTO csv.OrderStatus
VALUES ('1', 'Paid'), ('2', 'Unpaid'), ('3', 'Canceled')