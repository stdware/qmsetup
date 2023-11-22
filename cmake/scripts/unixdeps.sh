#!/bin/bash

# 显示用法信息
usage() {
    echo "Usage: $(basename $0) -i <dir> -m <path>"
    echo "                   --plugindir <plugin_dir> --libdir <lib_dir> --qmldir <qml_dir>"
    echo "                  [--qmake <qmake_path>] [--extra <extra_path>]..."
    echo "                  [--qml <qml_module>]... [--plugin <plugin>]... [--copy <src> <dest>]..."
    echo "                  [-f] [-s] [-V] [-h]"
    echo "  -i <input_dir>              Directory containing binaries and libraries"
    echo "  -m <qmcorecmd_path>         Path to qmcorecmd"
    echo "  --plugindir <plugin_dir>    Output directory for plugins"
    echo "  --libdir <lib_dir>          Output directory for libraries"
    echo "  --qmldir <qml_dir>          Output directory for QML files"
    echo "  --qmake <qmake_path>        Path to qmake (optional)"
    echo "  --extra <extra_path>        Extra plugin searching path (repeatable)"
    echo "  --qml <qml_module>          Relative path to QML directory (repeatable)"
    echo "  --plugin <plugin>           Specify a Qt plugin to deploy (repeatable)"
    echo "  --copy <src> <dest>         Specify additional binary file to copy and its destination directory (repeatable)"
    echo "  -f                          Force overwrite existing files"
    echo "  -s                          Ignore C/C++ runtime and system libraries"
    echo "  -V                          Show verbose output"
    echo "  -h                          Show this help message"
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
        -i)            INPUT_DIR="$2"; shift 2;;
        -m)            QMCORECMD_PATH="$2"; shift 2;;
        --plugindir)   PLUGIN_DIR="$2"; shift 2;;
        --libdir)      LIB_DIR="$2"; shift 2;;
        --qmldir)      QML_DIR="$2"; shift 2;;
        --qmake)       QMAKE_PATH="$2"; shift 2;;
        --extra)       EXTRA_PLUGIN_PATHS+=("$2"); shift 2;;
        --plugin)      PLUGINS+=("$2"); shift 2;;
        --qml)         QML_REL_PATHS+=("$2"); shift 2;;
        --copy)        ARGS+=("-c \"$2\" \"$3\""); shift 3;;
        -f|-s)         ARGS+=("$1"); shift;;
        -V)            VERBOSE="-V"; shift;;
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

# 定义递归遍历函数
search_input_dir() {
    local path="$1"
    for item in "$path"/*; do
        if [ -d "$item" ]; then
            # 检查是否为 mac .framework
            if [[ "OSTYPE" == "darwin"* ]] && [[ "$item" == *.framework ]]; then
                FILES="$FILES \"$file\""
            else
                search_input_dir "$item"
            fi
        elif [ -f "$item" ]; then
            if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
                # Windows 环境，只搜索 .dll 和 .exe 文件
                FILES="$FILES \"$file\""
            else
                # Unix 系统，遍历所有文件，使用 file 命令检查是否为可执行的二进制文件
                file_type=$(file -b "$file")
                if [[ ($file_type == "ELF"* || $file_type == "Mach-O"*) && -x "$file"  ]]; then
                    FILES="$FILES \"$file\""
                fi
            fi
        fi
    done
}

# 搜索输入目录
search_input_dir "$INPUT_DIR"

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
    local rel_path="${file#$QML_PATH/}"

    local target="$QML_DIR/$rel_path"
    local target_dir="$(dirname "$target")"

    # 如果是目录那么必是 mac framework
    if [ -d "$file" ]; then
        ARGS+=("-c \"$file\" \"$target_dir\"")
        return
    fi

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
            ARGS+=("-c \"$file\" \"$target_dir\"")
        else
            mkdir -p "$target_dir"
            cp "$file" "$target"
        fi
    else
        file_type=$(file -b "$file")
        if [[ ($file_type == "ELF"* || $file_type == "Mach-O"*) && -x "$file" ]]; then
            ARGS+=("-c \"$file\" \"$target_dir\"")
        else
            mkdir -p "$target_dir"
            cp "$file" "$target"
        fi
    fi
}

# 搜索 QML 目录
search_qml_dir() {
    local path="$1"
    for item in "$path"/*; do
        if [ -d "$item" ]; then
            # 检查是否为 mac .framework
            if [[ "OSTYPE" == "darwin"* ]] && [[ "$item" == *.framework ]]; then
                handle_qml_file "$item"
            else
                search_qml_dir "$item"
            fi
        elif [ -f "$item" ]; then
            handle_qml_file "$item"
        fi
    done
}

# 处理 QML 目录
for qml_rel_path in "${QML_REL_PATHS[@]}"; do
    full_path="$QML_PATH/$qml_rel_path"
    if [[ -d "$full_path" ]]; then
        # 处理目录
        search_qml_dir "$full_path"
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
