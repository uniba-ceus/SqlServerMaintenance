﻿CREATE TABLE [dbo].[Log] (
	[Id] INT IDENTITY(1, 1) NOT NULL
	,[ServerName] NVARCHAR(500) CONSTRAINT [DF_Log_ServerName] DEFAULT(@@servername) NOT NULL
	,[LogTime] DATETIME CONSTRAINT [DF_Log_LogTime] DEFAULT(getdate()) NOT NULL
	,[Level] NVARCHAR(10) NOT NULL
	,[OperationId] UNIQUEIDENTIFIER NOT NULL
	,[Owner] NVARCHAR(500) NOT NULL
	,[Msg] NVARCHAR(MAX) NOT NULL
	,CONSTRAINT [PK_Log] PRIMARY KEY CLUSTERED ([Id] ASC)
	,CONSTRAINT [CHK_Level] CHECK (
		[Level] = 'TRACE'
		OR [Level] = 'DEBUG'
		OR [Level] = 'INFO'
		OR [Level] = 'WARNUNG'
		OR [Level] = 'FEHLER'
		)
	);
