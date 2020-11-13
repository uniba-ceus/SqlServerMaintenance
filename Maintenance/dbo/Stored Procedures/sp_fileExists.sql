-- =============================================
-- Author:		Tobias Kiehl
-- Create date: 26.09.2018
-- Description:	Checks if a file in a file system is existing. Returns 1 if the file exists, otherwise 0.
-- =============================================
CREATE PROCEDURE sp_fileExists @filePath NVARCHAR(4000)
	,@serverName NVARCHAR(500) = @@SERVERNAME
AS
BEGIN
	DECLARE @exists AS INT = 0
	DECLARE @filexExistsSql AS NVARCHAR(4000) = 'EXEC master.dbo.xp_fileexist ''' + @filePath + ''''
	DECLARE @fileResults TABLE (
		fileExists INT
		,fileIsADirectory INT
		,parentDirectoryExists INT
		)

	BEGIN TRY
		INSERT INTO @fileResults (
			fileExists
			,fileIsADirectory
			,parentDirectoryExists
			)
		EXEC sp_executeSqlLinked @filexExistsSql
			,@serverName
	END TRY

	BEGIN CATCH
		IF ERROR_NUMBER() = 7391
		BEGIN
			-- suppress error and log it
			EXEC dbo.sp_error 0x0
				,
				'The procedure sp_fileExists needs enabled MSDTC or linked server option "remote proc transaction promotion" must be set to false!'
		END
		ELSE
		BEGIN
				;

			THROW
		END
	END CATCH

	SET @exists = (
			SELECT TOP 1 fileExists
			FROM @fileResults
			);

	IF @exists IS NULL
	BEGIN
		SET @exists = - 1
	END

	RETURN @exists
END
