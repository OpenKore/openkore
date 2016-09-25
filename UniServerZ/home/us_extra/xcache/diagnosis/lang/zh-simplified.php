<?php
// auto generated, do not modify
$strings += array(
		"Diagnosis Result"
		=> "诊断结果",
		"Item"
		=> "项目",
		"Level"
		=> "级别",
		"Result"
		=> "结果",
		"Explanation/Suggestion"
		=> "解释/建议",
		"XCache extension"
		=> "XCache extension",
		"Add extension=xcache.so (or xcache.dll) in %s"
		=> "在 %s 增加 extension=xcache.so (或 xcache.dll)",
		"Please put a php.ini in %s and add extension=xcache.so (or xcache.dll) in it"
		=> "请在 %s 里放个 php.ini 并且在文件内写入 extension=xcache.so (或 xcache.dll)",
		"Cannot detect php.ini location"
		=> "无法检测 php.ini 位置",
		"(See above)"
		=> "(参见上面)",
		"Not loaded"
		=> "未载入",
		"error"
		=> "错误",
		"Loaded"
		=> "已载入",
		"info"
		=> "信息",
		"Enabling PHP Cacher"
		=> "启用 PHP 缓存器",
		"skipped"
		=> "跳过",
		"Not enabled"
		=> "尚未启用",
		"Your PHP pages is not accelerated by XCache. Set xcache.size to non-zero, set xcache.cacher = On"
		=> "XCache 并未对您的 PHP 网页起到加速作用. 设置 xcache.size 为非 0, 设置 xcache.cacher = On",
		"No php script cached"
		=> "未缓存任何 PHP 脚本",
		"Your PHP pages is not accelerated by XCache. Set xcache.cacher = On"
		=> "XCache 并未对您的 PHP 网页起到加速作用. 设置 xcache.cacher = On",
		"Enabled"
		=> "已启用",
		"PHP Compile Time Error"
		=> "PHP 编译时错误",
		"warning"
		=> "警告",
		"Error happened when compiling at least one of your PHP code"
		=> "至少在编译其中一个您的 PHP 代码时发生编译错误",
		"This usually means there is syntax error in your PHP code. Enable PHP error_log to see what parser error is it, fix your code"
		=> "这通常意味着您的 PHP 代码有语法错误. 请启用 error_log 调查具体错误原因并修复您的代码",
		"No error happened"
		=> "未发生过错误",
		"Busy Compiling"
		=> "忙着编译",
		"Cache marked as busy for compiling"
		=> "编译中, 缓存标记为忙",
		"It's ok if this status don't stay for long. Otherwise, it could be a sign of PHP crash/coredump, report to XCache devs"
		=> "这个状态如果持续不就则无影响. 否则可能标志着 PHP 曾经发生异常退出, 如果是的话请报告给 XCache 开发组",
		"Idle"
		=> "空闲",
		"Enabling VAR Cacher"
		=> "启用 VAR 缓存器",
		"PHP code that use XCache caching backend have to use other caching backend instead. Set xcache.var_size to non-zero"
		=> "使用 XCache 作为数据缓存器的 PHP 代码将不得不采用其他缓存器代替. 设置 xcache.var_size 为非 0",
		"Using VAR Cacher"
		=> "使用 VAR 缓存器",
		"No variable data cached"
		=> "未缓存任何变量数据",
		"Var Cacher won't work simply by enabling it. PHP code must call XCache APIs like xcache_set() to use it as cache backend. 3rd party web apps may come with XCache support, config it to use XCache as caching backend"
		=> "只启用变量数据缓存器并无法将其利用起来. 必须通过 PHP 代码去调用 XCache API 接口(如 xcache_set() 函数) 将 XCache 作为缓存器. 第三方网页软件可能带有 XCache 支持, 留意其中的设置启用 XCache 作为缓存器",
		"Cache in use"
		=> "缓存使用中",
		"Cache Size"
		=> "缓存大小",
		"Out of memory happened when trying to write to cache"
		=> "存入缓存时发生内存不足",
		"Increase xcache.size and/or xcache.var_size"
		=> "加大 xcache.size 或 xcache.var_size",
		"Enough"
		=> "充足",
		"Hash Slots"
		=> "哈希槽",
		"Slots value too big"
		=> "哈希槽设定太大",
		"A very small value is set to %s value and leave %s value is too big.\nDecrease %s if small cache is really what you want"
		=> "设置给 %s 的值很小, 却采用过大的 %s. 如果您的确想要配置占用很少内存的缓存器, 可减少 %s",
		"Slots value too small"
		=> "哈希槽设定太小",
		"So many item are cached. Increase %s to a more proper value"
		=> "相当多的项目缓存了. 请适量加大 %s",
		"Looks good"
		=> "看起来还行",
		"Cache Status"
		=> "缓存状态",
		"At least one of the caches is disabled. "
		=> "至少一个缓存器是禁止状态",
		"Enable the cache."
		=> "启用已禁止的缓存器.",
		"It was disabled by PHP crash/coredump handler or you disabled it manually."
		=> "可能是在 PHP 异常退出时自动标记为禁止了, 或者您手工禁止了",
		"You disabled it manually."
		=> "您手工禁止了",
		"If it was caused by PHP crash/coredump, report to XCache devs"
		=> "如果是由于 PHP 异常退出造成, 请报告给 XCache 开发组",
		"Coredump Directory"
		=> "Coredump 目录",
		"Enable coredump to save debugging information in case when PHP crash. It can also be enabled in other module like php-fpm beside XCache"
		=> "启用 coredump 设置. 这样万一发生 PHP 异常退出时可保存调试信息. 这个功能也可以在其他地方启用, 如 php-fpm",
		"Core files found:\n"
		=> "发现 core 文件:\n",
		"Disable XCache PHP Cacher (set xcache.size=0), remove the core file(s), then restart PHP. If core file appears again, report call stack backtrace in the core to XCache devs"
		=> "禁止 XCache 缓存器 (设置 xcache.size=0), 删除 Core 文件, 再重启 PHP. 如果不用 XCache 时不出现 Core, 请从 Core 中取得 call stack back trace 信息报告回 XCache 开发组",
		"You can see core files if PHP crash in %s if PHP crash"
		=> "如果 PHP 异常退出, 您可以在 %s 目录看到 Core 文件",
		"Readonly Protection"
		=> "只读保护",
		"Set to enabled but not available"
		=> "设置为启用, 但目前不可用",
		"Use xcache.mmap_path other than /dev/zero"
		=> "设置 xcache.mmap_path 使用 /dev/zero 以外的值",
		"Disabled"
		=> "已禁止",
		"Enable readonly_protection == --performance & ++stability. Disable readonly_protection == ++performance & --stability"
		=> "启用 readonly_protection == --性能 & ++稳定性. 禁用 readonly_protection == ++性能 & --稳定性",
		"XCache modules"
		=> "XCache 模块",
		"Acceptable. Module(s) listed are built into XCache but not for production server.\nLeave it as is if you're feeling good.\nRe-configure XCache with the module(s) disabled if you're strict with server security."
		=> "可接受. 以上列出的模块已编译入 XCache, 但这些模块并非用于产业服务器.\n如果您觉得没大碍, 就保持现状.\n如果您对稳定性/安全性要求极其严格, 建议重新编译 XCache 不启用这些模块\n",
		"XCache test setting"
		=> "XCache 测试设置",
		"xcache.test is for testing only, not for server. set it to off"
		=> "xcache.test 仅用于开发测试用, 不用于服务器. 将它设置为 off",
		"PHP Version"
		=> "PHP 版本",
		"The version of PHP you're using is known to be unstable: "
		=> "您所使用的 PHP 版本, 是众所周知的不稳定版本: ",
		"Upgrade to new version of PHP"
		=> "升级到更新的 PHP 版本",
		"Extension Compatibility"
		=> "Extension 兼容性",
		"Zend Optimizer loaded"
		=> "Zend Optimizer 载入了",
		"Optimizer feature of 'Zend Optimizer' is disabled by XCache due to compatibility reason; the Loader of it is still available, encoded files are still supported"
		=> "由于兼容性问题, 'Zend Optimizer' 的优化器已被 XCache 禁止; 其加载器依然可用, 可继续使用 Zend 加密的文件",
		"SAPI Compatibility"
		=> "Extension 兼容性",
		);

