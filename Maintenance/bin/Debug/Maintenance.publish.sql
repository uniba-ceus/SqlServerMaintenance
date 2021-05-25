/*
Bereitstellungsskript für Maintenance

Dieser Code wurde von einem Tool generiert.
Änderungen an dieser Datei führen möglicherweise zu falschem Verhalten und gehen verloren, falls
der Code neu generiert wird.
*/

GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;

SET NUMERIC_ROUNDABORT OFF;


GO
:setvar DatabaseName "Maintenance"
:setvar DefaultFilePrefix "Maintenance"
:setvar DefaultDataPath "D:\MSSQL\DATA\"
:setvar DefaultLogPath "D:\MSSQL\DATA\"

GO
:on error exit
GO
/*
Überprüfen Sie den SQLCMD-Modus, und deaktivieren Sie die Skriptausführung, wenn der SQLCMD-Modus nicht unterstützt wird.
Um das Skript nach dem Aktivieren des SQLCMD-Modus erneut zu aktivieren, führen Sie folgenden Befehl aus:
SET NOEXEC OFF; 
*/
:setvar __IsSqlCmdEnabled "True"
GO
IF N'$(__IsSqlCmdEnabled)' NOT LIKE N'True'
    BEGIN
        PRINT N'Der SQLCMD-Modus muss aktiviert sein, damit dieses Skript erfolgreich ausgeführt werden kann.';
        SET NOEXEC ON;
    END


GO
USE [$(DatabaseName)];


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET ANSI_NULLS ON,
                ANSI_PADDING ON,
                ANSI_WARNINGS ON,
                ARITHABORT ON,
                CONCAT_NULL_YIELDS_NULL ON,
                QUOTED_IDENTIFIER ON,
                ANSI_NULL_DEFAULT ON,
                CURSOR_DEFAULT LOCAL,
                RECOVERY FULL 
            WITH ROLLBACK IMMEDIATE;
    END


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET PAGE_VERIFY NONE 
            WITH ROLLBACK IMMEDIATE;
    END


GO
ALTER DATABASE [$(DatabaseName)]
    SET TARGET_RECOVERY_TIME = 0 SECONDS 
    WITH ROLLBACK IMMEDIATE;


GO
PRINT N'Tabelle "[dbo].[BackupCheckDetails]" wird erstellt...';


GO
CREATE TABLE [dbo].[BackupCheckDetails] (
    [Id]             INT              IDENTITY (1, 1) NOT NULL,
    [ServerName]     NVARCHAR (500)   NOT NULL,
    [DatabaseName]   NVARCHAR (500)   NOT NULL,
    [OperationId]    UNIQUEIDENTIFIER NOT NULL,
    [BackupFileName] NVARCHAR (1024)  NOT NULL,
    [StartTime]      DATETIME         NOT NULL,
    [EndTime]        DATETIME         NULL,
    [Status]         NVARCHAR (255)   NOT NULL,
    CONSTRAINT [PK_BackupCheckDetails] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Tabelle "[dbo].[BackupDetails]" wird erstellt...';


GO
CREATE TABLE [dbo].[BackupDetails] (
    [Id]             INT              IDENTITY (1, 1) NOT NULL,
    [ServerName]     NVARCHAR (500)   NOT NULL,
    [DatabaseName]   NVARCHAR (1024)  NOT NULL,
    [OperationId]    UNIQUEIDENTIFIER NOT NULL,
    [BackupFileName] NVARCHAR (1024)  NULL,
    [BackupType]     NVARCHAR (50)    NOT NULL,
    [BaseDirectory]  NVARCHAR (1024)  NOT NULL,
    [StartTime]      DATETIME         NOT NULL,
    [EndTime]        DATETIME         NULL,
    [RetainDays]     INT              NOT NULL,
    [Status]         NVARCHAR (255)   NOT NULL,
    CONSTRAINT [PK_BackupDetails] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Tabelle "[dbo].[BackupJobDetails]" wird erstellt...';


GO
CREATE TABLE [dbo].[BackupJobDetails] (
    [Id]          INT              IDENTITY (1, 1) NOT NULL,
    [BackupJobId] INT              NOT NULL,
    [OperationId] UNIQUEIDENTIFIER NOT NULL,
    [StartTime]   DATETIME         NOT NULL,
    [EndTime]     DATETIME         NULL,
    [Status]      NVARCHAR (255)   NOT NULL,
    CONSTRAINT [PK_BackupJobDetails] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Tabelle "[dbo].[BackupJobs]" wird erstellt...';


GO
CREATE TABLE [dbo].[BackupJobs] (
    [Id]                 INT             IDENTITY (1, 1) NOT NULL,
    [Name]               NVARCHAR (500)  NOT NULL,
    [ServerName]         NVARCHAR (500)  NOT NULL,
    [DatabaseNames]      NVARCHAR (MAX)  NOT NULL,
    [BaseDirectory]      NVARCHAR (1024) NOT NULL,
    [BackupType]         NVARCHAR (50)   NOT NULL,
    [RetainDays]         INT             NOT NULL,
    [RetainQuantity]     INT             NOT NULL,
    [RestoreVerify]      BIT             NOT NULL,
    [AutoShrink]         BIT             NOT NULL,
    [ViewCheck]          BIT             NOT NULL,
    [CreateSubDirectory] INT             NOT NULL,
    [Description]        NVARCHAR (MAX)  NULL,
    CONSTRAINT [PK_BackupJobs] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [CHK_Name] UNIQUE NONCLUSTERED ([Name] ASC)
);


GO
PRINT N'Tabelle "[dbo].[Config]" wird erstellt...';


GO
CREATE TABLE [dbo].[Config] (
    [Id]          INT             IDENTITY (1, 1) NOT NULL,
    [ServerName]  NVARCHAR (500)  NOT NULL,
    [Key]         NVARCHAR (255)  NOT NULL,
    [Value]       NVARCHAR (4000) NULL,
    [Description] NVARCHAR (4000) NULL,
    CONSTRAINT [PK__Config__C41E02887ED49DF0] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [UQ_Key] UNIQUE NONCLUSTERED ([ServerName] ASC, [Key] ASC)
);


GO
PRINT N'Tabelle "[dbo].[Log]" wird erstellt...';


GO
CREATE TABLE [dbo].[Log] (
    [Id]          INT              IDENTITY (1, 1) NOT NULL,
    [ServerName]  NVARCHAR (500)   NOT NULL,
    [LogTime]     DATETIME         NOT NULL,
    [Level]       NVARCHAR (10)    NOT NULL,
    [OperationId] UNIQUEIDENTIFIER NOT NULL,
    [Owner]       NVARCHAR (500)   NOT NULL,
    [Msg]         NVARCHAR (MAX)   NOT NULL,
    CONSTRAINT [PK_Log] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Tabelle "[dbo].[ViewCheckDetails]" wird erstellt...';


GO
CREATE TABLE [dbo].[ViewCheckDetails] (
    [Id]           INT              IDENTITY (1, 1) NOT NULL,
    [ServerName]   NVARCHAR (500)   NOT NULL,
    [DatabaseName] NVARCHAR (500)   NOT NULL,
    [OperationId]  UNIQUEIDENTIFIER NOT NULL,
    [StartTime]    DATETIME         NOT NULL,
    [EndTime]      DATETIME         NULL,
    [Status]       NVARCHAR (255)   NOT NULL,
    CONSTRAINT [PK_ViewChecks] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'DEFAULT-Einschränkung "[dbo].[DF_Backups_ServerName]" wird erstellt...';


GO
ALTER TABLE [dbo].[BackupDetails]
    ADD CONSTRAINT [DF_Backups_ServerName] DEFAULT (@@servername) FOR [ServerName];


GO
PRINT N'DEFAULT-Einschränkung "unbenannte Einschränkungen auf [dbo].[BackupJobs]" wird erstellt...';


GO
ALTER TABLE [dbo].[BackupJobs]
    ADD DEFAULT @@SERVERNAME FOR [ServerName];


GO
PRINT N'DEFAULT-Einschränkung "unbenannte Einschränkungen auf [dbo].[BackupJobs]" wird erstellt...';


GO
ALTER TABLE [dbo].[BackupJobs]
    ADD DEFAULT 'FULL' FOR [BackupType];


GO
PRINT N'DEFAULT-Einschränkung "unbenannte Einschränkungen auf [dbo].[BackupJobs]" wird erstellt...';


GO
ALTER TABLE [dbo].[BackupJobs]
    ADD DEFAULT 0 FOR [RetainDays];


GO
PRINT N'DEFAULT-Einschränkung "unbenannte Einschränkungen auf [dbo].[BackupJobs]" wird erstellt...';


GO
ALTER TABLE [dbo].[BackupJobs]
    ADD DEFAULT 0 FOR [RetainQuantity];


GO
PRINT N'DEFAULT-Einschränkung "unbenannte Einschränkungen auf [dbo].[BackupJobs]" wird erstellt...';


GO
ALTER TABLE [dbo].[BackupJobs]
    ADD DEFAULT 0 FOR [RestoreVerify];


GO
PRINT N'DEFAULT-Einschränkung "unbenannte Einschränkungen auf [dbo].[BackupJobs]" wird erstellt...';


GO
ALTER TABLE [dbo].[BackupJobs]
    ADD DEFAULT 1 FOR [AutoShrink];


GO
PRINT N'DEFAULT-Einschränkung "unbenannte Einschränkungen auf [dbo].[BackupJobs]" wird erstellt...';


GO
ALTER TABLE [dbo].[BackupJobs]
    ADD DEFAULT 1 FOR [ViewCheck];


GO
PRINT N'DEFAULT-Einschränkung "unbenannte Einschränkungen auf [dbo].[BackupJobs]" wird erstellt...';


GO
ALTER TABLE [dbo].[BackupJobs]
    ADD DEFAULT 1 FOR [CreateSubDirectory];


GO
PRINT N'DEFAULT-Einschränkung "[dbo].[DF_Config_ServerName]" wird erstellt...';


GO
ALTER TABLE [dbo].[Config]
    ADD CONSTRAINT [DF_Config_ServerName] DEFAULT (@@servername) FOR [ServerName];


GO
PRINT N'DEFAULT-Einschränkung "[dbo].[DF_Log_LogTime]" wird erstellt...';


GO
ALTER TABLE [dbo].[Log]
    ADD CONSTRAINT [DF_Log_LogTime] DEFAULT (getdate()) FOR [LogTime];


GO
PRINT N'DEFAULT-Einschränkung "[dbo].[DF_Log_ServerName]" wird erstellt...';


GO
ALTER TABLE [dbo].[Log]
    ADD CONSTRAINT [DF_Log_ServerName] DEFAULT (@@servername) FOR [ServerName];


GO
PRINT N'DEFAULT-Einschränkung "[dbo].[DF_ViewChecks_ServerName]" wird erstellt...';


GO
ALTER TABLE [dbo].[ViewCheckDetails]
    ADD CONSTRAINT [DF_ViewChecks_ServerName] DEFAULT (@@servername) FOR [ServerName];


GO
PRINT N'CHECK-Einschränkung "[dbo].[CHK_BackupType]" wird erstellt...';


GO
ALTER TABLE [dbo].[BackupJobs] WITH NOCHECK
    ADD CONSTRAINT [CHK_BackupType] CHECK (BackupType = 'FULL'
		OR BackupType = 'DIFF'
		OR BackupType = 'LOG'
		OR BackupType = 'FULLCOPYONLY'
		OR BackupType = 'LOGCOPYONLY');


GO
PRINT N'CHECK-Einschränkung "[dbo].[CHK_Level]" wird erstellt...';


GO
ALTER TABLE [dbo].[Log] WITH NOCHECK
    ADD CONSTRAINT [CHK_Level] CHECK ([Level] = 'TRACE'
		OR [Level] = 'DEBUG'
		OR [Level] = 'INFO'
		OR [Level] = 'WARNUNG'
		OR [Level] = 'FEHLER');


GO
PRINT N'Funktion "[dbo].[fn_escape]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 15.12.2017
-- Description:	Escapes a given string. Replaces -, :, and . to _ .
-- =============================================
CREATE FUNCTION [dbo].[fn_escape] (@text NVARCHAR(1024))
RETURNS NVARCHAR(1024)
AS
BEGIN
	RETURN Replace(Replace(Replace(@text, '-', '_'), ':', ''), '.', '_')
END
GO
PRINT N'Funktion "[dbo].[fn_formatLog]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 15.12.2017
-- Description:	Formats a log entry.
-- =============================================
CREATE FUNCTION [dbo].[fn_formatLog] (
	@operationId UNIQUEIDENTIFIER
	,@msg NVARCHAR(MAX)
	,@level NVARCHAR(MAX)
	,@owner NVARCHAR(500)
	,@serverName NVARCHAR(500)
	,@logTime DATETIME
	)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	RETURN CONVERT(NVARCHAR(128), @logTime, 20) + ' [' + @level + '] ' + @serverName + ': ' + @msg
END
GO
PRINT N'Funktion "[dbo].[fn_getBackupTimestamp]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 15.12.2017
-- Description:	Returns the current date as formatted timestamp.
-- =============================================
CREATE FUNCTION fn_getBackupTimestamp (@backupFileName VARCHAR(1024) = '')
RETURNS NVARCHAR(1024)
AS
BEGIN
	DECLARE @timestamp AS NVARCHAR(1024) = ''

	IF @backupFileName = ''
	BEGIN
		-- Generate new timestamp
		SET @timestamp = Replace(Replace(Replace(Replace(Convert(VARCHAR(27), SYSDATETIME(), 127), '-', '_'), 'T', '_'), ':', ''), 
				'.', '_')
	END
	ELSE
	BEGIN
		SET @timestamp = @timestamp

		-- remove file extension
		IF CHARINDEX('.', @timestamp) > 0
		BEGIN
			SET @timestamp = SUBSTRING(@timestamp, 1, CHARINDEX('.', @timestamp) - 1)
		END

		-- remove database name and backup
		IF LEN(@timestamp) >= 25
		BEGIN
			SET @timestamp = RIGHT(@timestamp, 25)
		END
				-- EXTENSION FOR FUTURE
				-- repdroduce datetime format
				--SET @timestamp = STUFF(@timestamp, CHARINDEX('_', @timestamp), LEN('_'), '-')
				--SET @timestamp = STUFF(@timestamp, CHARINDEX('_', @timestamp), LEN('_'), '-')
				--SET @timestamp = STUFF(@timestamp, CHARINDEX('_', @timestamp), LEN('_'), 'T')
				--SET @timestamp = STUFF(@timestamp, 14, 0, ':')
				--SET @timestamp = STUFF(@timestamp, 17, 0, ':')
				--SET @timestamp = STUFF(@timestamp, CHARINDEX('_', @timestamp), LEN('_'), '.')
				-- cast to datetime
				--PRINT CONVERT(DATETIME,Convert(DATETIME2(7), @timestamp))
	END

	RETURN @timestamp
END
GO
PRINT N'Funktion "[dbo].[fn_getConfig]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 19.03.2018
-- Description:	Reads a configuration from Config table.
-- =============================================
CREATE FUNCTION [dbo].[fn_getConfig] (
	@key NVARCHAR(255)
	,@serverName NVARCHAR(500) = ''
	)
RETURNS NVARCHAR(4000)
AS
BEGIN
	IF @serverName = ''
	BEGIN
		SET @serverName = @@SERVERNAME
	END

	DECLARE @value AS NVARCHAR(4000)

	SELECT @value = [Value]
	FROM Config
	WHERE [Key] LIKE @key
		AND [ServerName] LIKE @serverName

	RETURN @value
END
GO
PRINT N'Funktion "[dbo].[fn_getErrors]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 18.12.2017
-- Description:	Returns all error messages of a backup operation.
-- =============================================
CREATE FUNCTION [dbo].[fn_getErrors] (
	@operationId UNIQUEIDENTIFIER
	,@owner NVARCHAR(500) = ''
	)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	DECLARE @msgs NVARCHAR(MAX) = ''

	IF @owner = ''
	BEGIN
		SET @owner = '%'
	END

	SELECT @msgs = @msgs + CONVERT(NVARCHAR(128), LogTime, 20) + ' [' + [Level] + '] ' + [ServerName] + ': ' + Msg + CHAR(13) + CHAR(10)
	FROM Log
	WHERE [OperationId] = @operationId
		AND [Owner] LIKE @owner
		AND [Level] LIKE 'FEHLER'

	RETURN @msgs
END
GO
PRINT N'Funktion "[dbo].[fn_newline]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 18.12.2017
-- Description:	Returns text with CR LF characters.
-- =============================================
CREATE FUNCTION [dbo].[fn_newline] ()
RETURNS NVARCHAR(50)
AS
BEGIN
	RETURN CHAR(13) + CHAR(10)
END
GO
PRINT N'Funktion "[dbo].[fn_prepareName]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 01.03.2018
-- Description:	Prepares a given name. Replaces CR LF with empty string. Replaces tabs with blanks. Trims the text.
-- =============================================
CREATE FUNCTION [dbo].[fn_prepareName] (@text NVARCHAR(1024))
RETURNS NVARCHAR(1024)
AS
BEGIN
	RETURN LTRIM(RTRIM(REPLACE(REPLACE(@text, dbo.fn_newline(), ''), CHAR(9), ' ')))
END
GO
PRINT N'Funktion "[dbo].[fn_preparePath]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 28.02.2018
-- Description:	Prepares a given path. Replaces all backslashes ("\") to slahes ("/"). Removes ending slash if necessary.
-- =============================================
CREATE FUNCTION [dbo].[fn_preparePath] (@path NVARCHAR(1024))
RETURNS NVARCHAR(1024)
AS
BEGIN
	-- convert backslahes to slashes
	SET @path = REPLACE(@path, '\', '/')
	-- replaces double slashes mostly from wrong path concatination
	SET @path = REPLACE(@path, '//', '/')

	-- remove ending slash
	IF @path LIKE '%' + '/'
	BEGIN
		SET @path = SUBSTRING(@path, 1, LEN(@path) - LEN('/'))
	END

	RETURN @path
END
GO
PRINT N'Funktion "[dbo].[fn_getBackupFileName]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 15.05.2019
-- Description:	Returns the name for the backup file without extension containing of database name and timestamp. The timestamp format is equivalent to the "Wartungsplan" format.
-- =============================================
CREATE FUNCTION fn_getBackupFileName (@databaseName VARCHAR(1024))
RETURNS VARCHAR(1024)
AS
BEGIN
	RETURN @databaseName + '_backup_' + dbo.fn_getBackupTimestamp(DEFAULT)
END
GO
PRINT N'Funktion "[dbo].[fn_getLogs]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 18.12.2017
-- Description:	Returns all log messages of a backup operation.
-- =============================================
CREATE FUNCTION [dbo].[fn_getLogs] (
	@operationId UNIQUEIDENTIFIER
	,@minLevel NVARCHAR(MAX) = 'INFO'
	,@owner NVARCHAR(500) = ''
	)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	DECLARE @msgs NVARCHAR(MAX) = ''

	IF @owner = ''
	BEGIN
		SET @owner = '%'
	END

	IF @minLevel = 'TRACE'
	BEGIN
		SELECT @msgs = @msgs + dbo.fn_formatLog([OperationId], [Msg], [Level], [Owner], [ServerName], [LogTime]) + dbo.fn_newline()
		FROM Log
		WHERE OperationId = @operationId
			AND [Owner] LIKE @owner
			AND (
				[Level] LIKE 'TRACE'
				OR [Level] LIKE 'DEBUG'
				OR [Level] LIKE 'INFO'
				OR [Level] LIKE 'WARNUNG'
				OR [Level] LIKE 'FEHLER'
				)
	END
	ELSE IF @minLevel = 'DEBUG'
	BEGIN
		SELECT @msgs = @msgs + dbo.fn_formatLog([OperationId], [Msg], [Level], [Owner], [ServerName], [LogTime]) + dbo.fn_newline()
		FROM Log
		WHERE OperationId = @operationId
			AND [Owner] LIKE @owner
			AND (
				[Level] LIKE 'DEBUG'
				OR [Level] LIKE 'INFO'
				OR [Level] LIKE 'WARNUNG'
				OR [Level] LIKE 'FEHLER'
				)
	END
	ELSE IF @minLevel = 'INFO'
	BEGIN
		SELECT @msgs = @msgs + dbo.fn_formatLog([OperationId], [Msg], [Level], [Owner], [ServerName], [LogTime]) + dbo.fn_newline()
		FROM Log
		WHERE OperationId = @operationId
			AND [Owner] LIKE @owner
			AND (
				[Level] LIKE 'INFO'
				OR [Level] LIKE 'WARNUNG'
				OR [Level] LIKE 'FEHLER'
				)
	END
	ELSE IF @minLevel = 'WARNUNG'
	BEGIN
		SELECT @msgs = @msgs + dbo.fn_formatLog([OperationId], [Msg], [Level], [Owner], [ServerName], [LogTime]) + dbo.fn_newline()
		FROM Log
		WHERE OperationId = @operationId
			AND [Owner] LIKE @owner
			AND (
				[Level] LIKE 'WARNUNG'
				OR [Level] LIKE 'FEHLER'
				)
	END
	ELSE IF @minLevel = 'FEHLER'
	BEGIN
		SELECT @msgs = @msgs + dbo.fn_formatLog([OperationId], [Msg], [Level], [Owner], [ServerName], [LogTime]) + dbo.fn_newline()
		FROM Log
		WHERE OperationId = @operationId
			AND [Owner] LIKE @owner
			AND [Level] LIKE 'FEHLER'
	END

	RETURN @msgs
END
GO
PRINT N'Funktion "[dbo].[fn_splitString]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 15.12.2017
-- Description:	Splits a string based on a separator. Returns a table with ItemIndex and Part.
-- =============================================
CREATE FUNCTION [dbo].[fn_splitString] (
	@str NVARCHAR(MAX)
	,@separator CHAR(1)
	)
RETURNS TABLE
AS
RETURN (
		WITH tokens(p, a, b) AS (
				SELECT CAST(1 AS BIGINT)
					,CAST(1 AS BIGINT)
					,CHARINDEX(@separator, @str)
				
				UNION ALL
				
				SELECT p + 1
					,b + 1
					,CHARINDEX(@separator, @str, b + 1)
				FROM tokens
				WHERE b > 0
				)
		SELECT p - 1 ItemIndex
			,SUBSTRING(@str, a, CASE 
					WHEN b > 0
						THEN b - a
					ELSE LEN(@str)
					END) AS Part
		FROM tokens
		);
GO
PRINT N'Funktion "[dbo].[fn_getFileNameFromPath]" wird erstellt...';


GO
-- =============================================
-- Author:		Tobias Kiehl
-- Create date: 20.03.2019
-- Description:	Splits a filename with full path and return the filename without path.
-- =============================================
CREATE FUNCTION [dbo].[fn_getFileNameFromPath] (@str NVARCHAR(MAX))
RETURNS NVARCHAR(1024)
AS
BEGIN
	RETURN (
			SELECT TOP 1 Part
			FROM dbo.fn_splitString(dbo.fn_preparePath(@str), '/')
			ORDER BY ItemIndex DESC
			)
END
GO
PRINT N'Funktion "[dbo].[fn_getFileNameWithoutExtension]" wird erstellt...';


GO
-- =============================================
-- Author:		Tobias Kiehl
-- Create date: 20.03.2019
-- Description:	Splits a filename and its extension and returns the filename without extension.
-- =============================================
CREATE FUNCTION [dbo].[fn_getFileNameWithoutExtension] (@str NVARCHAR(MAX))
RETURNS NVARCHAR(1024)

BEGIN
	RETURN (
			SELECT TOP 1 Part
			FROM fn_splitString((@str), '.')
			)
END
GO
PRINT N'Prozedur "[dbo].[sp_databaseExists]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 03.03.2018
-- Description:	Checks if a database is existing or not. Returns 1 if exactly one database exists. Returns 0 if database does not exists. Returns > 1 if more than one database exists
-- =============================================
CREATE PROCEDURE [dbo].[sp_databaseExists] @databaseName NVARCHAR(500)
	,@serverName NVARCHAR(500) = @@SERVERNAME
AS
BEGIN
	DECLARE @existingCount AS INT = 0
	DECLARE @existsSql AS NVARCHAR(4000) = ''

	SET @existsSql = N'SELECT @existingCount = count(*)
	FROM ' + QUOTENAME(CONVERT(SYSNAME, @serverName)) + 
		'.master.sys.databases
	WHERE [name] like ''' + @databaseName + ''''

	EXEC sp_executesql @existsSql
		,N'@existingCount AS INT OUTPUT'
		,@existingCount = @existingCount OUTPUT

	RETURN @existingCount
END
GO
PRINT N'Prozedur "[dbo].[sp_executeSqlLinked]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 28.02.2018
-- Description:	Executes sql on a remote linked server. RPC-Out must be active on linked server.
-- =============================================
CREATE PROCEDURE [dbo].[sp_executeSqlLinked] @sql AS NVARCHAR(4000)
	,@serverName AS NVARCHAR(500)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @serverSql AS NVARCHAR(2000) = ''

	IF @serverName = @@SERVERNAME
	BEGIN
		SET @serverSql = 'EXEC (@innersql)'
	END
	ELSE
	BEGIN
		SET @serverSql = 'EXEC (@innersql) AT ' + QUOTENAME(CONVERT(SYSNAME, @serverName))
	END

	EXEC sp_executesql @serverSql
		,N'@innersql NVARCHAR(4000)'
		,@innersql = @sql
END
GO
PRINT N'Prozedur "[dbo].[sp_genFullBackupJob]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 26.02.2018
-- Description:	Generates a new job for full backup of all databases.
-- =============================================
CREATE PROCEDURE [dbo].[sp_genFullBackupJob] @serverName AS NVARCHAR(500) = @@SERVERNAME
AS
SET NOCOUNT ON;

DECLARE @tmpMsg AS NVARCHAR(MAX) = ''

-- clean names
SET @serverName = CONVERT(SYSNAME, dbo.fn_prepareName(@serverName))

BEGIN TRY
	SET @tmpMsg = 'Initialisiere einen Backup-Auftrag für den Server ' + QUOTENAME(@serverName)

	PRINT @tmpMsg

	DECLARE @tempDatabases AS TABLE (NAME NVARCHAR(500))

	DELETE
	FROM @tempDatabases

	DECLARE @getDatabaseNamesSql AS NVARCHAR(MAX) = 'SELECT NAME FROM ' + QUOTENAME(@serverName) + '.master.sys.databases'

	INSERT INTO @tempDatabases
	EXEC sp_executesql @getDatabaseNamesSql

	DECLARE @databaseNames NVARCHAR(MAX)

	SELECT @databaseNames = COALESCE(@databaseNames + ', ', '') + CAST(NAME AS NVARCHAR(500))
	FROM @tempDatabases

	-- create a backup job
	INSERT INTO [dbo].[BackupJobs] (
		[Name]
		,[ServerName]
		,[DatabaseNames]
		,[BaseDirectory]
		,[BackupType]
		,[RetainDays]
		,[RetainQuantity]
		,[RestoreVerify]
		,[AutoShrink]
		,[ViewCheck]
		,[CreateSubDirectory]
		,[Description]
		)
	VALUES (
		'Beispiel'
		,@serverName
		,@databaseNames
		,'S:/Backup/täglich/'
		,'FULL'
		,0
		,0
		,0
		,1
		,1
		,1
		,'Beispiel eines Backup-Auftrags'
		)
END TRY

BEGIN CATCH
	SET @tmpMsg = 'Fehler beim Initialisieren eines Backup-Auftrags für den Server ' + QUOTENAME(@serverName) + 
		'. Fehlermeldung: ' + ERROR_MESSAGE()

	PRINT @tmpMsg
END CATCH
GO
PRINT N'Prozedur "[dbo].[sp_getDatabaseNames]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 22.07.2020
-- Description:	Returns all database names from searchString
-- =============================================
CREATE PROCEDURE [dbo].[sp_getDatabaseNames] (
	@searchStr NVARCHAR(MAX)
	,@serverName AS NVARCHAR(500) = @@SERVERNAME -- name of the server
	)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @searchDbSql AS NVARCHAR(4000) = ''

	SET @searchDbSql = N'SELECT [name]
	FROM ' + QUOTENAME(CONVERT(SYSNAME, @serverName)) + 
		'.master.sys.databases
	WHERE [name] like ''' + @searchStr + ''''

	EXEC sp_executesql @searchDbSql
END
GO
PRINT N'Prozedur "[dbo].[sp_getFreeDriveSpace]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 03.03.2018
-- Description:	Reads the free drive space in MB and returns it as INT. Returns 0 if drive not found.
-- =============================================
CREATE PROCEDURE [dbo].[sp_getFreeDriveSpace] @driveName NVARCHAR(500)
	,@serverName NVARCHAR(500) = @@SERVERNAME
AS
BEGIN
	DECLARE @space AS INT = 0
	-- WARN: Following commands require DISTRIBUTED TRANSACTIONS
	/*
	DECLARE @spaceSql AS NVARCHAR(4000) = ''

	SET @spaceSql = N'DECLARE @temp as TABLE (Drive NVARCHAR(500), Mb NVARCHAR(500))

		INSERT INTO @temp
		EXEC ' + QUOTENAME(CONVERT(SYSNAME, @serverName)) + '.master.dbo.xp_fixeddrives

		SELECT @space = [Mb] FROM @temp WHERE [Drive] like ''' + @driveName + ''''

	EXEC sp_executesql @spaceSql
		,N'@space AS INT OUTPUT'
		,@space = @space OUTPUT

	RETURN @space
	*/
	DECLARE @tempDriveSpace AS TABLE (
		Drive NVARCHAR(500)
		,FreeMb NVARCHAR(500)
		)
	DECLARE @createTempDriveSpaceSql AS NVARCHAR(4000) = 
		'

	IF OBJECT_ID(N''tempdb.dbo.TempDriveSpace'', N''U'') IS NOT NULL
	BEGIN
		DROP TABLE tempdb.dbo.TempDriveSpace
	END

	CREATE TABLE tempdb.dbo.TempDriveSpace(
		 Drive NVARCHAR(500)
		,FreeMb NVARCHAR(500)
		)
	
		INSERT INTO tempdb.dbo.TempDriveSpace
		EXEC (''master.dbo.xp_fixeddrives'')'

	EXEC sp_executeSqlLinked @createTempDriveSpaceSql
		,@serverName

	DECLARE @tempDriveSpaceSql AS NVARCHAR(MAX) = 'SELECT [Drive], [FreeMb] FROM ' + QUOTENAME(@serverName) + 
		'.tempdb.dbo.TempDriveSpace'

	INSERT INTO @tempDriveSpace
	EXEC sp_executesql @tempDriveSpaceSql

	SELECT @space = [FreeMb]
	FROM @tempDriveSpace
	WHERE [Drive] LIKE @driveName

	RETURN @space
END
GO
PRINT N'Prozedur "[dbo].[sp_getRecoveryModel]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 28.02.2018
-- Description:	Gets the recovery model. Values are 1 = FULL, 2 = BULK_LOGGED and 3 = SIMPLE. In case database was not found it is 0 = empty.
-- =============================================
CREATE PROCEDURE [dbo].[sp_getRecoveryModel] @databaseName AS NVARCHAR(4000)
	,@serverName AS NVARCHAR(4000) = @@SERVERNAME
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @recoveryModelSql AS NVARCHAR(4000) = ''
	DECLARE @recoveryModel AS INT = 0

	SET @recoveryModelSql = N'SELECT @recoveryModel = recovery_model
	FROM ' + QUOTENAME(CONVERT(SYSNAME, @serverName)) + 
		'.master.sys.databases
	WHERE [name] like ''' + @databaseName + ''''

	EXEC sp_executesql @recoveryModelSql
		,N'@recoveryModel AS INT OUTPUT'
		,@recoveryModel = @recoveryModel OUTPUT

	RETURN @recoveryModel
END
GO
PRINT N'Prozedur "[dbo].[sp_getServerProductVersion]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 28.02.2018
-- Description:	Determines the server product version.
-- =============================================
CREATE PROCEDURE [dbo].[sp_getServerProductVersion] (
	@serverName NVARCHAR(500) = @@SERVERNAME
	,@productVersion NVARCHAR(500) OUTPUT
	)
AS
BEGIN
	SET NOCOUNT ON;

	IF @serverName = @@SERVERNAME
	BEGIN
		SELECT @productVersion = CAST(SERVERPROPERTY('PRODUCTVERSION') AS NVARCHAR)
	END
	ELSE
	BEGIN
		DECLARE @sqlQuery NVARCHAR(max) = 'SELECT @productVersion = CAST([Version] AS NVARCHAR(500))
		   FROM OPENQUERY(' + 
			QUOTENAME(CONVERT(SYSNAME, @serverName)) + ',''SELECT SERVERPROPERTY(''''PRODUCTVERSION'''') AS [Version]'')'

		EXEC sp_executesql @sqlQuery
			,N'@productVersion AS NVARCHAR(500) OUTPUT'
			,@productVersion = @productVersion OUTPUT
	END
END
GO
PRINT N'Prozedur "[dbo].[sp_log]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 17.12.2017
-- Description:	Appends a new message to log. NOTE: Trace will not be logged, only printed.
-- =============================================
CREATE PROCEDURE [dbo].[sp_log] (
	@operationId UNIQUEIDENTIFIER
	,@msg NVARCHAR(MAX)
	,@level NVARCHAR(MAX) = 'INFO'
	,-- allowed levels are TRACE, DEBUG, INFO, WARNUNG, FEHLER
	@owner NVARCHAR(500) = ''
	,@serverName NVARCHAR(500) = @@SERVERNAME
	,@logTrace BIT = 0
	)
AS
BEGIN
	DECLARE @logTime AS DATETIME = GETDATE()

	IF @logTrace = 1
		OR @level <> 'TRACE'
	BEGIN
		INSERT INTO [dbo].[Log] (
			[ServerName]
			,[LogTime]
			,[Level]
			,[OperationId]
			,[Owner]
			,[Msg]
			)
		VALUES (
			@serverName
			,@logTime
			,@level
			,@operationId
			,@owner
			,@msg
			)
	END

	PRINT dbo.fn_formatLog(@operationId, @msg, @level, @owner, @serverName, @logTime)
END
GO
PRINT N'Prozedur "[dbo].[sp_notifyOperator]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 09.04.2018
-- Description:	Notifies an operator per HTML mail. Copied from sp_notify_operator procedure and extended with @body_format paramater and some custom code.
-- =============================================
CREATE PROCEDURE [dbo].[sp_notifyOperator] @profile_name SYSNAME = NULL
	,
	-- name of database mail profile to be used for sending the email, cannot be null
	@id INT = NULL
	,@name SYSNAME = NULL
	-- Mutual exclusive, one and only one should be non null. Specify the operator whose email address will be used to send this email.
	,@subject NVARCHAR(256) = NULL
	,@body NVARCHAR(MAX) = NULL
	-- body of the email message
	,@file_attachments NVARCHAR(512) = NULL
	,@mail_database SYSNAME = N'msdb'
	-- have infrastructure in place to support this but disabled by default
	-- for first implementation we will have this parameters but using it will generate an error - not implemented yet.
	-- CUSTOM CODE --
	,@body_format VARCHAR(20) = NULL
	-- default is NULL which will use TEXT in procedure sp_send_dbmail
	,@serverName AS NVARCHAR(500) = @@SERVERNAME
	-----------------
AS
BEGIN
	-- CUSTOM CODE --
	IF (@name IS NULL)
	BEGIN
		-- try to read operator name from configuration
		DECLARE @notifyOperatorName AS NVARCHAR(500) = dbo.fn_getConfig('NotifyOperatorName', @serverName)

		SET @name = CONVERT(SYSNAME, @notifyOperatorName)
	END

	-----------------
	DECLARE @retval INT
	DECLARE @email_address NVARCHAR(100)
	DECLARE @enabled TINYINT
	DECLARE @qualified_sp_sendmail SYSNAME
	DECLARE @db_id INT

	SET NOCOUNT ON

	-- remove any leading and trailing spaces from parameters
	SELECT @profile_name = LTRIM(RTRIM(@profile_name))

	SELECT @name = LTRIM(RTRIM(@name))

	SELECT @file_attachments = LTRIM(RTRIM(@file_attachments))

	SELECT @mail_database = LTRIM(RTRIM(@mail_database))

	IF @profile_name = ''
		SELECT @profile_name = NULL

	IF @name = ''
		SELECT @name = NULL

	IF @file_attachments = ''
		SELECT @file_attachments = NULL

	IF @mail_database = ''
		SELECT @mail_database = NULL

	EXECUTE @retval = msdb.dbo.sp_verify_operator_identifiers '@name'
		,'@id'
		,@name OUTPUT
		,@id OUTPUT

	IF (@retval <> 0)
		RETURN (1) -- failure

	-- checks if the operator is available
	SELECT @enabled = enabled
		,@email_address = email_address
	FROM msdb.dbo.sysoperators
	WHERE id = @id

	IF @enabled = 0
	BEGIN
		RAISERROR (
				14601
				,16
				,1
				,@name
				)

		RETURN 1
	END

	IF @email_address IS NULL
	BEGIN
		RAISERROR (
				14602
				,16
				,1
				,@name
				)

		RETURN 1
	END

	SELECT @qualified_sp_sendmail = @mail_database + '.dbo.sp_send_dbmail'

	EXEC @retval = @qualified_sp_sendmail @profile_name = @profile_name
		,@recipients = @email_address
		,@subject = @subject
		,@body = @body
		,@file_attachments = @file_attachments
		,@body_format = @body_format

	RETURN @retval
END
GO
PRINT N'Prozedur "[dbo].[sp_trace]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 03.03.2018
-- Description:	Appends a new message to log. Adds timestamp and level. NOTE: Trace will be default only printend and not be logged. Set logTrace for enable writing to log.
-- =============================================
CREATE PROCEDURE [dbo].[sp_trace] (
	@operationId UNIQUEIDENTIFIER
	,@msg NVARCHAR(MAX)
	,@owner NVARCHAR(500) = ''
	,@serverName NVARCHAR(500) = @@SERVERNAME
	,@logTrace BIT = 0 -- set to 1 for enable trace log writing.
	)
AS
BEGIN
	EXEC dbo.sp_log @operationId
		,@msg
		,'TRACE'
		,@owner
		,@serverName
		,@logTrace
END
GO
PRINT N'Prozedur "[dbo].[sp_warn]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 17.12.2017
-- Description:	Appends a new message to log. Adds timestamp and level.
-- =============================================
CREATE PROCEDURE [dbo].[sp_warn] (
	@operationId UNIQUEIDENTIFIER
	,@msg NVARCHAR(MAX)
	,@owner NVARCHAR(500) = ''
	,@serverName NVARCHAR(500) = @@SERVERNAME
	)
AS
BEGIN
	EXEC dbo.sp_log @operationId
		,@msg
		,'WARNUNG'
		,@owner
		,@serverName
END
GO
PRINT N'Prozedur "[dbo].[sp_debug]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 17.12.2017
-- Description:	Appends a new message to log. Adds timestamp and level.
-- =============================================
CREATE PROCEDURE [dbo].[sp_debug] (
	@operationId UNIQUEIDENTIFIER
	,@msg NVARCHAR(MAX)
	,@owner NVARCHAR(500) = ''
	,@serverName NVARCHAR(500) = @@SERVERNAME
	)
AS
BEGIN
	EXEC dbo.sp_log @operationId
		,@msg
		,'DEBUG'
		,@owner
		,@serverName
END
GO
PRINT N'Prozedur "[dbo].[sp_deleteFile]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 17.12.2017
-- Description: Deletes a file from the file system. Uses xp_cmdshell which must be enabled.
-- =============================================
CREATE PROCEDURE [dbo].[sp_deleteFile] (
	@filePath NVARCHAR(1024)
	,@serverName NVARCHAR(500) = @@SERVERNAME
	)
AS
BEGIN
	DECLARE @sql AS NVARCHAR(4000)
	DECLARE @cmdshellActive AS BIT = 0

	-- NOTE: DEL only supports backslashes!
	SET @filePath = REPLACE(@filePath, '/', '\')

	IF @serverName = @@SERVERNAME
	BEGIN
		SET @sql = 
			'SELECT @cmdshellActive = CONVERT(INT, ISNULL(value, value_in_use))
FROM sys.configurations
WHERE  name = ''xp_cmdshell'''
			;

		EXEC sp_executesql @sql
			,N'@cmdshellActive AS BIT OUTPUT'
			,@cmdshellActive = @cmdshellActive OUTPUT
	END
	ELSE
	BEGIN
		SET @sql = 'SELECT @cmdshellActive = CONVERT(INT, ISNULL(value, value_in_use))
FROM ' + QUOTENAME(CONVERT(SYSNAME, 
					@serverName)) + 'master.sys.configurations
WHERE  name = ''xp_cmdshell''';

		EXEC sp_executesql @sql
			,N'@cmdshellActive AS BIT OUTPUT'
			,@cmdshellActive = @cmdshellActive OUTPUT
	END

	IF @cmdShellActive = 0
	BEGIN
		RAISERROR (
				'ERROR: For deletion of files xp_cmdshell must be active in configuration'
				,16
				,1
				)

		RETURN (1)

		-- print commando for activation of xp_cmdshell
		SET @sql = 
			'EXEC sp_configure ''show advanced options'', 1;  
GO 
RECONFIGURE;  
GO  
sp_configure ''xp_cmdshell'',1
GO
RECONFIGURE
GO
sp_configure ''xp_cmdshell''
GO'

		PRINT @sql
	END

	SET @sql = 'xp_cmdshell ''DEL "' + @filePath + '"'''

	DECLARE @returnCode AS INT = 0

	EXEC @returnCode = sp_executeSqlLinked @sql
		,@serverName

	RETURN @returnCode
END
GO
PRINT N'Prozedur "[dbo].[sp_error]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 17.12.2017
-- Description:	Appends a new messag to log. Adds timestamp and level.
-- =============================================
CREATE PROCEDURE [dbo].[sp_error] (
	@operationId UNIQUEIDENTIFIER
	,@msg NVARCHAR(MAX)
	,@owner NVARCHAR(500) = ''
	,@serverName NVARCHAR(500) = @@SERVERNAME
	)
AS
BEGIN
	EXEC dbo.sp_log @operationId
		,@msg
		,'FEHLER'
		,@owner
		,@serverName
END
GO
PRINT N'Prozedur "[dbo].[sp_fileExists]" wird erstellt...';


GO
-- =============================================
-- Author:		Tobias Kiehl
-- Create date: 26.09.2018
-- Description:	Checks if a file in a file system is existing. Returns 1 if the file exists, otherwise 0.
-- =============================================
CREATE PROCEDURE sp_fileExists @filePath NVARCHAR(4000)
	,@serverName NVARCHAR(500) = @@SERVERNAME
AS
BEGIN
	DECLARE @exists AS INT = 0
	DECLARE @filexExistsSql AS NVARCHAR(4000) = 'EXEC master.dbo.xp_fileexist ''' + @filePath + ''''
	DECLARE @fileResults TABLE (
		fileExists INT
		,fileIsADirectory INT
		,parentDirectoryExists INT
		)

	BEGIN TRY
		INSERT INTO @fileResults (
			fileExists
			,fileIsADirectory
			,parentDirectoryExists
			)
		EXEC sp_executeSqlLinked @filexExistsSql
			,@serverName
	END TRY

	BEGIN CATCH
		IF ERROR_NUMBER() = 7391
		BEGIN
			-- suppress error and log it
			EXEC dbo.sp_error 0x0
				,
				'The procedure sp_fileExists needs enabled MSDTC or linked server option "remote proc transaction promotion" must be set to false!'
		END
		ELSE
		BEGIN
				;

			THROW
		END
	END CATCH

	SET @exists = (
			SELECT TOP 1 fileExists
			FROM @fileResults
			);

	IF @exists IS NULL
	BEGIN
		SET @exists = - 1
	END

	RETURN @exists
END
GO
PRINT N'Prozedur "[dbo].[sp_info]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 17.12.2017
-- Description:	Appends a new messag to log. Adds timestamp and level.
-- =============================================
CREATE PROCEDURE [dbo].[sp_info] (
	@operationId UNIQUEIDENTIFIER
	,@msg NVARCHAR(MAX)
	,@owner NVARCHAR(500) = ''
	,@serverName NVARCHAR(500) = @@SERVERNAME
	)
AS
BEGIN
	EXEC dbo.sp_log @operationId
		,@msg
		,'INFO'
		,@owner
		,@serverName
END
GO
PRINT N'Prozedur "[dbo].[sp_purgeBackupHistory]" wird erstellt...';


GO
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
GO
PRINT N'Prozedur "[dbo].[sp_restoreVerifyBackup]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 31.01.2018
-- Description:	Restore and verifies a backup.
-- =============================================
CREATE PROCEDURE [dbo].[sp_restoreVerifyBackup] @backupFileName VARCHAR(1024) -- e.g. 'S:\Backup\täglich\test.bak'
	,@databaseName VARCHAR(1024) -- database name
	,@serverName AS NVARCHAR(500) = @@SERVERNAME -- server name	
	,@restoreVerifyDynamicNamingActive AS BIT = 0
	-- includes the database name in the #RestoreVerify database and the data files
	-- required for concurrent execution of centralized and decentralized backup processes
	,@notifyOperator AS BIT = 1 -- 0 = no mails, 1 = notify operator by email
	,@operatorName AS NVARCHAR(500) = NULL -- (optional) name of operator. Will override default operator of configuration.
	,@opId AS UNIQUEIDENTIFIER = 0x0
AS
SET NOCOUNT ON;

DECLARE @tmpMsg AS NVARCHAR(MAX) = ''
DECLARE @restoreVerifyDbName VARCHAR(1024)

SELECT @opId = CASE 
		WHEN @opId = 0x0
			THEN NEWID()
		ELSE @opId
		END

-- clean names
SET @databaseName = CONVERT(SYSNAME, dbo.fn_prepareName(@databaseName))
SET @serverName = CONVERT(SYSNAME, dbo.fn_prepareName(@serverName))
-- prepare file name
SET @backupFileName = dbo.fn_preparePath(@backupFileName)
-- extracting the DbName from the backupFileName without extension (.bak)
SET @restoreVerifyDbName = '#RestoreVerify' + CASE 
		WHEN @restoreVerifyDynamicNamingActive = 1
			THEN '_' + dbo.fn_getFileNameWithoutExtension(dbo.fn_getFileNameFromPath(@backupFileName))
		ELSE ''
		END

INSERT INTO [dbo].[BackupCheckDetails] (
	[ServerName]
	,[DatabaseName]
	,[BackupFileName]
	,[OperationId]
	,[StartTime]
	,[EndTime]
	,[Status]
	)
VALUES (
	@serverName
	,@databaseName
	,@backupFileName
	,@opId
	,GETDATE()
	,NULL
	,'Gestartet'
	)

DECLARE @detailsId INT = @@IDENTITY
DECLARE @owner AS NVARCHAR(500) = 'RestoreVerifyBackup_' + CAST(@detailsId AS NVARCHAR(11))

SET @tmpMsg = 'Überprüfung des Backups ' + @backupFileName + ' der Datenbank ' + QUOTENAME(@databaseName) + ' gestartet'

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
	IF NOT @backupFileName LIKE '%.bak'
	BEGIN
		SET @tmpMsg = 
			'Überprüfung des Backups nicht möglich. Es werden nur vollständige Sicherungen mit der Endung .bak unterstützt.'

		EXEC dbo.sp_warn @opId
			,@tmpMsg
			,@owner
			,@serverName
	END
	ELSE
	BEGIN
		-- create temporary database #RestoreVerify
		DECLARE @createRestoryVerfiyDbSQL AS NVARCHAR(4000) = 'IF DB_ID(''' + @restoreVerifyDbName + 
			''') IS NOT NULL DROP DATABASE ' + QUOTENAME(@restoreVerifyDbName) + '
CREATE DATABASE ' + QUOTENAME(
				@restoreVerifyDbName) + ''

		EXEC sp_executeSqlLinked @createRestoryVerfiyDbSQL
			,@serverName

		DECLARE @tempRestoreFileListOnly AS TABLE (
			LogicalName NVARCHAR(128)
			,PhysicalName NVARCHAR(260)
			)

		DELETE
		FROM @tempRestoreFileListOnly

		-- determine server product version
		-- NOTE: Since Version 2008 (= 10.x) new column THEThumbprint varbinary(32) was introduced!
		-- NOTE: Since Version 2016 (= 13.x) new column SnapshotUrl nvarchar(360) was introduced!
		-- NOTE: Until Version 2016 the FileId and BackupSizeInBytes has DataType BIGINT. In newer versions it is INT!
		DECLARE @productVersion NVARCHAR(500)

		EXEC sp_getServerProductVersion @serverName
			,@productVersion OUTPUT

		SET @tmpMsg = 'Bestimmung der Produktversion des Servers: ' + @productVersion

		EXEC dbo.sp_debug @opId
			,@tmpMsg
			,@owner
			,@serverName

		DECLARE @versionDependentColumnsSql NVARCHAR(MAX) = ''
		DECLARE @mainVersion AS INT = (
				SELECT TOP 1 Part
				FROM fn_splitString(@productVersion, '.')
				)

		IF @mainVersion >= 10
		BEGIN
			SET @versionDependentColumnsSql = ',THEThumbprint varbinary(32)'

			IF @mainVersion >= 13
			BEGIN
				SET @versionDependentColumnsSql = @versionDependentColumnsSql + ',SnapshotUrl nvarchar(360)'
			END
		END

		DECLARE @createTempRestoreFileListOnlyTableSql AS NVARCHAR(4000) = 
			'

IF OBJECT_ID(N''tempdb.dbo.TempRestoreFileListOnly'', N''U'') IS NOT NULL
BEGIN
	DROP TABLE tempdb.dbo.TempRestoreFileListOnly
END

CREATE TABLE tempdb.dbo.TempRestoreFileListOnly(
     LogicalName NVARCHAR(128)
    ,PhysicalName NVARCHAR(260)
    ,Type CHAR(1)
    ,FileGroupName NVARCHAR(128)
    ,Size numeric(20,0)
    ,MaxSize numeric(20,0)
    ,FileId BIGINT
    ,CreateLSN numeric(25,0)
    ,DropLSN numeric(25,0)
    ,UniqueId uniqueidentifier
    ,ReadOnlyLSN numeric(25,0)
    ,ReadWriteLSN numeric(25,0)
    ,BackupSizeInBytes BIGINT
    ,SourceBlockSize INT
    ,FilegroupId INT
    ,LogGroupGUID uniqueidentifier
    ,DifferentialBaseLSN numeric(25)
    ,DifferentialBaseGUID uniqueidentifier
    ,IsReadOnly INT
    ,IsPresent INT
	' 
			+ @versionDependentColumnsSql + 
			'
    )
	
	INSERT INTO tempdb.dbo.TempRestoreFileListOnly
	EXEC (''RESTORE FILELISTONLY FROM DISK = ''''' 
			+ @backupFileName + ''''''')'

		EXEC sp_executeSqlLinked @createTempRestoreFileListOnlyTableSql
			,@serverName

		DECLARE @tempRestoreFileListOnlySql AS NVARCHAR(MAX) = 'SELECT [LogicalName], [PhysicalName] FROM ' + QUOTENAME(
				@serverName) + '.tempdb.dbo.TempRestoreFileListOnly'

		INSERT INTO @tempRestoreFileListOnly
		EXEC sp_executesql @tempRestoreFileListOnlySql

		DECLARE @logicalBackupFile NVARCHAR(128)
		DECLARE @restoreCommand NVARCHAR(2048)
		DECLARE @counter INT

		SET @counter = 1
		SET @restoreCommand = 'RESTORE DATABASE [' + @restoreVerifyDbName + '] FROM  DISK = ''' + @backupFileName + 
			''' WITH  FILE = 1,  NOUNLOAD, REPLACE,  STATS = 10 '

		DECLARE LogicalBackupFilesCursor CURSOR
		FOR
		SELECT LogicalName
		FROM @tempRestoreFileListOnly

		OPEN LogicalBackupFilesCursor

		FETCH NEXT
		FROM LogicalBackupFilesCursor
		INTO @logicalBackupFile

		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Datafile must be moved! NOTE: It is important to use backslashes here!
			SET @restoreCommand = @restoreCommand + ', MOVE ''' + @logicalBackupFile + ''' TO ''C:\Temp\restored' + CASE 
					WHEN @restoreVerifyDynamicNamingActive = 1
						THEN '_' + @restoreVerifyDbName + '_'
					ELSE ''
					END + CAST(@counter AS NVARCHAR(10)) + '.mdf'''
			SET @counter = @counter + 1

			FETCH NEXT
			FROM LogicalBackupFilesCursor
			INTO @logicalBackupFile
		END

		-- WARNING: ENABLE THIS IF YOU ARE SURE SCRIPT RUNS CORRECTLY!
		EXEC sp_executeSqlLinked @restoreCommand
			,@serverName

		CLOSE LogicalBackupFilesCursor

		DEALLOCATE LogicalBackupFilesCursor

		SET @tmpMsg = 'Backup ' + @backupFileName + ' wiederhergestellt in ' + @restoreVerifyDbName

		EXEC dbo.sp_debug @opId
			,@tmpMsg
			,@owner
			,@serverName

		SET @tmpMsg = 'Überprüfe ' + @restoreVerifyDbName + ' Datenbank'

		EXEC dbo.sp_debug @opId
			,@tmpMsg
			,@owner
			,@serverName

		-- WARNING: ENABLE THIS IF YOU ARE SURE SCRIPT RUNS CORRECTLY!
		DECLARE @checkDbSql NVARCHAR(MAX) = 'DBCC CHECKDB(N''' + @restoreVerifyDbName + ''')  WITH NO_INFOMSGS'

		EXEC sp_executeSqlLinked @checkDbSql
			,@serverName

		SET @tmpMsg = 'Überprüfe ' + @restoreVerifyDbName + ' Datenbank'

		EXEC dbo.sp_debug @opId
			,@tmpMsg
			,@owner
			,@serverName

		-- drop temporary database #RestoryVerify
		DECLARE @dropRestoryVerfiyDbSQL AS NVARCHAR(4000) = 'IF DB_ID(''' + @restoreVerifyDbName + 
			''') IS NOT NULL DROP DATABASE ' + QUOTENAME(@restoreVerifyDbName)

		EXEC sp_executeSqlLinked @dropRestoryVerfiyDbSQL
			,@serverName
	END
END

EXEC dbo.sp_info @opId
	,'Überprüfung des Backups beendet'
	,@owner
	,@serverName

-- CHECK FOR ERRORS AND SEND E-MAIL
DECLARE @errors AS NVARCHAR(MAX) = dbo.fn_getErrors(@opId, @owner)

IF NOT @errors = ''
BEGIN
	IF @notifyOperator = 1
	BEGIN
		SET @tmpMsg = 'Beim Überprüfen des Backups auf Konsistenz sind Fehler aufgetreten!'
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + dbo.fn_newline() + 'Fehler:' + dbo.fn_newline() + @errors
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', 
				@owner)

		EXEC dbo.sp_notifyOperator @subject = N'(CHECK) Fehler'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	UPDATE [dbo].[BackupCheckDetails]
	SET [EndTime] = GETDATE()
		,[Status] = 'Fehler'
	WHERE OperationId = @opId
		AND Id = @detailsId

	RETURN (1)
END
ELSE
BEGIN
	IF @notifyOperator = 1
	BEGIN
		SET @tmpMsg = 'Das Überprüfen des Backups war erfolgreich!'
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', 
				@owner)

		EXEC dbo.sp_notifyOperator @subject = N'(CHECK) Erfolg'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	UPDATE [dbo].[BackupCheckDetails]
	SET [EndTime] = GETDATE()
		,[Status] = 'Erfolg'
	WHERE OperationId = @opId
		AND Id = @detailsId

	RETURN (0)
END
GO
PRINT N'Prozedur "[dbo].[sp_setRecoveryModelSimple]" wird erstellt...';


GO
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
GO
PRINT N'Prozedur "[dbo].[sp_shrinkDatabase]" wird erstellt...';


GO
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
GO
PRINT N'Prozedur "[dbo].[sp_checkDatabaseViews]" wird erstellt...';


GO
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
GO
PRINT N'Prozedur "[dbo].[sp_checkViews]" wird erstellt...';


GO
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
GO
PRINT N'Prozedur "[dbo].[sp_cleanBackupFiles]" wird erstellt...';


GO
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
GO
PRINT N'Prozedur "[dbo].[sp_createBackup]" wird erstellt...';


GO
-- =============================================
-- Author:		Thomas Joscht
-- Create date: 18.12.2017
-- Description:	Creates a database backup.
-- =============================================
CREATE PROCEDURE [dbo].[sp_createBackup] @baseDirectory VARCHAR(1024) -- e.g. 'S:\Backup\täglich\'
	,@databaseName VARCHAR(1024) -- name of the database
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

-- check valid backup type
SET @backupType = UPPER(@backupType)

DECLARE @supportedBackupTypes AS NVARCHAR(1024) = ';FULL;DIFF;LOG;FULLCOPYONLY;LOGCOPYONLY;'

IF CHARINDEX(';' + @backupType + ';', @supportedBackupTypes) = 0
BEGIN
	SET @tmpMsg = 'Not supported backup type ' + @backupType + '. Valid types are: ' + @supportedBackupTypes

	RAISERROR (
			@tmpMsg
			,16
			,1
			)

	RETURN (1)
END

-- clean names
SET @databaseName = CONVERT(SYSNAME, dbo.fn_prepareName(@databaseName))
SET @serverName = CONVERT(SYSNAME, dbo.fn_prepareName(@serverName))

-- log backup operation
INSERT INTO [dbo].[BackupDetails] (
	[DatabaseName]
	,[ServerName]
	,[OperationId]
	,[BackupType]
	,[StartTime]
	,[EndTime]
	,[BaseDirectory]
	,[RetainDays]
	,[Status]
	)
VALUES (
	@databaseName
	,@serverName
	,@opId
	,@backupType
	,GETDATE()
	,NULL
	,@baseDirectory
	,@retainDays
	,'Gestartet'
	)

DECLARE @detailsId INT = @@IDENTITY
DECLARE @owner AS NVARCHAR(500) = 'CreateBackup_' + CAST(@detailsId AS NVARCHAR(11))

SET @tmpMsg = 'Erstellen des Backups von ' + QUOTENAME(@databaseName) + ' gestartet'

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
	DECLARE @backupFileName AS VARCHAR(1024)
	DECLARE @backupDBName AS VARCHAR(255)
	DECLARE @backupDirectory AS VARCHAR(1024)

	SET @backupDirectory = dbo.fn_preparePath(@baseDirectory + '/' + CASE 
				WHEN @createSubDirectory = 1
					THEN @databaseName
				ELSE ''
				END)
	-- NOTE: File extension missing. Will be added later!
	SET @backupDBName = dbo.fn_getBackupFileName(@databaseName)
	SET @backupFileName = dbo.fn_preparePath(@backupDirectory + '/' + @backupDBName)

	IF @viewCheck = 1
	BEGIN
		-- check views
		EXEC sp_checkDatabaseViews @databaseName = @databaseName
			,@serverName = @serverName
			,@notifyOperator = 0
			,@operatorName = @operatorName
			,@opId = @opId
	END

	IF @autoShrink = 1
	BEGIN
		-- shrink log file
		EXEC sp_shrinkDatabase @databaseName
			,@serverName
			,@opId
	END

	BEGIN TRY
		-- determine recovery model
		DECLARE @recoveryModel AS INT

		EXEC @recoveryModel = dbo.sp_getRecoveryModel @databaseName
			,@serverName

		-- CREATE BACKUP DIRECTORY
		SET @tmpMsg = 'Erstelle Backupordner ' + @backupDirectory

		EXEC dbo.sp_debug @opId
			,@tmpMsg
			,@owner
			,@serverName

		DECLARE @createDirSQL AS NVARCHAR(4000) = 'EXECUTE ' + QUOTENAME(@serverName) + '.master.dbo.xp_create_subdir ''' + 
			@backupDirectory + ''''

		EXEC sp_executesql @createDirSQL

		-- set file extension
		DECLARE @fileExtension AS NVARCHAR(4) = ''

		IF @backupType = 'FULL'
			OR @backupType = 'FULLCOPYONLY'
		BEGIN
			SET @fileExtension = 'bak'
		END
		ELSE IF @backupType = 'DIFF'
		BEGIN
			SET @fileExtension = 'dif'
		END
		ELSE IF @backupType = 'LOG'
			OR @backupType = 'LOGCOPYONLY'
		BEGIN
			SET @fileExtension = 'trn'
		END

		SET @backupFileName = @backupFileName + '.' + @fileExtension
		SET @tmpMsg = 'Erstelle Backup der Datenbank ' + QUOTENAME(@databaseName) + ' auf ' + @backupFileName

		EXEC dbo.sp_info @opId
			,@tmpMsg
			,@owner
			,@serverName

		UPDATE [dbo].[BackupDetails]
		SET [BackupFileName] = @backupFileName
		WHERE OperationId = @opId
			AND Id = @detailsId

		DECLARE @backupSuccess AS BIT = 0

		-- CREATE BACKUP. NOTE: Depends on type and recovery model!
		IF @backupType = 'FULL'
		BEGIN
			DECLARE @createFullBackupSQL AS NVARCHAR(4000) = 'BACKUP DATABASE ' + QUOTENAME(@databaseName) + ' TO DISK = N''' + 
				@backupFileName + '''
			WITH RETAINDAYS = ' + CONVERT(NVARCHAR(50), @retainDays) + 
				'
				,COMPRESSION
				,NOFORMAT
				,NOINIT
				,NAME = ''' + @backupDBName + 
				'''
				,SKIP
				,REWIND
				,NOUNLOAD
				,STATS = 10
				,CHECKSUM'

			EXEC sp_executeSqlLinked @createFullBackupSQL
				,@serverName

			SET @backupSuccess = 1
		END
		ELSE IF @backupType = 'DIFF'
		BEGIN
			DECLARE @createDiffBackupSQL AS NVARCHAR(4000) = 'BACKUP DATABASE ' + QUOTENAME(@databaseName) + ' TO DISK = N''' + 
				@backupFileName + '''
		WITH RETAINDAYS = ' + CONVERT(NVARCHAR(50), @retainDays) + 
				'
			,COMPRESSION
			,NOFORMAT
			,NOINIT
			,NAME = ''' + @backupDBName + 
				'''
			,SKIP
			,REWIND
			,NOUNLOAD
			,STATS = 10
			,CHECKSUM
			,DIFFERENTIAL'

			EXEC sp_executeSqlLinked @createDiffBackupSQL
				,@serverName

			SET @backupSuccess = 1
		END
		ELSE IF @backupType = 'LOG'
		BEGIN
			IF @recoveryModel = 1
			BEGIN
				DECLARE @createLogBackupSql AS NVARCHAR(4000) = 'BACKUP LOG ' + QUOTENAME(@databaseName) + ' TO DISK = N''' + 
					@backupFileName + '''
			WITH RETAINDAYS = ' + CONVERT(NVARCHAR(50), @retainDays) + 
					'
			,COMPRESSION
				,NOFORMAT
				,NOINIT
				,NAME = ''' + @backupDBName + 
					'''
				,SKIP
				,REWIND
				,NOUNLOAD
				,STATS = 10
				,CHECKSUM'

				EXEC sp_executeSqlLinked @createLogBackupSql
					,@serverName

				SET @backupSuccess = 1
			END
			ELSE
			BEGIN
				EXEC dbo.sp_error @opId
					,
					'Backup der Datenbank mit dem Typ LOG nicht möglich. Es werden nur Datenbanken mit dem Wiederherstellungsmodell Vollständig unterstützt.'
					,@owner
					,@serverName
			END
		END
		ELSE IF @backupType = 'FULLCOPYONLY'
		BEGIN
			DECLARE @createFullCopyOnlyBackupSQL AS NVARCHAR(4000) = 'BACKUP DATABASE ' + QUOTENAME(@databaseName) + 
				' TO DISK = N''' + @backupFileName + '''
		WITH RETAINDAYS = ' + CONVERT(NVARCHAR(50), @retainDays) + 
				'
			,COMPRESSION
			,NOFORMAT
			,NOINIT
			,NAME = ''' + @backupDBName + 
				'''
			,SKIP
			,REWIND
			,NOUNLOAD
			,STATS = 10
			,CHECKSUM
			,COPY_ONLY'

			EXEC sp_executeSqlLinked @createFullCopyOnlyBackupSQL
				,@serverName

			SET @backupSuccess = 1
		END
		ELSE IF @backupType = 'LOGCOPYONLY'
		BEGIN
			IF @recoveryModel = 1
			BEGIN
				DECLARE @createLogCopyOnlyBackupSQL AS NVARCHAR(4000) = 'BACKUP LOG ' + QUOTENAME(@databaseName) + 
					' TO DISK = N''' + @backupFileName + '''
		WITH RETAINDAYS = ' + CONVERT(NVARCHAR(50), @retainDays) + 
					'
			,COMPRESSION
			,NOFORMAT
			,NOINIT
			,NAME = ''' + @backupDBName + 
					'''
			,SKIP
			,REWIND
			,NOUNLOAD
			,STATS = 10
			,CHECKSUM
			,COPY_ONLY'

				EXEC sp_executeSqlLinked @createLogCopyOnlyBackupSQL
					,@serverName

				SET @backupSuccess = 1
			END
			ELSE
			BEGIN
				EXEC dbo.sp_error @opId
					,
					'Backup der Datenbank mit dem Typ LOGCOPYONLY nicht möglich. Es werden nur Datenbanken mit dem Wiederherstellungsmodell Vollständig unterstützt.'
					,@owner
					,@serverName
			END
		END

		IF @backupSuccess = 1
		BEGIN
			SET @tmpMsg = 'Backup der Datenbank ' + QUOTENAME(@databaseName) + ' erfolgreich erstellt'

			EXEC dbo.sp_debug @opId
				,@tmpMsg
				,@owner
				,@serverName

			-- SIMPLE VERIFY BACKUP
			DECLARE @verifySQL AS NVARCHAR(4000) = 'RESTORE VERIFYONLY
			FROM DISK = N''' + @backupFileName + 
				'''
			WITH FILE = 1
				,NOUNLOAD
				,NOREWIND'

			EXEC sp_executeSqlLinked @verifySQL
				,@serverName
		END

		-- EXTENDED VERIFY BACKUP
		IF @backupSuccess = 1
			AND @restoreVerify = 1
		BEGIN
			DECLARE @restoreVerifyDynamicNamingActive AS BIT = CAST(dbo.fn_getConfig('restoreVerifyDynamicNamingActive', 
						@serverName) AS BIT)

			EXEC dbo.sp_restoreVerifyBackup @backupFileName = @backupFileName
				,@databaseName = @databaseName
				,@serverName = @serverName
				,@restoreVerifyDynamicNamingActive = @restoreVerifyDynamicNamingActive
				,@notifyOperator = 0
				,@operatorName = @operatorName
				,@opId = @opId
		END

		-- CLEAN old backups
		IF @backupSuccess = 1
			AND @retainDays > 0
		BEGIN
			BEGIN TRY
				-- add 12 hours for avoiding tight deletion miss
				DECLARE @validFrom AS NVARCHAR(19) = CONVERT(NVARCHAR(19), DATEADD(day, - @retainDays, DATEADD(hour, 12, 
								SYSDATETIME())), 127)

				SET @tmpMsg = 'Aufräumen aller Backups in ' + @backupDirectory + ' älter als ' + @validFrom

				EXEC dbo.sp_info @opId
					,@tmpMsg
					,@owner
					,@serverName

				DECLARE @cleanSQL AS NVARCHAR(4000) = 'EXECUTE ' + QUOTENAME(@serverName) + 
					'.master.dbo.xp_delete_file 0
				,''' + @backupDirectory + '''
				,N''' + @fileExtension + '''
				,''' 
					+ @validFrom + '''
				,1'

				EXEC sp_executeSqlLinked @cleanSQL
					,@serverName

				SET @tmpMsg = 'Aufräumen der alten Backups war erfolgreich'

				EXEC dbo.sp_info @opId
					,@tmpMsg
					,@owner
					,@serverName
			END TRY

			BEGIN CATCH
				SET @tmpMsg = 'Fehler beim Aufräumen der alten Backups in ' + @backupDirectory + '. Fehlermeldung: ' + 
					ERROR_MESSAGE()

				EXEC dbo.sp_error @opId
					,@tmpMsg
					,@owner
					,@serverName
			END CATCH
		END

		-- CLEAN backups quantity
		IF @backupSuccess = 1
			AND @retainQuantity > 0
		BEGIN
			BEGIN TRY
				SET @tmpMsg = 'Aufräumen aller überflüssigen Backups in ' + @backupDirectory + '. Maximal ' + CONVERT(NVARCHAR(50
						), @retainQuantity) + ' Versionen werden behalten.'

				EXEC dbo.sp_info @opId
					,@tmpMsg
					,@owner
					,@serverName

				-- read existing files and directories
				DECLARE @dirTreeSql AS NVARCHAR(4000) = 'EXEC master.dbo.xp_dirtree ''' + @backupDirectory + ''', 1, 1'
				DECLARE @dirTree TABLE (
					id INT IDENTITY(1, 1)
					,entryName NVARCHAR(512)
					,depth INT
					,isFile BIT
					,backupTimestamp NVARCHAR(1024)
					);

				INSERT INTO @dirTree (
					entryName
					,depth
					,isFile
					)
				EXEC sp_executeSqlLinked @dirTreeSql
					,@serverName

				-- ignore directories 
				DELETE
				FROM @dirTree
				WHERE isFile <> 1

				-- only keep backups
				DELETE
				FROM @dirTree
				WHERE NOT entryName LIKE '%.' + @fileExtension

				-- determine timestamp of backups
				UPDATE @dirTree
				SET backupTimestamp = dbo.fn_getBackupTimestamp(entryName)

				-- keep quantity backup files
				DECLARE @i AS INT = @retainQuantity

				WHILE (@i > 0)
				BEGIN
					WITH files
					AS (
						SELECT TOP 1 *
						FROM @dirTree
						ORDER BY backupTimestamp DESC
						)
					DELETE
					FROM files

					SET @i = @i - 1
				END

				-- delete all remaining files
				DECLARE @fileName AS NVARCHAR(1024)
				DECLARE @filePath AS NVARCHAR(1024)

				DECLARE FileCursor CURSOR STATIC
				FOR
				SELECT entryName
				FROM @dirTree
				ORDER BY backupTimestamp

				OPEN FileCursor

				FETCH NEXT
				FROM FileCursor
				INTO @fileName

				WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @filePath = dbo.fn_preparePath(@backupDirectory + '/' + @fileName)
					SET @tmpMsg = 'Delete file ' + @filePath

					EXEC dbo.sp_debug @opId
						,@tmpMsg
						,@owner
						,@serverName

					EXEC dbo.sp_deleteFile @filePath = @filePath
						,@serverName = @serverName

					FETCH NEXT
					FROM FileCursor
					INTO @fileName
				END

				SET @tmpMsg = 'Aufräumen der überflüssigen Backups war erfolgreich'

				EXEC dbo.sp_info @opId
					,@tmpMsg
					,@owner
					,@serverName
			END TRY

			BEGIN CATCH
				SET @tmpMsg = 'Fehler beim Aufräumen der überflüssiger Backups in ' + @backupDirectory + '. Fehlermeldung: ' + 
					ERROR_MESSAGE()

				EXEC dbo.sp_error @opId
					,@tmpMsg
					,@owner
					,@serverName
			END CATCH
		END
	END TRY

	BEGIN CATCH
		SET @tmpMsg = 'Fehler beim Durchführen des Backups ' + @backupFileName + '. Fehlermeldung: ' + ERROR_MESSAGE()

		EXEC dbo.sp_error @opId
			,@tmpMsg
			,@owner
			,@serverName
	END CATCH
END

SET @tmpMsg = 'Erstellen des Backups beendet'

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
		SET @tmpMsg = 'Es sind Fehler während des Backups der Datenbank ' + QUOTENAME(@serverName) + '.' + QUOTENAME(
				@databaseName) + ' nach ' + @baseDirectory + ' aufgetreten!' + dbo.fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Fehler:' + dbo.fn_newline() + @errors
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

		EXEC dbo.sp_notifyOperator @subject = N'(BACKUP) Fehler'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	UPDATE [dbo].[BackupDetails]
	SET [EndTime] = GETDATE()
		,[Status] = 'Fehler'
	WHERE OperationId = @opId
		AND Id = @detailsId

	RETURN (1)
END
ELSE
BEGIN
	IF @notifyOperator = 1
	BEGIN
		SET @tmpMsg = 'Das Backup der Datenbank ' + QUOTENAME(@serverName) + '.' + QUOTENAME(@databaseName) + ' nach ' + 
			@baseDirectory + ' war erfolgreich!' + dbo.fn_newline()
		SET @tmpMsg = @tmpMsg + dbo.fn_newline() + 'Protokoll:' + dbo.fn_newline() + dbo.fn_getLogs(@opId, 'INFO', @owner)

		EXEC dbo.sp_notifyOperator @subject = N'(BACKUP) Erfolg'
			,@body = @tmpMsg
			,@name = @operatorName
	END

	UPDATE [dbo].[BackupDetails]
	SET [EndTime] = GETDATE()
		,[Status] = 'Erfolg'
	WHERE OperationId = @opId
		AND Id = @detailsId

	RETURN (0)
END
GO
PRINT N'Prozedur "[dbo].[sp_createBackups]" wird erstellt...';


GO
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
GO
PRINT N'Prozedur "[dbo].[sp_getBackups]" wird erstellt...';


GO
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
GO
PRINT N'Prozedur "[dbo].[sp_runBackupJob]" wird erstellt...';


GO
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
GO
PRINT N'Prozedur "[dbo].[sp_runBackupJobByName]" wird erstellt...';


GO
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
GO
/*
Vorlage für ein Skript nach der Bereitstellung							
--------------------------------------------------------------------------------------
 Diese Datei enthält SQL-Anweisungen, die an das Buildskript angefügt werden.		
 Schließen Sie mit der SQLCMD-Syntax eine Datei in das Skript nach der Bereitstellung ein.			
 Beispiel:   :r .\myfile.sql								
 Verwenden Sie die SQLCMD-Syntax, um auf eine Variable im Skript nach der Bereitstellung zu verweisen.		
 Beispiel:   :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
-- Default Configuration Parameter
-- NOTE: Existing parameter will not be overwritten!
MERGE INTO Config AS Target
USING (
	VALUES (
		'FreeSpaceCheckActive'
		,N'0'
		,
		'1 = execute a check for free space before performing a backup. if the threshold is not reached, the backup process aborts. 0 = no check'
		)
		,(
		'FreeSpaceThresholdMb'
		,N'50000'
		,'free space limit for the free space check'
		)
		,(
		'FreeSpaceThresholdDrive'
		,N'S'
		,'drive to check by the free space check'
		)
		,(
		'NotifyOperatorName'
		,N'Admins'
		,'name of the database mail operator'
		)
		,(
		'RestoreVerifyDynamicNamingActive'
		,N'0'
		,
		'1 = appends the backup file name in the database name and the data file name. this avoids collisions of concurrent backup processes. 0 = use default naming'
		)
	) AS Source([Key], [Value], [Description])
	ON Target.[Key] = Source.[Key]
		-- update matched rows 
WHEN MATCHED
	THEN
		UPDATE
		SET [Description] = Source.[Description]
			-- insert new rows 
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[Key]
			,[Value]
			,[Description]
			)
		VALUES (
			[Key]
			,[Value]
			,[Description]
			)
			-- delete rows that are in the target but not the source 
WHEN NOT MATCHED BY SOURCE
	THEN
		DELETE;
GO

GO
PRINT N'Vorhandene Daten werden auf neu erstellte Einschränkungen hin überprüft.';


GO
USE [$(DatabaseName)];


GO
ALTER TABLE [dbo].[BackupJobs] WITH CHECK CHECK CONSTRAINT [CHK_BackupType];

ALTER TABLE [dbo].[Log] WITH CHECK CHECK CONSTRAINT [CHK_Level];


GO
PRINT N'Update abgeschlossen.';


GO
