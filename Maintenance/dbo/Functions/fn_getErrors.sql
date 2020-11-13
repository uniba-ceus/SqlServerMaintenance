-- =============================================
-- Author:		Thomas Joscht
-- Create date: 18.12.2017
-- Description:	Returns all error messages of a backup operation.
-- =============================================
CREATE FUNCTION [dbo].[fn_getErrors] (
	@operationId UNIQUEIDENTIFIER
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

	SELECT @msgs = @msgs + CONVERT(NVARCHAR(128), LogTime, 20) + ' [' + [Level] + '] ' + [ServerName] + ': ' + Msg + CHAR(13) + CHAR(10)
	FROM Log
	WHERE [OperationId] = @operationId
		AND [Owner] LIKE @owner
		AND [Level] LIKE 'FEHLER'

	RETURN @msgs
END
