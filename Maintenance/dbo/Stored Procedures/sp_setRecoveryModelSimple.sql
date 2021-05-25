-- =============================================
-- Author:		Thomas Joscht
-- Create date: 09.03.2021
-- Description:	Sets the recovery model to simple of given database (or all databases) except master, model, msdb, tempdb.
-- =============================================
CREATE PROCEDURE [dbo].[sp_setRecoveryModelSimple] @databaseName VARCHAR(500) = '%' -- name of the database
	,@serverName AS NVARCHAR(500) = @@SERVERNAME
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

DECLARE @sqlCommand VARCHAR(2000)
	,@dbname VARCHAR(64)
	,@logfile VARCHAR(128)

DECLARE c1 CURSOR
FOR
SELECT d.NAME
	,mf.NAME AS logfile --, physical_name AS current_file_location, size
FROM sys.master_files mf
INNER JOIN sys.databases d ON mf.database_id = d.database_id
WHERE recovery_model_desc <> 'SIMPLE'
	AND d.NAME LIKE @databaseName
	AND d.NAME NOT IN (
		'master'
		,'model'
		,'msdb'
		,'tempdb'
		)
	AND mf.type_desc = 'LOG'

OPEN c1

FETCH NEXT
FROM c1
INTO @dbname
	,@logfile

WHILE @@fetch_status <> - 1
BEGIN
	DECLARE @owner AS NVARCHAR(500) = 'SetRecoveryModelSimple'

	SET @tmpMsg = 'Änderung des Wiederherstullungsmodell der Datenbank ' + QUOTENAME(@databaseName) + ' zu Einfach'

	EXEC dbo.sp_info @opId
		,@tmpMsg
		,@owner
		,@serverName

	SELECT @sqlCommand = 'ALTER DATABASE ' + @dbname + ' SET RECOVERY SIMPLE'

	--PRINT @sqlCommand
	EXEC (@sqlCommand)

	SELECT @sqlCommand = 'USE ' + @dbname + ' checkpoint'

	--PRINT @sqlCommand
	EXEC (@sqlCommand)

	SELECT @sqlCommand = 'USE ' + @dbname + ' DBCC SHRINKFILE (' + @logfile + ', 1)'

	--PRINT @sqlCommand
	EXEC (@sqlCommand)

	FETCH NEXT
	FROM c1
	INTO @dbname
		,@logfile
END

CLOSE c1

DEALLOCATE c1

RETURN 0
