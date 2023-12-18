#!/bin/bash
you=/home/czq/.local/bin/you-get
#telegram参数
telegram_bot_token="6848265972:AAGVndu42o_E_yrKxCAInc2s9PC0bEnIUw4"
telegram_chat_id="2086224034"
#RSS 地址
rssURL="http://127.0.0.1:1200/bilibili/followings/video/1540431263"
#脚本存放地址
scriptLocation="/home/czq/bilibili/BiliFavoritesDownloader/test/script/"
#视频存放地址
videoLocation="/home/czq/bilibili/BiliFavoritesDownloader/test/download/"
#邮件地址
mailAddress="941436447@qq.com"

#如果时间戳记录文本不存在则创建（此处文件地址自行修改）
if [ ! -f "${scriptLocation}date.txt" ]; then
    # echo 313340 >"$scriptLocation"date.txt
    touch "$scriptLocation"date.txt
fi
#如果标题记录文本不存在则创建
if [ ! -f "${scriptLocation}title.txt" ]; then
    # echo 313340 >"${scriptLocation}"title.txt
    touch "${scriptLocation}"title.txt
fi
#如果BV记录文本不存在则创建
if [ ! -f "${scriptLocation}BV.txt" ]; then
    # echo 313340 >"${scriptLocation}"BV.txt
    touch "${scriptLocation}"BV.txt
fi

#获得之前下载过的视频标题
oldtitle=$(cat "${scriptLocation}"title.txt)
#获得上一个视频的时间戳（文件地址自行修改）
olddate=$(cat "${scriptLocation}"date.txt)
#获得上一个视频的BV号
oldBV=$(cat "${scriptLocation}"BV.txt)

#获得过滤up主名称
filterup=$(cat "${scriptLocation}"filter.txt)

#抓取rss更新
content=$(wget $rssURL -q -O -)
if [ -z "$content" ]; then
    echo "Content is empty or download failed."| mutt -s "bilibili:Rsshub server访问失败 ，请检查server后重试" $mailAddress
fi

IFS=$'\n' read -r -d '' -a xml <<< "$(xmlstarlet sel -t -m "//item" -o "description:" -v "description" -o "link:" -v "link" -o "author:" -v "author" -o "pubdate:" -v "pubDate" -o "title:" -v "title" -o "※※※" <<< "$content"| tr ' ' '_' | tr '\n' '_' | tac)"
IFS="※※※"  read -ra videoInfo <<< "$xml"

length=${#videoInfo[@]}
# 循环处理视频信息
# for info in "${videoInfo[@]}"; do
for ((index = length - 1; index >= 0; index--)); do
    info="${videoInfo[index]}"
    if [ "$info" != "" ]; then
        info=$(echo "$info" | sed 's/&lt;/\</g' | sed 's/&gt;/\>/g')
        echo "info $info"
        # 解析信息
        description=$(echo "$info" | grep -oP 'description:(.*?)(?=(link:|$))' | sed 's/description://')
        link=$(echo "$info" | grep -oP 'link:(.*?)(?=(author:|$))' | sed 's/link://')
        author=$(echo "$info" | grep -oP 'author:(.*?)(?=(pubdate:|$))' | sed 's/author://')
        pubdate=$(echo "$info" | grep -oP 'pubdate:(.*?)(?=(title:|$))' | sed 's/pubdate://')
        title=$(echo "$info" | grep -oP 'title:(.*?)(?=$)' | sed 's/title://')

        #获得封面图下载链接和文件名称
        photolink=$(echo "$description" | grep -oP '<img_src="\K[^"]+' | head -n 1)
        pname=$(echo "$photolink" | sed 's/.*\///')

        # echo "description: $description"
        # echo "video link: $link"
        # echo "photo link: $photolink"
        # echo "pname: $pname"
        # echo "Up主: $author"
        # echo "时间戳: $pubdate"
        # echo "标题: $title"

        #根据up主名称过滤
        result=$(echo $filterup | grep "${author}")
        if [ "$result" != "" ]; then
            echo "$author" filter
            continue
        fi

        av=$(echo $link | sed -n 's/.*\/av\([0-9]\+\).*/\1/p')
        result=$(echo $pubdate | grep "GMT")
        result5=$(echo $oldtitle | grep "$title")
        result6=$(echo $oldBV | grep "$av")

        # echo "pubdate $pubdate"
        # echo "olddate $olddate"
        # echo "result $result"
        # echo "result5 $result5"
        # echo "result6 $result6"
        # echo ""

        #判断当前时间戳和上次记录是否相同，不同则代表收藏列表更新
        if [ "$pubdate" != "$olddate" ] && [ "$result" != "" ] && [ "$result6" = "" ]; then
            #Cookies可用性检查
            stat=$($you -i -l -c "$scriptLocation"cookies.txt https://www.bilibili.com/video/BV1fK4y1t7hj)
            substat=${stat#*quality:}
            data=${substat%%#*}
            quality=${data%%size*}
            echo "Cookies可用性检查 quality $quality"
            if [[ $quality =~ "4K" ]]; then
                #清空 Bilibili 文件夹
                #rm -rf "$videoLocation"*
                #判断是否为重复标题
                if [ "$result5" != "" ]; then
                    time=$(date "+%Y-%m-%d_%H:%M:%S")
                    name="$title""("$time")"
                fi

                #获取视频清晰度以及大小信息
                echo "$you -i -l -c "$scriptLocation"cookies.txt $link"
                stat=$($you -i -l -c "$scriptLocation"cookies.txt $link)
                echo "获取视频清晰度以及大小信息\n $stat"
                #有几P视频
                count=$(echo $stat | awk -F'title' '{print NF-1}')
                echo "count $count"
                for ((i = 0; i < $count; i++)); do
                    stat=${stat#*title:}
                    title=${stat%%streams:*}
                    substat=${stat#*quality:}
                    data=${substat%%#*}
                    quality=${data%%size*}
                    size=${data#*size:}
                    title=$(echo $title)
                    quality=$(echo $quality)
                    size=$(echo $size)
                    #每一P的视频标题，清晰度，大小，发邮件用于检查下载是否正确进行
                    message=${message}"Title: "${title}$'\n'"Up: "${author}$'\n'"Quality: "${quality}$'\n'"Size: "${size}$'\n\n' #邮件方式
                    # message=${message}"Title:%20"${title}"%0AQuality:%20"${quality}"%0ASize:%20"${size}"%0A%0A" #telegram方式
                done

                #下载封面图（图片存储位置应和视频一致）
                echo "wget -P "$videoLocation$author/$title" $photolink"
                wget -P "$videoLocation$author/$title" $photolink

                echo "message : ${message}"
                #发送开始下载邮件（自行修改邮件地址）
                echo "echo "$message" | mutt -s "bilibili:开始下载" $mailAddress"
                echo "$message" | mutt -s "bilibili:开始下载" $mailAddress
                message=""
                # curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="<b>bilibili:开始下载</b>%0A%0A$message"
                #下载视频到指定位置（视频存储位置自行修改；you-get下载B站经常会出错，所以添加了出错重试代码）
                count=1
                echo "1" > "${scriptLocation}${cur_sec}mark.txt"
                while true; do
                    echo $you -l -c "$scriptLocation"cookies.txt -o "$videoLocation$author/$title" $link
                    $you -l -c "$scriptLocation"cookies.txt -o "$videoLocation$author/$title" $link #> "${scriptLocation}${cur_sec}.txt" #如果是邮件通知，删除 > "${scriptLocation}${cur_sec}.txt"
                    if [ $? -eq 0 ]; then
                        #下载完成
                        echo "0" > "${scriptLocation}${cur_sec}mark.txt"
                        #重命名封面图
                        result1=$(echo $pname | grep "jpg")
                        if [ "$result1" != "" ]; then
                            mv "$videoLocation$author/$title"/$pname "$videoLocation$author/$title"/poster.jpg
                        else
                            mv "$videoLocation$author/$title"/$pname "$videoLocation$author/$title"/poster.png
                        fi

                        #xml转ass && 获取下载完的视频文件信息
                        for file in "$videoLocation$author/$title"/*; do
                            if [ "${file##*.}" = "xml" ]; then
                                # echo ""${scriptLocation}"DanmakuFactory -o "${file%%.cmt.xml*}".ass -i "$file""
                                # "${scriptLocation}"DanmakuFactory -o "${file%%.cmt.xml*}".ass -i "$file"
                                #删除源文件
                                rm "$file"
                                elif [ "${file##*.}" = "mp4" ] || [ "${file##*.}" = "flv" ] || [ "${file##*.}" = "mkv" ]; then
                                videoname=${file#*"$title"\/}
                                videostat=$(du -h "$file")
                                videosize=${videostat%%\/*}
                                videosize=$(echo $videosize)
                                videomessage=${videomessage}"Title: "${videoname}$'\n'"Size: "${videosize}$'\n\n'  #邮件方式
                                # videomessage=${videomessage}"Title:%20"${videoname}"%0ASize:%20"${videosize}"%0A%0A" #telegram方式
                            fi
                        done

                        #发送下载完成邮件
                        echo "echo "$videomessage" | mutt -s "bilibili:下载完成" $mailAddress"
                        echo "$videomessage" | mutt -s "bilibili:下载完成" $mailAddress
                        videomessage=""
                        # curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="<b>bilibili:下载完成</b>%0A%0A$videomessage"

                        #记录时间戳
                        echo $pubdate >"${scriptLocation}"date.txt
                        #记录标题
                        echo $title >>"${scriptLocation}"title.txt
                        #记录BV号
                        echo $av >>"${scriptLocation}"BV.txt

                        #上传至OneDrive 百度云
                        # /usr/bin/rclone copy "$videoLocation$author/$title" OneDrive:
                        # /usr/local/bin/BaiduPCS-Go upload "$videoLocation$author/$title" /
                        #发送通知
                        # echo "$title" | mutt -s "bilibili:上传完成" $mailAddress #邮件方式
                        # curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="<b>bilibili:上传完成</b>%0A%0A$title"
                        break
                    else
                        if [ "$count" != "1" ]; then
                            count=$(($count + 1))
                            sleep 2
                        else
                            rm -rf "$videoLocation$author/$title"
                            #发送通知
                            echo "$title" | mutt -s "bilibili:下载失败" $mailAddress  #邮件
                            # curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="<b>bilibili:下载失败</b>"
                            continue
                        fi
                    fi
                done #& #如果是邮件通知，删除 & 和下面的内容(删到wait，fi保留)

                # second="start"
                # secondResult=$(curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="$second")
                # subSecondResult="${secondResult#*message_id\":}"
                # messageID=${subSecondResult%%,\"from*}

                # ccount=0
                # while true; do
                #     sleep 1
                #     text=$(tail -1 "${scriptLocation}${cur_sec}.txt")
                #     echo $text > "${scriptLocation}${cur_sec}${cur_sec}.txt"
                #     sed -i -e 's/\r/\n/g' "${scriptLocation}${cur_sec}${cur_sec}.txt"
                #     text=$(sed -n '$p' "${scriptLocation}${cur_sec}${cur_sec}.txt")
                #     result=$(curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/editMessageText" -d chat_id=$telegram_chat_id -d message_id=$messageID -d text="$text")
                #     mark=$(cat "${scriptLocation}${cur_sec}mark.txt")
                #     if [ $mark -eq 0 ]; then
                #         break
                #     fi
                # done
                # wait
                rm "${scriptLocation}${cur_sec}.txt"
                rm "${scriptLocation}${cur_sec}${cur_sec}.txt"
                rm "${scriptLocation}${cur_sec}mark.txt"
            else
                echo "bilibili:Cookies 文件失效，请更新后重试"
                echo "echo "$message" | mutt -s "bilibili:Cookies 文件失效，请更新后重试" $mailAddress"
                echo "$message" | mutt -s "bilibili:Cookies 文件失效，请更新后重试" $mailAddress
                # curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="<b>bilibili:Cookies 文件失效，请更新后重试</b>%0A%0A$videomessage"
            fi
        fi
    fi
done