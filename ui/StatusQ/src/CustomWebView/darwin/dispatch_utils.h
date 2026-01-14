#pragma once

#if defined(Q_OS_MACOS) || defined(Q_OS_IOS)

#import <dispatch/dispatch.h>
#import <Foundation/Foundation.h>

// Execute a block on the main thread (immediately if already on main thread, otherwise async)
inline void runOnMainThread(void (^block)(void))
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

// Execute a block on the main thread synchronously (WARNING: be careful with deadlocks)
inline void runOnMainThreadSync(void (^block)(void))
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

#endif // Q_OS_MACOS || Q_OS_IOS
