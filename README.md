# 其乐 TF2 MGE/PUG 服务器配置

* MGE/PUG 必备插件
* AFC7 和 UGC 的 6v6 规则
* 基于 UGC 规则修改的武器白名单
* Linux 下使用的 srcds daemon
* 示例 MOTD

## 插件

网上可以下载到的插件：

* [MGEMod](https://forums.alliedmods.net/showthread.php?t=154755)
* [SOAP-TF2DM](https://github.com/Lange/SOAP-TF2DM)
* [Admin Player Team Switch and Scramble Menu](https://forums.alliedmods.net/showthread.php?p=549446)
* [LogsTF for SourceMod](http://www.teamfortress.tv/13598/?page=1#post-1)
* [MedicStats](http://www.teamfortress.tv/13598/?page=1#post-1)
* [SupStats2](http://www.teamfortress.tv/13598/?page=1#post-1)
* [Pause](http://www.teamfortress.tv/13598/?page=1#post-1)
* [RestoreScore](http://www.teamfortress.tv/13598/?page=1#post-1)

自己编写的几个插件（附源码）：

* Server Broadcast
* RandomPW
* Whitelist

插件的功能说明如下：

#### Admin Player Team Switch and Scramble Menu

提供随机分配队伍、切换玩家队伍的功能。可以在 !admin 菜单的玩家选项中看到相关选项。

#### LogsTF for SourceMod

比赛结束后自动上传日志到 logs.tf，玩家可以使用 !log 聊天指令来查看日志。

#### MedicStats & SupStats2

为 logs.tf 提供更详细的日志。

#### Pause

防止两名玩家同时使用暂停功能，导致先暂停又被解除。在解除暂停时提供五秒倒计时。允许在暂停时聊天。

#### RestoreScore

当玩家断线重连进服务器时，恢复玩家的计分榜分数。

#### Server Broadcast

可以在服务器控制台使用 `sm_broadcast "内容"` 指令来向聊天框打印一句话。允许使用[颜色代码](https://www.doctormckay.com/morecolors.php)。

#### RandomPW

在服务器控制台使用 `sm_random_pw <前缀>` 指令来给服务器根据当天日期设置一个密码。
例如今天日期是8月13日，使用 sm_random_pw "keylol" 会给服务器设置密码 keylol0813
使用 `sm_print_pw` 可以把密码输出给所有玩家的聊天框。
如果需要给密码加上随机字符串，可以在源码里把我注释掉的代码还原回来。

#### Whitelist

实现赞助白名单功能。
**使用的时候务必把 `reservedslot.smx` 移除掉。这个插件是从预留通道插件改造过来的，已经包含了 `reservedslot.smx` 的所有功能。**
`sm_free_slots <number>` 指定免费通道的数量
`sm_whitelist_add <steam3-id> <x>` 将指定玩家加入白名单，有效期x个月
例如使用 `sm_whitelist_add "[U:1:39748236]"` 3 将玩家 [U:1:39748236] 加入白名单，有效期三个月。
白名单的数据存放在 `addons/sourcemod/configs/player_whitelist.cfg` 里，使用 Unix 时间戳记录起止时间。
插件会给白名单里的玩家打 custom(1) 权限标记。

## 规则

规则存放在 `cfg/tournment` 下。其中 `pug_pre.cfg` 在规则载入前执行， `pug_post.cfg` 在规则载入后执行。可以手动使用 exec 指令载入具体规则，也可以在 !admin 菜单选择“执行CFG”来载入规则。

目前包含以下规则：

* AFC7 Push
* AFC7 King of the Hill
* UGC 6v6 Standard
* UGC 6v6 Standard (Overtime)
* UGC 6v6 Stopwatch
* UGC 6v6 Golden
* UGC 6v6 King of the Hill
* UGC 6v6 King of the Hill (Overtime)

## Linux Daemon

如果你使用 Linux，可以使用这里提供的 `srcds_daemon` 脚本。
编辑这个文件，根据需要修改里面的用户名和启动参数。把它重命名为 `srcds`，放置到 `/etc/init.d`，之后你可以使用下列命令来控制服务器进程。

    service srcds {start|stop|restart|status}

## 如何使用这套配置

网上能下载到的插件，建议自己从源站下载安装，一定要看插件的说明。比如有些插件依赖 SteamTools 扩展，有些依赖 cURL 扩展，这些需要你自己安装。
对于我自己编写的插件，你可以在这里下载一份源码，阅读一遍了解原理后再自行重新编译安装。
规则配置需要配合这里提供的 `server.cfg` 来使用。你可以按照需要进行修改。
