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