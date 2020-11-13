-- =============================================
-- Author:		Thomas Joscht
-- Create date: 28.02.2018
-- Description:	Gets the recovery model. Values are 1 = FULL, 2 = BULK_LOGGED and 3 = SIMPLE. In case database was not found it is 0 = empty.
-- =============================================
CREATE PROCEDURE [dbo].[sp_getRecoveryModel] @databaseName AS NVARCHAR(4000)
	,@serverName AS NVARCHAR(4000) = @@SERVERNAME
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @recoveryModelSql AS NVARCHAR(4000) = ''
	DECLARE @recoveryModel AS INT = 0

	SET @recoveryModelSql = N'SELECT @recoveryModel = recovery_model
	FROM ' + QUOTENAME(CONVERT(SYSNAME, @serverName)) + 
		'.master.sys.databases
	WHERE [name] like ''' + @databaseName + ''''

	EXEC sp_executesql @recoveryModelSql
		,N'@recoveryModel AS INT OUTPUT'
		,@recoveryModel = @recoveryModel OUTPUT

	RETURN @recoveryModel
END
