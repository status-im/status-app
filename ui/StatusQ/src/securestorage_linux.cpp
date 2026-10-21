#include "StatusQ/securestorage.h"

#include <QDebug>
#include <QPointer>
#include <QSet>
#include <QTimer>

#include <chrono>
#include <condition_variable>
#include <functional>
#include <memory>
#include <mutex>
#include <thread>

// glib/gio headers use `signals` as an ordinary identifier, which clashes with Qt's macro.
#undef signals
#include <libsecret/secret.h>
#define signals Q_SIGNALS

namespace {

// Upper bound for how long a CALLER may wait for a public operation. libsecret's
// synchronous calls can block indefinitely (missing/hung daemon), so every operation runs
// on a detached worker thread; when this deadline passes the operation is cancelled and
// the caller returns immediately — it never joins the worker. Each public method performs
// exactly ONE bounded operation (service connection included), so this is the per-call
// worst case.
constexpr std::chrono::milliseconds kOperationTimeout{1500};

// After a TIMEOUT or TRANSPORT failure (daemon missing/hung), don't re-block callers:
// reads fail fast until this window expires. Mutations (user-initiated, rare) still
// attempt. Locked-keyring conditions do NOT arm this backoff — the daemon is healthy.
constexpr std::chrono::seconds kFailureBackoff{30};

std::chrono::steady_clock::time_point g_lastFailure{}; // epoch value = "no recent failure"

bool backoffActive()
{
    return g_lastFailure != std::chrono::steady_clock::time_point{}
           && std::chrono::steady_clock::now() - g_lastFailure < kFailureBackoff;
}

// Why an operation failed — drives backoff/availability handling. Only Timeout and
// Transport indicate an unhealthy daemon; Locked and Busy leave availability untouched.
enum class FailReason {
    None,
    Timeout,   // bounded deadline expired
    Transport, // Secret Service unreachable
    Locked,    // keyring locked / prompt refused / no default collection
    Busy,      // an earlier mutation for the same account is still unresolved
};

struct OpResult {
    SecureStorage::Status status = SecureStorage::StatusGenericError;
    QString credential;
    FailReason reason = FailReason::None;
};

// -------------------------------- pending mutations ------------------------------------
// A mutation whose caller timed out may still be running (or awaiting rollback) in its
// lingering worker. Until it fully resolves, later mutations for the same account are
// rejected — otherwise an old operation completing late could overwrite newer user intent
// (e.g. a timed-out delete resuming after a subsequent successful set).

std::mutex g_pendingMutationsMutex;
QSet<QString> g_pendingMutations;

bool acquireMutationSlot(const QString &account)
{
    std::lock_guard<std::mutex> lock(g_pendingMutationsMutex);
    if (g_pendingMutations.contains(account))
        return false;
    g_pendingMutations.insert(account);
    return true;
}

void releaseMutationSlot(const QString &account)
{
    std::lock_guard<std::mutex> lock(g_pendingMutationsMutex);
    g_pendingMutations.remove(account);
}

// ---------------------------------------------------------------------------------------
// A SecretService subclass whose prompt handlers refuse every prompt.
//
// The class contract forbids any prompting, but libsecret's service layer automatically
// executes provider-requested prompts (e.g. "unlock the keyring" when creating or
// deleting an item in a locked collection). A lock-state pre-check cannot guarantee
// anything — the collection can lock between check and use, and the prompt machinery
// stays armed regardless. Overriding the prompt vfuncs removes the capability itself:
// any operation that would prompt fails with G_IO_ERROR_PERMISSION_DENIED instead, which
// is mapped to StatusUnavailable with FailReason::Locked.
// ---------------------------------------------------------------------------------------

typedef struct {
    SecretService parent;
} StatusNoPromptSecretService;

typedef struct {
    SecretServiceClass parent_class;
} StatusNoPromptSecretServiceClass;

G_DEFINE_TYPE(StatusNoPromptSecretService, status_no_prompt_secret_service, SECRET_TYPE_SERVICE)

GVariant *statusNoPromptSyncVFunc(SecretService *service,
                                  SecretPrompt *prompt,
                                  GCancellable *cancellable,
                                  const GVariantType *returnType,
                                  GError **error)
{
    Q_UNUSED(service)
    Q_UNUSED(prompt)
    Q_UNUSED(cancellable)
    Q_UNUSED(returnType)
    g_set_error_literal(error, G_IO_ERROR, G_IO_ERROR_PERMISSION_DENIED,
                        "SecureStorage: prompting is disabled");
    return nullptr;
}

void statusNoPromptAsyncVFunc(SecretService *service,
                              SecretPrompt *prompt,
                              const GVariantType *returnType,
                              GCancellable *cancellable,
                              GAsyncReadyCallback callback,
                              gpointer userData)
{
    Q_UNUSED(prompt)
    Q_UNUSED(returnType)
    GTask *task = g_task_new(service, cancellable, callback, userData);
    g_task_return_new_error(task, G_IO_ERROR, G_IO_ERROR_PERMISSION_DENIED,
                            "SecureStorage: prompting is disabled");
    g_object_unref(task);
}

GVariant *statusNoPromptFinishVFunc(SecretService *service, GAsyncResult *result, GError **error)
{
    Q_UNUSED(service)
    return static_cast<GVariant *>(g_task_propagate_pointer(G_TASK(result), error));
}

void status_no_prompt_secret_service_class_init(StatusNoPromptSecretServiceClass *klass)
{
    SecretServiceClass *serviceClass = SECRET_SERVICE_CLASS(klass);
    serviceClass->prompt_sync = statusNoPromptSyncVFunc;
    serviceClass->prompt_async = statusNoPromptAsyncVFunc;
    serviceClass->prompt_finish = statusNoPromptFinishVFunc;
}

void status_no_prompt_secret_service_init(StatusNoPromptSecretService *self)
{
    Q_UNUSED(self)
}

// A fresh, uncached no-prompt service connection (secret_service_open_sync does not use
// the process-wide singleton, so the default prompt-capable service is never created).
// Opening the connection doubles as the availability check of every operation.
SecretService *openNoPromptService(GCancellable *cancellable, GError **error)
{
    return secret_service_open_sync(status_no_prompt_secret_service_get_type(),
                                    nullptr,
                                    SECRET_SERVICE_NONE,
                                    cancellable,
                                    error);
}

bool promptRefused(const GError *error)
{
    return error != nullptr && g_error_matches(error, G_IO_ERROR, G_IO_ERROR_PERMISSION_DENIED);
}

OpResult openServiceFailed(const GError *error)
{
    qWarning() << "SecureStorage: Secret Service unreachable:"
               << (error ? error->message : "unknown error");
    return {SecureStorage::StatusUnavailable, {}, FailReason::Transport};
}

// ---------------------------------------------------------------------------------------

// Items are stored in the default (login) collection of the freedesktop Secret Service —
// GNOME Keyring or KWallet — and identified by (service, account) schema attributes.
const SecretSchema *storageSchema()
{
    static const SecretSchema schema = {
        "im.status.StatusDesktop.SecureStorage",
        SECRET_SCHEMA_NONE,
        {
            {"service", SECRET_SCHEMA_ATTRIBUTE_STRING},
            {"account", SECRET_SCHEMA_ATTRIBUTE_STRING},
            {nullptr, SecretSchemaAttributeType(0)},
        },
        // remaining reserved fields zero-initialized
    };
    return &schema;
}

GHashTable *attributesFor(const QByteArray &service, const QByteArray &account)
{
    GHashTable *attributes = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
    g_hash_table_insert(attributes, g_strdup("service"), g_strdup(service.constData()));
    g_hash_table_insert(attributes, g_strdup("account"), g_strdup(account.constData()));
    return attributes;
}

// Invoked by the worker after the publish/rollback decision: `rollback` is true when the
// operation succeeded but its caller had already timed out. Always called exactly once
// when set, so it also carries resource cleanup.
using Finalizer = std::function<void(bool rollback)>;

// Runs `op` on a DETACHED worker thread and waits for at most kOperationTimeout. On
// timeout the operation is cancelled via GCancellable and the caller returns immediately
// with `timeoutStatus` — the worker is never joined, so even an operation that ignores
// cancellation cannot block the calling thread.
//
// The timeout decision and the worker's completion are synchronized on the same mutex:
// the caller marks `timedOut` under the lock, and the worker checks it under the lock
// before publishing — so exactly one of "caller receives the result" or "worker knows the
// caller is gone (and rolls back a success via the op's Finalizer)" happens; there is no
// window in which a success is published to a caller that already reported failure.
//
// `mutationAccount`, when non-empty, is released (pending-mutation registry) by the
// worker: on the delivered path BEFORE completion is published (so a caller receiving
// StatusSuccess can immediately start another mutation without a spurious rejection); on
// the timeout path only after rollback/finalization fully resolves.
//
// `op` MUST own everything it touches (capture by value): by the time it runs, the
// caller's stack frame may be gone.
OpResult runBounded(SecureStorage::Status timeoutStatus,
                    QString mutationAccount,
                    std::function<OpResult(GCancellable *, Finalizer &)> op)
{
    struct Shared {
        std::mutex mutex;
        std::condition_variable cv;
        bool done = false;
        bool timedOut = false;
        OpResult result;
        GCancellable *cancellable = g_cancellable_new();
        ~Shared() { g_object_unref(cancellable); }
    };

    auto shared = std::make_shared<Shared>();

    std::thread([shared, mutationAccount, op = std::move(op)]() {
        Finalizer finalize;
        OpResult result = op(shared->cancellable, finalize);

        bool rollback = false;
        bool delivered = false;
        {
            std::lock_guard<std::mutex> lock(shared->mutex);
            if (!shared->timedOut) {
                // Release the mutation slot before the caller can observe completion, so
                // an immediate follow-up mutation is not spuriously rejected. (Lock order
                // is shared->mutex then the registry mutex, never the reverse.)
                if (!mutationAccount.isEmpty())
                    releaseMutationSlot(mutationAccount);
                delivered = true;
                shared->result = result;
                shared->done = true;
            } else {
                // The caller already reported timeoutStatus; a success must be undone so
                // the stored state matches what the caller observed. The mutation slot
                // stays held until that fully resolves.
                rollback = (result.status == SecureStorage::StatusSuccess);
            }
        }
        shared->cv.notify_all();

        if (finalize)
            finalize(rollback);

        if (!delivered && !mutationAccount.isEmpty())
            releaseMutationSlot(mutationAccount);
    }).detach();

    std::unique_lock<std::mutex> lock(shared->mutex);
    if (!shared->cv.wait_for(lock, kOperationTimeout, [&shared]() { return shared->done; })) {
        shared->timedOut = true;
        lock.unlock();
        qWarning() << "SecureStorage: Secret Service operation timed out, cancelling";
        g_cancellable_cancel(shared->cancellable);
        return {timeoutStatus, {}, FailReason::Timeout};
    }

    return shared->result;
}

} // namespace

// Schedules an availableChanged emission for just after the backoff window expires. QML
// bindings do not re-evaluate on wall-clock time — without this, `available` could
// present false forever after a failure.
//
// The tick recomputes the ACTUAL remaining backoff when it fires: a newer failure that
// extended g_lastFailure makes it reschedule itself instead of consuming the notification
// early. Scheduling is deduplicated per instance via a dynamic property (not a global
// flag), and the timer's context object is the instance itself — if the instance is
// destroyed, the pending tick and its dedup state die with it; nothing global is left
// stuck.
static void scheduleRetryTick(QPointer<SecureStorage> storage)
{
    using namespace std::chrono;

    auto delay = duration_cast<milliseconds>((g_lastFailure + kFailureBackoff + seconds(1))
                                             - steady_clock::now());
    if (delay.count() < 0)
        delay = milliseconds(0);

    QTimer::singleShot(delay, storage.data(), [storage]() {
        if (storage.isNull())
            return;

        if (backoffActive()) {
            // A newer failure extended the backoff while this tick was pending — fire
            // again at the real expiry.
            scheduleRetryTick(storage);
            return;
        }

        storage->setProperty("secureStorageRetryScheduled", false);
        // Bindings re-evaluate `available`, which re-probes now that the backoff window
        // has expired.
        storage->availableChanged();
    });
}

static void scheduleRetryNotification(const SecureStorage *storage)
{
    auto *notifiable = const_cast<SecureStorage *>(storage);
    if (notifiable->property("secureStorageRetryScheduled").toBool())
        return;

    notifiable->setProperty("secureStorageRetryScheduled", true);
    scheduleRetryTick(QPointer<SecureStorage>(notifiable));
}

// Shared post-processing on the calling thread (CRUD paths).
//  - Timeout/Transport: the daemon is unhealthy — invalidate `available`, start the
//    backoff, notify bindings, and schedule a re-notification at backoff expiry.
//  - A successful round-trip (Success/NotFound): the daemon is proven reachable — clear
//    any backoff and restore `available`, notifying bindings if it changed.
//  - Locked/Busy and plain errors: availability is left untouched.
static void handleOutcomeLinux(const SecureStorage *storage, int &availableCache, const OpResult &result)
{
    auto *notifiable = const_cast<SecureStorage *>(storage);

    if (result.reason == FailReason::Timeout || result.reason == FailReason::Transport) {
        availableCache = -1;
        g_lastFailure = std::chrono::steady_clock::now();
        notifiable->availableChanged();
        scheduleRetryNotification(storage);
        return;
    }

    if (result.status == SecureStorage::StatusSuccess
        || result.status == SecureStorage::StatusNotFound) {
        g_lastFailure = {};
        if (availableCache != 1) {
            availableCache = 1;
            notifiable->availableChanged();
        }
    }
}

bool SecureStorage::available() const
{
    if (m_availableCache < 0) {
        // Reaching the Secret Service DBus interface proves a provider (GNOME Keyring,
        // KWallet, ...) is present. Failures may be transient (daemon starting up) — the
        // verdict is not cached, but the backoff prevents re-blocking the caller on every
        // call while the daemon stays broken.
        if (backoffActive())
            return false;

        const OpResult result = runBounded(StatusUnavailable, {},
                                           [](GCancellable *cancellable, Finalizer &) -> OpResult {
            GError *error = nullptr;
            SecretService *service = openNoPromptService(cancellable, &error);
            if (service == nullptr) {
                const OpResult failed = openServiceFailed(error);
                g_clear_error(&error);
                return failed;
            }
            g_object_unref(service);
            return {SecureStorage::StatusSuccess, {}, FailReason::None};
        });

        // No availableChanged emission from inside the property read — the binding
        // currently evaluating receives the fresh value directly, and emitting
        // mid-evaluation would risk a binding loop. The retry timer re-notifies once the
        // backoff expires; CRUD outcomes handle later transitions.
        if (result.status != StatusSuccess) {
            g_lastFailure = std::chrono::steady_clock::now();
            scheduleRetryNotification(this);
            return false;
        }

        m_availableCache = 1;
    }

    return m_availableCache == 1;
}

SecureStorage::Status SecureStorage::setCredential(const QString &account, const QString &credential)
{
    // Reject while an earlier mutation for this account is unresolved (see the
    // pending-mutation registry). No backoff involved — the daemon may be perfectly
    // healthy.
    if (!acquireMutationSlot(account)) {
        qWarning() << "SecureStorage: setCredential rejected, previous mutation unresolved";
        return StatusUnavailable;
    }

    // No available() pre-check: openNoPromptService inside the single bounded operation
    // IS the availability check — one deadline per public call. Mutations deliberately
    // ignore the read backoff: they are user-initiated and deserve a real attempt.
    const QByteArray serviceUtf8 = m_service.toUtf8();
    const QByteArray accountUtf8 = account.toUtf8();
    const QByteArray credentialUtf8 = credential.toUtf8();
    const QByteArray label = QStringLiteral("Status Desktop (%1)").arg(account).toUtf8();

    // Capture by value: the worker may outlive this frame (see runBounded).
    const OpResult result = runBounded(StatusIndeterminate, account,
                                       [=](GCancellable *cancellable, Finalizer &finalize) -> OpResult {
        GError *error = nullptr;
        SecretService *service = openNoPromptService(cancellable, &error);
        if (service == nullptr) {
            const OpResult failed = openServiceFailed(error);
            g_clear_error(&error);
            return failed;
        }

        SecretCollection *collection = secret_collection_for_alias_sync(service,
                                                                        SECRET_COLLECTION_DEFAULT,
                                                                        SECRET_COLLECTION_NONE,
                                                                        cancellable,
                                                                        &error);
        if (collection == nullptr) {
            qWarning() << "SecureStorage: no default Secret Service collection:"
                       << (error ? error->message : "not present");
            g_clear_error(&error);
            g_object_unref(service);
            return {SecureStorage::StatusUnavailable, {}, FailReason::Locked};
        }

        GHashTable *attributes = attributesFor(serviceUtf8, accountUtf8);
        SecretValue *value = secret_value_new(credentialUtf8.constData(),
                                              credentialUtf8.size(),
                                              "text/plain");

        // A locked collection makes the provider request an unlock prompt; the no-prompt
        // service refuses it, so this fails instead of showing any system UI.
        SecretItem *item = secret_item_create_sync(collection,
                                                   storageSchema(),
                                                   attributes,
                                                   label.constData(),
                                                   value,
                                                   SECRET_ITEM_CREATE_REPLACE,
                                                   cancellable,
                                                   &error);

        secret_value_unref(value);
        g_hash_table_unref(attributes);
        g_object_unref(collection);

        if (item == nullptr) {
            g_object_unref(service);
            const auto reason = promptRefused(error) ? FailReason::Locked : FailReason::None;
            const auto status = promptRefused(error) ? SecureStorage::StatusUnavailable
                                                     : SecureStorage::StatusGenericError;
            qWarning() << "SecureStorage: setCredential failed:"
                       << (error ? error->message : "unknown error");
            g_clear_error(&error);
            return {status, {}, reason};
        }

        // The rollback/cleanup decision is made by runBounded under the shared lock: if
        // the caller timed out (it already reported StatusIndeterminate), the created
        // item is deleted so the stored state matches what the caller observed. The
        // pending-mutation slot stays held until this ran, and the post-login
        // reconciliation task is the final safety net.
        finalize = [item, service](bool rollback) {
            if (rollback) {
                GError *rollbackError = nullptr;
                if (!secret_item_delete_sync(item, nullptr, &rollbackError)) {
                    qWarning() << "SecureStorage: rollback of timed-out setCredential failed:"
                               << (rollbackError ? rollbackError->message : "unknown error");
                    g_clear_error(&rollbackError);
                } else {
                    qWarning() << "SecureStorage: rolled back setCredential that committed "
                                  "after its caller timed out";
                }
            }
            g_object_unref(item);
            g_object_unref(service);
        };

        return {SecureStorage::StatusSuccess, {}, FailReason::None};
    });

    handleOutcomeLinux(this, m_availableCache, result);
    return result.status;
}

SecureStorage::Status SecureStorage::deleteCredential(const QString &account)
{
    // See setCredential: pending-mutation rejection, single bounded operation, no
    // available() pre-check, mutations ignore the read backoff. A delete that commits
    // after its caller timed out cannot overwrite newer intent — the registry blocks any
    // later mutation for this account until this one fully resolves.
    if (!acquireMutationSlot(account)) {
        qWarning() << "SecureStorage: deleteCredential rejected, previous mutation unresolved";
        return StatusUnavailable;
    }

    const QByteArray serviceUtf8 = m_service.toUtf8();
    const QByteArray accountUtf8 = account.toUtf8();

    // Capture by value: the worker may outlive this frame (see runBounded).
    const OpResult result = runBounded(StatusIndeterminate, account,
                                       [=](GCancellable *cancellable, Finalizer &) -> OpResult {
        GError *error = nullptr;
        SecretService *service = openNoPromptService(cancellable, &error);
        if (service == nullptr) {
            const OpResult failed = openServiceFailed(error);
            g_clear_error(&error);
            return failed;
        }

        GHashTable *attributes = attributesFor(serviceUtf8, accountUtf8);
        GList *items = secret_service_search_sync(service,
                                                  storageSchema(),
                                                  attributes,
                                                  SECRET_SEARCH_ALL,
                                                  cancellable,
                                                  &error);
        g_hash_table_unref(attributes);

        if (error != nullptr) {
            qWarning() << "SecureStorage: deleteCredential search failed:" << error->message;
            g_clear_error(&error);
            g_object_unref(service);
            return {SecureStorage::StatusGenericError, {}, FailReason::None};
        }

        if (items == nullptr) {
            g_object_unref(service);
            return {SecureStorage::StatusNotFound, {}, FailReason::None};
        }

        OpResult opResult{SecureStorage::StatusSuccess, {}, FailReason::None};
        for (GList *iter = items; iter != nullptr; iter = iter->next) {
            // Deleting from a locked collection would request an unlock prompt; the
            // no-prompt service refuses it and the deletion fails instead.
            if (!secret_item_delete_sync(SECRET_ITEM(iter->data), cancellable, &error)) {
                opResult.status = promptRefused(error) ? SecureStorage::StatusUnavailable
                                                       : SecureStorage::StatusGenericError;
                opResult.reason = promptRefused(error) ? FailReason::Locked : FailReason::None;
                qWarning() << "SecureStorage: deleteCredential failed:"
                           << (error ? error->message : "unknown error");
                g_clear_error(&error);
                break;
            }
        }

        g_list_free_full(items, g_object_unref);
        g_object_unref(service);
        return opResult;
    });

    handleOutcomeLinux(this, m_availableCache, result);
    return result.status;
}

SecureStorage::Status SecureStorage::hasCredential(const QString &account) const
{
    // Reads fail fast during the failure backoff — they sit on hot paths (property
    // bindings, startup) and must not repeatedly block on a broken daemon.
    if (backoffActive())
        return StatusUnavailable;

    const QByteArray serviceUtf8 = m_service.toUtf8();
    const QByteArray accountUtf8 = account.toUtf8();

    // Capture by value: the worker may outlive this frame (see runBounded).
    const OpResult result = runBounded(StatusUnavailable, {},
                                       [=](GCancellable *cancellable, Finalizer &) -> OpResult {
        GError *error = nullptr;
        SecretService *service = openNoPromptService(cancellable, &error);
        if (service == nullptr) {
            const OpResult failed = openServiceFailed(error);
            g_clear_error(&error);
            return failed;
        }

        GHashTable *attributes = attributesFor(serviceUtf8, accountUtf8);

        // Plain search: matches locked items too, loads no secrets, cannot prompt.
        GList *items = secret_service_search_sync(service,
                                                  storageSchema(),
                                                  attributes,
                                                  SECRET_SEARCH_NONE,
                                                  cancellable,
                                                  &error);
        g_hash_table_unref(attributes);
        g_object_unref(service);

        if (error != nullptr) {
            qWarning() << "SecureStorage: hasCredential search failed:" << error->message;
            g_clear_error(&error);
            return {SecureStorage::StatusGenericError, {}, FailReason::None};
        }

        const bool found = items != nullptr;
        g_list_free_full(items, g_object_unref);

        return {found ? SecureStorage::StatusSuccess : SecureStorage::StatusNotFound,
                {},
                FailReason::None};
    });

    handleOutcomeLinux(this, m_availableCache, result);
    return result.status;
}

QVariantMap SecureStorage::getCredential(const QString &account) const
{
    const auto asMap = [](const OpResult &result) {
        return QVariantMap{{QStringLiteral("status"), static_cast<int>(result.status)},
                           {QStringLiteral("credential"), result.credential}};
    };

    // See hasCredential: reads fail fast during the failure backoff.
    if (backoffActive())
        return asMap({StatusUnavailable, {}, FailReason::None});

    const QByteArray serviceUtf8 = m_service.toUtf8();
    const QByteArray accountUtf8 = account.toUtf8();

    // Capture by value: the worker may outlive this frame (see runBounded).
    const OpResult result = runBounded(StatusUnavailable, {},
                                       [=](GCancellable *cancellable, Finalizer &) -> OpResult {
        GError *error = nullptr;
        SecretService *service = openNoPromptService(cancellable, &error);
        if (service == nullptr) {
            const OpResult failed = openServiceFailed(error);
            g_clear_error(&error);
            return failed;
        }

        GHashTable *attributes = attributesFor(serviceUtf8, accountUtf8);

        // Deliberately no SECRET_SEARCH_UNLOCK: secrets load only from unlocked keyrings;
        // combined with the no-prompt service, a locked keyring can never trigger the
        // desktop's unlock dialog from this path.
        GList *items = secret_service_search_sync(service,
                                                  storageSchema(),
                                                  attributes,
                                                  SECRET_SEARCH_LOAD_SECRETS,
                                                  cancellable,
                                                  &error);
        g_hash_table_unref(attributes);
        g_object_unref(service);

        if (error != nullptr) {
            qWarning() << "SecureStorage: getCredential search failed:" << error->message;
            g_clear_error(&error);
            return {SecureStorage::StatusGenericError, {}, FailReason::None};
        }

        if (items == nullptr)
            return {SecureStorage::StatusNotFound, {}, FailReason::None};

        OpResult itemResult{SecureStorage::StatusGenericError, {}, FailReason::None};
        SecretItem *item = SECRET_ITEM(items->data);

        if (secret_item_get_locked(item)) {
            qWarning() << "SecureStorage: item is in a locked collection, not prompting";
            itemResult.status = SecureStorage::StatusUnavailable;
            itemResult.reason = FailReason::Locked;
        } else {
            SecretValue *value = secret_item_get_secret(item);
            if (value == nullptr) {
                qWarning() << "SecureStorage: item secret was not loaded";
            } else {
                gsize length = 0;
                const gchar *text = secret_value_get(value, &length);
                itemResult.credential = QString::fromUtf8(text, static_cast<int>(length));
                secret_value_unref(value);
                itemResult.status = SecureStorage::StatusSuccess;
            }
        }

        g_list_free_full(items, g_object_unref);
        return itemResult;
    });

    handleOutcomeLinux(this, m_availableCache, result);
    return asMap(result);
}
