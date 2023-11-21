@echo off
setlocal enabledelayedexpansion

:: 初始化参数
set "INPUT_DIR="
set "PLUGIN_DIR="
set "LIB_DIR="
set "QML_DIR="
set "QMAKE_PATH="
set "QMCORECMD_PATH="
set "VERBOSE="
set "FILES="
set "EXTRA_PLUGIN_PATHS="
set "PLUGINS="
set "QML_REL_PATHS="
set "ARGS="

:: 解析命令行参数
:parse_args
if "%~1"=="" goto :end_parse_args
if "%1"=="-i" set "INPUT_DIR=%~2" & shift & shift & goto :parse_args
if "%1"=="-m" set "QMCORECMD_PATH=%~2" & shift & shift & goto :parse_args
if "%1"=="--plugindir" set "PLUGIN_DIR=%~2" & shift & shift & goto :parse_args
if "%1"=="--libdir" set "LIB_DIR=%~2" & shift & shift & goto :parse_args
if "%1"=="--qmldir" set "QML_DIR=%~2" & shift & shift & goto :parse_args
if "%1"=="--qmake" set "QMAKE_PATH=%~2" & shift & shift & goto :parse_args
if "%1"=="--extra" set "EXTRA_PLUGIN_PATHS=!EXTRA_PLUGIN_PATHS! %~2" & shift & shift & goto :parse_args
if "%1"=="--plugin" set "PLUGINS=!PLUGINS! %~2" & shift & shift & goto :parse_args
if "%1"=="--qml" set "QML_REL_PATHS=!QML_REL_PATHS! %~2" & shift & shift & goto :parse_args
if "%1"=="--copy" set "ARGS=!ARGS! -c %~2 %~3" & shift & shift & shift & goto :parse_args
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
if not defined QML_DIR echo Error: Missing required argument 'QML_DIR' & call :usage & exit /b
if not defined QMCORECMD_PATH echo Error: Missing required argument 'QMCORECMD_PATH' & call :usage & exit /b

:: 获取 Qt 插件安装路径和 Qt QML 目录
set "PLUGIN_PATHS="
set "QML_PATH="
if defined QMAKE_PATH (
    for /f "tokens=*" %%a in ('!QMAKE_PATH! -query QT_INSTALL_PLUGINS') do set "QMAKE_PLUGIN_PATH=%%a"
    set "PLUGIN_PATHS=!QMAKE_PLUGIN_PATH!"
    for /f "tokens=*" %%a in ('!QMAKE_PATH! -query QT_INSTALL_QML') do set "QML_PATH=%%a"
    set "QML_PATH=!QML_PATH:/=\!"

    :: 添加 Qt bin 目录
    for /f "tokens=*" %%a in ('!QMAKE_PATH! -query QT_INSTALL_BINS') do set "QT_BIN_PATH=%%a"
    set "ARGS=!ARGS! -L !QT_BIN_PATH!"
)

:: 添加额外的插件搜索路径
set "PLUGIN_PATHS=!PLUGIN_PATHS! !EXTRA_PLUGIN_PATHS!"

:: 确保指定了 QML 相关路径时 QML 搜索路径不为空（需要指定 qmake）
if not "%QML_REL_PATHS%"=="" (
    if "%QML_PATH%"=="" (
        echo Error: qmake path must be specified when QML paths are provided
        exit /b
    )
)

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
        set "ARGS=!ARGS! -c !FOUND_PLUGIN! !DESTINATION_DIR!"
    )
)

:: 处理 QML 目录
for %%q in (%QML_REL_PATHS%) do (
    call :traverse_qml "%%q"
)

:: 构建并执行 qmcorecmd deploy 命令
set "DEPLOY_CMD=!QMCORECMD_PATH! deploy !FILES! !ARGS! -o !LIB_DIR! !VERBOSE!"
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




:: qml 目录内层循环
:traverse_qml
set "full_path=%QML_PATH%\%~1"
if exist "%full_path%\" (
    for /r "%full_path%" %%f in (*) do (
        call :handle_qml_file "%%f" "%QML_DIR%"
    )
) else if exist "%full_path%" (
    :: 处理单个文件
    call :handle_qml_file "%full_path%" "%QML_DIR%"
)
exit /b




:: 复制或添加到部署命令的函数
:handle_qml_file
set "file=%~1"
set "target_dir=%~2"

:: 标准化
set "file=!file:/=\!"
set "target_dir=!target_dir:/=\!"

:: 忽略特定文件（示例）
if "!file:~-4!"==".pdb" exit /b
if "!file:~-10!"==".dll.debug" exit /b
if "!file:~-5!" == "d.dll" (
    set "prefix=!file:~0,-5!"
    if exist "!prefix!.dll" (
        exit /b
    )
)

:: 用很智障的方式计算目标文件夹和目标文件
set "rel_path=!file:%QML_PATH%\=!"
set "target=%target_dir%\%rel_path%"
for %%I in ("!file!") do (
    set "file_dir=%%~dpI"
)
set "rel_dir_path=!file_dir:%QML_PATH%\=!"
set "target_dir=%target_dir%\%rel_dir_path%"

:: 判断是否为可执行二进制文件并相应处理
if "%file:~-4%"==".dll" (
    set "ARGS=!ARGS! -c !file! !target_dir!"
) else if "%file:~-4%"==".exe" (
    set "ARGS=!ARGS! -c !file! !target_dir!"
) else (
    if not exist "%target%" (
        mkdir "%target_dir%" >nul 2>&1
    )
    copy /Y "%file%" "%target%" >nul 2>&1
)

exit /b




:: 显示简介
:usage
echo Usage: %~n0 -i ^<dir^> -m ^<path^>
echo                --plugindir ^<plugin_dir^> --libdir ^<lib_dir^> --qmldir ^<qml_dir^>
echo               [--qmake ^<qmake_path^>] [--extra ^<extra_path^>]...
echo               [--qml ^<qml_module^>]... [--plugin ^<plugin^>]... [--copy ^<src^> ^<dest^>]...
echo               [-f] [-s] [-V] [-h]
echo               [-@ ^<file^>]... [-L ^<path^>]...
exit /b