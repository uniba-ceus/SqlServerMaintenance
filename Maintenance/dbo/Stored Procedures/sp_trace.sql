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
