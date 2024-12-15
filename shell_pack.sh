#!/bin/bash

# 检查是否提供了参数
if [ -z "$1" ]; then
    echo "Usage: $0 <packname>"
    exit 1
fi


packname=$1
originPackpath=$(which $packname)
# 检查是否找到了可执行文件
if [ -z "$originPackpath" ]; then
    echo "Error: Cannot find executable for $packname"
    exit 1
fi
if [ -L "$originPackpath" ]; then
    originPackpath=$(readlink -f "$originPackpath")
fi


scriptRootDir=$(pwd)
targetPackdir="${scriptRootDir}/${packname}"
targetPackLibDir="${targetPackdir}/lib"
# 创建目标目录（如果需要）
if [ ! -d "$targetPackdir" ]; then
    mkdir -p "$targetPackLibDir"
fi


# 复制库文件的函数
firstRowInfo=""
declare -A processed_files
copy_libs() {
    local origin_file_path=$1
    # 解析符号链接
    if [ -L "$origin_file_path" ]; then
        origin_file_path=$(readlink -f "$origin_file_path")
    fi
    origin_file_path=$(echo "$origin_file_path" | awk '{$1=$1};1')

    # 打印当前正在处理的文件
    local chain=$2

    # 跳过已处理的文件
    hashstr=$(echo -n "$origin_file_path" | md5sum | awk '{print $1}')
    if [ -n "${processed_files[$hashstr]}" ]; then
        echo "已忽略: ${chain}"
        return;
    fi

    # 标记文件为已处理
    processed_files[$hashstr]=1
    echo "处理中: ${chain}"

    # 如果目标文件不存在，则复制它
    local bname=$(basename "$origin_file_path")
    local target_path="${targetPackLibDir}/${bname}"
    if [ ! -f "$target_path" ]; then
        sudo cp "$origin_file_path" "$target_path"
        echo "已提取: ${chain}"
    fi


    # 继续查找并复制依赖项
    local childDepends=$(ldd $origin_file_path | awk '{
        if(match($0, /=> \/.* \(0x/)) {
            print substr($0, RSTART+3, RLENGTH-6)
        }else if(match($0, /\/.* \(0x/)){
            print substr($0, RSTART, RLENGTH-3)
        }
    }');
    if [ -n "$childDepends" ]; then
        echo "$childDepends" | while IFS= read -r line; do
            copy_libs "$line" "${chain}->$(basename $line)"
        done
    fi
}


# 复制主可执行文件并查找其依赖项
if [ ! -f "$targetPackdir/$packname" ]; then
    sudo cp "$originPackpath" "$targetPackdir"
    echo "已提取文件 ${originPackpath} 到 ${targetPackdir}/${packname}"
fi
childDepends=$(ldd $originPackpath | awk '{
    if(match($0, /=> \/.* \(0x/)) {
        print substr($0, RSTART+3, RLENGTH-6)
    }else if(match($0, /\/.* \(0x/)){
        print substr($0, RSTART, RLENGTH-3)
    }
}');
if [ -n "$childDepends" ]; then
    echo "$childDepends" | while IFS= read -r line; do
        copy_libs "$line" "$(basename $line)"
    done
fi


# 创建启动脚本
ldLibraryPath="export LD_LIBRARY_PATH=${targetPackLibDir}:\${LD_LIBRARY_PATH}"
exct="./${packname}"
launchStr="#!/bin/bash\n${ldLibraryPath}\n${exct}\n"
echo -e "$launchStr" > "${targetPackdir}/${packname}-launch.sh";


# 更改属主和权限（需要超级用户权限）
username=$(whoami)
groupname=$(id -gn)
sudo chown -R "${username}:${groupname}" "$targetPackdir"
sudo chmod -R 755 "$targetPackdir"


lib_count=$(find $targetPackLibDir -type f | wc -l)
echo ""
echo "已提取出 1 个主程序文件, 和 ${lib_count} 个依赖库文件."
echo "打包已完成, 执行 ${packname}-launch.sh 脚本启动程序."
exit 0