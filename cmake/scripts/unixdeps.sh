#!/bin/bash

# 显示用法信息
usage() {
    echo "Usage: $(basename $0) -i <input_dir> -p <plugin_dir> -l <lib_dir> -m <qmcorecmd_path> -o <qml_output_dir>"
    echo "                     [-q <qmake_path>] [-P <extra_path>]... [-Q <qml_rel_path>]..."
    echo "                     [-t <plugin>]... [-c <src> <dest>]... [-f] [-s] [-V] [-h]"
    echo "  -i <input_dir>       Directory containing binaries and libraries"
    echo "  -p <plugin_dir>      Output directory for plugins"
    echo "  -l <lib_dir>         Output directory for libraries"
    echo "  -o <qml_output_dir>  Output directory for QML files"
    echo "  -q <qmake_path>      Path to qmake (optional)"
    echo "  -P <extra_path>      Extra plugin search path. Can be repeated."
    echo "  -Q <qml_rel_path>    Relative path to QML directory. Can be repeated."
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
QML_REL_PATHS=()
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
        -o) QML_DIR="$2"; shift 2;;
        -q) QMAKE_PATH="$2"; shift 2;;
        -P) EXTRA_PLUGIN_PATHS+=("$2"); shift 2;;
        -Q) QML_REL_PATHS+=("$2"); shift 2;;
        -m) QMCORECMD_PATH="$2"; shift 2;;
        -t) PLUGINS+=("$2"); shift 2;;
        -f|-s) ARGS+=("$1"); shift;;
        -V) VERBOSE="-V"; shift;;
        -c) ARGS+=("-c \"$2\" \"$3\""); shift 3;;
        -h) usage; exit 0;;
        *) echo "Error: Unsupported argument $1"; usage; exit 1;;
    esac
done

# 检查必需参数
for arg in INPUT_DIR PLUGIN_DIR LIB_DIR QML_DIR QMCORECMD_PATH; do
    if [[ -z ${!arg} ]]; then
        echo "Error: Missing required argument '$arg'"
        usage
        exit 1
    fi
done

# 获取 Qt 插件安装路径和 Qt QML 目录
PLUGIN_PATHS=()
QML_PATH=""
if [[ -n "$QMAKE_PATH" ]]; then
    QMAKE_PLUGIN_PATH=$($QMAKE_PATH -query QT_INSTALL_PLUGINS)
    PLUGIN_PATHS+=("$QMAKE_PLUGIN_PATH")

    QML_PATH=$($QMAKE_PATH -query QT_INSTALL_QML)
fi

# 添加额外的插件搜索路径
PLUGIN_PATHS+=("${EXTRA_PLUGIN_PATHS[@]}")

# 确保指定了 QML 相关路径时 QML 搜索路径不为空（需要指定 qmake）
if [[ ${#QML_REL_PATHS[@]} -gt 0 && -z "$QML_PATH" ]]; then
    echo "Error: qmake path must be specified when QML paths are provided"
    usage
    exit 1
fi

# 根据操作系统决定搜索的文件类型
if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows 环境，只搜索 .dll 和 .exe 文件
    while IFS= read -r -d $'\0' file; do
        FILES="$FILES \"$file\""
    done < <(find "$INPUT_DIR" \( -name "*.dll" -o -name "*.exe" \) -type f -print0)
else
    # Unix-like 系统，遍历所有文件，使用 file 命令检查是否为可执行的二进制文件
    while IFS= read -r -d $'\0' file; do
        file_type=$(file -b "$file")
        if [[ ($file_type == "ELF"* || $file_type == "Mach-O"*) && -x "$file" ]]; then
            FILES="$FILES \"$file\""
        fi
    done < <(find "$INPUT_DIR" -type f -print0)
fi

# 查找 Qt 插件的完整路径
for plugin_path in "${PLUGINS[@]}"; do
    # 检查格式
    if [[ $plugin_path == */* ]]; then
        IFS='/' read -r -a plugin_parts <<< "$plugin_path"
        category=${plugin_parts[0]}
        name=${plugin_parts[1]}

        # 遍历路径
        found_plugin=""
        for search_path in "${PLUGIN_PATHS[@]}"; do
            found_plugin=$(find "${search_path}/${category}" -name "*${name}*" ! -name "*debug*" -print -quit)
            if [[ -n "$found_plugin" ]]; then
                break
            fi
        done

        if [ -z "$found_plugin" ]; then
            echo "Error: Plugin '${plugin_path}' not found in any search paths."
            exit 1
        fi

        dest_dir="${PLUGIN_DIR}/${category}"
        ARGS+=("-c \"$found_plugin\" \"$dest_dir\"")
    else
        echo "Error: Invalid plugin format '${plugin_path}'. Expected format: <category>/<name>"
        exit 1
    fi
done

# 复制或添加到部署命令的函数
handle_qml_file() {
    local file="$1"
    local target_dir="$2"

    local rel_path="${file#$QML_PATH/}"
    local target="$target_dir/$rel_path"

    # 忽略特定文件
    if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32" ]]; then
        if [[ "$file" == *.pdb ]] || [[ "$file" == *d.dll ]]; then
            return
        fi
    else
        if [[ "$file" == *_debug.dylib ]] || [[ "$file" == *.so.debug ]]; then
            return
        fi
    fi

    # 判断是否为可执行二进制文件并相应处理
    if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32" ]]; then
        if [[ "$file" == *.dll || "$file" == *.exe ]]; then
            ARGS+=("-c \"$file\" \"$(dirname "$target")\"")
        else
            mkdir -p "$(dirname "$target")"
            cp "$file" "$target"
        fi
    else
        file_type=$(file -b "$file")
        if [[ ($file_type == "ELF"* || $file_type == "Mach-O"*) && -x "$file" ]]; then
            ARGS+=("-c \"$file\" \"$(dirname "$target")\"")
        else
            mkdir -p "$(dirname "$target")"
            cp "$file" "$target"
        fi
    fi
}

# 处理 QML 目录
for qml_rel_path in "${QML_REL_PATHS[@]}"; do
    full_path="$QML_PATH/$qml_rel_path"
    if [[ -d "$full_path" ]]; then
        # 处理目录
        while IFS= read -r -d $'\0' file; do
            handle_qml_file "$file" "$QML_DIR"
        done < <(find "$full_path" -type f -print0)
    elif [[ -f "$full_path" ]]; then
        # 处理单个文件
        handle_qml_file "$full_path" "$QML_DIR"
    fi
done

# 构建并执行 qmcorecmd deploy 命令
DEPLOY_CMD="$QMCORECMD_PATH deploy $FILES ${ARGS[@]} -o \"$LIB_DIR\" $VERBOSE"
if [[ "$VERBOSE" == "-V" ]]; then
    echo "Executing: $DEPLOY_CMD"
fi
eval $DEPLOY_CMD

# 检查部署结果
if [ $? -ne 0 ]; then
    exit 1
fi
