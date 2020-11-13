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
