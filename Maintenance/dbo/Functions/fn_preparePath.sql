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
