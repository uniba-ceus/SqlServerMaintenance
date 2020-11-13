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
