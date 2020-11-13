-- =============================================
-- Author:		Thomas Joscht
-- Create date: 15.12.2017
-- Description:	Splits a string based on a separator. Returns a table with ItemIndex and Part.
-- =============================================
CREATE FUNCTION [dbo].[fn_splitString] (
	@str NVARCHAR(MAX)
	,@separator CHAR(1)
	)
RETURNS TABLE
AS
RETURN (
		WITH tokens(p, a, b) AS (
				SELECT CAST(1 AS BIGINT)
					,CAST(1 AS BIGINT)
					,CHARINDEX(@separator, @str)
				
				UNION ALL
				
				SELECT p + 1
					,b + 1
					,CHARINDEX(@separator, @str, b + 1)
				FROM tokens
				WHERE b > 0
				)
		SELECT p - 1 ItemIndex
			,SUBSTRING(@str, a, CASE 
					WHEN b > 0
						THEN b - a
					ELSE LEN(@str)
					END) AS Part
		FROM tokens
		);
