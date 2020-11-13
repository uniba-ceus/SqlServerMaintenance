-- =============================================
-- Author:		Thomas Joscht
-- Create date: 31.01.2018
-- Description:	Restore and verifies a backup.
-- =============================================
CREATE PROCEDURE [dbo].[sp_restoreVerifyBackup] @backupFileName VARCHAR(1024) -- e.g. 'S:\Backup\täglich\test.bak'
	,@databaseName VARCHAR(1024) -- database name
	,@serverName AS NVARCHAR(500) = @@SERVERNAME -- server name	
	,@restoreVerifyDynamicNamingActive AS BIT = 0
	-- includes the database name in the #RestoreVerify database and the data files
	-- required for concurrent execution of centralized and decentralized backup processes
	,@notifyOperator AS BIT = 1 -- 0 = no mails, 1 = notify operator by email
	,@operatorName AS NVARCHAR(500) = NULL -- (optional) name of operator. Will override default operator of configuration.
	,@opId AS UNIQUEIDENTIFIER = 0x0
AS
SET NOCOUNT ON;

DECLARE @tmpMsg AS NVARCHAR(MAX) = ''
DECLARE @restoreVerifyDbName VARCHAR(1024)

SELECT @opId = CASE 
		WHEN @opId = 0x0
			THEN NEWID()
		ELSE @opId
		END

-- clean names
SET @databaseName = CONVERT(SYSNAME, dbo.fn_prepareName(@databaseName))
SET @serverName = CONVERT(SYSNAME, dbo.fn_prepareName(@serverName))
-- prepare file name
SET @backupFileName = dbo.fn_preparePath(@backupFileName)
-- extracting the DbName from the backupFileName without extension (.bak)
SET @restoreVerifyDbName = '#RestoreVerify' + CASE 
		WHEN @restoreVerifyDynamicNamingActive = 1
			THEN '_' + dbo.fn_getFileNameWithoutExtension(dbo.fn_getFileNameFromPath(@backupFileName))
		ELSE ''
		END

INSERT INTO [dbo].[BackupCheckDetails] (
	[ServerName]
	,[DatabaseName]
	,[BackupFileName]
	,[OperationId]
	,[StartTime]
	,[EndTime]
	,[Status]
	)
VALUES (
	@serverName
	,@databaseName
	,@backupFileName
	,@opId
	,GETDATE()
	,NULL
	,'Gestartet'
	)

DECLARE @detailsId INT = @@IDENTITY
DECLARE @owner AS NVARCHAR(500) = 'RestoreVerifyBackup_' + CAST(@detailsId AS NVARCHAR(11))

SET @tmpMsg = 'Überprüfung des Backups ' + @backupFileName + ' der Datenbank ' + QUOTENAME(@databaseName) + ' gestartet'

EXEC dbo.sp_info @opId
	,@tmpMsg
	,@owner
	,@serverName

-- check if database exists
DECLARE @databaseExists AS INT = 0

EXEC @databaseExists = dbo.[sp_databaseExists] @databaseName
	,@serverName

IF @databaseExists = 0
BEGIN
	SET @tmpMsg = 'Datenbank ' + @databaseName + ' wurde nicht gefunden!'

	EXEC dbo.sp_error @opId
		,@tmpMsg
		,@owner
END
ELSE IF @databaseExists > 1
BEGIN
	SET @tmpMsg = 'Es wurden mehrere (' + CAST(@databaseExists AS NVARCHAR(11)) + ') Datenbanken mit dem Namen ' + @databaseName + 
		' gefunden!'

	EXEC dbo.sp_error @opId
		,@tmpMsg
		,@owner
END
ELSE
BEGIN
	IF NOT @backupFileName LIKE '%.bak'
	BEGIN
		SET @tmpMsg = 
			'Überprüfung des Backups nicht möglich. Es werden nur vollständige Sicherungen mit der Endung .bak unterstützt.'

		EXEC dbo.sp_warn @opId
			,@tmpMsg
			,@owner
			,@serverName
	END
	ELSE
	BEGIN
		-- create temporary database #RestoreVerify
		DECLARE @createRestoryVerfiyDbSQL AS NVARCHAR(4000) = 'IF DB_ID(''' + @restoreVerifyDbName + 
			''') IS NOT NULL DROP DATABASE ' + QUOTENAME(@restoreVerifyDbName) + '
CREATE DATABASE ' + QUOTENAME(
				@restoreVerifyDbName) + ''

		EXEC sp_executeSqlLinked @createRestoryVerfiyDbSQL
			,@serverName

		DECLARE @tempRestoreFileListOnly AS TABLE (
			LogicalName NVARCHAR(128)
			,PhysicalName NVARCHAR(260)
			)

		DELETE
		FROM @tempRestoreFileListOnly

		-- determine server product version
		-- NOTE: Since Version 2008 (= 10.x) new column THEThumbprint varbinary(32) was introduced!
		-- NOTE: Since Version 2016 (= 13.x) new column SnapshotUrl nvarchar(360) was introduced!
		-- NOTE: Until Version 2016 the FileId and BackupSizeInBytes has DataType BIGINT. In newer versions it is INT!
		DECLARE @productVersion NVARCHAR(500)

		EXEC sp_getServerProductVersion @serverName
			,@productVersion OUTPUT

		SET @tmpMsg = 'Bestimmung der Produktversion des Servers: ' + @productVersion

		EXEC dbo.sp_debug @opId
			,@tmpMsg
			,@owner
			,@serverName

		DECLARE @versionDependentColumnsSql NVARCHAR(MAX) = ''
		DECLARE @mainVersion AS INT = (
				SELECT TOP 1 Part
				FROM fn_splitString(@productVersion, '.')
				)

		IF @mainVersion >= 10
		BEGIN
			SET @versionDependentColumnsSql = ',THEThumbprint varbinary(32)'

			IF @mainVersion >= 13
			BEGIN
				SET @versionDependentColumnsSql = @versionDependentColumnsSql + ',SnapshotUrl nvarchar(360)'
			END
		END

		DECLARE @createTempRestoreFileListOnlyTableSql AS NVARCHAR(4000) = 
			'

IF OBJECT_ID(N''tempdb.dbo.TempRestoreFileListOnly'', N''U'') IS NOT NULL
BEGIN
	DROP TABLE tempdb.dbo.TempRestoreFileListOnly
END

CREATE TABLE tempdb.dbo.TempRestoreFileListOnly(
     LogicalName NVARCHAR(128)
    ,PhysicalName NVARCHAR(260)
    ,Type CHAR(1)
    ,FileGroupName NVARCHAR(128)
    ,Size numeric(20,0)
    ,MaxSize numeric(20,0)
    ,FileId BIGINT
    ,CreateLSN numeric(25,0)
    ,DropLSN numeric(25,0)
    ,UniqueId uniqueidentifier
    ,ReadOnlyLSN numeric(25,0)
    ,ReadWriteLSN numeric(25,0)
    ,BackupSizeInBytes BIGINT
    ,SourceBlockSize INT
    ,FilegroupId INT
    ,LogGroupGUID uniqueidentifier
    ,DifferentialBaseLSN numeric(25)
    ,DifferentialBaseGUID uniqueidentifier
    ,IsReadOnly INT
    ,IsPresent INT
	' 
			+ @versionDependentColumnsSql + 
			'
    )
	
	INSERT INTO tempdb.dbo.TempRestoreFileListOnly
	EXEC (''RESTORE FILELISTONLY FROM DISK = ''''' 
			+ @backupFileName + ''''''')'

		EXEC sp_executeSqlLinked @createTempRestoreFileListOnlyTableSql
			,@serverName

		DECLARE @tempRestoreFileListOnlySql AS NVARCHAR(MAX) = 'SELECT [LogicalName], [PhysicalName] FROM ' + QUOTENAME(
				@serverName) + '.tempdb.dbo.TempRestoreFileListOnly'

		INSERT INTO @tempRestoreFileListOnly
		EXEC sp_executesql @tempRestoreFileListOnlySql

		DECLARE @logicalBackupFile NVARCHAR(128)
		DECLARE @restoreCommand NVARCHAR(2048)
		DECLARE @counter INT

		SET @counter = 1
		SET @restoreCommand = 'RESTORE DATABASE [' + @restoreVerifyDbName + '] FROM  DISK = ''' + @backupFileName + 
			''' WITH  FILE = 1,  NOUNLOAD, REPLACE,  STATS = 10 '

		DECLARE LogicalBackupFilesCursor CURSOR
		FOR
		SELECT LogicalName
		FROM @tempRestoreFileListOnly

		OPEN LogicalBackupFilesCursor

		FETCH NEXT
		FROM LogicalBackupFilesCursor
		INTO @logicalBackupFile

		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Datafile must be moved! NOTE: It is important to use backslashes here!
			SET @restoreCommand = @restoreCommand + ', MOVE ''' + @logicalBackupFile + ''' TO ''C:\Temp\restored' + CASE 
					WHEN @restoreVerifyDynamicNamingActive = 1
						THEN '_' + @restoreVerifyDbName + '_'
					ELSE ''
					END + CAST(@counter AS NVARCHAR(10)) + '.mdf'''
			SET @counter = @counter + 1

			FETCH NEXT
			FROM LogicalBackupFilesCursor
			INTO @logicalBackupFile
		END

		-- WARNING: ENABLE THIS IF YOU ARE SURE SCRIPT RUNS CORRECTLY!
		EXEC sp_executeSqlLinked @restoreCommand
			,@serverName

		CLOSE LogicalBackupFilesCursor

		DEALLOCATE LogicalBackupFilesCursor

		SET @tmpMsg = 'Backup ' + @backupFileName + ' wiederhergestellt in ' + @restoreVerifyDbName

		EXEC dbo.sp_debug @opId
			,@tmpMsg
			,@owner
			,@serverName

		SET @tmpMsg = 'Überprüfe ' + @restoreVerifyDbName + ' Datenbank'

		EXEC dbo.sp_debug @opId
			,@tmpMsg
			,@owner
			,@serverName

		-- WARNING: ENABLE THIS IF YOU ARE SURE SCRIPT RUNS CORRECTLY!
		DECLARE @checkDbSql NVARCHAR(MAX) = 'DBCC CHECKDB(N''' + @restoreVerifyDbName + ''')  WITH NO_INFOMSGS'

		EXEC sp_executeSqlLinked @checkDbSql
			,@serverName

		SET @tmpMsg = 'Überprüfe ' + @restoreVerifyDbName + ' Datenbank'

		EXEC dbo.sp_debug @opId
			,@tmpMsg
			,@owner
			,@serverName

		-- drop temporary database #RestoryVerify
		DECLARE @dropRestoryVerfiyDbSQL AS NVARCHAR(4000) = 'IF DB_ID(''' + @restoreVerifyDbName + 
			''') IS NOT NULL DROP DATABASE ' + QUOTENAME(@restoreVerifyDbName)

		EXEC sp_executeSqlLinked @dropRestoryVerfiyDbSQL
			,@serverName
	END
END

EXEC dbo.sp_info @opId
	,'Überprüfung des Backups beendet'
	,@owner
	,@serverName

-- CHECK FOR ERRORS AND SEND E-MAIL
DECLARE @errors AS NVARCHAR(MAX) = dbo.fn_getErrors(@opId, @owner)

IF NOT @errors = ''
BEGIN
	IF @notifyOperator = 1
	BEGIN
		SET @tmpMsg = 'Beim Überprüfen des Backups auf Konsistenz sind Fehler aufgetreten!'
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + dbo.fn_newline() + 'Fehler:' + dbo.fn_newline() + @errors
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', 
				@owner)

		EXEC dbo.sp_notifyOperator @subject = N'(CHECK) Fehler'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	UPDATE [dbo].[BackupCheckDetails]
	SET [EndTime] = GETDATE()
		,[Status] = 'Fehler'
	WHERE OperationId = @opId
		AND Id = @detailsId

	RETURN (1)
END
ELSE
BEGIN
	IF @notifyOperator = 1
	BEGIN
		SET @tmpMsg = 'Das Überprüfen des Backups war erfolgreich!'
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', 
				@owner)

		EXEC dbo.sp_notifyOperator @subject = N'(CHECK) Erfolg'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	UPDATE [dbo].[BackupCheckDetails]
	SET [EndTime] = GETDATE()
		,[Status] = 'Erfolg'
	WHERE OperationId = @opId
		AND Id = @detailsId

	RETURN (0)
END
