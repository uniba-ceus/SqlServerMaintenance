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
