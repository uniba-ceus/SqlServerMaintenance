-- =============================================
-- Author:		Thomas Joscht
-- Create date: 03.03.2018
-- Description:	Reads the free drive space in MB and returns it as INT. Returns 0 if drive not found.
-- =============================================
CREATE PROCEDURE [dbo].[sp_getFreeDriveSpace] @driveName NVARCHAR(500)
	,@serverName NVARCHAR(500) = @@SERVERNAME
AS
BEGIN
	DECLARE @space AS INT = 0
	-- WARN: Following commands require DISTRIBUTED TRANSACTIONS
	/*
	DECLARE @spaceSql AS NVARCHAR(4000) = ''

	SET @spaceSql = N'DECLARE @temp as TABLE (Drive NVARCHAR(500), Mb NVARCHAR(500))

		INSERT INTO @temp
		EXEC ' + QUOTENAME(CONVERT(SYSNAME, @serverName)) + '.master.dbo.xp_fixeddrives

		SELECT @space = [Mb] FROM @temp WHERE [Drive] like ''' + @driveName + ''''

	EXEC sp_executesql @spaceSql
		,N'@space AS INT OUTPUT'
		,@space = @space OUTPUT

	RETURN @space
	*/
	DECLARE @tempDriveSpace AS TABLE (
		Drive NVARCHAR(500)
		,FreeMb NVARCHAR(500)
		)
	DECLARE @createTempDriveSpaceSql AS NVARCHAR(4000) = 
		'

	IF OBJECT_ID(N''tempdb.dbo.TempDriveSpace'', N''U'') IS NOT NULL
	BEGIN
		DROP TABLE tempdb.dbo.TempDriveSpace
	END

	CREATE TABLE tempdb.dbo.TempDriveSpace(
		 Drive NVARCHAR(500)
		,FreeMb NVARCHAR(500)
		)
	
		INSERT INTO tempdb.dbo.TempDriveSpace
		EXEC (''master.dbo.xp_fixeddrives'')'

	EXEC sp_executeSqlLinked @createTempDriveSpaceSql
		,@serverName

	DECLARE @tempDriveSpaceSql AS NVARCHAR(MAX) = 'SELECT [Drive], [FreeMb] FROM ' + QUOTENAME(@serverName) + 
		'.tempdb.dbo.TempDriveSpace'

	INSERT INTO @tempDriveSpace
	EXEC sp_executesql @tempDriveSpaceSql

	SELECT @space = [FreeMb]
	FROM @tempDriveSpace
	WHERE [Drive] LIKE @driveName

	RETURN @space
END
