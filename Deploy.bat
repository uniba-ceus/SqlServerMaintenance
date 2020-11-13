REM "Build project"
msbuild Maintenance/Maintenance.sqlproj 
REM "Deploy to localhost"
msbuild Maintenance/Maintenance.sqlproj /t:Publish /p:SqlPublishProfilePath=../publish/Local.publish.xml