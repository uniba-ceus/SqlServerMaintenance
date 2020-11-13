-- =============================================
-- Author:		Thomas Joscht
-- Create date: 22.07.2020
-- Description:	Returns all database names from searchString
-- =============================================
CREATE PROCEDURE [dbo].[sp_getDatabaseNames] (
	@searchStr NVARCHAR(MAX)
	,@serverName AS NVARCHAR(500) = @@SERVERNAME -- name of the server
	)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @searchDbSql AS NVARCHAR(4000) = ''

	SET @searchDbSql = N'SELECT [name]
	FROM ' + QUOTENAME(CONVERT(SYSNAME, @serverName)) + 
		'.master.sys.databases
	WHERE [name] like ''' + @searchStr + ''''

	EXEC sp_executesql @searchDbSql
END
