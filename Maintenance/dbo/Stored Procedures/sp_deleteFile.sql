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
