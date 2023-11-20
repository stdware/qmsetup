#!/bin/bash

# 显示用法信息
usage() {
    echo "Usage: $(basename $0) -i <input_dir> -p <plugin_dir> -l <lib_dir> -q <qmake_path> -m <qmcorecmd_path> [-t <plugin>]... [-c <src> <dest>]... [-f] [-s] [-V]"
    echo "  -i <input_dir>       Directory containing binaries and libraries"
    echo "  -p <plugin_dir>      Output directory for plugins"
    echo "  -l <lib_dir>         Output directory for libraries"
    echo "  -q <qmake_path>      Path to qmake"
    echo "  -m <qmcorecmd_path>  Path to qmcorecmd"
    echo "  -t <plugin>          Specify a Qt plugin to deploy. Can be repeated for multiple plugins."
    echo "  -c <src> <dest>      Specify additional binary file to copy and its destination directory. Can be repeated."
    echo "  -f                   Force overwrite existing files"
    echo "  -s                   Ignore C/C++ runtime and system libraries"
    echo "  -V                   Show verbose output"
    echo "  -h                   Show this help message"
}

# 初始化参数
COPY_ARGS=()
ARGS=()
PLUGINS=()
FILES=""

# 解析命令行参数
while (( "$#" )); do
    case "$1" in
        -i) INPUT_DIR="$2"; shift 2;;
        -p) PLUGIN_DIR="$2"; shift 2;;
        -l) LIB_DIR="$2"; shift 2;;
        -q) QMAKE_PATH="$2"; shift 2;;
        -m) QMCORECMD_PATH="$2"; shift 2;;
        -t) PLUGINS+=("$2"); shift 2;;
        -f|-s|-V) ARGS+=("$1"); shift;;
        -c) COPY_ARGS+=("$2" "$3"); shift 3;;
        -h) usage; exit 0;;
        *) echo "Error: Unsupported argument $1"; usage; exit 1;;
    esac
done

# 检查必需参数
for arg in INPUT_DIR PLUGIN_DIR LIB_DIR QMAKE_PATH QMCORECMD_PATH; do
    if [[ -z ${!arg} ]]; then
        echo "Error: Missing required argument '$arg'"
        usage
        exit 1
    fi
done

# 根据操作系统决定搜索的文件类型
if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows 环境，只搜索 .dll 和 .exe 文件
    for file in $(find $INPUT_DIR \( -name "*.dll" -o -name "*.exe" \) -type f); do
        FILES="$FILES $file"
    done
else
    # Unix-like 系统，遍历所有文件，使用 file 命令检查是否为可执行的二进制文件
    for file in $(find $INPUT_DIR -type f); do
        file_type=$(file -b "$file")
        if [[ ($file_type == "ELF"* || $file_type == "Mach-O"*) && -x "$file" ]]; then
            FILES="$FILES $file"
        fi
    done
fi

# 查找 Qt 插件的完整路径
for plugin_path in "${QT_PLUGINS[@]}"; do
    if [[ $plugin_path == */* ]]; then
        IFS='/' read -r -a plugin_parts <<< "$plugin_path"
        category=${plugin_parts[0]}
        name=${plugin_parts[1]}

        if [ ! -d "${QT_PLUGIN_PATH}/${category}" ]; then
            echo "Error: Plugin category directory '${QT_PLUGIN_PATH}/${category}' not found."
            exit 1
        fi

        FOUND_PLUGIN=$(find "${QT_PLUGIN_PATH}/${category}" -name "*${name}*" ! -name "*debug*" -print -quit)
        if [ -z "$FOUND_PLUGIN" ]; then
            echo "Error: Plugin '${plugin_path}' not found."
            exit 1
        fi

        DESTINATION_DIR="${PLUGIN_DIR}/${category}"
        mkdir -p "${DESTINATION_DIR}"
        FILES="$FILES -c $FOUND_PLUGIN $DESTINATION_DIR"
    else
        echo "Error: Invalid plugin format '${plugin_path}'. Expected format: <category>/<name>"
        exit 1
    fi
done

# 添加额外的 -c 参数
for ((i=0; i < ${#COPY_ARGS[@]}; i+=2)); do
    FILES="$FILES -c ${COPY_ARGS[i]} ${COPY_ARGS[i+1]}"
done

# 构建并执行 qmcorecmd deploy 命令
DEPLOY_CMD="$QMCORECMD_PATH deploy $FILES ${ARGS[@]} -o $LIB_DIR"
eval $DEPLOY_CMD

# 检查部署结果
if [ $? -ne 0 ]; then
    exit 1
fi
