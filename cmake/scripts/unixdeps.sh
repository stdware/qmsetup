#!/bin/bash

# 显示用法信息
usage() {
    echo "Usage: $(basename $0) -i <input_dir> -p <plugin_dir> -l <lib_dir> -m <qmcorecmd_path>"
    echo "                     [-q <qmake_path>] [-P <extra_path>]..."
    echo "                     [-t <plugin>]... [-c <src> <dest>]... [-f] [-s] [-V] [-h]"
    echo "  -i <input_dir>       Directory containing binaries and libraries"
    echo "  -p <plugin_dir>      Output directory for plugins"
    echo "  -l <lib_dir>         Output directory for libraries"
    echo "  -q <qmake_path>      Path to qmake (optional)"
    echo "  -P <extra_path>      Extra plugin search path. Can be repeated."
    echo "  -m <qmcorecmd_path>  Path to qmcorecmd"
    echo "  -t <plugin>          Specify a Qt plugin to deploy. Can be repeated for multiple plugins."
    echo "  -c <src> <dest>      Specify additional binary file to copy and its destination directory. Can be repeated."
    echo "  -f                   Force overwrite existing files"
    echo "  -s                   Ignore C/C++ runtime and system libraries"
    echo "  -V                   Show verbose output"
    echo "  -h                   Show this help message"
}

# 初始化参数
EXTRA_PLUGIN_PATHS=()
COPY_ARGS=()
ARGS=()
VERBOSE=""
PLUGINS=()
FILES=""

# 解析命令行参数
while (( "$#" )); do
    case "$1" in
        -i) INPUT_DIR="$2"; shift 2;;
        -p) PLUGIN_DIR="$2"; shift 2;;
        -l) LIB_DIR="$2"; shift 2;;
        -q) QMAKE_PATH="$2"; shift 2;;
        -P) EXTRA_PLUGIN_PATHS+=("$2"); shift 2;;
        -m) QMCORECMD_PATH="$2"; shift 2;;
        -t) PLUGINS+=("$2"); shift 2;;
        -f|-s) ARGS+=("$1"); shift;;
        -V) VERBOSE="-V"; shift;;
        -c) COPY_ARGS+=("$2" "$3"); shift 3;;
        -h) usage; exit 0;;
        *) echo "Error: Unsupported argument $1"; usage; exit 1;;
    esac
done

# 检查必需参数
for arg in INPUT_DIR PLUGIN_DIR LIB_DIR QMCORECMD_PATH; do
    if [[ -z ${!arg} ]]; then
        echo "Error: Missing required argument '$arg'"
        usage
        exit 1
    fi
done

# 获取 Qt 插件安装路径
PLUGIN_PATHS=()
if [[ -n "$QMAKE_PATH" ]]; then
    QMAKE_PLUGIN_PATH=$($QMAKE_PATH -query QT_INSTALL_PLUGINS)
    PLUGIN_PATHS+=("$QMAKE_PLUGIN_PATH")
fi

# 添加额外的插件搜索路径
PLUGIN_PATHS+=("${EXTRA_PLUGIN_PATHS[@]}")


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
for plugin_path in "${PLUGINS[@]}"; do
    # 检查格式
    if [[ $plugin_path == */* ]]; then
        IFS='/' read -r -a plugin_parts <<< "$plugin_path"
        category=${plugin_parts[0]}
        name=${plugin_parts[1]}

        # 遍历路径
        for search_path in "${PLUGIN_PATHS[@]}"; do
            FOUND_PLUGIN=$(find "${search_path}/${category}" -name "*${name}*" ! -name "*debug*" -print -quit)
            if [[ -n "$FOUND_PLUGIN" ]]; then
                FILES="$FILES -c $FOUND_PLUGIN ${PLUGIN_DIR}/${category}"
                break
            fi
        done

        if [ -z "$FOUND_PLUGIN" ]; then
            echo "Error: Plugin '${plugin_path}' not found in any search paths."
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
DEPLOY_CMD="$QMCORECMD_PATH deploy $FILES ${ARGS[@]} $VERBOSE -o $LIB_DIR"
if [[ "$VERBOSE" == "-V" ]]; then
    echo "Executing: $DEPLOY_CMD"
fi
eval $DEPLOY_CMD

# 检查部署结果
if [ $? -ne 0 ]; then
    exit 1
fi
