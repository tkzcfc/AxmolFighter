#include "native_utils.h"

#import <Foundation/Foundation.h>

namespace native_utils
{

#if AX_TARGET_PLATFORM == AX_PLATFORM_MAC
std::vector<std::string> get_command_line()
{
    std::vector<std::string> args;
    @autoreleasepool
    {
        NSArray* arguments = [[NSProcessInfo processInfo] arguments];
        for (NSString* arg in arguments)
        {
            args.push_back([arg UTF8String]);
        }
    }
    return args;
}
#endif  // AX_TARGET_PLATFORM == AX_PLATFORM_MAC

}  // namespace native_utils
