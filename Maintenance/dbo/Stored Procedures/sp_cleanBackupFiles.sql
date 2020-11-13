-- =============================================
-- Author:	 Tobias Kiehl
-- Create date: 26.09.2018
-- Description: Checks for every BackupFileName in BackupDetails if the BackupFile is available. If not, deletes the record in BackupDetails and BackupCheckDetails.
-- =============================================
CREATE PROCEDURE dbo.[sp_cleanBackupFiles] @serverName AS NVARCHAR(500) = @@SERVERNAME -- name of the target server
	,@notifyOperator AS BIT = 1 -- 0 = no mails, 1 = notify operator by email
	,@operatorName AS NVARCHAR(500) = NULL -- (optional) name of operator. Will override default operator of configuration.
	,@opId AS UNIQUEIDENTIFIER = 0x0
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpMsg AS NVARCHAR(MAX) = ''
	DECLARE @owner AS NVARCHAR(500) = 'CleanBackupFiles'

	SELECT @opId = CASE 
			WHEN @opId = 0x0
				THEN NEWID()
			ELSE @opId
			END

	SET @tmpMsg = 'Beginne Bereinigung von Tabelle BackupDetails ...'

	EXEC dbo.sp_info @opId
		,@tmpMsg
		,@owner
		,@serverName

	DECLARE fileCursor CURSOR
	FOR
	SELECT Id
		,BackupFileName
	FROM BackupDetails
	WHERE ServerName = @serverName

	DECLARE @backupId INT
		,@backupFileName VARCHAR(1000)
		,@exists INT
		,@allExist BIT = 1;

	OPEN fileCursor

	FETCH NEXT
	FROM fileCursor
	INTO @backupId
		,@backupFileName

	IF @@FETCH_STATUS <> 0
	BEGIN
		SET @tmpMsg = 'Keine Einträge in Tabelle BackupDetails zur Überprüfung vorhanden'

		EXEC dbo.sp_info @opId
			,@tmpMsg
			,@owner
			,@serverName
	END

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC @exists = dbo.sp_fileExists @backupFileName
			,@serverName

		IF @exists <> 1
		BEGIN
			SET @tmpMsg = 'BackupFile ''' + @backupFileName + ''' existiert nicht'
			SET @allExist = 0;

			EXEC dbo.sp_info @opId
				,@tmpMsg
				,@owner
				,@serverName

			SET @tmpMsg = 'BackupFile ''' + @backupFileName + ''' mit ID ''' + CAST(@backupID AS VARCHAR(100)) + 
				''' wird aus BackupDetails und BackupCheckDetails gelöscht'

			EXEC dbo.sp_info @opId
				,@tmpMsg
				,@owner
				,@serverName

			DELETE
			FROM BackupCheckDetails
			WHERE BackupFileName = (
					SELECT BackupFileName
					FROM BackupDetails
					WHERE Id = @backupId
					)

			DELETE
			FROM BackupDetails
			WHERE Id = @backupId
		END
		ELSE
		BEGIN
			SET @tmpMsg = 'BackupFile ''' + @backupFileName + ''' existiert'

			EXEC dbo.sp_info @opId
				,@tmpMsg
				,@owner
				,@serverName
		END

		FETCH NEXT
		FROM fileCursor
		INTO @backupId
			,@backupFileName
	END

	CLOSE fileCursor

	DEALLOCATE fileCursor

	SET @tmpMsg = 'Bereinigung abgeschlossen'

	EXEC dbo.sp_info @opId
		,@tmpMsg
		,@owner
		,@serverName

	-- CHECK FOR WARNINGS AND SEND E-MAIL
	DECLARE @errors AS NVARCHAR(MAX) = dbo.fn_getErrors(@opId, @owner)

	IF NOT @errors = ''
	BEGIN
		IF @notifyOperator = 1
		BEGIN
			SET @tmpMsg = 'Es sind Fehler während der Bereinigung der Tabelle BackupDetails aufgetreten.' + dbo.fn_newline()
			SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Fehler:' + dbo.fn_newline() + @errors + dbo.fn_newline()
			SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

			EXEC dbo.sp_notifyOperator @subject = N'Backups bereinigen: Fehler'
				,@body = @tmpMsg
				,@name = @operatorName
		END

		RETURN (1)
	END
	ELSE
	BEGIN
		IF @notifyOperator = 1
		BEGIN
			SET @tmpMsg = 'Bereiningung von Tabelle BackupDetails abgeschlossen.' + dbo.fn_newline()

			IF @allExist = 1
			BEGIN
				SET @tmpMsg = @tmpMsg + 'Es existieren alle BackupFiles.' + dbo.fn_newline()
			END
			ELSE
			BEGIN
				SET @tmpMsg = @tmpMsg + 'Es wurden einige BackupFiles-Einträge gelöscht.' + dbo.fn_newline()
			END

			SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

			EXEC dbo.sp_notifyOperator @subject = N'Backups bereinigen: Erfolg'
				,@body = @tmpMsg
				,@name = @operatorName
		END

		RETURN (0)
	END
END
