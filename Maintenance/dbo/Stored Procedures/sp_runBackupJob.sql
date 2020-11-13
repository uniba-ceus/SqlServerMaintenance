-- =============================================
-- Author:		Thomas Joscht
-- Create date: 27.02.2018
-- Description:	Runs a configured backup job.
-- =============================================
CREATE PROCEDURE [dbo].[sp_runBackupJob] @jobId AS INT
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
