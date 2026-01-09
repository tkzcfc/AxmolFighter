#pragma once

#include "axmol.h"

namespace game_utils
{
bool unzip_file(const char* zipFile,
                std::string dstDir,
                const char* password,
                const std::function<void(float)>& percentCallback = nullptr);

int compress(const char* in_str, size_t in_len, std::string& out_str, int level);

int decompress(const char* in_str, size_t in_len, std::string& out_str);

// 得到当前时间点的 epoch 毫秒
int64_t now_epoch_ms();

// 得到当前时间点的 epoch ticks(精度为秒后 7 个 0)
int64_t now_epoch_10m();

// 获取当前UTC时间戳（秒）
int64_t get_utc_timestamp_seconds();

// 获取当前UTC时间戳（毫秒）
int64_t get_utc_timestamp_milliseconds();

}  // namespace game_utils
