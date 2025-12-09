-- Flyway MySimpleMigration Database Setup Script --
-- Creates databases for migrations-based workflow
-- Dev and Target start with the same schema (cut from the same cloth)

-- Drop databases if they exist to ensure fresh setup
IF DB_ID('MySimpleMigration_dev') IS NOT NULL
BEGIN
	USE MASTER
    ALTER DATABASE MySimpleMigration_dev SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MySimpleMigration_dev;
	PRINT 'MySimpleMigration_dev Database Dropped'
END;

IF DB_ID('MySimpleMigration_target') IS NOT NULL
BEGIN
	USE MASTER
    ALTER DATABASE MySimpleMigration_target SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MySimpleMigration_target;
	PRINT 'MySimpleMigration_target Database Dropped'
END;

-- Ensure each database exists, creating them if needed
IF DB_ID('MySimpleMigration_dev') IS NULL CREATE DATABASE MySimpleMigration_dev PRINT 'MySimpleMigration_dev Database Created';
IF DB_ID('MySimpleMigration_shadow') IS NULL CREATE DATABASE MySimpleMigration_shadow PRINT 'MySimpleMigration_shadow Database Created';
IF DB_ID('MySimpleMigration_build') IS NULL CREATE DATABASE MySimpleMigration_build PRINT 'MySimpleMigration_build Database Created';
IF DB_ID('MySimpleMigration_target') IS NULL CREATE DATABASE MySimpleMigration_target PRINT 'MySimpleMigration_target Database Created';
GO

USE MySimpleMigration_dev;
GO

ALTER DATABASE MySimpleMigration_dev
SET MULTI_USER;
GO

-- Creating Schemas
CREATE SCHEMA Sales;
GO
CREATE SCHEMA Inventory;
GO
CREATE SCHEMA Customers;
GO


CREATE ROLE CustomerService;
CREATE ROLE Admin;


-- Tables in Customers Schema
CREATE TABLE Customers.Customer (
    CustomerID INT IDENTITY(1,1),
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    DateOfBirth DATE,
    Phone NVARCHAR(20),
    Address NVARCHAR(200),
    CONSTRAINT PK_Customer_CustomerID PRIMARY KEY (CustomerID),
    CONSTRAINT UQ_Customer_Email UNIQUE (Email)
);

CREATE TABLE Customers.LoyaltyProgram (
    ProgramID INT IDENTITY(1,1),
    ProgramName NVARCHAR(50) NOT NULL,
    PointsMultiplier DECIMAL(3, 2) DEFAULT 1.0,
    CONSTRAINT PK_LoyaltyProgram_ProgramID PRIMARY KEY (ProgramID)
);

CREATE TABLE Customers.CustomerFeedback (
    FeedbackID INT IDENTITY(1,1),
    CustomerID INT NOT NULL,
    FeedbackDate DATETIME DEFAULT GETDATE(),
    Rating INT NOT NULL,
    Comments NVARCHAR(500),
    CONSTRAINT PK_CustomerFeedback_FeedbackID PRIMARY KEY (FeedbackID),
    CONSTRAINT FK_CustomerFeedback_CustomerID FOREIGN KEY (CustomerID) REFERENCES Customers.Customer(CustomerID),
    CONSTRAINT CK_CustomerFeedback_Rating CHECK (Rating BETWEEN 1 AND 5)
);
GO

-- Tables in Inventory Schema
CREATE TABLE Inventory.Flight (
    FlightID INT IDENTITY(1,1),
    Airline NVARCHAR(50) NOT NULL,
    DepartureCity NVARCHAR(50) NOT NULL,
    ArrivalCity NVARCHAR(50) NOT NULL,
    DepartureTime DATETIME NOT NULL,
    ArrivalTime DATETIME NOT NULL,
    Price DECIMAL(10, 2) NOT NULL,
    AvailableSeats INT NOT NULL,
    CONSTRAINT PK_Flight_FlightID PRIMARY KEY (FlightID)
);

CREATE TABLE Inventory.FlightRoute (
    RouteID INT IDENTITY(1,1),
    DepartureCity NVARCHAR(50) NOT NULL,
    ArrivalCity NVARCHAR(50) NOT NULL,
    Distance INT NOT NULL,
    CONSTRAINT PK_FlightRoute_RouteID PRIMARY KEY (RouteID)
);

CREATE TABLE Inventory.MaintenanceLog (
    LogID INT IDENTITY(1,1),
    FlightID INT NOT NULL,
    MaintenanceDate DATETIME DEFAULT GETDATE(),
    Description NVARCHAR(500),
    MaintenanceStatus NVARCHAR(20) DEFAULT 'Pending',
    CONSTRAINT PK_MaintenanceLog_LogID PRIMARY KEY (LogID),
    CONSTRAINT FK_MaintenanceLog_FlightID FOREIGN KEY (FlightID) REFERENCES Inventory.Flight(FlightID)
);
GO

-- Tables in Sales Schema
CREATE TABLE Sales.Orders (
    OrderID INT IDENTITY(1,1),
    CustomerID INT NOT NULL,
    FlightID INT NOT NULL,
    OrderDate DATETIME DEFAULT GETDATE(),
    Status NVARCHAR(20) DEFAULT 'Pending',
    TotalAmount DECIMAL(10, 2),
    TicketQuantity INT,
    CONSTRAINT PK_Orders_OrderID PRIMARY KEY (OrderID),
    CONSTRAINT FK_Orders_CustomerID FOREIGN KEY (CustomerID) REFERENCES Customers.Customer(CustomerID),
    CONSTRAINT FK_Orders_FlightID FOREIGN KEY (FlightID) REFERENCES Inventory.Flight(FlightID)
);

CREATE TABLE Sales.DiscountCode (
    DiscountID INT IDENTITY(1,1),
    Code NVARCHAR(20) NOT NULL,
    DiscountPercentage DECIMAL(4, 2) NOT NULL,
    ExpiryDate DATETIME,
    CONSTRAINT PK_DiscountCode_DiscountID PRIMARY KEY (DiscountID),
    CONSTRAINT UQ_DiscountCode_Code UNIQUE (Code),
    CONSTRAINT CK_DiscountCode_Percentage CHECK (DiscountPercentage BETWEEN 0 AND 100)
);

CREATE TABLE Sales.OrderAuditLog (
    AuditID INT IDENTITY(1,1),
    OrderID INT NOT NULL,
    ChangeDate DATETIME DEFAULT GETDATE(),
    ChangeDescription NVARCHAR(500),
    CONSTRAINT PK_OrderAuditLog_AuditID PRIMARY KEY (AuditID),
    CONSTRAINT FK_OrderAuditLog_OrderID FOREIGN KEY (OrderID) REFERENCES Sales.Orders(OrderID)
);
GO

-- Views
GO
CREATE VIEW Sales.CustomerOrdersView AS
SELECT 
    c.CustomerID,
    c.FirstName,
    c.LastName,
    o.OrderID,
    o.OrderDate,
    o.Status,
    o.TotalAmount
FROM Customers.Customer c
JOIN Sales.Orders o ON c.CustomerID = o.CustomerID;
GO

CREATE VIEW Customers.CustomerFeedbackSummary AS
SELECT 
    c.CustomerID,
    c.FirstName,
    c.LastName,
    AVG(f.Rating) AS AverageRating,
    COUNT(f.FeedbackID) AS FeedbackCount
FROM Customers.Customer c
LEFT JOIN Customers.CustomerFeedback f ON c.CustomerID = f.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName;
GO

CREATE VIEW Inventory.FlightMaintenanceStatus AS
SELECT 
    f.FlightID,
    f.Airline,
    f.DepartureCity,
    f.ArrivalCity,
    COUNT(m.LogID) AS MaintenanceCount,
    SUM(CASE WHEN m.MaintenanceStatus = 'Completed' THEN 1 ELSE 0 END) AS CompletedMaintenance
FROM Inventory.Flight f
LEFT JOIN Inventory.MaintenanceLog m ON f.FlightID = m.FlightID
GROUP BY f.FlightID, f.Airline, f.DepartureCity, f.ArrivalCity;
GO

-- Stored Procedures
CREATE PROCEDURE Sales.GetCustomerFlightHistory @CustomerID INT
AS
BEGIN
    SELECT 
        o.OrderID,
        f.Airline,
        f.DepartureCity,
        f.ArrivalCity,
        o.OrderDate,
        o.Status,
        o.TotalAmount
    FROM Sales.Orders o
    JOIN Inventory.Flight f ON o.FlightID = f.FlightID
    WHERE o.CustomerID = @CustomerID
    ORDER BY o.OrderDate;
END;
GO

CREATE PROCEDURE Sales.UpdateOrderStatus
    @OrderID INT,
    @NewStatus NVARCHAR(20)
AS
BEGIN
    UPDATE Sales.Orders
    SET Status = @NewStatus
    WHERE OrderID = @OrderID;
END;
GO

CREATE PROCEDURE Inventory.UpdateAvailableSeats
    @FlightID INT,
    @SeatChange INT
AS
BEGIN
    UPDATE Inventory.Flight
    SET AvailableSeats = AvailableSeats + @SeatChange
    WHERE FlightID = @FlightID;
END;
GO

CREATE PROCEDURE Sales.ApplyDiscount
    @OrderID INT,
    @DiscountCode NVARCHAR(20)
AS
BEGIN
    DECLARE @DiscountID INT, @DiscountPercentage DECIMAL(4, 2), @ExpiryDate DATETIME;
    
    SELECT 
        @DiscountID = DiscountID,
        @DiscountPercentage = DiscountPercentage,
        @ExpiryDate = ExpiryDate
    FROM Sales.DiscountCode
    WHERE Code = @DiscountCode;
    
    IF @DiscountID IS NOT NULL AND @ExpiryDate >= GETDATE()
    BEGIN
        UPDATE Sales.Orders
        SET TotalAmount = TotalAmount * (1 - @DiscountPercentage / 100)
        WHERE OrderID = @OrderID;

        INSERT INTO Sales.OrderAuditLog (OrderID, ChangeDescription)
        VALUES (@OrderID, CONCAT('Discount ', @DiscountCode, ' applied with ', @DiscountPercentage, '% off.'));
    END
    ELSE
    BEGIN
        RAISERROR('Invalid or expired discount code.', 16, 1);
    END
END;
GO

CREATE PROCEDURE Inventory.AddMaintenanceLog
    @FlightID INT,
    @Description NVARCHAR(500)
AS
BEGIN
    INSERT INTO Inventory.MaintenanceLog (FlightID, Description, MaintenanceStatus)
    VALUES (@FlightID, @Description, 'Pending');

    PRINT 'Maintenance log entry created.';
END;
GO

CREATE PROCEDURE Customers.RecordFeedback
    @CustomerID INT,
    @Rating INT,
    @Comments NVARCHAR(500)
AS
BEGIN
    INSERT INTO Customers.CustomerFeedback (CustomerID, Rating, Comments)
    VALUES (@CustomerID, @Rating, @Comments);

    PRINT 'Customer feedback recorded successfully.';
END;
GO

-- Sample Data Insertion

-- Adding Customers
INSERT INTO Customers.Customer (FirstName, LastName, Email, DateOfBirth, Phone, Address)
VALUES ('Huxley', 'Kendell', 'FlywayAP@Red-Gate.com', '2000-08-10', '555-1234', '123 Main St'),
       ('Chris', 'Hawkins', 'Chrawkins@Red-Gate.com', '1971-07-20', '555-5678', '456 Elm St');

-- Adding Flights
INSERT INTO Inventory.Flight (Airline, DepartureCity, ArrivalCity, DepartureTime, ArrivalTime, Price, AvailableSeats)
VALUES ('Flyway Airlines', 'New York', 'London', '2024-11-20 10:00', '2024-11-20 20:00', 500.00, 150),
       ('MySimpleMigration', 'Los Angeles', 'Tokyo', '2024-12-01 16:00', '2024-12-02 08:00', 800.00, 200);

-- Adding Orders
INSERT INTO Sales.Orders (CustomerID, FlightID, OrderDate, Status, TotalAmount, TicketQuantity)
VALUES (1, 1, GETDATE(), 'Confirmed', 500.00, 1),
       (2, 2, GETDATE(), 'Pending', 1600.00, 2);

-- Adding Loyalty Programs
INSERT INTO Customers.LoyaltyProgram (ProgramName, PointsMultiplier)
VALUES ('Silver', 1.0), ('Gold', 1.5), ('Platinum', 2.0);

-- Adding Discount Codes
INSERT INTO Sales.DiscountCode (Code, DiscountPercentage, ExpiryDate)
VALUES ('FLY20', 20.00, '2024-12-31'), ('NEWYEAR', 10.00, '2025-01-04');

GO

-- =============================================================================
-- REPLICATE SCHEMA TO TARGET DATABASE (Cut from the same cloth as Dev)
-- =============================================================================
USE MySimpleMigration_target;
GO

ALTER DATABASE MySimpleMigration_target
SET MULTI_USER;
GO

-- Creating Schemas
CREATE SCHEMA Sales;
GO
CREATE SCHEMA Inventory;
GO
CREATE SCHEMA Customers;
GO


CREATE ROLE CustomerService;
CREATE ROLE Admin;


-- Tables in Customers Schema
CREATE TABLE Customers.Customer (
    CustomerID INT IDENTITY(1,1),
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    DateOfBirth DATE,
    Phone NVARCHAR(20),
    Address NVARCHAR(200),
    CONSTRAINT PK_Customer_CustomerID PRIMARY KEY (CustomerID),
    CONSTRAINT UQ_Customer_Email UNIQUE (Email)
);

CREATE TABLE Customers.LoyaltyProgram (
    ProgramID INT IDENTITY(1,1),
    ProgramName NVARCHAR(50) NOT NULL,
    PointsMultiplier DECIMAL(3, 2) DEFAULT 1.0,
    CONSTRAINT PK_LoyaltyProgram_ProgramID PRIMARY KEY (ProgramID)
);

CREATE TABLE Customers.CustomerFeedback (
    FeedbackID INT IDENTITY(1,1),
    CustomerID INT NOT NULL,
    FeedbackDate DATETIME DEFAULT GETDATE(),
    Rating INT NOT NULL,
    Comments NVARCHAR(500),
    CONSTRAINT PK_CustomerFeedback_FeedbackID PRIMARY KEY (FeedbackID),
    CONSTRAINT FK_CustomerFeedback_CustomerID FOREIGN KEY (CustomerID) REFERENCES Customers.Customer(CustomerID),
    CONSTRAINT CK_CustomerFeedback_Rating CHECK (Rating BETWEEN 1 AND 5)
);
GO

-- Tables in Inventory Schema
CREATE TABLE Inventory.Flight (
    FlightID INT IDENTITY(1,1),
    Airline NVARCHAR(50) NOT NULL,
    DepartureCity NVARCHAR(50) NOT NULL,
    ArrivalCity NVARCHAR(50) NOT NULL,
    DepartureTime DATETIME NOT NULL,
    ArrivalTime DATETIME NOT NULL,
    Price DECIMAL(10, 2) NOT NULL,
    AvailableSeats INT NOT NULL,
    CONSTRAINT PK_Flight_FlightID PRIMARY KEY (FlightID)
);

CREATE TABLE Inventory.FlightRoute (
    RouteID INT IDENTITY(1,1),
    DepartureCity NVARCHAR(50) NOT NULL,
    ArrivalCity NVARCHAR(50) NOT NULL,
    Distance INT NOT NULL,
    CONSTRAINT PK_FlightRoute_RouteID PRIMARY KEY (RouteID)
);

CREATE TABLE Inventory.MaintenanceLog (
    LogID INT IDENTITY(1,1),
    FlightID INT NOT NULL,
    MaintenanceDate DATETIME DEFAULT GETDATE(),
    Description NVARCHAR(500),
    MaintenanceStatus NVARCHAR(20) DEFAULT 'Pending',
    CONSTRAINT PK_MaintenanceLog_LogID PRIMARY KEY (LogID),
    CONSTRAINT FK_MaintenanceLog_FlightID FOREIGN KEY (FlightID) REFERENCES Inventory.Flight(FlightID)
);
GO

-- Tables in Sales Schema
CREATE TABLE Sales.Orders (
    OrderID INT IDENTITY(1,1),
    CustomerID INT NOT NULL,
    FlightID INT NOT NULL,
    OrderDate DATETIME DEFAULT GETDATE(),
    Status NVARCHAR(20) DEFAULT 'Pending',
    TotalAmount DECIMAL(10, 2),
    TicketQuantity INT,
    CONSTRAINT PK_Orders_OrderID PRIMARY KEY (OrderID),
    CONSTRAINT FK_Orders_CustomerID FOREIGN KEY (CustomerID) REFERENCES Customers.Customer(CustomerID),
    CONSTRAINT FK_Orders_FlightID FOREIGN KEY (FlightID) REFERENCES Inventory.Flight(FlightID)
);

CREATE TABLE Sales.DiscountCode (
    DiscountID INT IDENTITY(1,1),
    Code NVARCHAR(20) NOT NULL,
    DiscountPercentage DECIMAL(4, 2) NOT NULL,
    ExpiryDate DATETIME,
    CONSTRAINT PK_DiscountCode_DiscountID PRIMARY KEY (DiscountID),
    CONSTRAINT UQ_DiscountCode_Code UNIQUE (Code),
    CONSTRAINT CK_DiscountCode_Percentage CHECK (DiscountPercentage BETWEEN 0 AND 100)
);

CREATE TABLE Sales.OrderAuditLog (
    AuditID INT IDENTITY(1,1),
    OrderID INT NOT NULL,
    ChangeDate DATETIME DEFAULT GETDATE(),
    ChangeDescription NVARCHAR(500),
    CONSTRAINT PK_OrderAuditLog_AuditID PRIMARY KEY (AuditID),
    CONSTRAINT FK_OrderAuditLog_OrderID FOREIGN KEY (OrderID) REFERENCES Sales.Orders(OrderID)
);
GO

-- Views
GO
CREATE VIEW Sales.CustomerOrdersView AS
SELECT 
    c.CustomerID,
    c.FirstName,
    c.LastName,
    o.OrderID,
    o.OrderDate,
    o.Status,
    o.TotalAmount
FROM Customers.Customer c
JOIN Sales.Orders o ON c.CustomerID = o.CustomerID;
GO

CREATE VIEW Customers.CustomerFeedbackSummary AS
SELECT 
    c.CustomerID,
    c.FirstName,
    c.LastName,
    AVG(f.Rating) AS AverageRating,
    COUNT(f.FeedbackID) AS FeedbackCount
FROM Customers.Customer c
LEFT JOIN Customers.CustomerFeedback f ON c.CustomerID = f.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName;
GO

CREATE VIEW Inventory.FlightMaintenanceStatus AS
SELECT 
    f.FlightID,
    f.Airline,
    f.DepartureCity,
    f.ArrivalCity,
    COUNT(m.LogID) AS MaintenanceCount,
    SUM(CASE WHEN m.MaintenanceStatus = 'Completed' THEN 1 ELSE 0 END) AS CompletedMaintenance
FROM Inventory.Flight f
LEFT JOIN Inventory.MaintenanceLog m ON f.FlightID = m.FlightID
GROUP BY f.FlightID, f.Airline, f.DepartureCity, f.ArrivalCity;
GO

-- Stored Procedures
CREATE PROCEDURE Sales.GetCustomerFlightHistory @CustomerID INT
AS
BEGIN
    SELECT 
        o.OrderID,
        f.Airline,
        f.DepartureCity,
        f.ArrivalCity,
        o.OrderDate,
        o.Status,
        o.TotalAmount
    FROM Sales.Orders o
    JOIN Inventory.Flight f ON o.FlightID = f.FlightID
    WHERE o.CustomerID = @CustomerID
    ORDER BY o.OrderDate;
END;
GO

CREATE PROCEDURE Sales.UpdateOrderStatus
    @OrderID INT,
    @NewStatus NVARCHAR(20)
AS
BEGIN
    UPDATE Sales.Orders
    SET Status = @NewStatus
    WHERE OrderID = @OrderID;
END;
GO

CREATE PROCEDURE Inventory.UpdateAvailableSeats
    @FlightID INT,
    @SeatChange INT
AS
BEGIN
    UPDATE Inventory.Flight
    SET AvailableSeats = AvailableSeats + @SeatChange
    WHERE FlightID = @FlightID;
END;
GO

CREATE PROCEDURE Sales.ApplyDiscount
    @OrderID INT,
    @DiscountCode NVARCHAR(20)
AS
BEGIN
    DECLARE @DiscountID INT, @DiscountPercentage DECIMAL(4, 2), @ExpiryDate DATETIME;
    
    SELECT 
        @DiscountID = DiscountID,
        @DiscountPercentage = DiscountPercentage,
        @ExpiryDate = ExpiryDate
    FROM Sales.DiscountCode
    WHERE Code = @DiscountCode;
    
    IF @DiscountID IS NOT NULL AND @ExpiryDate >= GETDATE()
    BEGIN
        UPDATE Sales.Orders
        SET TotalAmount = TotalAmount * (1 - @DiscountPercentage / 100)
        WHERE OrderID = @OrderID;

        INSERT INTO Sales.OrderAuditLog (OrderID, ChangeDescription)
        VALUES (@OrderID, CONCAT('Discount ', @DiscountCode, ' applied with ', @DiscountPercentage, '% off.'));
    END
    ELSE
    BEGIN
        RAISERROR('Invalid or expired discount code.', 16, 1);
    END
END;
GO

CREATE PROCEDURE Inventory.AddMaintenanceLog
    @FlightID INT,
    @Description NVARCHAR(500)
AS
BEGIN
    INSERT INTO Inventory.MaintenanceLog (FlightID, Description, MaintenanceStatus)
    VALUES (@FlightID, @Description, 'Pending');

    PRINT 'Maintenance log entry created.';
END;
GO

CREATE PROCEDURE Customers.RecordFeedback
    @CustomerID INT,
    @Rating INT,
    @Comments NVARCHAR(500)
AS
BEGIN
    INSERT INTO Customers.CustomerFeedback (CustomerID, Rating, Comments)
    VALUES (@CustomerID, @Rating, @Comments);

    PRINT 'Customer feedback recorded successfully.';
END;
GO

-- Sample Data Insertion for Target (same as Dev)

-- Adding Customers
INSERT INTO Customers.Customer (FirstName, LastName, Email, DateOfBirth, Phone, Address)
VALUES ('Huxley', 'Kendell', 'FlywayAP@Red-Gate.com', '2000-08-10', '555-1234', '123 Main St'),
       ('Chris', 'Hawkins', 'Chrawkins@Red-Gate.com', '1971-07-20', '555-5678', '456 Elm St');

-- Adding Flights
INSERT INTO Inventory.Flight (Airline, DepartureCity, ArrivalCity, DepartureTime, ArrivalTime, Price, AvailableSeats)
VALUES ('Flyway Airlines', 'New York', 'London', '2024-11-20 10:00', '2024-11-20 20:00', 500.00, 150),
       ('MySimpleMigration', 'Los Angeles', 'Tokyo', '2024-12-01 16:00', '2024-12-02 08:00', 800.00, 200);

-- Adding Orders
INSERT INTO Sales.Orders (CustomerID, FlightID, OrderDate, Status, TotalAmount, TicketQuantity)
VALUES (1, 1, GETDATE(), 'Confirmed', 500.00, 1),
       (2, 2, GETDATE(), 'Pending', 1600.00, 2);

-- Adding Loyalty Programs
INSERT INTO Customers.LoyaltyProgram (ProgramName, PointsMultiplier)
VALUES ('Silver', 1.0), ('Gold', 1.5), ('Platinum', 2.0);

-- Adding Discount Codes
INSERT INTO Sales.DiscountCode (Code, DiscountPercentage, ExpiryDate)
VALUES ('FLY20', 20.00, '2024-12-31'), ('NEWYEAR', 10.00, '2025-01-04');

PRINT '=== Both Dev and Target databases are now identical ==='