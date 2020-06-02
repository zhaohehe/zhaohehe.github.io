---
title: IO多路复用
date: 2020-05-28 22:39:05
tags:
- IO
- 同步和异步
- 阻塞
---

## 标准IO

标准IO也叫带缓冲IO，顾名思义，相比于unbuffered IO，它的不同之处在于通过一个读写缓冲区来减少使用`read`和`write`系统调用的次数。

在标准IO中，当进程发起一个读请求的时候，数据先会被copy到内核中的缓冲区，当缓冲区填满或者满足其他需要刷新缓冲区的情况时，数据才会从内核的缓冲区copy到进程的地址空间中。

<!--more-->

因此，标准IO在发生一个read请求的时候，会经历两个阶段:
1. 等待数据在缓冲区中准备好。
2. 将数据从缓冲区copy到进程的地址空间。

正因为有了这两个阶段，才产生了我们常说的阻塞/非阻塞和同步/异步IO。

## 阻塞与非阻塞

在linux中，默认情况下所有socket都是阻塞的。

### 阻塞IO
当用户进程调用了`recvfrom`系统调用，内核就进入了IO的第一个阶段：准备数据。对于一个网络IO，可能一开始数据还没有到达，比如还没有接收到一个完整的UDP包，这个时候内核就要等待足够的数据到来，而且数据copy到内核的缓冲区也是需要时间的，这个期间，用户进程就会被阻塞。当数据成功copy到缓冲区之后，进入第二阶段，将数据复制到进程的地址空间。然后内核才会返回结果，于是用户进程的阻塞状态解除。

所以，阻塞IO的特点就是在IO执行的两个阶段中，用户进程都被阻塞了。

### 非阻塞IO
可以通过设置使socket变成非阻塞模式。
此时用户进程再发起`recvfrom`系统调用，如果缓冲区的数据还没有准备好，就不会阻塞用户进程了，而是立刻返回一个error，告知用户进程数据尚未ready。
所以，IO的第一阶段是非阻塞的，当用户进程判断返回了一个error的时候，就知道缓存区的数据还没有准备好，用户进程就可以再次发起请求，直到缓冲区准备好了的时候，内核就会执行第二阶段，将数据copy到进程的地址空间，然后返回。

对于非阻塞IO，在第一阶段缓冲区数据准备的过程中，用户进程是不阻塞的，但是用户进程需要主动的不断询问内核，数据是否ready。

阻塞与非阻塞IO的一个区别是，阻塞期间，用户进程会被挂起，直到等待的事件完成才会被唤醒。

## 同步和异步
上面所说的两种IO都属于同步IO，因为用户进程在IO执行第二阶段的时候，都会被阻塞，直到数据复制到了进程的地址空间。而异步IO则没有等待的过程。

当用户进程发起了一个异步的IO操作的时候，内核会立即返回。用户进程就可以自由地去做其他事情了，内核会自己完成准备缓冲区和copy数据到用户进程地址空间的任务。当IO完成的时候，内核会发一个signal来通知用户进程IO操作完成了。

## IO多路复用
> IO多路复用也叫事件驱动IO，就是我们常用的select，poll，epoll。IO多路复用的好处在于单个进程就可以同时处理很多个网络连接的IO了。nginx和redis等擅长处理超多客户端连接的服务都是使用了IO多路复用技术。

在用户进程调用select，poll，epoll的时候，用户进程是被阻塞的，此时内核会监视所负责的一组socket，当其中任何一个socket准备好了，内核就会返回。然后用户进程可以对该socket进程读取了。

### select
```c
int select (int n, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout);
```
select函数监控的文件描述符分为三种：readfds、writefds、exceptfds。调用select后用户进程阻塞，直到有描述符就绪（有数据可读、可写或者有except）或者等待时间超过timeout，select函数才会返回。然后用户进程需要遍历fdset来检查相应的文件描述符有没有就绪。

select函数的一个优点就是跨平台支持很好，几乎所有的操作系统都支持select。但是单个进程通过select函数可以监控的文件描述符数量有限，linux下一般为1024。而且内核需要将包含全部文件描述符的fdset返回给用户进程，用户进程也需要遍历fdset才能知道哪些文件描述符就绪了，效率较低。

### poll
```c
int poll (struct pollfd *fds, unsigned int nfds, int timeout);
```
select函数通过三个bitmap来分别表三种不同事件类型的fdset，而poll只需要一个pollfd类型的指针即可。

```c
struct pollfd {
    int fd; /* file descriptor */
    short events; /* requested events to watch */
    short revents; /* returned events witnessed */
};
```
一个pollfd结构包含三个字段：需要监听的文件描述符、要关心的事件和已就绪的事件。
传入内核的只是一个pollfd类型的指针，相当于数组的首元素地址，内核可以得到一个pollfd列表。这样poll函数就没有了可监听的文件描述符数量的限制了。

内核会把用户进程关心的文件描述符上就绪的事件赋值到revents字段上，用户进程也需要遍历fds并解析revents来得到就绪的文件描述符。所以当用户进程监控的文件描述符数量很大，且同时就绪的描述符又很少的时候，select和poll的效率就会线性下降。

### epoll
epoll操作过程需要三个接口
```c
int epoll_create(int size)；// 创建一个epoll的句柄，size用来告诉内核这个监听的数目一共有多大，不是限制，只是给内核初始化内部数据结构的建议
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event)；
int epoll_wait(int epfd, struct epoll_event *events, int maxevents, int timeout);
```

调用epoll_create函数创建了一个epoll的句柄后，可以调用epoll_ctl来向这个epoll上添加需要监控的文件描述符。
其中：
- epfd就是epoll_create函数的返回值
- op表示操作类型：添加EPOLL_CTL_ADD，删除EPOLL_CTL_DEL，修改EPOLL_CTL_MOD
- fd是要监控的文件描述符
- event表示要监听的event是什么，epoll_event结构如下:
```c
typedef union epoll_data {
    void *ptr; /* 指向用户自定义数据 */
    int fd; /* 注册的文件描述符 */
    uint32_t u32; /* 32-bit integer */
    uint64_t u64; /* 64-bit integer */
} epoll_data_t;

struct epoll_event {
  __uint32_t events;  /* Epoll events */
  epoll_data_t data;  /* User data variable */
};

// events可以是以下几个宏的集合：
// EPOLLIN ：表示对应的文件描述符可以读（包括对端SOCKET正常关闭）；
// EPOLLOUT：表示对应的文件描述符可以写；
// EPOLLPRI：表示对应的文件描述符有紧急的数据可读（这里应该表示有带外数据到来）；
// EPOLLERR：表示对应的文件描述符发生错误；
// EPOLLHUP：表示对应的文件描述符被挂断；
// EPOLLET： 将EPOLL设为边缘触发(Edge Triggered)模式，这是相对于水平触发(Level Triggered)来说的。
// EPOLLONESHOT：只监听一次事件，当监听完这次事件之后，如果还需要继续监听这个socket的话，需要再次把这个socket加入到EPOLL队列里
```
epoll_wait函数用于等待epfd上的io事件就绪，内核会把就绪的时间赋值到events参数中。这样用户进程就只需要从内核获取已就绪的fd集合，减少了遍历的过程，对于监听的fd很多，但活跃的fd不多的情况，大大提升了效率。

### epoll的原理 
> epoll的核心数据结构就是一个红黑树和一个链表(存储就绪的文件描述符)。

用户进程调用epoll_create时，会根据size参数的建议，初始化一个红黑树和一个链表。
红黑树用于保存用户进程关心的文件描述符及其上绑定的事件的集合，也就是说红黑树的每一个节点都包含一个文件描述符以及相关的event，用户进程可以通过epoll_ctl函数来对红黑树进行增删改操作。

当用户进程调用epoll_ctl进行EPOLL_CTL_ADD操作的时候，内核除了在红黑树中插入一个节点外，还会为这个fd注册一个回调函数，当该fd上有对应的event就绪时，内核会调用这个回调函数，而这个回调函数的功能就是将fd添加到上述的就绪链表中。

这样，当用户进程调用epoll_wait时，内核只需要按照maxevents参数，从就绪链表上取出对应数量的已就绪的fd，然后复制到events参数中去即可。

对于poll和select，用户进程都需要将与文件描述符有关的数据结构copy到内核中，内核进行处理后再copy会用户进程的地址空间。而epoll的相关数据结构本身就是在内核态中的，返回时只需要复制就绪的文件描述符列表就可以了，减少了复制开销。

总体而言，epoll比poll和select更加优秀，但是由于epoll的实现依赖于大量的回调函数，对于连接数较少且大都十分活跃的网络应用，epoll的性能未必比select和poll更好。所以还是要因地制宜。

## 总结
- 阻塞和非阻塞的区别在于用户进程是否需要等待数据准备
- 异步io的区别在于用户进程发起请求后就无需关心，内核将数据复制到进程空间后会主动通知用户进程
- io多路复用都是属于同步io，因为用户进程需要自己主动去执行读写操作
- epoll相比于select和poll在各方面都有所进步，但也不能说在任何场景下的表现都会比select和poll要好，还是要具体场景具体分析