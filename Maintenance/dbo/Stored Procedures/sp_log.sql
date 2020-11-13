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
