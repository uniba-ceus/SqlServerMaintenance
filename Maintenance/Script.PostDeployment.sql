/*
Vorlage für ein Skript nach der Bereitstellung							
--------------------------------------------------------------------------------------
 Diese Datei enthält SQL-Anweisungen, die an das Buildskript angefügt werden.		
 Schließen Sie mit der SQLCMD-Syntax eine Datei in das Skript nach der Bereitstellung ein.			
 Beispiel:   :r .\myfile.sql								
 Verwenden Sie die SQLCMD-Syntax, um auf eine Variable im Skript nach der Bereitstellung zu verweisen.		
 Beispiel:   :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
-- Default Configuration Parameter
-- NOTE: Existing parameter will not be overwritten!
MERGE INTO Config AS Target
USING (
	VALUES (
		'FreeSpaceCheckActive'
		,N'0'
		,
		'1 = Execute a check for free space before performing a backup. If the threshold is not reached, the backup process aborts. 0 = No check.'
		)
		,(
		'FreeSpaceThresholdMb'
		,N'50000'
		,'Free space limit for the free space check.'
		)
		,(
		'FreeSpaceThresholdDrive'
		,N'S'
		,'Drive to check by the free space check.'
		)
		,(
		'NotifyOperatorName'
		,N'Admins'
		,'Name of the database mail operator.'
		)
		,(
		'RestoreVerifyDynamicNamingActive'
		,N'0'
		,
		'1 = Appends the backup file name in the database name and the data file name. this avoids collisions of concurrent backup processes. 0 = Use default naming.'
		)
		,(
		'RestoreVerifyTempDirectoryPath'
		,N'C:\Temp'
		,
		'Path to a temporary directory wehre verify command stores the restored data files. This path must be exist. Use only backslashes and no trailing backslash.'
		)
	) AS Source([Key], [Value], [Description])
	ON Target.[Key] = Source.[Key]
		-- update matched rows 
WHEN MATCHED
	THEN
		UPDATE
		SET [Description] = Source.[Description]
			-- insert new rows 
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[Key]
			,[Value]
			,[Description]
			)
		VALUES (
			[Key]
			,[Value]
			,[Description]
			)
			-- delete rows that are in the target but not the source 
WHEN NOT MATCHED BY SOURCE
	THEN
		DELETE;
