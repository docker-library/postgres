@echo off
SETLOCAL EnableDelayedExpansion

:: Batch file has no concept of a function, only goto
goto :start

:: usage: CALL :file_env VARIABLE [DEFAULT]
::    ie: CALL :file_env 'XYZ_DB_PASSWORD' 'example'
::       (will allow for "%XYZ_DB_PASSWORD_FILE%" to fill in the value of
::       "%XYZ_DB_PASSWORD%" from a file, especially for Docker's secrets feature)
:file_env
:: Reset all values
set cmdVar=
set fileVar=
set default=
set value=
:: Start the 'function'
set cmdVar=%~1
set fileVar=%cmdVar%_FILE
set default=%~2
:: No concept of AND in batch scripts
:: Instead we use nested if
if NOT [!%cmdVar%!] == [] (
    if NOT [!%fileVar%!] == [] (
        :: Instead of exiting, just use the environment value
        echo Warning: both %cmdVar% and %fileVar% are set, %fileVar% will be ignored
    )
)
:: set as the default value
set value=%default%
if NOT [!%cmdVar%!] == [] (
    :: override with the environment value
    set value=!%cmdVar%!
)
:: No concept of ELIF in batch scripts
:: we use nested if with opposite test
if [!%cmdVar%!] == [] (
    if NOT [!%fileVar%!] == [] (
        :: override with the file value
        set /p value=<!%fileVar%!
    )
)
set %cmdVar%=%value%
EXIT /B 0

:: ------------------------------------------------------------
:: ------------------------------------------------------------
:: ------------------------------------------------------------

:start

:: Ensure the data directory exists
if NOT exist %PGDATA% (
    mkdir %PGDATA%
)

:: Ensure the directories have correct permissions
call icacls "%PGDATA%" /grant "%USERNAME%":(OI)(CI)F > NUL

:: look specifically for PG_VERSION, as it is expected in the DB dir
if NOT exist "%PGDATA%\PG_VERSION" (

    call :file_env POSTGRES_USER, postgres
    call :file_env POSTGRES_PASSWORD
    call :file_env POSTGRES_INITDB_ARGS

    if NOT [!POSTGRES_PASSWORD!] == [] (
        echo !POSTGRES_PASSWORD!> "C:\.pgpass"
        set POSTGRES_INITDB_ARGS=!POSTGRES_INITDB_ARGS! --pwfile="C:\.pgpass"
    )

    if NOT [%POSTGRES_INITDB_WALDIR%] == [] (
        set POSTGRES_INITDB_ARGS=!POSTGRES_INITDB_ARGS! --waldir %POSTGRES_INITDB_WALDIR%
    )

    call initdb -U "!POSTGRES_USER!" -E UTF8 --no-locale -D "%PGDATA%" !POSTGRES_INITDB_ARGS!
    if exist "C:\.pgpass" (
        call del "C:\.pgpass"
    )

    if NOT [!POSTGRES_PASSWORD!] == [] (
        set authMethod=md5
        echo authMethod: !authMethod!
    ) else (
        echo ****************************************************
        echo WARNING: No password has been set for the database.
        echo          This will allow anyone with access to the
        echo          Postgres port to access your database. In
        echo          Docker's default configuration, this is
        echo          effectively any other container on the same
        echo          system.
        echo          Use "-e POSTGRES_PASSWORD=password" to set
        echo          it in "docker run".
        echo ****************************************************
        set authMethod=trust
        echo authMethod: !authMethod!
    )
    echo.>> "%PGDATA%\pg_hba.conf"
    echo host all all all !authMethod!>> "%PGDATA%\pg_hba.conf"

    :: internal start of server in order to allow set-up using psql-client
    :: does not listen on external TCP/IP and waits until start finishes
	call pg_ctl -U "!POSTGRES_USER!" -D "%PGDATA%" -w start

    call :file_env POSTGRES_DB !POSTGRES_USER!

    set psqlParam=^-v ON_ERROR_STOP=1 --username "!POSTGRES_USER!" --no-password

    :: Create a database with its name as the user name, override %PGDATABASE%
    if NOT [!POSTGRES_DB!] == [postgres] (
        echo CREATE DATABASE :"db"; | call psql !psqlParam! --dbname postgres --set db="!POSTGRES_DB!"
    )
    set psqlParam=^-v ON_ERROR_STOP=1 --username "!POSTGRES_USER!" --no-password --dbname "!POSTGRES_DB!"

    :: Execute any batch scripts for this new DB
    for %%f in (C:\docker-entrypoint-initdb.d\*.cmd) do (
        echo cmd: running %%f
        call "%%f"
    )
    :: Execute any SQL scripts for this new DB
    for %%f in (C:\docker-entrypoint-initdb.d\*.sql) do (
        echo psql: running %%f
        call psql !psqlParam! -f "%%f"
    )

    pg_ctl -U "!POSTGRES_USER!" -D "%PGDATA%" -m fast -w stop

    echo PostgreSQL init process complete; ready for start up.
)

:: start the database
call %*
