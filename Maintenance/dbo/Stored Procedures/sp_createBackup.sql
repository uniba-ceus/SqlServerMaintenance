-- =============================================
-- Author:		Thomas Joscht
-- Create date: 18.12.2017
-- Description:	Creates a database backup.
-- =============================================
CREATE PROCEDURE [dbo].[sp_createBackup] @baseDirectory VARCHAR(1024) -- e.g. 'S:\Backup\täglich\'
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
