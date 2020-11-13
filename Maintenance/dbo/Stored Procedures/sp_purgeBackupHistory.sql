-- =============================================
-- Author:		Thomas Joscht
-- Create date: 08.05.2018
-- Description:	Purges the backup history in msdb.
-- =============================================
CREATE PROCEDURE [dbo].[sp_purgeBackupHistory] @serverName AS NVARCHAR(500) = @@SERVERNAME -- name of the server
	,@retainDays AS INT = 0 -- e.g. 31 means all backup entries older than 31 days will be deleted
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
SET @serverName = CONVERT(SYSNAME, dbo.fn_prepareName(@serverName))

DECLARE @owner AS NVARCHAR(500) = 'PurgeHistory'

SET @tmpMsg = 'Bereinigen der Backup-Historie älter als ' + CAST(@retainDays AS NVARCHAR(11)) + ' gestartet'

EXEC dbo.sp_info @opId
	,@tmpMsg
	,@owner
	,@serverName

BEGIN TRY
	-- delete backup history
	DECLARE @deleteBackupHistorySql AS NVARCHAR(4000) = '
DECLARE @oldestDate [smalldatetime] = GETDATE() - ' + CAST(
			@retainDays AS NVARCHAR(11)) + '
EXEC [msdb]..[sp_delete_backuphistory] @oldestDate;'

	EXEC sp_executeSqlLinked @deleteBackupHistorySql
		,@serverName
END TRY

BEGIN CATCH
	SET @tmpMsg = 'Fehler beim Bereinigen der Backup-Historie. Fehlermeldung: ' + ERROR_MESSAGE()

	EXEC dbo.sp_error @opId
		,@tmpMsg
		,@owner
		,@serverName
END CATCH

SET @tmpMsg = 'Bereinigen der Backup-Historie beendet'

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
		SET @tmpMsg = 'Es sind Fehler während der Bereinigung der Backup-Historie auf ' + QUOTENAME(@serverName) + 
			' aufgetreten!' + dbo.fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Fehler:' + dbo.fn_newline() + @errors
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

		EXEC dbo.sp_notifyOperator @subject = N'(CLEAN) Fehler'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	RETURN (1)
END
ELSE
BEGIN
	IF @notifyOperator = 1
	BEGIN
		SET @tmpMsg = 'Das Bereinigen der Backup-Historie auf ' + QUOTENAME(@serverName) + ' war erfolgreich!' + dbo.fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

		EXEC dbo.sp_notifyOperator @subject = N'(CLEAN) Erfolg'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	RETURN (0)
END
