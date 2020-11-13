-- =============================================
-- Author:		Thomas Joscht
-- Create date: 28.02.2018
-- Description:	Runs a configured backup job. Determines the job by name.
-- =============================================
CREATE PROCEDURE [dbo].[sp_runBackupJobByName] @jobName AS NVARCHAR(500)
	,@opId AS UNIQUEIDENTIFIER = 0x0
AS
SET NOCOUNT ON;

DECLARE @tmpMsg AS NVARCHAR(MAX) = ''

SELECT @opId = CASE 
		WHEN @opId = 0x0
			THEN NEWID()
		ELSE @opId
		END

DECLARE @owner AS NVARCHAR(500) = 'RunBackupJobByName'
DECLARE @jobFound AS BIT = 0
DECLARE @jobId AS INT
DECLARE @returnCode BIT = 0

-- search for backup job
SELECT @jobFound = 1
	,@jobId = [Id]
FROM [dbo].[BackupJobs]
WHERE [Name] LIKE @jobName

IF @jobFound <> 1
BEGIN
	SET @tmpMsg = 'Backup-Auftrag ' + @jobName + ' wurde nicht gefunden!'

	EXEC dbo.sp_error @opId
		,@tmpMsg
		,@owner

	RETURN
END

EXEC @returnCode = dbo.sp_runBackupJob @jobId
	,@opId

RETURN @returnCode
