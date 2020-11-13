-- =============================================
-- Author:		Thomas Joscht
-- Create date: 02.03.2018
-- Description:	Checks the views of a database.
-- =============================================
CREATE PROCEDURE [dbo].[sp_checkDatabaseViews] @databaseName VARCHAR(500) -- name of the database
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
