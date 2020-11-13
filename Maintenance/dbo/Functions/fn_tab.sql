-- =============================================
-- Author:		Thomas Joscht
-- Create date: 18.12.2017
-- Description:	Returns text with TAB character.
-- =============================================
CREATE FUNCTION [dbo].[fn_tab] ()
RETURNS NVARCHAR(50)
AS
BEGIN
	RETURN CHAR(9)
END
