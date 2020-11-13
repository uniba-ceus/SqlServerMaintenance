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
