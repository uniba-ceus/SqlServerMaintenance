-- =============================================
-- Author:		Thomas Joscht
-- Create date: 18.12.2017
-- Description:	Returns all log messages of a backup operation.
-- =============================================
CREATE FUNCTION [dbo].[fn_getLogs] (
	@operationId UNIQUEIDENTIFIER
	,@minLevel NVARCHAR(MAX) = 'INFO'
	,@owner NVARCHAR(500) = ''
	)
RETURNS NVARCHAR(MAX)
AS
BEGIN
	DECLARE @msgs NVARCHAR(MAX) = ''

	IF @owner = ''
	BEGIN
		SET @owner = '%'
	END

	IF @minLevel = 'TRACE'
	BEGIN
		SELECT @msgs = @msgs + dbo.fn_formatLog([OperationId], [Msg], [Level], [Owner], [ServerName], [LogTime]) + dbo.fn_newline()
		FROM Log
		WHERE OperationId = @operationId
			AND [Owner] LIKE @owner
			AND (
				[Level] LIKE 'TRACE'
				OR [Level] LIKE 'DEBUG'
				OR [Level] LIKE 'INFO'
				OR [Level] LIKE 'WARNUNG'
				OR [Level] LIKE 'FEHLER'
				)
	END
	ELSE IF @minLevel = 'DEBUG'
	BEGIN
		SELECT @msgs = @msgs + dbo.fn_formatLog([OperationId], [Msg], [Level], [Owner], [ServerName], [LogTime]) + dbo.fn_newline()
		FROM Log
		WHERE OperationId = @operationId
			AND [Owner] LIKE @owner
			AND (
				[Level] LIKE 'DEBUG'
				OR [Level] LIKE 'INFO'
				OR [Level] LIKE 'WARNUNG'
				OR [Level] LIKE 'FEHLER'
				)
	END
	ELSE IF @minLevel = 'INFO'
	BEGIN
		SELECT @msgs = @msgs + dbo.fn_formatLog([OperationId], [Msg], [Level], [Owner], [ServerName], [LogTime]) + dbo.fn_newline()
		FROM Log
		WHERE OperationId = @operationId
			AND [Owner] LIKE @owner
			AND (
				[Level] LIKE 'INFO'
				OR [Level] LIKE 'WARNUNG'
				OR [Level] LIKE 'FEHLER'
				)
	END
	ELSE IF @minLevel = 'WARNUNG'
	BEGIN
		SELECT @msgs = @msgs + dbo.fn_formatLog([OperationId], [Msg], [Level], [Owner], [ServerName], [LogTime]) + dbo.fn_newline()
		FROM Log
		WHERE OperationId = @operationId
			AND [Owner] LIKE @owner
			AND (
				[Level] LIKE 'WARNUNG'
				OR [Level] LIKE 'FEHLER'
				)
	END
	ELSE IF @minLevel = 'FEHLER'
	BEGIN
		SELECT @msgs = @msgs + dbo.fn_formatLog([OperationId], [Msg], [Level], [Owner], [ServerName], [LogTime]) + dbo.fn_newline()
		FROM Log
		WHERE OperationId = @operationId
			AND [Owner] LIKE @owner
			AND [Level] LIKE 'FEHLER'
	END

	RETURN @msgs
END
