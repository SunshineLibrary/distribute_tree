distribute_tree
===============
用于实现单个Cloud和多个Local服务器之间数据共享的 Rails Engine 。

Cloud(1) <-> Local(n) 同步机制概述
---------------
同步模式:

* 自动: 保存一个资源均只同步自身的JSON和File，即不递归同步子集。
* 手动: 新增一个学校，或者只想给某些学校，分配某些资源，在后台管理也没点击同步，并递归子集。

启动方式
---------------

```bash
RAILS_ENV=production bundle exec rake resque:work QUEUE='cloud_distribute_tree' --trace
```

如果需要对一个queue起多个work，那么多开几个rake进程就好了，系统会自动排队和并发处理的。

[循环sync] local(只要在这里把资源标上创建地点即可让cloud识别) -> cloud -> locals

同步架构变迁历史概述
---------------
#### 第一代(mysql replication)

优点:
1. 从数据库层面一致。

缺点:

1. 单向。
1. 无法提供细力度控制和外部操作。

#### 第二代(rabbitmq)

优点:

1. 高性能

缺点：

1. 按订阅全部同步，容易造成VPN网络堵塞。虽然可以改成点对点发送，但也失去了用rabbitmq的必要。
2. 无细力度的UI，不透明。这个开发难度比 resque 高，且是另外一套系统。

#### 第三代(resque)
架构：基于resque队列系统。队列可视化，rails风格。

1. 初始化同步，或者中途中断后同步， cloud -> local。

配置学校，可以按school同步，并在resque里递归从属或关联子集，产生新队列（这一想法基于之前给刘聪做的递归更新父级时间戳 [mongoid_touch_parents_recursively](https://github.com/SunshineLibrary/mongoid_touch_parents_recursively) 。

2. 增量更新同步. cloud -> local (lesson) ，或者local -> cloud (piece) 。

在数据同步后紧接着触发文件同步，都放在resque里。两者交互机制就是经典的client-server API 架构CRUD数据，这样也就符合了我来书屋面试前还没成型的想法，隐约地想要把学校local也看成是cloud的伪android客户端。删除也参考warpgate的做法。

注: 感谢和小平的冲突，感谢和诺哥的讨论，在萨莉亚吃完晚饭后，萦绕的思绪突然激发了这一想法。这个完全不是时间逼的。

FAQ
---------------
问题: paperclip包含的静态资源过大，比如100M，在cloud的resque连接上local的Rails接口去上传文件时会发生网络请求超时错误，并会占用一个unicorn slave。

答案: 可以反过来做，改为在元数据同步过去到local后，不管paperclip包含的文件对象大小，
      让local自己主动向cloud的nginx静态资源服务器读取大文件，并在下载完成后保存即可，从而达到异步的效果。
      这点warpgate就是这样做的，跨网络传输文件还是下行快一点。

TODO
---------------
1. 突破Mongoid.relations限制以支持ActiveModel

相关引用
---------------
1. [warpgate](https://github.com/SunshineLibrary/warpgate)
