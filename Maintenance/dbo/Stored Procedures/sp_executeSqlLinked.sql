-- =============================================
-- Author:		Thomas Joscht
-- Create date: 28.02.2018
-- Description:	Executes sql on a remote linked server. RPC-Out must be active on linked server.
-- =============================================
CREATE PROCEDURE [dbo].[sp_executeSqlLinked] @sql AS NVARCHAR(4000)
	,@serverName AS NVARCHAR(500)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @serverSql AS NVARCHAR(2000) = ''

	IF @serverName = @@SERVERNAME
	BEGIN
		SET @serverSql = 'EXEC (@innersql)'
	END
	ELSE
	BEGIN
		SET @serverSql = 'EXEC (@innersql) AT ' + QUOTENAME(CONVERT(SYSNAME, @serverName))
	END

	EXEC sp_executesql @serverSql
		,N'@innersql NVARCHAR(4000)'
		,@innersql = @sql
END
