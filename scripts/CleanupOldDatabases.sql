-- ===========================
-- Cleanup Old Database Names
-- Drops MySimpleMigration_test and MySimpleMigration_prod
-- ===========================

USE MASTER;
GO

IF DB_ID('MySimpleMigration_test') IS NOT NULL
BEGIN
    ALTER DATABASE MySimpleMigration_test SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MySimpleMigration_test;
    PRINT 'MySimpleMigration_test Database Dropped';
END
ELSE
    PRINT 'MySimpleMigration_test does not exist';
GO

IF DB_ID('MySimpleMigration_prod') IS NOT NULL
BEGIN
    ALTER DATABASE MySimpleMigration_prod SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MySimpleMigration_prod;
    PRINT 'MySimpleMigration_prod Database Dropped';
END
ELSE
    PRINT 'MySimpleMigration_prod does not exist';
GO
