-- =============================================
-- Author:		Thomas Joscht
-- Create date: 29.12.2017
-- Description:	Shrinks a database in case it has recovery model simple.
-- =============================================
CREATE PROCEDURE [dbo].[sp_shrinkDatabase] @databaseName VARCHAR(1024)
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
