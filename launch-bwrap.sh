#!/bin/bash
curdir=$(pwd)
chrootEnvPath=${curdir}/bwrap-env

## 获取第一个非 root 用户名和 ID
non_root_user=$(who | awk '{print $1}' | head -n 1)
uid=$(id -u $non_root_user)

#### This part is for args pharm
if [ "$1" = "" ]; then
    container_command="bash"
else
    container_command="$1"
    shift
    for arg in "$@"; do
        arg="$(echo "${arg}x" | sed 's|'\''|'\'\\\\\'\''|g')"
        arg="${arg%x}"
        container_command="${container_command} '${arg}'"
    done
fi


#########################################################################################
##########合成bwrap 1. 函数配置段
BASE_COMMAND="bwrap --dev-bind / /"
EXEC_COMMAND="bwrap"
CON_COMMAND="bash -c \"${container_command}\""


# add_command 函数定义
function add_command() {
    # 参数拼接，考虑到转义和空格的处理
    for arg in "$@"; do
        EXEC_COMMAND="${EXEC_COMMAND} ${arg}"
    done
}
# add_env_var 添加环境变量函数定义
function add_env_var() {
    local var_name="${1}"
    local var_value="${2}"
    if [ "$var_value" != "" ]; then
        add_command "--setenv $var_name $var_value"
    fi
}
# cursor_theme_dir_integration 添加特殊字段函数定义
function cursor_theme_dir_integration() {
    local directory=""
    if [ "$(id -u)" = "0" ]; then #####We don't want bother root to install themes,but will try to fix the unwriteable issue
        mkdir -p $chrootEnvPath/usr/share/icons
        chmod 777 -R $chrootEnvPath/usr/share/icons
        return
    fi
    for directory in "/usr/share/icons"/*; do
        # 检查是否为目录
        if [ -d "$directory" ]; then
            # 检查目录中是否存在 cursors 文件
            if [ -d "$directory/cursors" ]; then
                if [ -w $chrootEnvPath/usr/share/icons ]; then
                    add_command "--ro-bind-try $directory $directory"
                fi
            fi
        fi
    done
}


##########合成bwrap 2. 环境变量和目录绑定配置段
# 添加环境变量和其他初始设置
ENV_VARS=(
    "LANG $LANG"
    "LC_COLLATE $LC_COLLATE"
    "LC_CTYPE $LC_CTYPE"
    "LC_MONETARY $LC_MONETARY"
    "LC_MESSAGES $LC_MESSAGES"
    "LC_NUMERIC $LC_NUMERIC"
    "LC_TIME $LC_TIME"
    "LC_ALL $LC_ALL"
    "PULSE_SERVER /run/user/\$uid/pulse/native"
    "PATH /flamescion-container-tools/bin-override:\$PATH"
    "IS_ACE_ENV 1"
)

BIND_DIRS=(
    "--dev-bind $chrootEnvPath/ /"
    "--dev-bind / /host"
    "--dev-bind /sys /sys"
    "--dev-bind /run /run"
    "--dev-bind-try /home /home"
    "--dev-bind-try /media /media"
    "--dev-bind-try /tmp /tmp"
    "--dev-bind-try /dev/dri /dev/dri"
    "--dev-bind-try /run/user/\$uid/pulse /run/user/\$uid/pulse"
    "--dev-bind-try /etc/resolv.conf /etc/resolv.conf"
    "--ro-bind-try /usr/share/themes /usr/local/share/themes"
    "--ro-bind-try /usr/share/icons /usr/local/share/icons"
    "--ro-bind-try /usr/share/fonts /usr/local/share/fonts"
    "--ro-bind-try $(realpath /etc/localtime) /etc/localtime"
    "--dev /dev"
    "--proc /proc"
)

EXTRA_ARGS=(
    "--hostname yuanjiajia-bwrap"
    "--unshare-uts"
    "--cap-add CAP_SYS_ADMIN"
)

EXTRA_SCRIPTS=(
    cursor_theme_dir_integration
)

##########合成bwrap 3. 合成并执行指令
# 逐一添加到 EXEC_COMMAND
for var in "${ENV_VARS[@]}"; do
    add_env_var $var
done
for var in "${BIND_DIRS[@]}"; do
    add_command "$var"
done
for var in "${EXTRA_ARGS[@]}"; do
    add_command "$var"
done
for var in "${EXTRA_SCRIPTS[@]}"; do
    $var
done


# 输出完整的 EXEC_COMMAND 以查看
FINAL_COMMAND="${EXEC_COMMAND} ${CON_COMMAND}"
echo "${FINAL_COMMAND}"

# 注意: 实际执行时，请确保所有变量（如 $uid, $chrootEnvPath 等）都已正确定义
eval ${FINAL_COMMAND}
