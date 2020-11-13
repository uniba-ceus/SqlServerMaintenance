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
