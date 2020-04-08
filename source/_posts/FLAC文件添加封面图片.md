---
title: FLAC文件添加封面图片
date: 2020-04-08
tags:
- FLAC
- 音乐
- 字节序
---
> FLAC是一套著名的自由音频压缩编码，其特点是无损压缩。
> 在播放一个FLAC格式的音乐的时候，发现没有封面，于是就比较好奇FLAC是怎么保存音乐的图片信息的，以及怎么样添加或替换一个FLAC文件的图片。

<!--more-->

## FLAC文件格式
FLAC文件格式大体上可以分为三个部分：

| 结构|说明|
|  ----  | ----  |
| flac标志  | 4byte 字符"`fLaC`", 用于识别flac数据流 |
| METADATA_BLOCK  | 一个以上的描述信息块 |
| FRAME  | 一个以上的音频帧 |

其中，文件的头4个字符固定为"fLaC"，用于识别falc数据流，而我所关心的图片信息就保存在METADATA_BLOCK结构中。

METADATA_BLOCK结构可以分为两个部分，固定长度的METADATA_BLOCK_HEADER和不固定长度的METADATA_BLOCK_DATA。

`METADATA_BLOCK_HEADER`结构如下:

| 长度（位）|说明|
|  ----  | ----  |
| 1  | 该位为1，表示当前METADATA_BLOCK是最后一个|
| 7 | BLOCK_TYPE <br>0 : STREAMINFO <br>1 : PADDING<br>2 : APPLICATION<br>3 : SEEKTABLE<br>4 :VORBIS_COMMENT<br>5 : CUESHEET<br>6 : PICTURE<br>7-126 : 保留值<br>127 : 无效|
| 24 | METADATA_BLOCK_HEADER后面跟着的METADATA_BLOCK_DATA的长度 |

之所以METADATA_BLOCK有一个或多个，是因为一个FLAC文件必须存在一个BLOCK_TYPE=STREAMINFO的描述信息块。包含了FLAC格式必须的一些信息，比如采样率、声道数等。

每个描述信息块的长度都不一样，这是因为每种类型的描述信息本身的结构都各不相同。以PICTURE类型为例，它的METADATA_BLOCK_DATA部分的结构如下：

| 长度（位）|说明|
|  ----  | ----  |
| 32  | 图片类型|
| 32  | MIME类型字符长度（byte）|
| n*8  | MIME类型|
| 32  | 描述符长度（byte）|
| n*8  | 描述符|
| 32  | 图片宽度|
| 32  | 图片高度|
| 32  | 图片颜色深度|
| 32  | 索引图使用的颜色数目，0非索引图|
| 32  | 图片数据长度|
| n*8  | 图片数据|

## 解析FLAC文件
通过上面的描述，发现flac文件格式很有规律，在c语言中，可以很方便地使用结构体来表示flac格式的一些结构。
```c
/**
 * METADATA_BLOCK_HEADER
 */
typedef struct _flac_meta_block_header
{
    unsigned int is_final   : 1;
    unsigned int block_type : 7;
    unsigned int block_size : 24;
} flac_meta_block_header;

/**
 *  METADATA_BLOCK_PICTURE
 */
typedef struct _flac_meta_block_picture
{
    unsigned int picture_type;
    unsigned int mime_length;
    char *mime;
    unsigned int description_length;
    char *description;
    unsigned int width;
    unsigned int height;
    unsigned int color_depth;
    unsigned int index_color_count;
    unsigned int image_data_length;
    char *image_data;
} flac_meta_block_picture;
```
通过`fread()`函数，按照flac文件格式往后遍历，可以把全部的METADATA_BLOCK结构组成一个flac_meta_block_header[]数组，is_final字段作为遍历终止条件。

检查flac_meta_block_header[]数组中有没有block_type=6的元素，就可以得知这个文件中有没有包含图片信息了。更近一步，可以获取图片的各种信息，包含尺寸、描述等，也包括图片内容本身。

## 插入图片信息
插入图片信息之前，先要把图片组装成一个METADATA_BLOCK_PICTURE格式的结构，然后在前面加上METADATA_BLOCK_HEADER，头的类型为PICTURE，长度为METADATA_BLOCK_PICTURE的长度。这就组成了一个图片类型的METADATA_BLOCK描述信息块。

在解析FLAC的时候可以记录下METADATA_BLOCK部分结束位置的文件偏移量。然后在此处插入新加的图片的METADATA_BLOCK。需要注意处理一下METADATA_BLOCK_HEADER的is_final位，保证只有最后一个描述信息块的is_final=1。

## 字节序
FLAC文件格式中的所有数值都是整形，大端(big-endian)模式。而一般的x86系列CPU都是小端(little-endian)的字节序。这样在写入数值到FLAC文件中的时候就要注意了。

以METADATA_BLOCK_PICTURE的image_data_length字段为例，当我想写入的数值为19088743的时候，如果直接
```c
int length = 240;
fwrite(&length, sizeof(int), 1, fp);
```
写入的会是什么呢？
19088743的16进制形式为: 0x01234567，假设length变量的地址为0x10000，那么length在内存中的情况:

|地址| 0x10000|0x10001|0x10002|0x10003|
| ---- |  ----  | ----  |
|大端法的值|0x01|0x23|0x45|0x67|
|小端法的值|0x67|0x45|0x23|0x01|

在我的计算机中，数值是以小端法在内存中存储的，上面的代码写入到文件中的值也是|0x67|0x45|0x23|0x01|的顺序，当读取FLAC文件的时候，由于我们已知其是大端格式，在将length解释为一个int值的时候就会出问题。

所以在写文件的时候，写入到文件中的字节序要与内存中的顺序相反，一个简单的办法就是通过运算按照从高有效字节到低有效字节的顺序把32位int转换成一个char[]数组，这样内存中各个字节的排列顺序就变成大端的形式了:
```c
FILE* write_int_32(FILE *fp, unsigned int number)
{
    char char_array[4];

    char_array[0] = number >> 24;
    char_array[1] = number << 8 >> 24;
    char_array[2] = number << 16 >> 24;
    char_array[3] = number << 24 >> 24;

    fwrite(char_array, 1, 4, fp);

    return fp;
}
```

## 总结
1. FLAC文件格式将各种描述信息按顺序写入到METADATA_BLOCK结构中，至少有一个STREAMINFO类型的描述信息块来存储一些必需的信息，is_final位表示METADATA_BLOCK的结束。FLAC格式中的的数值都是整数，且采用大端字节序。在读取和写入数值的时候需要注意。
2. 在网络通信时，也会遇到不同主机之间字节序不同的问题，因此TCP/IP协议规定了网络通信统一采用网络字节序（大端字节序）。

## 参考文档
[代码](https://github.com/zhaohehe/flac-parser)
[flac格式](https://xiph.org/flac/format.html#metadata_block_picture)