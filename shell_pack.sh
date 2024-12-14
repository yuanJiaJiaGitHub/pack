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
copy_libs() {
    local origin_file_path=$1
    # 解析符号链接
    if [ -L "$origin_file_path" ]; then
        origin_file_path=$(readlink -f "$origin_file_path")
    fi
    origin_file_path=$(echo "$origin_file_path" | awk '{$1=$1};1')
    local bname=$(basename "$origin_file_path")
    local target_path="${targetPackLibDir}/${bname}"
    # 如果目标文件不存在，则复制它
    if [ ! -f "$target_path" ]; then
        echo "已提取文件 ${origin_file_path} 到 ${target_path}"
        sudo cp "$origin_file_path" "$target_path"
    fi
    # 查找并复制依赖项
    local childDepends=$(ldd $origin_file_path | awk '{
        if(match($0, /\/.* \(0x/)) {
            print substr($0, RSTART, RLENGTH-3)
        }
    }');
    if [ -n "$childDepends" ]; then
        echo "$childDepends" | while IFS= read -r line; do
            copy_libs "$line"
        done
    fi
}


# 复制主可执行文件并查找其依赖项
if [ ! -f "$targetPackdir/$packname" ]; then
    echo "已提取文件 ${originPackpath} 到 ${targetPackdir}/${packname}"
    sudo cp "$originPackpath" "$targetPackdir"
fi
childDepends=$(ldd $originPackpath | awk '{
    if(match($0, /\/.* \(0x/)) {
        print substr($0, RSTART, RLENGTH-3)
    }
}');
if [ -n "$childDepends" ]; then
    echo "$childDepends" | while IFS= read -r line; do
        copy_libs "$line"
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


exit 0