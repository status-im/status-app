#include "StatusQ/localnetworkpermission.h"

#ifdef Q_OS_IOS

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include <QMetaObject>
#include <QObject>
#include <QPointer>
#include <QTimer>

#include <dns_sd.h>

#include "localnetworkpermission_backend.h"

namespace {
static NSString* const kDomain = @"local.";
static NSString* const kType = @"_lnp._tcp.";
static const int kPort = 1100;
}

namespace {
class IOSBackend;
}

@interface LNPServiceDelegate : NSObject <NSNetServiceDelegate>
- (instancetype)initWithBackend:(IOSBackend*)backend;
@end

namespace {
class IOSBackend final : public QObject, public LocalNetworkPermissionBackend {
public:
    explicit IOSBackend(LocalNetworkPermission* owner)
        : QObject(owner)
        , LocalNetworkPermissionBackend(owner)
    {
        // Poll every 500ms for permission changes.
        m_timer.setInterval(500);
        QObject::connect(&m_timer, &QTimer::timeout, this, [this]() {
            this->tick();
        });
    }

    ~IOSBackend() override { cancel(); }

    // Request permission from IOS.
    // If the permission is granted or denied already we'll just update the status.
    void request() override
    {
        ensureTimer();
        doProbe();
    }

    // This backend will poll the permissions until it's cancelled or deleted.
    void cancel() override
    {
        stopTimer();
        cleanupService();
    }

    void onDidPublish()
    {
        postStatus(LocalNetworkPermission::Granted);
        cleanupService();
    }

    void onDidNotPublish(int domain, int code)
    {
        Q_UNUSED(domain);
        if (code == kDNSServiceErr_PolicyDenied) {
            postStatus(LocalNetworkPermission::Denied);
            cleanupService();
        } else {
            // Inconclusive. Cannot determine whether the permission was denied.
            cleanupService();
        }
    }

    void tick()
    {
        doProbe();
    }

private:
    QTimer m_timer;
    QElapsedTimer m_publishElapsed;
    QElapsedTimer m_cycleCooldown;
    bool m_publishAttempted{false};

    NSNetService* m_service{nil};
    LNPServiceDelegate* m_delegate{nil};

    void ensureTimer()
    {
        if (!m_owner) return;
        if (m_timer.isActive()) return;
        m_timer.start();
    }

    void stopTimer()
    {
        if (m_timer.isActive())
            m_timer.stop();
    }

    void doProbe()
    {
        if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
            return;

        if (m_publishAttempted && m_publishElapsed.isValid() && m_publishElapsed.elapsed() > 1500) {
            postStatus(LocalNetworkPermission::Denied);
            cleanupService();
            return;
        }

        if (m_cycleCooldown.isValid() && m_cycleCooldown.elapsed() < 1500)
            return;

        if (m_publishAttempted)
            return;

        m_publishAttempted = true;
        m_publishElapsed.restart();
        if (!m_cycleCooldown.isValid()) m_cycleCooldown.start(); else m_cycleCooldown.restart();

        QPointer<IOSBackend> backend = this;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!backend)
                return;
            // Create a unique name to avoid collision errors.
            NSString* name = [NSString stringWithFormat:@"LocalNetworkPrivacy-%@", [NSUUID UUID].UUIDString];
            NSNetService* svc = [[NSNetService alloc] initWithDomain:kDomain type:kType name:name port:kPort];
            svc.includesPeerToPeer = YES;

            LNPServiceDelegate* delegate = [[LNPServiceDelegate alloc] initWithBackend:backend.data()];
            svc.delegate = delegate;
            [svc scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            [svc publish];

            if (!backend) {
                [svc stop];
                [svc removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
                [svc release];
                [delegate release];
                return;
            }

            backend->m_service = svc;
            backend->m_delegate = delegate;
        });
    }

    void cleanupService()
    {
        m_publishAttempted = false;
        m_publishElapsed.invalidate();

        if (m_service) {
            [m_service stop];
            [m_service removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            [m_service release];
            m_service = nil;
        }
        if (m_delegate) {
            [m_delegate release];
            m_delegate = nil;
        }
    }
};
} // namespace

@implementation LNPServiceDelegate
{
    QPointer<IOSBackend> _backend;
}

- (instancetype)initWithBackend:(IOSBackend*)backend
{
    self = [super init];
    if (self) {
        _backend = backend;
    }
    return self;
}

- (void)netServiceDidPublish:(NSNetService *)sender
{
    Q_UNUSED(sender);
    IOSBackend* backend = _backend.data();
    if (backend) backend->onDidPublish();
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary<NSString *,NSNumber *> *)errorDict
{
    Q_UNUSED(sender);
    IOSBackend* backend = _backend.data();
    if (!backend) return;
    const int code = errorDict[NSNetServicesErrorCode].intValue;
    const int domain = errorDict[NSNetServicesErrorDomain].intValue;
    backend->onDidNotPublish(domain, code);
}

@end

std::unique_ptr<LocalNetworkPermissionBackend> createLNPermissionIOS(LocalNetworkPermission* owner)
{
    return std::make_unique<IOSBackend>(owner);
}

#endif // Q_OS_IOS

