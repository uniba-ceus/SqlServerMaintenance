-- =============================================
-- Author:		Thomas Joscht
-- Create date: 15.12.2017
-- Description:	Escapes a given string. Replaces -, :, and . to _ .
-- =============================================
CREATE FUNCTION [dbo].[fn_escape] (@text NVARCHAR(1024))
RETURNS NVARCHAR(1024)
AS
BEGIN
	RETURN Replace(Replace(Replace(@text, '-', '_'), ':', ''), '.', '_')
END
