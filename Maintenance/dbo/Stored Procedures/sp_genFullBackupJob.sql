-- =============================================
-- Author:		Thomas Joscht
-- Create date: 26.02.2018
-- Description:	Generates a new job for full backup of all databases.
-- =============================================
CREATE PROCEDURE [dbo].[sp_genFullBackupJob] @serverName AS NVARCHAR(500) = @@SERVERNAME
AS
SET NOCOUNT ON;

DECLARE @tmpMsg AS NVARCHAR(MAX) = ''

-- clean names
SET @serverName = CONVERT(SYSNAME, dbo.fn_prepareName(@serverName))

BEGIN TRY
	SET @tmpMsg = 'Initialisiere einen Backup-Auftrag für den Server ' + QUOTENAME(@serverName)

	PRINT @tmpMsg

	DECLARE @tempDatabases AS TABLE (NAME NVARCHAR(500))

	DELETE
	FROM @tempDatabases

	DECLARE @getDatabaseNamesSql AS NVARCHAR(MAX) = 'SELECT NAME FROM ' + QUOTENAME(@serverName) + '.master.sys.databases'

	INSERT INTO @tempDatabases
	EXEC sp_executesql @getDatabaseNamesSql

	DECLARE @databaseNames NVARCHAR(MAX)

	SELECT @databaseNames = COALESCE(@databaseNames + ', ', '') + CAST(NAME AS NVARCHAR(500))
	FROM @tempDatabases

	-- create a backup job
	INSERT INTO [dbo].[BackupJobs] (
		[Name]
		,[ServerName]
		,[DatabaseNames]
		,[BaseDirectory]
		,[BackupType]
		,[RetainDays]
		,[RetainQuantity]
		,[RestoreVerify]
		,[AutoShrink]
		,[ViewCheck]
		,[CreateSubDirectory]
		,[Description]
		)
	VALUES (
		'Beispiel'
		,@serverName
		,@databaseNames
		,'S:/Backup/täglich/'
		,'FULL'
		,0
		,0
		,0
		,1
		,1
		,1
		,'Beispiel eines Backup-Auftrags'
		)
END TRY

BEGIN CATCH
	SET @tmpMsg = 'Fehler beim Initialisieren eines Backup-Auftrags für den Server ' + QUOTENAME(@serverName) + 
		'. Fehlermeldung: ' + ERROR_MESSAGE()

	PRINT @tmpMsg
END CATCH
