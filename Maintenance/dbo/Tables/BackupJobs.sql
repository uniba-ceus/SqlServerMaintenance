﻿CREATE TABLE [dbo].[BackupJobs] (
	[Id] INT IDENTITY(1, 1) NOT NULL
	,[Name] NVARCHAR(500) NOT NULL
	,[ServerName] NVARCHAR(500) NOT NULL DEFAULT @@SERVERNAME
	,[DatabaseNames] NVARCHAR(MAX) NOT NULL
	,[BaseDirectory] NVARCHAR(1024) NOT NULL
	,[BackupType] NVARCHAR(50) NOT NULL DEFAULT 'FULL'
	,[RetainDays] INT NOT NULL DEFAULT 0
	,[RetainQuantity] INT NOT NULL DEFAULT 0
	,[RestoreVerify] BIT NOT NULL DEFAULT 0
	,[AutoShrink] BIT NOT NULL DEFAULT 1
	,[ViewCheck] BIT NOT NULL DEFAULT 1
	,[CreateSubDirectory] INT NOT NULL DEFAULT 1
	,[Description] NVARCHAR(MAX) NULL
	,CONSTRAINT [PK_BackupJobs] PRIMARY KEY CLUSTERED ([Id] ASC)
	,CONSTRAINT [CHK_BackupType] CHECK (
		BackupType = 'FULL'
		OR BackupType = 'DIFF'
		OR BackupType = 'LOG'
		OR BackupType = 'FULLCOPYONLY'
		OR BackupType = 'LOGCOPYONLY'
		)
	,CONSTRAINT [CHK_Name] UNIQUE ([Name])
	);
