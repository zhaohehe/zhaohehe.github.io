---
title: Git实现原理
date: 2020-06-07 14:55:16
tags:
- git
- 版本控制
---
# 版本控制
> 版本控制系统（VCS）是记录一个或多个文件的内容变化，以便将来查阅特定版本修订情况的系统。

最简单的版本控制方式就是复制整个项目目录，然后通过目录名中加上时间或版本号来区分，就像大公主陈沅沅的遗书一样。这样做的好处是足够简单，但是容易犯错，也不方便回忆不同版本之间的区别。

后来出现了一些通过记录不同版本之间差异的版本控制系统，系统可以通过最初的版本以及每次迭代的差异来重新计算出不同版本的内容。

随着项目越来越复杂，一起参与开发的人也多了起来，如何让项目的开发者之间互相协同也成为了VCS亟需考虑的功能。

于是集中化的版本控制系统应运而生（例如：CVS、Subversion等），不同开发人员将自己的最新修改统一提交到服务器，大家在修改之前也可以先从服务器拉取最新的代码。但是由于整个项目的提交历史都保存在一台服务器上，一旦服务器发生故障，数据就会丢失，而且服务器故障期间，客户端也无法提交自己的修改了。基于此，分布式版本控制系统出现了，其中最优秀的代表就是Git。

所谓分布式版本控制系统，是指除了中心服务器外，每个客户端上也会保存项目的全部提交历史和版本记录，就不用担心单点故障的问题了。

# Git
Git和其他的版本控制系统的主要差别在于：其他大部分的版本控制系统是保存一组基本文件和每个文件逐步累积的差异来实现的（基于差异的版本控制）。而Git则是记录了整个项目每个版本的快照，如果项目中一部分文件在不同版本之间没有修改，那么Git不会重复存储文件本身，而只是保留一个指向该文件内容的指针。

要想理解Git的实现原理，得先弄清楚它的核心数据结构：对象。

## Git对象
Git对象本质上其实是一个键值对数据库，value是某个文件的内容，key则是对文件内容和一个头部信息一起做 SHA-1 校验运算而得的校验和。

### 数据对象

数据对象存储的是文件内容，可以通过一组git底层命令来对git对象，也就是键值对数据对象进行读写。
```shell
# git hash-object 命令用于计算校验和以及写入键值对
$ echo 'version 1' > test.txt
$ git hash-object -w test.txt
83baae61804e65cc73a7201a7252750c76066a30
```
上面的操作用于将内容'version 1'写入数据对象，k系统会根据文件内容生成key，然后将40个字符的key划分为2个字符的目录和38个字符的文件名。并保存在`.git/objects/`目录下，于是就生成一个新的文件`.git/objects/83/baae61804e65cc73a7201a7252750c76066a30`, 文件的内容就是'version 1，但是是经过加密的，可以通过`git cat-file`命令来取得文件内容。
```shell
$ git cat-file -p 83baae61804e65cc73a7201a7252750c76066a30
version 1
```

可以对文件`test.txt`的内容进行修改，然后重新写入到数据对象。
```shell
$ echo 'version 2' > test.txt
$ git hash-object -w test.txt
1f7a7a472abf3dd9643fd615f6da379c4acb3e3a
```

此时可以看到git保存了两个数据对象。
```shell
$ find .git/objects -type f
.git/objects/1f/7a7a472abf3dd9643fd615f6da379c4acb3e3a
.git/objects/83/baae61804e65cc73a7201a7252750c76066a30
```
如果像恢复`test.txt`文件的内容到'version 1'，只需要通过数据对象的key来取回第一个版本的文件内容，并写入到'text.text'即可。
```shell
$ git cat-file -p 83baae61804e65cc73a7201a7252750c76066a30 > test.txt
$ cat test.txt
version 1
```

通过对数据对象的操作，很容易实现对单个文件的版本管理，现在的问题是，要如何知道文件每一个版本的 SHA-1 值，已经如何对目录进行版本控制？

### 树对象

树对象主要用于解决对目录的版本控制，一个树对象就代表了一个目录，而树对象下的子节点则代表了目录下的文件或子目录。

假设项目的当前工作目录结构如下:
```
test.txt
+ hello_dir
   - test.txt
```
一个文件`test.txt`和一个子目录`hello_dir`, 子目录下有一个文件`test.txt`。
可以通过底层命令`git cat-file -p` 来查看树对象内容：
```shell
$ git cat-file -p master^{tree}
100644 blob ce013625030ba8dba906f756967f9e9ca394464a	test.txt
040000 tree d8329fc1cc938780ffdd9f94e0d364e0ea74f579	hello_dir
```
master^{tree} 语法表示 master 分支上最新的提交所指向的树对象。
可以看到树对象记录了对应目录下文件或子目录的文件名，以及目录包含的数据对象或者树对象的 SHA-1 值。

继续查看`hello_dir`子目录对应的树对象的内容：
```shell
$ git cat-file -p d8329fc1cc938780ffdd9f94e0d364e0ea74f579
  100644 blob 83baae61804e65cc73a7201a7252750c76066a30	test.txt

$ git cat-file -p 83baae61804e65cc73a7201a7252750c76066a30
  version 1
```

通过树对象，可以方便的对目录进行版本管理，由于树对象只保存对应目录下文件的 SHA-1 值，所以尽管每次提交都是对整个工作目录的快照，但是只需要对那些有修改的文件新增一个数据对象就可以了，当然，从有修改的文件向上追溯直到工作根目录，这中间的每一层目录也都要新增一个新版的树对象。

### Git如何创建树对象
一般来说，Git是根据某一时刻的暂存区的状态创建一个树对象。我们可以通过底层命令`git update-index `为一个单独的文件创建暂存区。比如，在工作目录下创建一个test.txt文件，把test.txt的第一个版本加入暂存区：
```shell
$ echo 'version 1' | > test.txt
$ git hash-object -w test.txt
  83baae61804e65cc73a7201a7252750c76066a30

$ git update-index --add --cacheinfo 100644 83baae61804e65cc73a7201a7252750c76066a30 test.txt  
```
然后通过 git write-tree 命令将暂存区内容写入一个树对象：
```shell
$ git write-tree
d8329fc1cc938780ffdd9f94e0d364e0ea74f579
```
接着来创建一个新的树对象，它包括 test.txt 文件的第二个版本，以及一个新的文件：
```shell
$ echo 'version 2' > test.txt
$ git hash-object -w test.txt
  1f7a7a472abf3dd9643fd615f6da379c4acb3e3a
$ echo 'new file' > new.txt
$ git update-index --add --cacheinfo 100644 \
  1f7a7a472abf3dd9643fd615f6da379c4acb3e3a test.txt
$ git update-index --add new.txt
```
暂存区现在包含了 test.txt 文件的新版本，和一个新文件：new.txt。
```shell
$ git write-tree 
  0155eb4229851634a0f03eb265b69f5a2d56f341
$ git cat-file -p  0155eb4229851634a0f03eb265b69f5a2d56f341
  100644 blob fa49b077972391ad58037050f2a75f74e3671e92	new.txt
  100644 blob 1f7a7a472abf3dd9643fd615f6da379c4acb3e3a	test.txt
```
上面演示了如何将暂存区的内容写入到树对象，反过来也可以把树对象读到暂存区中，比如我们把第一次`write-tree`产生的树对象读到暂存区，并使其成为第二次`write-tree`产生的树对象的子树对象：
```shell
$ git read-tree --prefix=bak d8329fc1cc938780ffdd9f94e0d364e0ea74f579
$ git write-tree
  3c4e9cd789d88d8d89c1073707c3585e41b0e614
$ git cat-file -p 3c4e9cd789d88d8d89c1073707c3585e41b0e614
  040000 tree d8329fc1cc938780ffdd9f94e0d364e0ea74f579      bak
  100644 blob fa49b077972391ad58037050f2a75f74e3671e92      new.txt
  100644 blob 1f7a7a472abf3dd9643fd615f6da379c4acb3e3a      test.txt
```

此时，整个工作目录在Git内部的存储结构如下:

<img src="/images/git-inner-struct.png" width="80%" height="80%">


### 提交对象

树对象解决了目录版本控制，最后一个问题就是，我们如何知道文件或目录每一个版本对应的 SHA-1 值。

可以通过调用`commit-tree`命令创建一个提交对象，为此需要指定一个树对象的 SHA-1 值，以及该提交的父提交对象（通过 -p 参数），比如提交上一节创建的第一个树对象：
```shell
$ echo 'first commit' | git commit-tree d8329fc1cc938780ffdd9f94e0d364e0ea74f579
  5f377ddbc802f85b0efd07902edd8599d6d1fd4b

$ git cat-file -p 5f377ddbc802f85b0efd07902edd8599d6d1fd4b
  tree d8329fc1cc938780ffdd9f94e0d364e0ea74f579
  author zhaohehe <zhaohehedola@gmail.com> 1591518302 +0800
  committer zhaohehe <zhaohehedola@gmail.com> 1591518302 +0800

  first commit
```
提交对象记录了本次提交的时间、作者、提交者。注释等信息，以及最主要的：本次提交的顶层树对象，代表了当前整个项目项目录的快照。

接着，把另外两个树对象也提交了，每次提交把上一次提交作为父提交：
```shell
$ echo 'second commit' | git commit-tree 0155eb4229851634a0f03eb265b69f5a2d56f341 -p 5f377ddbc802f85b0efd07902edd8599d6d1fd4b
  4578418b0de46bd76c9e165edeae8c067283f3d7
$ echo 'third commit'  | git commit-tree   3c4e9cd789d88d8d89c1073707c3585e41b0e614 -p 4578418b0de46bd76c9e165edeae8c067283f3d7
  002477a6fb7d4b20082e951d7b3e909bfacdfa8d
```
这三个提交对象分别指向一个之前通过`write-tree`创建的树对象，对最后一个提交对象的 SHA-1 值进行`git log`操作，就能看到这三次提交的历史记录了：
```shell
$ git log --stat 002477a6fb7d4b20082e951d7b3e909bfacdfa8d
commit 002477a6fb7d4b20082e951d7b3e909bfacdfa8d
Author: zhaohehe <zhaohehedola@gmail.com>
Date:   Sun Jun 7 17:14:58 2020 +0800

    third commit

 bak/test.txt | 1 +
 1 file changed, 1 insertion(+)

commit 4578418b0de46bd76c9e165edeae8c067283f3d7
Author: zhaohehe <zhaohehedola@gmail.com>
Date:   Sun Jun 7 17:13:39 2020 +0800

    second commit

 new.txt  | 1 +
 test.txt | 2 +-
 2 files changed, 2 insertions(+), 1 deletion(-)

commit 5f377ddbc802f85b0efd07902edd8599d6d1fd4b
Author: zhaohehe <zhaohehedola@gmail.com>
Date:   Sun Jun 7 17:08:52 2020 +0800

    first commit

 test.txt | 1 +
 1 file changed, 1 insertion(+)
```

从上面的过程可以看出，在实际运用git的过程中，当我们执行`git add` 和 `git commit`命令时，Git所做的工作就是：
- 为被修改的文件新建数据对象 (hash-object -w)
- 更新暂存区 (update-index)
- 保存树对象 (write-tree)
- 创建一个指定了顶层树对象和父提交的提交对象 (commit-tree)

而过程中的这三种对象，都以文件的形式保存在`.git/objects`目录中。它们之间的关系如下:

<img src="/images/git-inner-struct2.png" width="80%" height="80%">

## 分支
> 理解了git内部的存储结构，就会发现git的分支的概念就很巧妙了，git中的分支其实就是一个指向某一个提交对象的指针。

`.git/HEAD`是一个特殊的指针，它指向的是当前所处的分支
```shell
$ cat .git/HEAD 
  ref: refs/heads/master
```
可以通过查看`.git/HEAD`的内容发现当前分支是master，然后通过查询`./git/refs/master`文件的内容来知道当前分支指向的是哪一个提交，文件`./git/refs/master`的值其实就是master分支上最新一个提交对象的 SHA1 值。

<img src="/images/git-branch.png" width="50%" height="50%">


这样看来，其实.git这个目录就包含了一个项目的全部版本的文件内容以及各个提交之间的关系了。当我们clone某个远程git仓库的时候，其实也是只需要下载.git目录的内容。

git除了保存本地各个分支的指针外，当我们执行`git fetch`命令的时候，会从服务器拉取远程仓库的各个分支的最新提交，这个提交包含了提交对象本身已经提交对象对应的树对象和数据对象。

可以把一个个的提交对象想象成链表的节点，每个节点可能有一个或多个prev指针，指向该节点的父节点（合并提交会存在多个父提交）。而每个节点也会随着不同的分支向不同的方向延伸开来。当执行git fetch的时候，可能会把某些分支指向的节点继续往前延伸，但本地的分支还是指向原来的那个节点。