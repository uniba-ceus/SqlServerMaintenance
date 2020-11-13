-- =============================================
-- Author:		Thomas Joscht
-- Create date: 09.04.2018
-- Description:	Notifies an operator per HTML mail. Copied from sp_notify_operator procedure and extended with @body_format paramater and some custom code.
-- =============================================
CREATE PROCEDURE [dbo].[sp_notifyOperator] @profile_name SYSNAME = NULL
	,
	-- name of database mail profile to be used for sending the email, cannot be null
	@id INT = NULL
	,@name SYSNAME = NULL
	-- Mutual exclusive, one and only one should be non null. Specify the operator whose email address will be used to send this email.
	,@subject NVARCHAR(256) = NULL
	,@body NVARCHAR(MAX) = NULL
	-- body of the email message
	,@file_attachments NVARCHAR(512) = NULL
	,@mail_database SYSNAME = N'msdb'
	-- have infrastructure in place to support this but disabled by default
	-- for first implementation we will have this parameters but using it will generate an error - not implemented yet.
	-- CUSTOM CODE --
	,@body_format VARCHAR(20) = NULL
	-- default is NULL which will use TEXT in procedure sp_send_dbmail
	,@serverName AS NVARCHAR(500) = @@SERVERNAME
	-----------------
AS
BEGIN
	-- CUSTOM CODE --
	IF (@name IS NULL)
	BEGIN
		-- try to read operator name from configuration
		DECLARE @notifyOperatorName AS NVARCHAR(500) = dbo.fn_getConfig('NotifyOperatorName', @serverName)

		SET @name = CONVERT(SYSNAME, @notifyOperatorName)
	END

	-----------------
	DECLARE @retval INT
	DECLARE @email_address NVARCHAR(100)
	DECLARE @enabled TINYINT
	DECLARE @qualified_sp_sendmail SYSNAME
	DECLARE @db_id INT

	SET NOCOUNT ON

	-- remove any leading and trailing spaces from parameters
	SELECT @profile_name = LTRIM(RTRIM(@profile_name))

	SELECT @name = LTRIM(RTRIM(@name))

	SELECT @file_attachments = LTRIM(RTRIM(@file_attachments))

	SELECT @mail_database = LTRIM(RTRIM(@mail_database))

	IF @profile_name = ''
		SELECT @profile_name = NULL

	IF @name = ''
		SELECT @name = NULL

	IF @file_attachments = ''
		SELECT @file_attachments = NULL

	IF @mail_database = ''
		SELECT @mail_database = NULL

	EXECUTE @retval = msdb.dbo.sp_verify_operator_identifiers '@name'
		,'@id'
		,@name OUTPUT
		,@id OUTPUT

	IF (@retval <> 0)
		RETURN (1) -- failure

	-- checks if the operator is available
	SELECT @enabled = enabled
		,@email_address = email_address
	FROM msdb.dbo.sysoperators
	WHERE id = @id

	IF @enabled = 0
	BEGIN
		RAISERROR (
				14601
				,16
				,1
				,@name
				)

		RETURN 1
	END

	IF @email_address IS NULL
	BEGIN
		RAISERROR (
				14602
				,16
				,1
				,@name
				)

		RETURN 1
	END

	SELECT @qualified_sp_sendmail = @mail_database + '.dbo.sp_send_dbmail'

	EXEC @retval = @qualified_sp_sendmail @profile_name = @profile_name
		,@recipients = @email_address
		,@subject = @subject
		,@body = @body
		,@file_attachments = @file_attachments
		,@body_format = @body_format

	RETURN @retval
END
