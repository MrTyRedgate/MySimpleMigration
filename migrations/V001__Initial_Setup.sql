-- V001__Initial_Setup.sql
-- Initial database setup migration
-- Created by: Developer
-- Date: 2024-01-01

-- Create sample schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'app')
BEGIN
    EXEC('CREATE SCHEMA app')
END
GO

-- Create sample table
CREATE TABLE app.SampleTable
(
    Id INT IDENTITY(1,1) NOT NULL,
    Name NVARCHAR(100) NOT NULL,
    Description NVARCHAR(500) NULL,
    CreatedDate DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 NULL,
    CONSTRAINT PK_SampleTable PRIMARY KEY CLUSTERED (Id)
)
GO

-- Add index
CREATE NONCLUSTERED INDEX IX_SampleTable_Name 
ON app.SampleTable (Name)
GO

PRINT 'V001__Initial_Setup.sql completed successfully'
GO
