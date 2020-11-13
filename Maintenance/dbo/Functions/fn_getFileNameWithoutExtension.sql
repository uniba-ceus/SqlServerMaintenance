-- =============================================
-- Author:		Tobias Kiehl
-- Create date: 20.03.2019
-- Description:	Splits a filename and its extension and returns the filename without extension.
-- =============================================
CREATE FUNCTION [dbo].[fn_getFileNameWithoutExtension] (@str NVARCHAR(MAX))
RETURNS NVARCHAR(1024)

BEGIN
	RETURN (
			SELECT TOP 1 Part
			FROM fn_splitString((@str), '.')
			)
END
