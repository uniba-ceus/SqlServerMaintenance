--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 02.03.2018
-- Description:	Creates backups of all databases.
-- =============================================
CREATE PROCEDURE [dbo].[sp_createBackups] @baseDirectory VARCHAR(1024) -- e.g. 'S:\Backup\täglich\'
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
