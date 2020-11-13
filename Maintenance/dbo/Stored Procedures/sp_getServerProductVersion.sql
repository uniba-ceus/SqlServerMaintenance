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
