-- =============================================
-- Author:		Thomas Joscht
-- Create date: 18.12.2017
-- Description:	Checks all views.
-- =============================================
CREATE PROCEDURE [dbo].[sp_checkViews] @databaseNames VARCHAR(MAX) = 'msdb' -- comma separated list of database names
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
SET @databaseNames = dbo.fn_prepareName(@databaseNames)
SET @serverName = CONVERT(SYSNAME, dbo.fn_prepareName(@serverName))

DECLARE @owner AS NVARCHAR(500) = 'CheckViews'

SET @tmpMsg = 'Überprüfung aller Sichten der Datenbank(en)' + @databaseNames + ' gestartet'

EXEC dbo.sp_info @opId
	,@tmpMsg
	,@owner
	,@serverName

DECLARE @pos INT = 0
DECLARE @len INT = 0
DECLARE @databaseName VARCHAR(8000)

-- Split database names and iterate over all. NOTE: @databaseNames must end with a comma ","!
SET @databaseNames = @databaseNames + ','

WHILE CHARINDEX(',', @databaseNames, @pos + 1) > 0
BEGIN
	SET @len = CHARINDEX(',', @databaseNames, @pos + 1) - @pos
	SET @databaseName = CONVERT(SYSNAME, dbo.fn_prepareName(SUBSTRING(@databaseNames, @pos, @len)))

	IF @databaseName <> ''
	BEGIN
		EXEC sp_checkDatabaseViews @databaseName = @databaseName
			,@serverName = @serverName
			,@notifyOperator = 0
			,@operatorName = @operatorName
			,@opId = @opId
	END

	SET @pos = CHARINDEX(',', @databaseNames, @pos + @len) + 1
END

EXEC dbo.sp_info @opId
	,'Überprüfung aller Sichten beendet'
	,@owner
	,@serverName

-- CHECK FOR WARNINGS AND SEND E-MAIL
DECLARE @warnings AS NVARCHAR(MAX) = dbo.fn_getLogs(@opId, 'WARNUNG', DEFAULT)

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
END

RETURN (0)
