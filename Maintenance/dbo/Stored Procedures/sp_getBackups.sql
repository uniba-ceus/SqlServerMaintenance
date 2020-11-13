-- =============================================
-- Author:		Tobias Kiehl
-- Create date: 11.09.2018
-- Description:	Checks if backups are available in a given folder structure and adds them to table BackupDetails. 
-- At the beginning all directories and files are collected. Starting with a root element full paths are derived.
-- =============================================
CREATE PROCEDURE dbo.[sp_getBackups] @baseDirectory VARCHAR(1024) -- e.g. 'S:\Backup\täglich\'
	,@serverName AS NVARCHAR(500) = @@SERVERNAME -- name of the target server
	,@backupType AS NVARCHAR(50) = 'FULL' -- allowed types are FULL, DIFF, LOG, FULLCOPYONLY, LOGCOPYONLY
	,@retainDays AS INT = 0 -- e.g. 1 day, 0 means infinite days
	,@autoShrink AS BIT = 1 -- execute a shrink before backup
	,@viewCheck AS BIT = 0 -- checks all views before backup
	,@restoreVerify AS BIT = 0 -- executes a restore verify after creation of backup
	,@notifyOperator AS BIT = 1 -- 0 = no mails, 1 = notify operator by email
	,@operatorName AS NVARCHAR(500) = NULL -- (optional) name of operator. Will override default operator of configuration.
	,@opId AS UNIQUEIDENTIFIER = 0x0
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpMsg AS NVARCHAR(MAX) = ''
	DECLARE @owner AS NVARCHAR(500) = 'GetBackups'
	DECLARE @getBackupsSQL AS NVARCHAR(4000) = 'EXEC master.sys.xp_dirtree ''' + @baseDirectory + ''', 0, 1'

	-- 0 = include subdirectories, 1 = include files
	SELECT @opId = CASE 
			WHEN @opId = 0x0
				THEN NEWID()
			ELSE @opId
			END

	IF OBJECT_ID('tempdb..#DirectoryTree') IS NOT NULL
		DROP TABLE #DirectoryTree;

	CREATE TABLE #DirectoryTree (
		id INT IDENTITY(1, 1)
		,directory VARCHAR(2000) -- filled by xp_dirtree
		,parentDirectoryID VARCHAR(2000) -- filled by xp_dirtree
		,depth INT
		,isfile BIT -- filled by xp_dirtree
		);

	-- clustered index to maintain order of files
	ALTER TABLE #DirectoryTree ADD CONSTRAINT PK_DirectoryTree PRIMARY KEY CLUSTERED (id);

	SET @baseDirectory = dbo.fn_preparePath(@baseDirectory)

	-- root element
	INSERT #DirectoryTree (
		directory
		,depth
		,isfile
		)
	VALUES (
		@baseDirectory
		,0
		,0
		);

	SET @tmpMsg = 'Suche nach BackupFiles in ' + @baseDirectory + ' gestartet'

	EXEC dbo.sp_info @opId
		,@tmpMsg
		,@owner
		,@serverName

	-- insert all backup files below root element
	BEGIN TRY
		INSERT #DirectoryTree (
			directory
			,depth
			,isfile
			)
		EXEC sp_executeSqlLinked @getBackupsSQL
			,@serverName
	END TRY

	BEGIN CATCH
		IF ERROR_NUMBER() = 7391
		BEGIN
			-- suppress error and log it
			EXEC dbo.sp_error 0x0
				,
				'The procedure sp_getBackups needs enabled MSDTC or linked server option "remote proc transaction promotion" must be set to false!'
		END
		ELSE
		BEGIN
				;

			THROW
		END
	END CATCH

	-- determine parent directories
	UPDATE #DirectoryTree
	SET parentDirectoryID = (
			SELECT MAX(id)
			FROM #DirectoryTree
			WHERE depth = dt.depth - 1
				AND id < dt.id
			)
	FROM #DirectoryTree dt;

	IF OBJECT_ID('tempdb..#BackupDetails') IS NOT NULL
		DROP TABLE #BackupDetails;

	CREATE TABLE [dbo].[#BackupDetails] (
		[Id] INT IDENTITY(1, 1) NOT NULL
		,[DatabaseName] NVARCHAR(1024) NOT NULL
		,[ServerName] NVARCHAR(500) CONSTRAINT [DF_Backups_ServerName] DEFAULT(@@servername) NOT NULL
		,[OperationId] UNIQUEIDENTIFIER NOT NULL
		,[BackupType] NVARCHAR(50) NOT NULL
		,[StartTime] DATETIME NOT NULL
		,[EndTime] DATETIME NULL
		,[BaseDirectory] NVARCHAR(1024) NOT NULL
		,[BackupFileName] NVARCHAR(1024) NULL
		,[RetainDays] INT NOT NULL
		,[Status] NVARCHAR(255) NOT NULL CONSTRAINT [PK_#BackupDetails] PRIMARY KEY CLUSTERED ([Id] ASC)
		);

	WITH directories -- derive full paths
	AS (
		-- root element
		SELECT id
			,directory AS DatabaseName
			,CAST(directory AS NVARCHAR(MAX)) AS backupFileName
			,parentDirectoryID
			,depth
			,isfile
		FROM #DirectoryTree
		WHERE parentDirectoryID IS NULL
		
		UNION ALL
		
		SELECT dt.id
			,dt.directory
			,backupFileName + '/' + dt.directory
			,dt.parentDirectoryID
			,dt.depth
			,dt.isfile
		FROM #DirectoryTree AS dt
		INNER JOIN directories ON dt.parentDirectoryID = directories.id
		)
	-- insert full pathes into #BackupDetails
	INSERT INTO #BackupDetails (
		[DatabaseName]
		,[ServerName]
		,[OperationId]
		,[BackupType]
		,[StartTime]
		,[EndTime]
		,[BaseDirectory]
		,[BackupFileName]
		,[RetainDays]
		,[Status]
		)
	SELECT DatabaseName
		,@serverName
		,@opId
		,@backupType
		,CURRENT_TIMESTAMP
		,CURRENT_TIMESTAMP
		,dbo.fn_prepareName(@baseDirectory)
		,backupFileName
		,@retainDays
		,'Erfolg'
	FROM directories
	WHERE backupFileName LIKE '%.bak'
	ORDER BY backupFileName;

	SET @tmpMsg = 'Suche nach BackupFiles in ' + @baseDirectory + ' abgeschlossen'

	EXEC dbo.sp_info @opId
		,@tmpMsg
		,@owner
		,@serverName

	-- insert new BackupFileNames into BackupDetails unless already existing
	INSERT INTO BackupDetails (
		DatabaseName
		,ServerName
		,OperationId
		,BackupType
		,StartTime
		,EndTime
		,BaseDirectory
		,BackupFileName
		,[RetainDays]
		,[Status]
		)
	SELECT DatabaseName
		,ServerName
		,OperationId
		,BackupType
		,StartTime
		,EndTime
		,BaseDirectory
		,BackupFileName
		,[RetainDays]
		,[Status]
	FROM #BackupDetails
	WHERE BackupFileName IN (
			-- check for existence
			SELECT BackupFileName
			FROM #BackupDetails
			
			EXCEPT
			
			SELECT BackupFileName
			FROM BackupDetails
			)

	SET @tmpMsg = CAST(@@ROWCOUNT AS VARCHAR(100)) + ' BackupFiles in Tabelle BackupDetails hinzugefügt'

	EXEC dbo.sp_info @opId
		,@tmpMsg
		,@owner
		,@serverName

	-- clean up
	IF OBJECT_ID('tempdb..#DirectoryTree') IS NOT NULL
		DROP TABLE #DirectoryTree;

	IF OBJECT_ID('tempdb..#BackupDetails') IS NOT NULL
		DROP TABLE #BackupDetails;

	-- check for erros
	DECLARE @errors AS NVARCHAR(MAX) = dbo.fn_getErrors(@opId, @owner)

	-- send email
	IF NOT @errors = ''
	BEGIN
		IF @notifyOperator = 1
		BEGIN
			SET @tmpMsg = 'Es sind Fehler während dem Hinzufügen von BackupFiles im Pfad ' + @baseDirectory + ' auf Server ' + 
				QUOTENAME(@serverName) + ' aufgetreten.' + dbo.fn_newline() + dbo.fn_newline()
			SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Fehler:' + dbo.fn_newline() + @errors + dbo.fn_newline()
			SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

			EXEC dbo.sp_notifyOperator @subject = N'BackupFiles hinzufügen: Fehler'
				,@body = @tmpMsg
				,@name = @operatorName
		END

		RETURN (1)
	END
	ELSE
	BEGIN
		IF @notifyOperator = 1
		BEGIN
			SET @tmpMsg = 'Das Hinzufügen von BackupFiles im Pfad ' + @baseDirectory + ' auf Server ' + QUOTENAME(@serverName) + 
				' war erfolgreich.' + dbo.fn_newline()
			SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

			EXEC dbo.sp_notifyOperator @subject = N'BackupFiles hinzufügen: Erfolg'
				,@body = @tmpMsg
				,@name = @operatorName
		END

		RETURN (0)
	END
END
