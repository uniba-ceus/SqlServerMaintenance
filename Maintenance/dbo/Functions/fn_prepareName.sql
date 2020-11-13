-- =============================================
-- Author:		Thomas Joscht
-- Create date: 01.03.2018
-- Description:	Prepares a given name. Replaces CR LF with empty string. Replaces tabs with blanks. Trims the text.
-- =============================================
CREATE FUNCTION [dbo].[fn_prepareName] (@text NVARCHAR(1024))
RETURNS NVARCHAR(1024)
AS
BEGIN
	RETURN LTRIM(RTRIM(REPLACE(REPLACE(@text, dbo.fn_newline(), ''), CHAR(9), ' ')))
END
