-- =============================================
-- Author:		Thomas Joscht
-- Create date: 18.12.2017
-- Description:	Returns text with CR LF characters.
-- =============================================
CREATE FUNCTION [dbo].[fn_newline] ()
RETURNS NVARCHAR(50)
AS
BEGIN
	RETURN CHAR(13) + CHAR(10)
END
