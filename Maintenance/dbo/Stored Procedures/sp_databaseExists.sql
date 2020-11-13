-- =============================================
-- Author:		Thomas Joscht
-- Create date: 03.03.2018
-- Description:	Checks if a database is existing or not. Returns 1 if exactly one database exists. Returns 0 if database does not exists. Returns > 1 if more than one database exists
-- =============================================
CREATE PROCEDURE [dbo].[sp_databaseExists] @databaseName NVARCHAR(500)
	,@serverName NVARCHAR(500) = @@SERVERNAME
AS
BEGIN
	DECLARE @existingCount AS INT = 0
	DECLARE @existsSql AS NVARCHAR(4000) = ''

	SET @existsSql = N'SELECT @existingCount = count(*)
	FROM ' + QUOTENAME(CONVERT(SYSNAME, @serverName)) + 
		'.master.sys.databases
	WHERE [name] like ''' + @databaseName + ''''

	EXEC sp_executesql @existsSql
		,N'@existingCount AS INT OUTPUT'
		,@existingCount = @existingCount OUTPUT

	RETURN @existingCount
END
