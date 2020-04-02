---
title: php中获取中文字符串的长度
date: 2020-04-02
tags:
- php
- 字符串
- UTF-8
---
## php中的字符串
php中字符串的结构如下:
```c
struct _zend_string {
    zend_refcounted_h gc;     // 引用计数相关
    zend_ulong        h;      // 字符串的哈希值
    size_t            len;    // 字符串的长度，单位为byte
    char              var[1]; // char数组，存储字符串的值，结构体的最后一个数组字段可作为变长数组
}; 
```
<!--more-->

可以看到，_zend_string中直接存储了字符串的长度信息，这样做有两个好处：
1. 可以通过len字段判断char数组应该在何处结束，而不像c语言中通过末尾的空字符'\0'来判断，保证了php中字符串读写的二进制安全。
2. 在代码中通过`strlen()`函数获取字符串长度的时候不需要实时计算，可以在O(1)的时间复杂度内完成。

所以`strlen()`函数返回的其实是字符串的字节长度，当字符串中只包含英文、数字等单字节字符的时候是没有问题的。但是对于含有中文的字符串，`strlen()`就无法准确地返回字符串中字符的数量了。

## 获取中文字符串的长度
我们都知道要获取一个中文字符串的长度可以用`mb_strlen()`函数。
```php
<?php
$str = "中文字符串abc";
echo strlen($str) . PHP_EOL;    // 输出 18, 其中每个中文占3个字节
echo mb_strlen($str, 'UTF-8') . PHP_EOL;    // 输出 8
```

`mb_strlen()`函数是如何准确获得字符串的长度的呢??

### `mb_strlen()`的实现
mbstring扩展是php内置的用来处理多字节字符串的，默认不开启。
`mb_strlen`函数的定义如下:
```c
// ext/mbstring/mbstring.c

PHP_FUNCTION(mb_strlen)
{
	size_t n;
	mbfl_string string;
	char *str;
	size_t str_len;
	zend_string *enc_name = NULL;

	ZEND_PARSE_PARAMETERS_START(1, 2)
		Z_PARAM_STRING(str, str_len)
		Z_PARAM_OPTIONAL
		Z_PARAM_STR(enc_name)
	ZEND_PARSE_PARAMETERS_END();

        // 把字符串的值和字节长度等信息赋值给一个mbfl_string类型的变量
	string.val = (unsigned char *) str;
	string.len = str_len;
	string.no_language = MBSTRG(language);

        // 根据enc_name获取不同的编码的处理方式，enc_name就是mb_strlen($str, 'UTF-8')的入参 UTF-8  
	string.encoding = php_mb_get_encoding(enc_name, 2);
	if (!string.encoding) {
		RETURN_THROWS();
	}

	n = mbfl_strlen(&string);    // 这里返回值n就是字符串的长度
	if (!mbfl_is_error(n)) {
		RETVAL_LONG(n);
	} else {
		RETVAL_FALSE;
	}
}
```
可以发现，关键的一行代码就是`mbfl_strlen()`函数。

`mbfl_strlen()`函数会先判断下当前的编码是不是固定字节的，如果是类似UTF-8这样的变长编码就会进入下面的逻辑:
```c
// ext/mbstring/libmbfl/mbfl/mbfilter.c

size_t len, n, k;
unsigned char *p;
const mbfl_encoding *encoding = string->encoding;

const unsigned char *mbtab = encoding->mblen_table;
n = 0;              // 记录已读取的字节数
p = string->val;    // 指向存储字符串的char数组的首字节
k = string->len;    // 字符串的字节长度
/* count */
if (p != NULL) {
	while (n < k) {
		unsigned m = mbtab[*p];
		n += m;
		p += m;
		len++;
	}
}
```
从string->val表示的字符串的首字节开始往后遍历，每次循环`mbtab[*p]`会返回当前指针指向的字符（不是字节）的字节长度m，指针p跳跃m个字节，到达下一个字符的首字节位置，然后将表示字符串长度的变量len递增1。

所以重点就是`mbtab[*p]`如何得知以指针p指向的字节作为首字节的字符所占据的字节数。
mbtab是一个数组，`*p`则是指针位置，即字符首字节的值。以UTF-8为例，他的encoding->mblen_table数组如下:
```c
// ext/mbstring/libmbfl/filters/mbfilter_utf8.c

const unsigned char mblen_table_utf8[] = {
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
	4, 4, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
};
```
这是一个包含256个元素的数组，而0-255刚好是一个字节可以表示的范围。也就是说，这个数组是一个映射关系，对于一个UTF-8编码的字符，通过字符首字节的值，就可以知道这个字符一共多少个字节。

## UTF-8规则
> UTF规定：
如果一个符号只占一个字节，那么这个8位字节的第一位就为0。
如果为两个字节，那么规定第一个字节的前两位都为1，然后第一个字节的第三位为0，第二个字节的前两位为10。
如果是三个字节的话，那么第一个字节的前三位为111，第四位为0，剩余的两个字节的前两位都为10。

以一个三字节的中文为例，他的首字节的前4位就是1110, 所以首字节的值必然在11100000-11101111之间，也就是224-239。而mblen_table_utf8数组的224-239个元素恰好都是3。

## 总结
`strlen()`函数直接读取_zend_string.len获取字符串的字节长度。时间复杂度为O(1);
`mb_string()`函数需要遍历字符串获取字符长度，对于不同的编码只需要查找不同编码的encoding->mblen_table数组即可。时间复杂度是O(n);