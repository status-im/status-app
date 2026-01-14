#pragma once

#import <WebKit/WebKit.h>

class DarwinWebViewBackend;

@interface NavigationDelegate : NSObject <WKNavigationDelegate>
@property (nonatomic, assign) DarwinWebViewBackend *owner;
@end

