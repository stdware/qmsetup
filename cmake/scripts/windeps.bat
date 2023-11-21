@echo off
setlocal enabledelayedexpansion

:: 初始化参数
set "INPUT_DIR="
set "PLUGIN_DIR="
set "LIB_DIR="
set "QMAKE_PATH="
set "QMCORECMD_PATH="
set "VERBOSE="
set "FILES="
set "EXTRA_PLUGIN_PATHS="
set "PLUGINS="
set "COPY_ARGS="

:: 解析命令行参数
:parse_args
if "%~1"=="" goto :end_parse_args
if "%1"=="-i" set "INPUT_DIR=%~2" & shift & shift & goto :parse_args
if "%1"=="-p" set "PLUGIN_DIR=%~2" & shift & shift & goto :parse_args
if "%1"=="-l" set "LIB_DIR=%~2" & shift & shift & goto :parse_args
if "%1"=="-q" set "QMAKE_PATH=%~2" & shift & shift & goto :parse_args
if "%1"=="-P" set "EXTRA_PLUGIN_PATHS=!EXTRA_PLUGIN_PATHS! %~2" & shift & shift & goto :parse_args
if "%1"=="-m" set "QMCORECMD_PATH=%~2" & shift & shift & goto :parse_args
if "%1"=="-t" set "PLUGINS=!PLUGINS! %~2" & shift & shift & goto :parse_args
if "%1"=="-c" set "COPY_ARGS=!COPY_ARGS! -c %~2 %~3" & shift & shift & shift & goto :parse_args
if "%1"=="-f" set "ARGS=!ARGS! -f" & shift & goto :parse_args
if "%1"=="-s" set "ARGS=!ARGS! -s" & shift & goto :parse_args
if "%1"=="-V" set "VERBOSE=-V" & shift & goto :parse_args
if "%1"=="-h" call :usage & exit /b

if "%1"=="-@" set "ARGS=!ARGS! -@ %~2" & shift & shift & goto :parse_args
if "%1"=="-L" set "ARGS=!ARGS! -L %~2" & shift & shift & goto :parse_args

shift
goto :parse_args
:end_parse_args

:: 检查必需参数
if not defined INPUT_DIR echo Error: Missing required argument 'INPUT_DIR' & call :usage & exit /b
if not defined PLUGIN_DIR echo Error: Missing required argument 'PLUGIN_DIR' & call :usage & exit /b
if not defined LIB_DIR echo Error: Missing required argument 'LIB_DIR' & call :usage & exit /b
if not defined QMCORECMD_PATH echo Error: Missing required argument 'QMCORECMD_PATH' & call :usage & exit /b

:: 获取 Qt 插件安装路径
if defined QMAKE_PATH (
    for /f "tokens=*" %%a in ('!QMAKE_PATH! -query QT_INSTALL_PLUGINS') do set "QMAKE_PLUGIN_PATH=%%a"
    set "PLUGIN_PATHS=!QMAKE_PLUGIN_PATH!"
)

:: 添加额外的插件搜索路径
set "PLUGIN_PATHS=!PLUGIN_PATHS! !EXTRA_PLUGIN_PATHS!"

:: 根据操作系统决定搜索的文件类型
:: Windows 环境，搜索 .exe 和 .dll 文件
for /r "%INPUT_DIR%" %%f in (*.exe *.dll) do (
    set "FILES=!FILES! %%f"
)

:: 查找 Qt 插件的完整路径
for %%p in (!PLUGINS!) do (
    set "plugin_path=%%p"

    :: 检查格式
    echo !plugin_path! | findstr /R "[^/]*\/[^/]*" >nul
    if errorlevel 1 (
        echo Error: Invalid plugin format '!plugin_path!'. Expected format: ^<category^>/^<name^>
        exit /b
    )

    :: 提取类别和名称
    for /f "tokens=1,2 delims=/" %%a in ("!plugin_path!") do (
        set "category=%%a"
        set "name=%%b"

        :: 遍历路径并查找具体插件文件
        set "FOUND_PLUGIN="
        call :search_plugin

        if not defined FOUND_PLUGIN (
            echo Error: Plugin '!plugin_path!' not found in any search paths.
            exit /b
        )

        set "DESTINATION_DIR=!PLUGIN_DIR!\!category!"
        set "DESTINATION_DIR=!DESTINATION_DIR:/=\!"

        mkdir "!DESTINATION_DIR!" >nul 2>&1
        set "FILES=!FILES! -c !FOUND_PLUGIN! !DESTINATION_DIR!"
    )
)

:: 添加额外的 -c 参数
set "FILES=!FILES! !COPY_ARGS!"

:: 构建并执行 qmcorecmd deploy 命令
set "DEPLOY_CMD=!QMCORECMD_PATH! deploy !FILES! !ARGS! !VERBOSE! -o !LIB_DIR!"
if "!VERBOSE!"=="-V" echo Executing: !DEPLOY_CMD!
call !DEPLOY_CMD!

:: 检查部署结果
if %errorlevel% neq 0 exit /b
exit /b

:: 查找插件
:search_plugin
for %%d in (!PLUGIN_PATHS!) do (
    for %%f in ("%%d\!category!\!name!*") do (
        if exist "%%f" (
            set "FOUND_PLUGIN=%%f"
            exit /b
        )
    )
)
exit /b

:: 显示简介
:usage
echo Usage: %~nx0 -i ^<input_dir^> -p ^<plugin_dir^> -l ^<lib_dir^> -m ^<qmcorecmd_path^>
echo                     [-q ^<qmake_path^>] [-P ^<extra_path^>]...
echo                     [-t ^<plugin^>]... [-c ^<src^> ^<dest^>]... [-f] [-s] [-V] [-h]
echo                     [-f] [-s] [-V] [-h]
echo                     [-@ ^<file^>]... [-L ^<path^>]...
exit /b