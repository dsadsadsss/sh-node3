#!/bin/bash

# 变量设置
export VPATH=${VPATH:-'vls'}
export MPATH=${MPATH:-'vms'}
export VL_PORT=${VL_PORT:-'8002'}
export VM_PORT=${VM_PORT:-'8001'}
export UUID=${UUID:-'fd80f56e-93f3-4c85-b2a8-c77216c509a7'}
export CF_IP=${CF_IP:-'ip.sb'}
export SUB_NAME=${SUB_NAME:-'argo'}
export SUB_URL=${SUB_URL:-''}
export NEZHA_SERVER=${NEZHA_SERVER:-'xue'}
export NEZHA_KEY=${NEZHA_KEY:-'gbBmbo2XwWcYMgjnbbn'}
export NEZHA_PORT=${NEZHA_PORT:-'443'}
export NEZHA_TLS=${NEZHA_TLS:-'--tls'}
export FLIE_PATH=${FLIE_PATH:-'/tmp/worlds/'} 
export TOK=${TOK:-''}
export ARGO_DOMAIN=${ARGO_DOMAIN:-''}
export ne_file=${ne_file:-'nene.js'}
export cff_file=${cff_file:-'cff.js'}
export web_file=${web_file:-'web.js'}

if [ "$NEZHA_TLS" == "1" ]; then
    TLS="--tls"
else
    TLS=""
fi

# 检查文件
check_files_exist_and_not_empty() {
    if [ -s "${FLIE_PATH}/${cff_file}" ] && [ -s "${FLIE_PATH}/${web_file}" ] && [ -s "${FLIE_PATH}/${ne_file}" ]; then
        return 0  # 返回0表示文件存在且不为空
    else
        return 1  # 返回1表示文件不完全存在或为空
    fi
}

# 引用变量
YML_FILE="./c.yml"

# 检查文件是否存在
if [ -s "$YML_FILE" ]; then
    source "$YML_FILE"
fi
setup_tunnel_config() {
  if [[ -n "${TOK}" ]]; then
    [[ "$TOK" =~ TunnelSecret ]] && grep -qv '"' <<< "$TOK" && TOK=$(sed 's@{@{"@g;s@[,:]@"\0"@g;s@}@"}@g' <<< "$TOK")
    [[ "$TOK" =~ ey[A-Z0-9a-z=]{120,250}$ ]] && TOK=$(awk '{print $NF}' <<< "$TOK")  
    if [[ "${TOK}" =~ TunnelSecret ]]; then
      echo "${TOK}" | sed 's@{@{"@g;s@[,:]@"\0"@g;s@}@"}@g' > "${FLIE_PATH}tunnel.json"    
      # 创建 tunnel.yml 配置文件
      cat > "${FLIE_PATH}tunnel.yml" << EOF
tunnel: $(sed "s@.*TunnelID:\(.*\)}@\1@g" <<< "${TOK}")
credentials-file: "${FLIE_PATH}tunnel.json"
protocol: http2
ingress:
  - hostname: "$ARGO_DOMAIN"
    service: http://localhost:8002
EOF     
      # 添加默认的 404 服务到 tunnel.yml
      cat >> "${FLIE_PATH}tunnel.yml" << EOF
  - service: http_status:404
EOF
     fi
  fi
}
# 初始化 FLIE_PATH 变量
initialize_flie_path() {
    if [ -z "$FLIE_PATH" ]; then   # 如果 FLIE_PATH 变量未设置或为空
        if [ -n "$PWD" ]; then
            PWD="${PWD%/}"             # 去掉 PWD 末尾的斜杠
            export FLIE_PATH="$PWD/worlds/"  # 设置 FLIE_PATH 为当前目录的 worlds 子目录
        else
            export FLIE_PATH="/tmp/worlds/"  # 否则设置 FLIE_PATH 为 /tmp/worlds/
        fi
    fi
    
    if [ ! -d "$FLIE_PATH" ]; then  # 如果 FLIE_PATH 目录不存在
        mkdir -p "$FLIE_PATH"       # 创建该目录及其父目录（如果不存在）
    fi
}

has_ps_command=false
# 检查并安装必要的工具
check_and_install_tools() {
    tools=("curl" "wget")
    download_tool=""

    for tool in "${tools[@]}"; do
        if command -v $tool >/dev/null 2>&1; then
            download_tool=$tool
            echo "$tool is already installed."
            break
        fi
    done

    if [ -z "$download_tool" ]; then
        echo "Neither curl nor wget is installed. Attempting to install curl..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y curl
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y curl
        elif command -v apk >/dev/null 2>&1; then
            sudo apk add --no-cache curl
        else
            echo "Unable to install curl. Please install curl or wget manually."
            exit 1
        fi

        if command -v curl >/dev/null 2>&1; then
            download_tool="curl"
            echo "curl has been successfully installed."
        else
            echo "Failed to install curl. Please install curl or wget manually."
            exit 1
        fi
    fi

    if ! command -v base64 >/dev/null 2>&1; then
        echo "base64 is not installed. Attempting to install..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y coreutils
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y coreutils
        elif command -v apk >/dev/null 2>&1; then
            sudo apk add --no-cache coreutils
        else
            echo "Unable to install base64. Some features may not work correctly."
        fi
    fi

    echo "Using $download_tool for downloads."
    if command -v ps >/dev/null 2>&1; then
        has_ps_command=true   
        echo "ps command is already install"
    else
        echo "ps command is not exist. Process checking will be limited."
    fi
}

# 获取国家代码
get_country_code() {
    country_code="UN"
    urls=("http://ipinfo.io/country" "https://ifconfig.co/country" "https://ipapi.co/country")

    for url in "${urls[@]}"; do
        if [ "$download_tool" = "curl" ]; then
            country_code=$(curl -s "$url")
        else
            country_code=$(wget -qO- "$url")
        fi

        if [ -n "$country_code" ] && [ ${#country_code} -eq 2 ]; then
            break
        fi
    done

    echo $country_code
}

# 检查主机名变化
check_hostname_change() {
    if [ -z "$TOK" ]; then
        new_hostname=$(grep -oE "https://.*[a-z]+cloudflare.com" /tmp/ago.log | tail -n 1 | sed "s#https://##")
        if [ -n "$new_hostname" ] && [ "$new_hostname" != "$host_name" ]; then
               if [ -n "$host_name" ]; then
            echo "host_name changed from $host_name to $new_hostname"
               fi
            host_name=$new_hostname
        fi
    else 
           host_name=$ARGO_DOMAIN
    fi
}

# 构建URL
build_urls() {
    check_hostname_change
    pass="{PASS}"
    up_url="${pass}://${UUID}@${CF_IP}:443?path=%2F${VPATH}%3Fed%3D2048&security=tls&encryption=none&host=${host_name}&type=ws&sni=${host_name}#${country_code}-${SUB_NAME}"
    echo $up_url > /tmp/list.log
    echo $up_url > ${FLIE_PATH}list.log
    up_url=$(echo $up_url | sed 's/{PA/vl/g' | sed 's/SS}/ess/g')
    if command -v base64 >/dev/null 2>&1; then
        encoded_url=$(echo -n $up_url | base64)
    else
        echo "base64 is not available. Skipping URL encoding."
        encoded_url=$up_url
    fi
}

# 上传订阅
upload_subscription() {
   build_urls
   if [ -n "$SUB_URL" ]; then        
    if [ "$download_tool" = "curl" ]; then
        response=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"URL_NAME\":\"$SUB_NAME\",\"URL\":\"$up_url\"}" $SUB_URL)
    else
        response=$(wget -qO- --post-data="{\"URL_NAME\":\"$SUB_NAME\",\"URL\":\"$up_url\"}" --header="Content-Type: application/json" $SUB_URL)
    fi

    if [ $? -eq 0 ]; then
        sleep 1
    else
        echo "Sub Upload failed"
    fi
  fi
}

# 检查并启动进程
check_and_start_process() {
    process_name=$1
    start_command=$2

    if $has_ps_command; then
        if ! ps aux | grep -v grep | grep -q "$process_name"; then
            eval "$start_command"
            echo "$process_name started"
        else
            echo "$process_name is already running"
        fi
    else
       
        sleep 20
        eval "$start_command"
        echo "$process_name started"
    fi
}

# 保持进程运行
keep_processes_alive() {
    if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_KEY" ]; then
        check_and_start_process "$ne_file" "chmod 777 ${FLIE_PATH}${ne_file} && nohup ${FLIE_PATH}${ne_file} -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${TLS} >/dev/null 2>&1 &"
    fi

    if [ -n "$TOK" ]; then
       if [[ "${TOK}" =~ TunnelSecret ]]; then
       check_and_start_process "$cff_file" "chmod 777 ${FLIE_PATH}${cff_file} && nohup ${FLIE_PATH}${cff_file} tunnel --edge-ip-version auto --config ${FLIE_PATH}tunnel.yml run >/dev/null 2>&1 &"
       else
        check_and_start_process "$cff_file" "chmod 777 ${FLIE_PATH}${cff_file} && nohup ${FLIE_PATH}${cff_file} tunnel --edge-ip-version auto --protocol http2 run --token ${TOK} >/dev/null 2>&1 &"
        fi
    else
        check_and_start_process "$cff_file" "chmod 777 ${FLIE_PATH}${cff_file} && nohup ${FLIE_PATH}${cff_file} tunnel --url http://localhost:${VL_PORT} --no-autoupdate > /tmp/ago.log 2>&1 &"
        sleep 10 
        upload_subscription     
    fi

    check_and_start_process "$web_file" "chmod 777 ${FLIE_PATH}${web_file} && nohup ${FLIE_PATH}${web_file} >/dev/null 2>&1 &"
}

# 下载文件
download_file() {
    url=$1
    filename=$2
    max_attempts=3
    attempt=1

    while [ $attempt -le $max_attempts ]; do
        if [ "$download_tool" = "curl" ]; then
            curl -sSL -o "${FLIE_PATH}${filename}" "$url"
        else
            wget -q -O "${FLIE_PATH}${filename}" "$url"
        fi
        
        if [ $? -eq 0 ]; then
            echo "Download $filename successful"
            return 0
        else
            echo "Download $filename failed (Attempt $attempt of $max_attempts)"
            attempt=$((attempt + 1))
            [ $attempt -le $max_attempts ] && sleep 1  # 在重试前稍微等待
        fi
    done

    echo "Download $filename failed after $max_attempts attempts"
    return 1
}

# 初始化下载
initialize_downloads() {
    platform=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    
    download_success=true
    
    if [ "$platform" = "linux" ]; then
        if [ "$arch" = "x86_64" ]; then
            download_file "https://github.com/dsadsadsss/d/releases/download/sd/kano-6-amd-w" "$web_file" || download_success=false
            download_file "https://github.com/dsadsadsss/d/releases/download/sd/nezha-amd" "$ne_file" || download_success=false
            download_file "https://github.com/dsadsadsss/1/releases/download/11/cff-amd" "$cff_file" || download_success=false
        elif [ "$arch" = "aarch64" ]; then
            download_file "https://github.com/dsadsadsss/d/releases/download/sd/kano-6-arm-w" "$web_file" || download_success=false
            download_file "https://github.com/dsadsadsss/d/releases/download/sd/nezha-arm" "$ne_file" || download_success=false
            download_file "https://github.com/dsadsadsss/1/releases/download/11/cff-arm" "$cff_file" || download_success=false
        fi
    elif [ "$platform" = "freebsd" ]; then
        download_file "https://github.com/dsadsadsss/1/releases/download/11/botbsd.js" "$web_file" || download_success=false
        download_file "https://github.com/dsadsadsss/1/releases/download/11/nezha-bsd.js" "$ne_file" || download_success=false
        download_file "https://github.com/dsadsadsss/1/releases/download/11/cff-bsd.js" "$cff_file" || download_success=false
    else
        echo "Unsupported platform or architecture"
        return 1
    fi
    
    if $download_success; then
        echo "All files downloaded successfully"
        return 0
    else
        echo "Some files failed to download after multiple attempts"
        return 1
    fi
}

# 主函数
main() {
    initialize_flie_path
    check_and_install_tools
    setup_tunnel_config
    initialize_downloads
    while ! check_files_exist_and_not_empty; do
    echo "wait for download..."
    sleep 1  
    done
    keep_processes_alive
    country_code=$(get_country_code)
    echo "Country Code: $country_code"  
    echo "OS: $platform     Arch:$arch"
    build_urls
    if [ -n "$TOK" ] && [ -z "$ARGO_DOMAIN" ]; then
    echo "Host : Tunnel domain is not set"
    else
    echo "Host : $host_name"
    fi
    echo ""
    echo "=============URL_Code============="
    echo "$encoded_url"
    echo ""
    echo "=================================="
    while true; do
        if [ -n "$SUB_URL" ]; then
            upload_subscription
        fi
        if $has_ps_command; then
            keep_processes_alive
        else
          if [ -z "$TOK" ]; then
                if [ ! -s "/tmp/argo.log" ]; then
                   check_and_start_process "cff.js" "chmod 777 ${FLIE_PATH}cff.js && nohup ${FLIE_PATH}cff.js tunnel --url http://localhost:8002 --no-autoupdate > /tmp/argo.log 2>&1 &"
                   sleep 10 
                   upload_subscription    
               fi
          fi
        fi
        if [ -n "$GLITCH_SHARED_INCLUDES_LEGACY_CLS" ]; then
          rm -rf /app/.git
        fi
        sleep 30
        if [ -n "$SUB_URL" ]; then
            upload_subscription
        fi    
        sleep 30  
    done
}

if [ -n "${JAR_SH}" ]; then
    main &> /dev/null &
    eval "$JAR_SH"
else
    main
fi
tail -f /dev/null