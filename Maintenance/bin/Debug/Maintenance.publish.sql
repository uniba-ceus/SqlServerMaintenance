/*
Bereitstellungsskript für Maintenance

Dieser Code wurde von einem Tool generiert.
Änderungen an dieser Datei führen möglicherweise zu falschem Verhalten und gehen verloren, falls
der Code neu generiert wird.
*/
GO

SET ANSI_NULLS
	,ANSI_PADDING
	,ANSI_WARNINGS
	,ARITHABORT
	,CONCAT_NULL_YIELDS_NULL
	,QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

:setvar DatabaseName "Maintenance" :setvar DefaultFilePrefix "Maintenance" :setvar DefaultDataPath "E:\MSSQL\DATA\" :setvar 
	DefaultLogPath "E:\MSSQL\DATA\"
GO

:on error EXIT
GO

/*
Überprüfen Sie den SQLCMD-Modus, und deaktivieren Sie die Skriptausführung, wenn der SQLCMD-Modus nicht unterstützt wird.
Um das Skript nach dem Aktivieren des SQLCMD-Modus erneut zu aktivieren, führen Sie folgenden Befehl aus:
SET NOEXEC OFF; 
*/
:setvar __IsSqlCmdEnabled "True"
GO

IF N'$(__IsSqlCmdEnabled)' NOT LIKE N'True'
BEGIN
	PRINT N'Der SQLCMD-Modus muss aktiviert sein, damit dieses Skript erfolgreich ausgeführt werden kann.';

	SET NOEXEC ON;
END
GO

USE [$(DatabaseName)];
GO

PRINT N'[dbo].[sp_databaseExists] wird geändert....';
GO

-- =============================================
-- Author:		Thomas Joscht
-- Create date: 03.03.2018
-- Description:	Checks if a database is existing or not. Returns 1 if exactly one database exists. Returns 0 if database does not exists. Returns > 1 if more than one database exists
-- =============================================
ALTER PROCEDURE [dbo].[sp_databaseExists] @databaseName NVARCHAR(500)
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
GO

PRINT N'[dbo].[sp_restoreVerifyBackup] wird geändert....';
GO

-- =============================================
-- Author:		Thomas Joscht
-- Create date: 31.01.2018
-- Description:	Restore and verifies a backup.
-- =============================================
ALTER PROCEDURE [dbo].[sp_restoreVerifyBackup] @backupFileName VARCHAR(1024) -- e.g. 'S:\Backup\täglich\test.bak'
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
GO

PRINT N'[dbo].[sp_shrinkDatabase] wird geändert....';
GO

-- =============================================
-- Author:		Thomas Joscht
-- Create date: 29.12.2017
-- Description:	Shrinks a database in case it has recovery model simple.
-- =============================================
ALTER PROCEDURE [dbo].[sp_shrinkDatabase] @databaseName VARCHAR(1024)
	,@serverName AS NVARCHAR(500) = @@SERVERNAME -- the server name
	,@opId AS UNIQUEIDENTIFIER = 0x0
AS
SET NOCOUNT ON;

SELECT @opId = CASE 
		WHEN @opId = 0x0
			THEN NEWID()
		ELSE @opId
		END

-- clean names
SET @databaseName = CONVERT(SYSNAME, dbo.fn_prepareName(@databaseName))
SET @serverName = CONVERT(SYSNAME, dbo.fn_prepareName(@serverName))

DECLARE @tmpMsg AS NVARCHAR(MAX) = ''
DECLARE @owner AS NVARCHAR(500) = 'Shrink'
-- check if database exists
DECLARE @databaseExists AS INT = 0
DECLARE @returnCode BIT = 0

EXEC @databaseExists = dbo.[sp_databaseExists] @databaseName
	,@serverName

SET @tmpMsg = 'Datenbank ' + QUOTENAME(@databaseName) + ' wird verkleinert'

EXEC dbo.sp_info @opId
	,@tmpMsg
	,@owner
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
	BEGIN TRY
		DECLARE @recoveryModel AS INT

		EXEC @recoveryModel = dbo.sp_getRecoveryModel @databaseName
			,@serverName

		IF @recoveryModel = 3
		BEGIN
			-- SHRINK LOGFILES
			DECLARE @logFileName AS NVARCHAR(2000)
			DECLARE @logFileNamesSQL AS NVARCHAR(4000) = ''
			DECLARE @logFileNamesTable TABLE ([name] NVARCHAR(500))

			SET @logFileNamesSQL = N'SELECT mf.NAME
		FROM ' + QUOTENAME(@serverName) + 
				'.master.sys.master_files mf
		LEFT JOIN ' + QUOTENAME(@serverName) + 
				'.master.sys.databases d 
			ON mf.database_id = d.database_id
		WHERE d.NAME like ''' + @databaseName + 
				''' AND type_desc=''LOG'''

			-- get log file names as table variable
			INSERT INTO @logFileNamesTable
			EXEC sp_executesql @logFileNamesSQL

			IF CURSOR_STATUS('global', 'LogFileNames') >= - 1
			BEGIN
				DEALLOCATE LogFileNames
			END

			DECLARE LogFileNames CURSOR STATIC
			FOR
			SELECT [name]
			FROM @logFileNamesTable

			OPEN LogFileNames

			FETCH NEXT
			FROM LogFileNames
			INTO @logFileName

			WHILE @@FETCH_STATUS = 0
			BEGIN
				DECLARE @shrinkSQL AS NVARCHAR(4000) = ''

				SET @shrinkSQL = 'USE ' + QUOTENAME(@databaseName) + ' DBCC SHRINKFILE (''' + @logFileName + ''',1)'
				SET @tmpMsg = 'Verkleinere Log-Datei ' + @logFileName + ' auf 1 MB'

				EXEC dbo.sp_debug @opId
					,@tmpMsg
					,@owner
					,@serverName

				EXEC sp_executeSqlLinked @shrinkSQL
					,@serverName

				SET @tmpMsg = 'Log-Datei ' + @logFileName + ' erfolgreich verkleinert'

				EXEC dbo.sp_debug @opId
					,@tmpMsg
					,@owner
					,@serverName

				FETCH NEXT
				FROM LogFileNames
				INTO @logFileName
			END

			CLOSE LogFileNames

			DEALLOCATE LogFileNames

			-- SHRINK DATABASE
			DECLARE @shrinkDbSQL AS NVARCHAR(4000) = 'USE ' + QUOTENAME(@databaseName) + ' DBCC SHRINKDATABASE(N''' + @databaseName 
				+ ''')'

			SET @tmpMsg = 'Verkleinere Datenbank ' + QUOTENAME(@databaseName)

			EXEC dbo.sp_debug @opId
				,@tmpMsg
				,@owner
				,@serverName

			EXEC sp_executeSqlLinked @shrinkSQL
				,@serverName

			SET @tmpMsg = 'Datenbank ' + QUOTENAME(@databaseName) + ' erfolgreich verkleinert'

			EXEC dbo.sp_debug @opId
				,@tmpMsg
				,@owner
		END
		ELSE
		BEGIN
			IF @recoveryModel = 0
			BEGIN
				EXEC dbo.sp_warn @opId
					,'Verkleinern der Datenbank nicht möglich. Die Datenbank wurde nicht gefunden.'
					,@owner
					,@serverName
			END
			ELSE
			BEGIN
				EXEC dbo.sp_info @opId
					,
					'Verkleinern der Datenbank nicht möglich. Es werden nur Datenbank mit dem Wiederherstellungsmodell EINFACH unterstützt.'
					,@owner
					,@serverName
			END
		END
	END TRY

	BEGIN CATCH
		SET @tmpMsg = 'Fehler beim Verkleinern der Datenbank ' + QUOTENAME(@databaseName) + '. Fehlermeldung: ' + ERROR_MESSAGE()

		EXEC dbo.sp_error @opId
			,@tmpMsg
			,@owner
			,@serverName

		SET @returnCode = 1
	END CATCH
END

EXEC dbo.sp_info @opId
	,'Verkleinern der Datenbank beendet'
	,@owner
	,@serverName

RETURN @returnCode
GO

PRINT N'[dbo].[sp_getDatabaseNames] wird erstellt....';
GO

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
GO

PRINT N'[dbo].[sp_checkDatabaseViews] wird geändert....';
GO

-- =============================================
-- Author:		Thomas Joscht
-- Create date: 02.03.2018
-- Description:	Checks the views of a database.
-- =============================================
ALTER PROCEDURE [dbo].[sp_checkDatabaseViews] @databaseName VARCHAR(500) -- name of the database
	,@serverName AS NVARCHAR(500) = @@SERVERNAME
	,@notifyOperator AS BIT = 1 -- 0 = no mails, 1 = notify operator by email
	,@operatorName AS NVARCHAR(500) = NULL -- (optional) name of operator. Will override default operator of configuration.
	,@opId AS UNIQUEIDENTIFIER = 0x0
AS
SET NOCOUNT ON;

DECLARE @tmpMsg AS NVARCHAR(MAX) = ''

SELECT @opId = CASE 
		WHEN @opId = 0x0
			THEN NEWID()
		ELSE @opId
		END

-- clean names
SET @databaseName = CONVERT(SYSNAME, dbo.fn_prepareName(@databaseName))
SET @serverName = CONVERT(SYSNAME, dbo.fn_prepareName(@serverName))

INSERT INTO [dbo].[ViewCheckDetails] (
	[ServerName]
	,[DatabaseName]
	,[OperationId]
	,[StartTime]
	,[EndTime]
	,[Status]
	)
VALUES (
	@serverName
	,@databaseName
	,@opId
	,GETDATE()
	,NULL
	,'Gestartet'
	)

DECLARE @detailsId INT = @@IDENTITY
DECLARE @owner AS NVARCHAR(500) = 'CheckViews_' + CAST(@detailsId AS NVARCHAR(11))

SET @tmpMsg = 'Überprüfung der Sichten in der Datenbank ' + QUOTENAME(@databaseName) + ' gestartet'

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
	DECLARE @tempViews AS TABLE (
		[name] NVARCHAR(500)
		,[isSchemaBound] BIT
		,[schemaName] NVARCHAR(500)
		)

	DELETE
	FROM @tempViews

	-- NOTE: sp_refreshsqlmodule only supports not schema bound views!
	-- Normally the IsSchemaBound property can be determined via OBJECTPROPERTY, but this is not possible on remote server.
	--DECLARE @getViewsSql AS NVARCHAR(MAX) = 'SELECT NAME FROM ' + QUOTENAME(@serverName) + '.' + 
	--QUOTENAME(@databaseName) + '.sys.views WHERE OBJECTPROPERTY(object_id, ''IsSchemaBound'') = 0
	-- Therefore the workaround via dependencies is used.
	DECLARE @getViewsSql AS NVARCHAR(MAX) = 
		'SELECT DISTINCT v.[name], COALESCE( d.[is_schema_bound_reference],0) AS isSchemaBound, s.[name] AS schemaName FROM ' 
		+ QUOTENAME(@serverName) + '.' + QUOTENAME(@databaseName) + '.sys.views v LEFT JOIN ' + QUOTENAME(@serverName) + '.' + 
		QUOTENAME(@databaseName) + '.sys.sql_expression_dependencies d ON v.object_id = d.referencing_id 
LEFT JOIN ' + 
		QUOTENAME(@serverName) + '.' + QUOTENAME(@databaseName) + '.sys.objects o ON v.object_id = o.object_id
LEFT JOIN ' + 
		QUOTENAME(@serverName) + '.' + QUOTENAME(@databaseName) + 
		'.sys.schemas s ON v.schema_id = s.schema_id
ORDER BY v.[name]'

	INSERT INTO @tempViews
	EXEC sp_executesql @getViewsSql

	-- NOTE: The view master.dbo.spt_values returns an error because of missing sys.spt_values. This is a false negative!
	-- The view works correctly and is necessary for starting sql server properly. Therefore the view is ignored.
	IF @databaseName = 'master'
	BEGIN
		DELETE
		FROM @tempViews
		WHERE [name] = 'spt_values'
	END

	DECLARE @viewName AS VARCHAR(128)
	DECLARE @viewCount AS INT = 0
	DECLARE @viewOkCount AS INT = 0

	IF CURSOR_STATUS('global', 'ViewCursor') >= - 1
	BEGIN
		DEALLOCATE ViewCursor
	END

	DECLARE ViewCursor CURSOR STATIC
	FOR
	SELECT QUOTENAME([schemaName]) + '.' + QUOTENAME([name])
	FROM @tempViews
	WHERE [isSchemaBound] = 0

	OPEN ViewCursor

	FETCH NEXT
	FROM ViewCursor
	INTO @viewName

	WHILE @@FETCH_STATUS = 0
	BEGIN
		BEGIN TRY
			SET @viewCount = @viewCount + 1

			DECLARE @sqlCommand AS NVARCHAR(MAX) = QUOTENAME(@serverName) + '.' + QUOTENAME(@databaseName) + 
				'.dbo.sp_refreshsqlmodule ''' + @viewName + ''''

			EXEC (@sqlCommand)

			SET @viewOkCount = @viewOkCount + 1
			-- NOTE: Produces to many log entries. Therefore trace is used which will only be printed. For debug logTrace could be set to 1.
			SET @tmpMsg = 'Überprüfung der Sicht ' + @viewName + ': OK'

			EXEC dbo.sp_trace @opId
				,@tmpMsg
				,@owner
				,@serverName
		END TRY

		BEGIN CATCH
			SET @tmpMsg = 'Fehler bei der Überprüfung der Sicht ' + @viewName + ' in Datenbank ' + QUOTENAME(@databaseName) + 
				'. Fehlermeldung: ' + ERROR_MESSAGE()

			EXEC dbo.sp_warn @opId
				,@tmpMsg
				,@owner
				,@serverName
		END CATCH

		FETCH NEXT
		FROM ViewCursor
		INTO @viewName
	END

	CLOSE ViewCursor

	DEALLOCATE ViewCursor
END

SET @tmpMsg = 'Überprüfung der Sichten beendet. ' + CAST(@viewOkCount AS NVARCHAR(12)) + ' von ' + CAST(@viewCount AS NVARCHAR(12)) + 
	' sind OK'

EXEC dbo.sp_info @opId
	,@tmpMsg
	,@owner
	,@serverName

-- CHECK FOR WARNINGS AND SEND E-MAIL
DECLARE @warnings AS NVARCHAR(MAX) = dbo.fn_getLogs(@opId, 'WARNUNG', @owner)

IF NOT @warnings = ''
BEGIN
	IF @notifyOperator = 1
	BEGIN
		SET @tmpMsg = 'Beim Überprüfen der Sichten auf Konsistenz sind Warnungen aufgetreten!' + dbo.fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Warnungen:' + dbo.fn_newline() + @warnings
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

		EXEC dbo.sp_notifyOperator @subject = N'(CHECK) Fehler'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	UPDATE [dbo].[ViewCheckDetails]
	SET [EndTime] = GETDATE()
		,[Status] = 'Fehler'
	WHERE OperationId = @opId
		AND Id = @detailsId
END
ELSE
BEGIN
	IF @notifyOperator = 1
	BEGIN
		SET @tmpMsg = 'Das Überprüfen der Sichten war erfolgreich!' + dbo.fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

		EXEC dbo.sp_notifyOperator @subject = N'(CHECK) Erfolg'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	UPDATE [dbo].[ViewCheckDetails]
	SET [EndTime] = GETDATE()
		,[Status] = 'Erfolg'
	WHERE OperationId = @opId
		AND Id = @detailsId
END

RETURN (0)
GO

PRINT N'[dbo].[sp_createBackup] wird geändert....';
GO

-- =============================================
-- Author:		Thomas Joscht
-- Create date: 18.12.2017
-- Description:	Creates a database backup.
-- =============================================
ALTER PROCEDURE [dbo].[sp_createBackup] @baseDirectory VARCHAR(1024) -- e.g. 'S:\Backup\täglich\'
	,@databaseName VARCHAR(1024) -- name of the database
	,@serverName AS NVARCHAR(500) = @@SERVERNAME -- name of the server
	,@backupType AS NVARCHAR(50) = 'FULL' -- allowed types are FULL, DIFF, LOG, FULLCOPYONLY, LOGCOPYONLY
	,@retainDays AS INT = 0 -- e.g. 1 day, 0 means infinite days
	,@retainQuantity AS INT = 0 -- e.g. 1 backup file, 0 means infinite backup files
	,@autoShrink AS BIT = 1 -- execute a shrink before backup
	,@viewCheck AS BIT = 0 -- checks all views before backup
	,@restoreVerify AS BIT = 0 -- executes a restore verify after creation of backup
	,@createSubDirectory AS BIT = 1
	-- 1 = backup is saved in a subdirectory which is named equal to the database name. 0 = backup is saved in baseDirectory.
	,@notifyOperator AS BIT = 1 -- 0 = no mails, 1 = notify operator by email
	,@operatorName AS NVARCHAR(500) = NULL -- (optional) name of operator. Will override default operator of configuration.
	,@opId AS UNIQUEIDENTIFIER = 0x0
AS
SET NOCOUNT ON;

DECLARE @tmpMsg AS NVARCHAR(MAX) = ''

SELECT @opId = CASE 
		WHEN @opId = 0x0
			THEN NEWID()
		ELSE @opId
		END

-- check valid backup type
SET @backupType = UPPER(@backupType)

DECLARE @supportedBackupTypes AS NVARCHAR(1024) = ';FULL;DIFF;LOG;FULLCOPYONLY;LOGCOPYONLY;'

IF CHARINDEX(';' + @backupType + ';', @supportedBackupTypes) = 0
BEGIN
	SET @tmpMsg = 'Not supported backup type ' + @backupType + '. Valid types are: ' + @supportedBackupTypes

	RAISERROR (
			@tmpMsg
			,16
			,1
			)

	RETURN (1)
END

-- clean names
SET @databaseName = CONVERT(SYSNAME, dbo.fn_prepareName(@databaseName))
SET @serverName = CONVERT(SYSNAME, dbo.fn_prepareName(@serverName))

-- log backup operation
INSERT INTO [dbo].[BackupDetails] (
	[DatabaseName]
	,[ServerName]
	,[OperationId]
	,[BackupType]
	,[StartTime]
	,[EndTime]
	,[BaseDirectory]
	,[RetainDays]
	,[Status]
	)
VALUES (
	@databaseName
	,@serverName
	,@opId
	,@backupType
	,GETDATE()
	,NULL
	,@baseDirectory
	,@retainDays
	,'Gestartet'
	)

DECLARE @detailsId INT = @@IDENTITY
DECLARE @owner AS NVARCHAR(500) = 'CreateBackup_' + CAST(@detailsId AS NVARCHAR(11))

SET @tmpMsg = 'Erstellen des Backups von ' + QUOTENAME(@databaseName) + ' gestartet'

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
	DECLARE @backupFileName AS VARCHAR(1024)
	DECLARE @backupDBName AS VARCHAR(255)
	DECLARE @backupDirectory AS VARCHAR(1024)

	SET @backupDirectory = dbo.fn_preparePath(@baseDirectory + '/' + CASE 
				WHEN @createSubDirectory = 1
					THEN @databaseName
				ELSE ''
				END)
	-- NOTE: File extension missing. Will be added later!
	SET @backupDBName = dbo.fn_getBackupFileName(@databaseName)
	SET @backupFileName = dbo.fn_preparePath(@backupDirectory + '/' + @backupDBName)

	IF @viewCheck = 1
	BEGIN
		-- check views
		EXEC sp_checkDatabaseViews @databaseName = @databaseName
			,@serverName = @serverName
			,@notifyOperator = 0
			,@operatorName = @operatorName
			,@opId = @opId
	END

	IF @autoShrink = 1
	BEGIN
		-- shrink log file
		EXEC sp_shrinkDatabase @databaseName
			,@serverName
			,@opId
	END

	BEGIN TRY
		-- determine recovery model
		DECLARE @recoveryModel AS INT

		EXEC @recoveryModel = dbo.sp_getRecoveryModel @databaseName
			,@serverName

		-- CREATE BACKUP DIRECTORY
		SET @tmpMsg = 'Erstelle Backupordner ' + @backupDirectory

		EXEC dbo.sp_debug @opId
			,@tmpMsg
			,@owner
			,@serverName

		DECLARE @createDirSQL AS NVARCHAR(4000) = 'EXECUTE ' + QUOTENAME(@serverName) + '.master.dbo.xp_create_subdir ''' + 
			@backupDirectory + ''''

		EXEC sp_executesql @createDirSQL

		-- set file extension
		DECLARE @fileExtension AS NVARCHAR(4) = ''

		IF @backupType = 'FULL'
			OR @backupType = 'FULLCOPYONLY'
		BEGIN
			SET @fileExtension = 'bak'
		END
		ELSE IF @backupType = 'DIFF'
		BEGIN
			SET @fileExtension = 'dif'
		END
		ELSE IF @backupType = 'LOG'
			OR @backupType = 'LOGCOPYONLY'
		BEGIN
			SET @fileExtension = 'trn'
		END

		SET @backupFileName = @backupFileName + '.' + @fileExtension
		SET @tmpMsg = 'Erstelle Backup der Datenbank ' + QUOTENAME(@databaseName) + ' auf ' + @backupFileName

		EXEC dbo.sp_info @opId
			,@tmpMsg
			,@owner
			,@serverName

		UPDATE [dbo].[BackupDetails]
		SET [BackupFileName] = @backupFileName
		WHERE OperationId = @opId
			AND Id = @detailsId

		DECLARE @backupSuccess AS BIT = 0

		-- CREATE BACKUP. NOTE: Depends on type and recovery model!
		IF @backupType = 'FULL'
		BEGIN
			DECLARE @createFullBackupSQL AS NVARCHAR(4000) = 'BACKUP DATABASE ' + QUOTENAME(@databaseName) + ' TO DISK = N''' + 
				@backupFileName + '''
			WITH RETAINDAYS = ' + CONVERT(NVARCHAR(50), @retainDays) + 
				'
				,COMPRESSION
				,NOFORMAT
				,NOINIT
				,NAME = ''' + @backupDBName + 
				'''
				,SKIP
				,REWIND
				,NOUNLOAD
				,STATS = 10
				,CHECKSUM'

			EXEC sp_executeSqlLinked @createFullBackupSQL
				,@serverName

			SET @backupSuccess = 1
		END
		ELSE IF @backupType = 'DIFF'
		BEGIN
			DECLARE @createDiffBackupSQL AS NVARCHAR(4000) = 'BACKUP DATABASE ' + QUOTENAME(@databaseName) + ' TO DISK = N''' + 
				@backupFileName + '''
		WITH RETAINDAYS = ' + CONVERT(NVARCHAR(50), @retainDays) + 
				'
			,COMPRESSION
			,NOFORMAT
			,NOINIT
			,NAME = ''' + @backupDBName + 
				'''
			,SKIP
			,REWIND
			,NOUNLOAD
			,STATS = 10
			,CHECKSUM
			,DIFFERENTIAL'

			EXEC sp_executeSqlLinked @createDiffBackupSQL
				,@serverName

			SET @backupSuccess = 1
		END
		ELSE IF @backupType = 'LOG'
		BEGIN
			IF @recoveryModel = 1
			BEGIN
				DECLARE @createLogBackupSql AS NVARCHAR(4000) = 'BACKUP LOG ' + QUOTENAME(@databaseName) + ' TO DISK = N''' + 
					@backupFileName + '''
			WITH RETAINDAYS = ' + CONVERT(NVARCHAR(50), @retainDays) + 
					'
			,COMPRESSION
				,NOFORMAT
				,NOINIT
				,NAME = ''' + @backupDBName + 
					'''
				,SKIP
				,REWIND
				,NOUNLOAD
				,STATS = 10
				,CHECKSUM'

				EXEC sp_executeSqlLinked @createLogBackupSql
					,@serverName

				SET @backupSuccess = 1
			END
			ELSE
			BEGIN
				EXEC dbo.sp_error @opId
					,
					'Backup der Datenbank mit dem Typ LOG nicht möglich. Es werden nur Datenbanken mit dem Wiederherstellungsmodell Vollständig unterstützt.'
					,@owner
					,@serverName
			END
		END
		ELSE IF @backupType = 'FULLCOPYONLY'
		BEGIN
			DECLARE @createFullCopyOnlyBackupSQL AS NVARCHAR(4000) = 'BACKUP DATABASE ' + QUOTENAME(@databaseName) + 
				' TO DISK = N''' + @backupFileName + '''
		WITH RETAINDAYS = ' + CONVERT(NVARCHAR(50), @retainDays) + 
				'
			,COMPRESSION
			,NOFORMAT
			,NOINIT
			,NAME = ''' + @backupDBName + 
				'''
			,SKIP
			,REWIND
			,NOUNLOAD
			,STATS = 10
			,CHECKSUM
			,COPY_ONLY'

			EXEC sp_executeSqlLinked @createFullCopyOnlyBackupSQL
				,@serverName

			SET @backupSuccess = 1
		END
		ELSE IF @backupType = 'LOGCOPYONLY'
		BEGIN
			IF @recoveryModel = 1
			BEGIN
				DECLARE @createLogCopyOnlyBackupSQL AS NVARCHAR(4000) = 'BACKUP LOG ' + QUOTENAME(@databaseName) + 
					' TO DISK = N''' + @backupFileName + '''
		WITH RETAINDAYS = ' + CONVERT(NVARCHAR(50), @retainDays) + 
					'
			,COMPRESSION
			,NOFORMAT
			,NOINIT
			,NAME = ''' + @backupDBName + 
					'''
			,SKIP
			,REWIND
			,NOUNLOAD
			,STATS = 10
			,CHECKSUM
			,COPY_ONLY'

				EXEC sp_executeSqlLinked @createLogCopyOnlyBackupSQL
					,@serverName

				SET @backupSuccess = 1
			END
			ELSE
			BEGIN
				EXEC dbo.sp_error @opId
					,
					'Backup der Datenbank mit dem Typ LOGCOPYONLY nicht möglich. Es werden nur Datenbanken mit dem Wiederherstellungsmodell Vollständig unterstützt.'
					,@owner
					,@serverName
			END
		END

		IF @backupSuccess = 1
		BEGIN
			SET @tmpMsg = 'Backup der Datenbank ' + QUOTENAME(@databaseName) + ' erfolgreich erstellt'

			EXEC dbo.sp_debug @opId
				,@tmpMsg
				,@owner
				,@serverName

			-- SIMPLE VERIFY BACKUP
			DECLARE @verifySQL AS NVARCHAR(4000) = 'RESTORE VERIFYONLY
			FROM DISK = N''' + @backupFileName + 
				'''
			WITH FILE = 1
				,NOUNLOAD
				,NOREWIND'

			EXEC sp_executeSqlLinked @verifySQL
				,@serverName
		END

		-- EXTENDED VERIFY BACKUP
		IF @backupSuccess = 1
			AND @restoreVerify = 1
		BEGIN
			DECLARE @restoreVerifyDynamicNamingActive AS BIT = CAST(dbo.fn_getConfig('restoreVerifyDynamicNamingActive', 
						@serverName) AS BIT)

			EXEC dbo.sp_restoreVerifyBackup @backupFileName = @backupFileName
				,@databaseName = @databaseName
				,@serverName = @serverName
				,@restoreVerifyDynamicNamingActive = @restoreVerifyDynamicNamingActive
				,@notifyOperator = 0
				,@operatorName = @operatorName
				,@opId = @opId
		END

		-- CLEAN old backups
		IF @backupSuccess = 1
			AND @retainDays > 0
		BEGIN
			BEGIN TRY
				-- add 12 hours for avoiding tight deletion miss
				DECLARE @validFrom AS NVARCHAR(19) = CONVERT(NVARCHAR(19), DATEADD(day, - @retainDays, DATEADD(hour, 12, 
								SYSDATETIME())), 127)

				SET @tmpMsg = 'Aufräumen aller Backups in ' + @backupDirectory + ' älter als ' + @validFrom

				EXEC dbo.sp_info @opId
					,@tmpMsg
					,@owner
					,@serverName

				DECLARE @cleanSQL AS NVARCHAR(4000) = 'EXECUTE ' + QUOTENAME(@serverName) + 
					'.master.dbo.xp_delete_file 0
				,''' + @backupDirectory + '''
				,N''' + @fileExtension + '''
				,''' 
					+ @validFrom + '''
				,1'

				EXEC sp_executeSqlLinked @cleanSQL
					,@serverName

				SET @tmpMsg = 'Aufräumen der alten Backups war erfolgreich'

				EXEC dbo.sp_info @opId
					,@tmpMsg
					,@owner
					,@serverName
			END TRY

			BEGIN CATCH
				SET @tmpMsg = 'Fehler beim Aufräumen der alten Backups in ' + @backupDirectory + '. Fehlermeldung: ' + 
					ERROR_MESSAGE()

				EXEC dbo.sp_error @opId
					,@tmpMsg
					,@owner
					,@serverName
			END CATCH
		END

		-- CLEAN backups quantity
		IF @backupSuccess = 1
			AND @retainQuantity > 0
		BEGIN
			BEGIN TRY
				SET @tmpMsg = 'Aufräumen aller überflüssigen Backups in ' + @backupDirectory + '. Maximal ' + CONVERT(NVARCHAR(50
						), @retainQuantity) + ' Versionen werden behalten.'

				EXEC dbo.sp_info @opId
					,@tmpMsg
					,@owner
					,@serverName

				-- read existing files and directories
				DECLARE @dirTreeSql AS NVARCHAR(4000) = 'EXEC master.dbo.xp_dirtree ''' + @backupDirectory + ''', 1, 1'
				DECLARE @dirTree TABLE (
					id INT IDENTITY(1, 1)
					,entryName NVARCHAR(512)
					,depth INT
					,isFile BIT
					,backupTimestamp NVARCHAR(1024)
					);

				INSERT INTO @dirTree (
					entryName
					,depth
					,isFile
					)
				EXEC sp_executeSqlLinked @dirTreeSql
					,@serverName

				-- ignore directories 
				DELETE
				FROM @dirTree
				WHERE isFile <> 1

				-- only keep backups
				DELETE
				FROM @dirTree
				WHERE NOT entryName LIKE '%.' + @fileExtension

				-- determine timestamp of backups
				UPDATE @dirTree
				SET backupTimestamp = dbo.fn_getBackupTimestamp(entryName)

				-- keep quantity backup files
				DECLARE @i AS INT = @retainQuantity

				WHILE (@i > 0)
				BEGIN
					WITH files
					AS (
						SELECT TOP 1 *
						FROM @dirTree
						ORDER BY backupTimestamp DESC
						)
					DELETE
					FROM files

					SET @i = @i - 1
				END

				-- delete all remaining files
				DECLARE @fileName AS NVARCHAR(1024)
				DECLARE @filePath AS NVARCHAR(1024)

				DECLARE FileCursor CURSOR STATIC
				FOR
				SELECT entryName
				FROM @dirTree
				ORDER BY backupTimestamp

				OPEN FileCursor

				FETCH NEXT
				FROM FileCursor
				INTO @fileName

				WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @filePath = dbo.fn_preparePath(@backupDirectory + '/' + @fileName)
					SET @tmpMsg = 'Delete file ' + @filePath

					EXEC dbo.sp_debug @opId
						,@tmpMsg
						,@owner
						,@serverName

					EXEC dbo.sp_deleteFile @filePath = @filePath
						,@serverName = @serverName

					FETCH NEXT
					FROM FileCursor
					INTO @fileName
				END

				SET @tmpMsg = 'Aufräumen der überflüssigen Backups war erfolgreich'

				EXEC dbo.sp_info @opId
					,@tmpMsg
					,@owner
					,@serverName
			END TRY

			BEGIN CATCH
				SET @tmpMsg = 'Fehler beim Aufräumen der überflüssiger Backups in ' + @backupDirectory + '. Fehlermeldung: ' + 
					ERROR_MESSAGE()

				EXEC dbo.sp_error @opId
					,@tmpMsg
					,@owner
					,@serverName
			END CATCH
		END
	END TRY

	BEGIN CATCH
		SET @tmpMsg = 'Fehler beim Durchführen des Backups ' + @backupFileName + '. Fehlermeldung: ' + ERROR_MESSAGE()

		EXEC dbo.sp_error @opId
			,@tmpMsg
			,@owner
			,@serverName
	END CATCH
END

SET @tmpMsg = 'Erstellen des Backups beendet'

EXEC dbo.sp_info @opId
	,@tmpMsg
	,@owner
	,@serverName

-- CHECK FOR ERRORS
DECLARE @errors AS NVARCHAR(MAX) = dbo.fn_getErrors(@opId, @owner)

IF NOT @errors = ''
BEGIN
	IF @notifyOperator = 1
	BEGIN
		SET @tmpMsg = 'Es sind Fehler während des Backups der Datenbank ' + QUOTENAME(@serverName) + '.' + QUOTENAME(
				@databaseName) + ' nach ' + @baseDirectory + ' aufgetreten!' + dbo.fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Fehler:' + dbo.fn_newline() + @errors
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

		EXEC dbo.sp_notifyOperator @subject = N'(BACKUP) Fehler'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	UPDATE [dbo].[BackupDetails]
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
		SET @tmpMsg = 'Das Backup der Datenbank ' + QUOTENAME(@serverName) + '.' + QUOTENAME(@databaseName) + ' nach ' + 
			@baseDirectory + ' war erfolgreich!' + dbo.fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

		EXEC dbo.sp_notifyOperator @subject = N'(BACKUP) Erfolg'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	UPDATE [dbo].[BackupDetails]
	SET [EndTime] = GETDATE()
		,[Status] = 'Erfolg'
	WHERE OperationId = @opId
		AND Id = @detailsId

	RETURN (0)
END
GO

PRINT N'[dbo].[sp_createBackups] wird geändert....';
GO

--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 02.03.2018
-- Description:	Creates backups of all databases.
-- =============================================
ALTER PROCEDURE [dbo].[sp_createBackups] @baseDirectory VARCHAR(1024) -- e.g. 'S:\Backup\täglich\'
	,@databaseSearchStrings NVARCHAR(MAX) -- comma separated list of database search strings	
	,@serverName AS NVARCHAR(500) = @@SERVERNAME -- name of the server
	,@backupType AS NVARCHAR(50) = 'FULL' -- allowed types are FULL, DIFF, LOG, FULLCOPYONLY, LOGCOPYONLY
	,@retainDays AS INT = 0 -- e.g. 1 day, 0 means infinite days
	,@retainQuantity AS INT = 0 -- e.g. 1 backup file, 0 means infinite backup files
	,@autoShrink AS BIT = 1 -- execute a shrink before backup
	,@viewCheck AS BIT = 0 -- checks all views before backup
	,@restoreVerify AS BIT = 0 -- executes a restore verify after creation of backup
	,@createSubDirectory AS BIT = 1
	-- 1 = backup is saved in a subdirectory which is named equal to the database name. 0 = backup is saved in baseDirectory.
	,@notifyOperator AS BIT = 1 -- 0 = no mails, 1 = notify operator by email
	,@operatorName AS NVARCHAR(500) = NULL -- (optional) name of operator. Will override default operator of configuration.
	,@opId AS UNIQUEIDENTIFIER = 0x0
AS
SET NOCOUNT ON;

DECLARE @tmpMsg AS NVARCHAR(MAX) = ''

SELECT @opId = CASE 
		WHEN @opId = 0x0
			THEN NEWID()
		ELSE @opId
		END

DECLARE @pos INT = 0
DECLARE @len INT = 0
DECLARE @index INT = 0
DECLARE @databaseSearchString VARCHAR(8000)
DECLARE @databaseName VARCHAR(8000)
DECLARE @databaseNamesCount INT = 0
DECLARE @returnCode BIT = 0
DECLARE @owner AS NVARCHAR(500) = 'CreateBackups'
DECLARE @databaseNames TABLE ([DatabaseName] VARCHAR(1024));

SET @tmpMsg = 'Erstelle Backups fuer die Liste an Suchkriterien ' + @databaseSearchStrings

EXEC dbo.sp_debug @opId
	,@tmpMsg
	,@owner
	,@serverName

-- Split database search strings and iterate over all. NOTE: @databaseSearchStrings must end with a comma ","!
SET @databaseSearchStrings = @databaseSearchStrings + ','

WHILE CHARINDEX(',', @databaseSearchStrings, @pos + 1) > 0
BEGIN
	SET @index = @index + 1
	SET @len = CHARINDEX(',', @databaseSearchStrings, @pos + 1) - @pos
	SET @databaseSearchString = dbo.fn_prepareName(SUBSTRING(@databaseSearchStrings, @pos, @len))
	SET @tmpMsg = 'Erstelle Backups fuer ' + CAST(@index AS NVARCHAR(11)) + '. Suchkriterium ' + @databaseSearchString

	EXEC dbo.sp_debug @opId
		,@tmpMsg
		,@owner
		,@serverName

	DELETE
	FROM @databaseNames

	-- @databaseSearchString can return multiple databases
	INSERT INTO @databaseNames
	EXEC [sp_getDatabaseNames] @databaseSearchString

	SET @databaseNamesCount = 0

	SELECT @databaseNamesCount = count(*)
	FROM @databaseNames

	SET @tmpMsg = 'Anzahl gefundener Datenbanken anhand des Suchkriteriums: ' + CAST(@databaseNamesCount AS NVARCHAR(11))

	EXEC dbo.sp_debug @opId
		,@tmpMsg
		,@owner
		,@serverName

	IF CURSOR_STATUS('global', 'DatabaseCursor') >= - 1
	BEGIN
		DEALLOCATE DatabaseCursor
	END

	DECLARE DatabaseCursor CURSOR STATIC
	FOR
	SELECT [DatabaseName]
	FROM @databaseNames

	OPEN DatabaseCursor

	FETCH NEXT
	FROM DatabaseCursor
	INTO @databaseName

	DECLARE @returnCodeSubTask BIT;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @databaseName <> ''
		BEGIN
			SET @databaseName = CONVERT(SYSNAME, @databaseName)

			-- create Backup
			EXEC @returnCodeSubTask = sp_createBackup @baseDirectory = @baseDirectory
				,@databaseName = @databaseName
				,@serverName = @serverName
				,@backupType = @backupType
				,@retainDays = @retainDays
				,@retainQuantity = @retainQuantity
				,@autoShrink = @autoShrink
				,@viewCheck = @viewCheck
				,@restoreVerify = @restoreVerify
				,@createSubDirectory = @createSubDirectory
				,@notifyOperator = 0
				,@operatorName = @operatorName
				,@opId = @opId
		END

		-- If any createBackup returns an error code createBackups returns an error code
		IF (@returnCodeSubTask <> 0)
		BEGIN
			SET @returnCode = 1
		END

		FETCH NEXT
		FROM DatabaseCursor
		INTO @databaseName
	END

	CLOSE DatabaseCursor

	DEALLOCATE DatabaseCursor

	SET @pos = CHARINDEX(',', @databaseSearchStrings, @pos + @len) + 1
END

SET @tmpMsg = 'Erstellen der Backups beendet'

EXEC dbo.sp_info @opId
	,@tmpMsg
	,@owner
	,@serverName

-- CHECK FOR ERRORS
DECLARE @errors AS NVARCHAR(MAX) = dbo.fn_getErrors(@opId, @owner)

IF NOT @errors = ''
	OR @returnCode = 1
BEGIN
	IF @notifyOperator = 1
	BEGIN
		SET @tmpMsg = 'Es sind Fehler während der Backups nach ' + @baseDirectory + ' aufgetreten!' + dbo.fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Fehler:' + dbo.fn_newline() + @errors
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

		EXEC dbo.sp_notifyOperator @subject = N'(BACKUP) Fehler'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	RETURN (1)
END
ELSE
BEGIN
	IF @notifyOperator = 1
	BEGIN
		SET @tmpMsg = 'Die Backups der Datenbanken war erfolgreich!' + dbo.fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

		EXEC dbo.sp_notifyOperator @subject = N'(BACKUP) Erfolg'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	RETURN (0)
END
GO

PRINT N'[dbo].[sp_runBackupJob] wird geändert....';
GO

-- =============================================
-- Author:		Thomas Joscht
-- Create date: 27.02.2018
-- Description:	Runs a configured backup job.
-- =============================================
ALTER PROCEDURE [dbo].[sp_runBackupJob] @jobId AS INT
	,@opId AS UNIQUEIDENTIFIER = 0x0
AS
SET NOCOUNT ON;

DECLARE @tmpMsg AS NVARCHAR(MAX) = ''

SELECT @opId = CASE 
		WHEN @opId = 0x0
			THEN NEWID()
		ELSE @opId
		END

DECLARE @owner AS NVARCHAR(500) = 'RunBackupJob'
DECLARE @jobFound AS BIT = 0
DECLARE @backupJobName AS NVARCHAR(500) = ''
DECLARE @serverName AS NVARCHAR(500) = ''
DECLARE @databaseNames AS NVARCHAR(MAX) = ''
DECLARE @retainDays AS INT = 0
DECLARE @retainQuantity AS INT = 0
DECLARE @restoreVerify AS BIT = 0
DECLARE @autoShrink AS BIT = 0
DECLARE @viewCheck AS BIT = 0
DECLARE @createSubDirectory AS BIT = 1
DECLARE @baseDirectory AS NVARCHAR(1024) = ''
DECLARE @backupType AS NVARCHAR(50) -- allowed types are FULL, DIFF, LOG, FULLCOPYONLY, LOGCOPYONLY
DECLARE @operatorName AS NVARCHAR(500) = NULL -- NOTE: Make this configurable

-- read backup job parameters
SELECT @jobFound = 1
	,@backupJobName = [Name]
	,@serverName = [ServerName]
	,@databaseNames = [DatabaseNames]
	,@baseDirectory = [BaseDirectory]
	,@backupType = [BackupType]
	,@retainDays = [RetainDays]
	,@retainQuantity = [RetainQuantity]
	,@restoreVerify = [RestoreVerify]
	,@autoShrink = [AutoShrink]
	,@viewCheck = [ViewCheck]
	,@createSubDirectory = [CreateSubDirectory]
FROM [dbo].[BackupJobs]
WHERE [Id] = @jobId

IF @jobFound <> 1
BEGIN
	SET @tmpMsg = 'Backup-Auftrag mit Id ' + CAST(@jobId AS NVARCHAR(50)) + ' wurde nicht gefunden!'

	EXEC dbo.sp_error @opId
		,@tmpMsg
		,@owner

	RETURN
END

-- clean names
SET @databaseNames = dbo.fn_prepareName(@databaseNames)
SET @serverName = CONVERT(SYSNAME, dbo.fn_prepareName(@serverName))

INSERT INTO [dbo].[BackupJobDetails] (
	[BackupJobId]
	,[OperationId]
	,[StartTime]
	,[EndTime]
	,[Status]
	)
VALUES (
	@jobId
	,@opId
	,GETDATE()
	,NULL
	,'Gestartet'
	)

DECLARE @detailsId INT = @@IDENTITY

SET @owner = 'RunBackupJob_' + CAST(@detailsId AS NVARCHAR(11))
SET @tmpMsg = 'Starte Backup-Auftrag ' + @backupJobName + ' (' + CAST(@jobId AS NVARCHAR(50)) + ')'

EXEC dbo.sp_info @opId
	,@tmpMsg
	,@owner
	,@serverName

-- CHECK FREE SPACE THRESHOLD
DECLARE @freeSpaceCheckActive AS BIT = CAST(dbo.fn_getConfig('FreeSpaceCheckActive', @serverName) AS BIT)
DECLARE @freeSpaceThresholdDrive AS NVARCHAR(500) = dbo.fn_getConfig('FreeSpaceThresholdDrive', @serverName)
DECLARE @freeSpaceThresholdMb AS INT = CAST(dbo.fn_getConfig('FreeSpaceThresholdMb', @serverName) AS INT)
DECLARE @freeMb AS INT = 0
DECLARE @retCode BIT = 0

IF @freeSpaceCheckActive = 1
BEGIN
	SET @tmpMsg = 'Überprüfe freien Speicherplatz auf ' + @freeSpaceThresholdDrive + ' mit Grenzwert ' + CAST(
			@freeSpaceThresholdMb AS NVARCHAR(500)) + ' MB'

	EXEC dbo.sp_info @opId
		,@tmpMsg
		,@owner
		,@serverName

	EXEC @freeMb = sp_getFreeDriveSpace @freeSpaceThresholdDrive
		,@serverName

	IF @freeSpaceThresholdMb > @freeMb
	BEGIN
		SET @tmpMsg = 'Nicht genügend freier Speicherplatz vorhanden: ' + CAST(@freeMb AS NVARCHAR(500)) + 
			' MB frei. Der Grenzwert ist auf ' + CAST(@freeSpaceThresholdMb AS NVARCHAR(500)) + 
			' MB eingestellt. Backup-Auftrag wid abgebrochen.'

		EXEC dbo.sp_error @opId
			,@tmpMsg
			,@owner
			,@serverName
	END
	ELSE
	BEGIN
		SET @tmpMsg = 'Es ist genügend freier Speicherplatz vorhanden: ' + CAST(@freeMb AS NVARCHAR(500)) + ' MB frei.'

		EXEC dbo.sp_info @opId
			,@tmpMsg
			,@owner
			,@serverName
	END
END

IF @freeSpaceCheckActive = 0
	OR @freeSpaceThresholdMb < @freeMb
BEGIN
	BEGIN TRY
		EXEC @retCode = sp_createBackups @baseDirectory = @baseDirectory
			,@databaseSearchStrings = @databaseNames
			,@serverName = @serverName
			,@backupType = @backupType
			,@retainDays = @retainDays
			,@retainQuantity = @retainQuantity
			,@autoShrink = @autoShrink
			,@viewCheck = @viewCheck
			,@restoreVerify = @restoreVerify
			,@createSubDirectory = @createSubDirectory
			,@notifyOperator = 0
			,@operatorName = @operatorName
			,@opId = @opId
	END TRY

	BEGIN CATCH
		SET @tmpMsg = 'Fehler während des Backup-Auftrags ' + @backupJobName + ' (' + CAST(@jobId AS NVARCHAR(50)) + 
			'). Fehlermeldung: ' + ERROR_MESSAGE()

		EXEC dbo.sp_error @opId
			,@tmpMsg
			,@owner
			,@serverName
	END CATCH
END

SET @tmpMsg = 'Der Backup-Auftrag ' + @backupJobName + ' (' + CAST(@jobId AS NVARCHAR(50)) + ') wurde beendet'

EXEC dbo.sp_info @opId
	,@tmpMsg
	,@owner
	,@serverName

-- CHECK FOR ERRORS
DECLARE @errors AS NVARCHAR(MAX) = dbo.fn_getErrors(@opId, DEFAULT)

IF NOT @errors = ''
BEGIN
	SET @tmpMsg = 'Es sind Fehler während des Backup-Auftrags ' + @backupJobName + ' (' + CAST(@jobId AS NVARCHAR(50)) + 
		') aufgetreten!' + dbo.fn_newline()
	SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Fehler:' + dbo.fn_newline() + @errors
	SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', DEFAULT)

	EXEC dbo.sp_notifyOperator @subject = N'(BACKUP) Fehler'
		,@body = @tmpMsg
		,@name = @operatorName

	UPDATE [dbo].[BackupJobDetails]
	SET [EndTime] = GETDATE()
		,[Status] = 'Fehler'
	WHERE OperationId = @opId
		AND Id = @detailsId

	RETURN (1)
END
ELSE
BEGIN
	-- CHECK FOR WARNINGS
	DECLARE @warnings AS NVARCHAR(MAX) = dbo.fn_getLogs(@opId, 'WARNUNG', DEFAULT)

	IF NOT @warnings = ''
	BEGIN
		SET @tmpMsg = 'Der Backup-Auftrag ' + @backupJobName + ' (' + CAST(@jobId AS NVARCHAR(50)) + ') wurde mit Warnungen beendet!' 
			+ dbo.fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Warnungen:' + dbo.fn_newline() + @warnings
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', DEFAULT)

		EXEC dbo.sp_notifyOperator @subject = N'(BACKUP) Warnung'
			,@body = @tmpMsg
			,@name = @operatorName

		UPDATE [dbo].[BackupJobDetails]
		SET [EndTime] = GETDATE()
			,[Status] = 'Warnung'
		WHERE OperationId = @opId
			AND Id = @detailsId
	END
	ELSE
	BEGIN
		SET @tmpMsg = 'Der Backup-Auftrag ' + @backupJobName + ' (' + CAST(@jobId AS NVARCHAR(50)) + ') war erfolgreich!' + dbo.
			fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', DEFAULT)

		EXEC dbo.sp_notifyOperator @subject = N'(BACKUP) Erfolg'
			,@body = @tmpMsg
			,@name = @operatorName

		UPDATE [dbo].[BackupJobDetails]
		SET [EndTime] = GETDATE()
			,[Status] = 'Erfolg'
		WHERE OperationId = @opId
			AND Id = @detailsId
	END

	RETURN (0)
END
GO

PRINT N'[dbo].[sp_checkViews] wird aktualisiert....';
GO

EXECUTE sp_refreshsqlmodule N'[dbo].[sp_checkViews]';
GO

PRINT N'[dbo].[sp_runBackupJobByName] wird aktualisiert....';
GO

EXECUTE sp_refreshsqlmodule N'[dbo].[sp_runBackupJobByName]';
GO

/*
Vorlage für ein Skript nach der Bereitstellung							
--------------------------------------------------------------------------------------
 Diese Datei enthält SQL-Anweisungen, die an das Buildskript angefügt werden.		
 Schließen Sie mit der SQLCMD-Syntax eine Datei in das Skript nach der Bereitstellung ein.			
 Beispiel:   :r .\myfile.sql								
 Verwenden Sie die SQLCMD-Syntax, um auf eine Variable im Skript nach der Bereitstellung zu verweisen.		
 Beispiel:   :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
-- Default Configuration Parameter
-- NOTE: Existing parameter will not be overwritten!
MERGE INTO Config AS Target
USING (
	VALUES (
		'FreeSpaceCheckActive'
		,N'0'
		,
		'1 = execute a check for free space before performing a backup. if the threshold is not reached, the backup process aborts. 0 = no check'
		)
		,(
		'FreeSpaceThresholdMb'
		,N'50000'
		,'free space limit for the free space check'
		)
		,(
		'FreeSpaceThresholdDrive'
		,N'S'
		,'drive to check by the free space check'
		)
		,(
		'NotifyOperatorName'
		,N'Admins'
		,'name of the database mail operator'
		)
		,(
		'RestoreVerifyDynamicNamingActive'
		,N'0'
		,
		'1 = appends the backup file name in the database name and the data file name. this avoids collisions of concurrent backup processes. 0 = use default naming'
		)
	) AS Source([Key], [Value], [Description])
	ON Target.[Key] = Source.[Key]
		-- update matched rows 
WHEN MATCHED
	THEN
		UPDATE
		SET [Description] = Source.[Description]
			-- insert new rows 
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[Key]
			,[Value]
			,[Description]
			)
		VALUES (
			[Key]
			,[Value]
			,[Description]
			)
			-- delete rows that are in the target but not the source 
WHEN NOT MATCHED BY SOURCE
	THEN
		DELETE;
GO


GO

PRINT N'Update abgeschlossen.';
GO


