-- =============================================
-- Author:		Tobias Kiehl
-- Create date: 20.03.2019
-- Description:	Splits a filename with full path and return the filename without path.
-- =============================================
CREATE FUNCTION [dbo].[fn_getFileNameFromPath] (@str NVARCHAR(MAX))
RETURNS NVARCHAR(1024)
AS
BEGIN
	RETURN (
			SELECT TOP 1 Part
			FROM dbo.fn_splitString(dbo.fn_preparePath(@str), '/')
			ORDER BY ItemIndex DESC
			)
END
