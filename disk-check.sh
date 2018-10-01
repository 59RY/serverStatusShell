#!/bin/sh

### 設定 ###

# サイト名
SITENAME="【サイト名】"

# サイトのURL
SITEURL="https://example.com/"

# チェックするディスクのパーティション（例：/dev/vda1、/dev/xvda1、/dev/sda1）
PARTITION="/dev/xvda1"

# 指定した空き容量（GB）を下回るとアラートを飛ばす。0で無効化。下記と併用可
ALERT_THRESHOLD_SIZE=1

# 指定した使用率（%）を上回るとアラートを飛ばす。101で無効化。上記と併用可
ALERT_THRESHOLD_RATIO=90

# アラートを飛ばす際のメール送信先。空白で無効化
ALERT_MAIL=""

# アラートを飛ばす際のSlackのURL。空白で無効化
ALERT_SLACK_URL=""

# アラート以外を飛ばす際のSlackのURL。空白で無効化
INFO_SLACK_URL=""



### メインプログラム ###
### VERSION. 0.01    ###

# 容量のヒューマン用表示
# ※注：1GB = 1024MBと表す。ただし厳密には1GiB = 1024MiBだが、Windows 同様 GB・MB で表記する。
function capacityHumanly() {
	if [ $1 -ge 1073741824 ]; then
		echo "$(echo "scale=2; $1 / 1073741824" | bc) TB"
	elif [ $1 -ge 1048576 ]; then
		echo "$(echo "scale=2; $1 / 1048576" | bc) GB"
	elif [ $1 -ge 1024 ]; then
		echo "$(echo "scale=2; $1 / 1024" | bc) MB"
	else
		echo "${1} KiB"
	fi
}

# 上から順に、ディスク容量の合計・使用済み・空き領域（bytes）、使用率（%）
DISKTOTAL=`df -k -P ${PARTITION} | awk 'NR==2 {print $2}'`
DISKUSED=`df -k -P ${PARTITION} | awk 'NR==2 {print $3}'`
DISKFREE=`df -k -P ${PARTITION} | awk 'NR==2 {print $4}'`
DISKUSERATIO=`echo $((100 * $DISKUSED / $DISKTOTAL))`

# 上から順に、ディスク容量の合計・使用済み・空き領域（ヒューマン用表示）
DISKTOTAL_HUMANLY=`capacityHumanly ${DISKTOTAL}`
DISKUSED_HUMANLY=`capacityHumanly ${DISKUSED}`
DISKFREE_HUMANLY=`capacityHumanly ${DISKFREE}`

# ALERT_THRESHOLD_SIZE を KB 換算したもの
ALERT_THRESHOLD_SIZE_KB=`expr $ALERT_THRESHOLD_SIZE \* 1048576`

# 現在の時間
CURRENT_TIME=$(echo `date +%s`)

if [ $DISKUSERATIO -gt $ALERT_THRESHOLD_RATIO -o $DISKFREE -lt $ALERT_THRESHOLD_SIZE_KB ]; then
	## 容量が閾値未満の場合
	# Slack送信
	curl -X POST --data-urlencode "payload={\"username\": \"Shell\", \"attachments\": [{\"fallback\": \"｢${SITENAME}｣のディスク容量がしきい値未満になりました\", \"color\": \"#ff6000\", \"title\": \"${SITENAME}\", \"title_link\": \"${SITEURL}\", \"text\": \"ディスク容量がしきい値未満になりました。\", \"fields\": [{\"title\": \"空き容量/全体容量\", \"value\": \"${DISKFREE_HUMANLY} / ${DISKTOTAL_HUMANLY}\", \"short\": true}, {\"title\": \"ディスク使用率\", \"value\": \"${DISKUSERATIO}%\", \"short\": true}], \"ts\": ${CURRENT_TIME}}]}" ${ALERT_SLACK_URL}
	# メール送信
	echo -e "｢${SITENAME}｣のディスク容量がしきい値未満になりました。\n・空き/全体容量: ${DISKFREE_HUMANLY} / ${DISKTOTAL_HUMANLY}\n・ディスク使用率: ${DISKUSERATIO}%" | /bin/mail -s "【容量警告】${SITENAME}" ${ALERT_MAIL}
else
	# 容量が正常の場合
	# Slack送信
	curl -X POST --data-urlencode "payload={\"username\": \"Shell\", \"attachments\": [{\"fallback\": \"｢${SITENAME}｣のディスク容量: OK\", \"color\": \"#36a64f\", \"title\": \"${SITENAME}\", \"title_link\": \"${SITEURL}\", \"text\": \"ディスク容量に問題はありません。\", \"fields\": [{\"title\": \"空き容量/全体容量\", \"value\": \"${DISKFREE_HUMANLY} / ${DISKTOTAL_HUMANLY}\", \"short\": true}, {\"title\": \"ディスク使用率\", \"value\": \"${DISKUSERATIO}%\", \"short\": true}], \"ts\": ${CURRENT_TIME}}]}" ${INFO_SLACK_URL}
fi