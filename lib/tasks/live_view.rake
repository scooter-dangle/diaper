desc "Update the development db to what is being used in prod"
task :copy_live => :environment do
  system("echo Performing dump of the database.")
  system("ssh diaperdeploy 'pg_dump -U diaper_base -h localhost -Fc diaper_base_production > backup.dump'")
  system("echo Downloading dump of the database locally.")
  system("scp diaperdeploy:~/backup.dump .")
  system("echo Download complete, removing remote copy of dump.")
  system("ssh diaperdeploy 'rm backup.dump'")
  system("echo Loading dump into local database.")
  system("pg_restore --verbose --clean --no-acl --no-owner -h localhost -d diaper_dev backup.dump")
  system("echo Removing local copy of the database dump.")
  system("rm backup.dump")
end
