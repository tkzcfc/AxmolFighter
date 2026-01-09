#pragma once

#include "axmol.h"

namespace native_utils
{

std::vector<std::string> get_command_line();

void set_clipboard_string(std::string data);

std::string get_clipboard_string();

std::string get_executable_path();

}  // namespace native_utils
