#include <QObject>
#include <QQmlParserStatus>
#include <QSet>
#include <QSettings>

#include <array>

#include "managetokensmodel.h"

class QAbstractItemModel;
class QTimer;

/// @brief Controller for managing visibility and order for all kind of tokens and groups.
///
/// There is an "abstraction" layer for saving data to different mediums and is controlled form QML.
/// The QML implementation forwards data to current QSettings for storybook and nim controllers for the app.
/// @see request* signals for triggering actions and start/finish methods for notifying about the process.
/// @see *QSettings related methods for saving and loading data in user profile settings.
class ManageTokensController : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)

    // input properties
    Q_PROPERTY(QAbstractItemModel* sourceModel READ sourceModel WRITE setSourceModel NOTIFY sourceModelChanged FINAL)
    Q_PROPERTY(QString settingsKey READ settingsKey WRITE setSettingsKey NOTIFY settingsKeyChanged FINAL REQUIRED)
    Q_PROPERTY(bool serializeAsCollectibles READ serializeAsCollectibles WRITE setSerializeAsCollectibles NOTIFY serializeAsCollectiblesChanged FINAL REQUIRED)

    Q_PROPERTY(bool arrangeByCommunity READ arrangeByCommunity WRITE setArrangeByCommunity NOTIFY arrangeByCommunityChanged FINAL)
    Q_PROPERTY(bool arrangeByCollection READ arrangeByCollection WRITE setArrangeByCollection NOTIFY arrangeByCollectionChanged FINAL)

    // output properties
    Q_PROPERTY(QAbstractItemModel* regularTokensModel READ regularTokensModel CONSTANT FINAL)
    Q_PROPERTY(QAbstractItemModel* collectionGroupsModel READ collectionGroupsModel CONSTANT FINAL)
    Q_PROPERTY(QAbstractItemModel* communityTokensModel READ communityTokensModel CONSTANT FINAL)
    Q_PROPERTY(QAbstractItemModel* communityTokenGroupsModel READ communityTokenGroupsModel CONSTANT FINAL)
    Q_PROPERTY(QAbstractItemModel* hiddenTokensModel READ hiddenTokensModel CONSTANT FINAL)

    Q_PROPERTY(QStringList hiddenCommunityGroups READ hiddenCommunityGroups NOTIFY hiddenCommunityGroupsChanged FINAL)
    Q_PROPERTY(QAbstractItemModel* hiddenCommunityTokenGroupsModel READ hiddenCommunityTokenGroupsModel CONSTANT FINAL)
    Q_PROPERTY(QStringList hiddenCollectionGroups READ hiddenCollectionGroups NOTIFY hiddenCollectionGroupsChanged FINAL)
    Q_PROPERTY(QAbstractItemModel* hiddenCollectionGroupsModel READ hiddenCollectionGroupsModel CONSTANT FINAL)

    Q_PROPERTY(bool dirty READ dirty NOTIFY dirtyChanged FINAL)
    Q_PROPERTY(bool hasSettings READ hasSettings NOTIFY settingsDirtyChanged FINAL)
    Q_PROPERTY(bool settingsDirty READ settingsDirty NOTIFY settingsDirtyChanged FINAL)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged FINAL)

public:
    explicit ManageTokensController(QObject* parent = nullptr);

    Q_INVOKABLE void showHideRegularToken(const QString& key, bool flag);
    Q_INVOKABLE void showHideCommunityToken(const QString& key, bool flag);
    Q_INVOKABLE void showHideGroup(const QString& groupId, bool flag);
    Q_INVOKABLE void showHideCollectionGroup(const QString& groupId, bool flag);

    Q_INVOKABLE void clearQSettings();
    Q_INVOKABLE void revert();

    /// required to call and guard the saving process
    Q_INVOKABLE void savingStarted();
    Q_INVOKABLE void savingFinished();
    /// required to call and guard the loading process
    Q_INVOKABLE void loadingStarted();
    Q_INVOKABLE void loadingFinished(const QString& jsonData);

    Q_INVOKABLE QString serializeSettingsAsJson();

    Q_INVOKABLE int order(const QString& key) const;
    Q_INVOKABLE int compareTokens(const QString& lhsKey, const QString& rhsKey) const;
    Q_INVOKABLE bool filterAcceptsKey(const QString& key) const;

    // utils
    Q_INVOKABLE QJsonObject getOwnershipTotalBalanceAndLastTimestamp(QAbstractItemModel *model, const QStringList& filterList) const;

protected:
    void classBegin() override;
    void componentComplete() override;

signals:
    void sourceModelChanged();
    void dirtyChanged();
    void arrangeByCommunityChanged();
    void arrangeByCollectionChanged();
    void settingsKeyChanged();
    void settingsDirtyChanged(bool dirty);
    void serializeAsCollectiblesChanged();

    void tokenHidden(const QString& key, const QString& name);
    void tokenShown(const QString& key, const QString& name);
    void communityTokenGroupHidden(const QString& communityName);
    void communityTokenGroupShown(const QString& communityName);
    void collectionTokenGroupHidden(const QString& communityName);
    void collectionTokenGroupShown(const QString& communityName);

    void hiddenCommunityGroupsChanged();
    void hiddenCollectionGroupsChanged();

    void revisionChanged();

    /// Emitted when the settings are requested to be saved.
    /// Receiver requires to call savingStarted and savingFinished to notify about the saving process.
    /// @param jsonData serialized json data
    void requestSaveSettings(const QString& jsonData);
    /// Emitted when the settings are requested to be loaded. Client should call loadSettings as a response.
    /// Receiver requires to call loadingStarted and loadingFinished to notify about the loading process.
    void requestLoadSettings();
    /// @brief Emitted when the settings are requested to be cleared.
    /// Receiver requires to call loadingStarted and loadingFinished to notify about the loading process.
    void requestClearSettings();

private:
    QAbstractItemModel* m_sourceModel{nullptr};
    QAbstractItemModel* sourceModel() const { return m_sourceModel; }
    void setSourceModel(QAbstractItemModel* newSourceModel);
    void parseSourceModel();
    void rebuildModels();

    void addItem(int index);

    // Incremental source-model dataChanged handling: instead of re-parsing the
    // whole source model on every dataChanged, accumulate the changed rows,
    // coalesce a storm into a single batched pass, and update only the affected
    // token rows in place. A change touching any role the partitioning/grouping/
    // ordering depends on falls back to a full re-parse.
    void onSourceDataChanged(const QModelIndex& topLeft, const QModelIndex& bottomRight, const QList<int>& roles);
    void scheduleSourceUpdateFlush();
    void flushPendingSourceUpdates();
    void applyIncrementalDataUpdate(int sourceRow);
    void cancelPendingSourceUpdates();
    bool hasPendingSourceUpdates() const;

    QTimer* m_sourceUpdateBatchTimer{nullptr};
    QSet<int> m_pendingChangedRows;
    QSet<QByteArray> m_pendingChangedRoleNames;
    bool m_pendingFullReparse{false};

    ManageTokensModel* m_regularTokensModel{nullptr};
    QAbstractItemModel* regularTokensModel() const { return m_regularTokensModel; }

    ManageTokensModel* m_collectionGroupsModel{nullptr};
    QAbstractItemModel* collectionGroupsModel() const { return m_collectionGroupsModel; }

    ManageTokensModel* m_communityTokensModel{nullptr};
    QAbstractItemModel* communityTokensModel() const { return m_communityTokensModel; }

    ManageTokensModel* m_communityTokenGroupsModel{nullptr};
    QAbstractItemModel* communityTokenGroupsModel() const { return m_communityTokenGroupsModel; }

    ManageTokensModel* m_hiddenTokensModel{nullptr};
    QAbstractItemModel* hiddenTokensModel() const { return m_hiddenTokensModel; }

    ManageTokensModel* m_hiddenCommunityTokenGroupsModel{nullptr};
    QAbstractItemModel* hiddenCommunityTokenGroupsModel() const { return m_hiddenCommunityTokenGroupsModel; }

    ManageTokensModel* m_hiddenCollectionGroupsModel{nullptr};
    QAbstractItemModel* hiddenCollectionGroupsModel() const { return m_hiddenCollectionGroupsModel; }

    bool dirty() const;

    bool m_arrangeByCommunity{false};
    bool arrangeByCommunity() const;
    void setArrangeByCommunity(bool newArrangeByCommunity);

    bool m_arrangeByCollection{false};
    bool arrangeByCollection() const;
    void setArrangeByCollection(bool newArrangeByCollection);

    void rebuildCommunityTokenGroupsModel();
    void rebuildHiddenCommunityTokenGroupsModel();
    void rebuildCollectionGroupsModel();
    void rebuildHiddenCollectionGroupsModel();

    const std::array<ManageTokensModel*, 7> m_allModels {m_regularTokensModel, m_collectionGroupsModel, m_communityTokensModel, m_communityTokenGroupsModel,
                                                         m_hiddenTokensModel, m_hiddenCommunityTokenGroupsModel, m_hiddenCollectionGroupsModel};

    QString m_settingsKey;
    QString settingsKey() const;
    QString settingsGroupName() const;
    void setSettingsKey(const QString& newSettingsKey);

    bool m_serializeAsCollectibles{false};
    bool serializeAsCollectibles() const;
    void setSerializeAsCollectibles(const bool newSerializeAsCollectibles);

    QSettings m_settings;
    SerializedTokenData m_settingsData;
    bool hasSettings() const;
    void loadSettingsData(bool withGroup = false);

    bool m_settingsDirty{false};
    bool settingsDirty() const { return m_settingsDirty; }
    void setSettingsDirty(bool dirty);

    int m_revision{0};
    int revision() const { return m_revision; }
    void incRevision();

    bool m_modelConnectionsInitialized{false};

    // explicitely mass-hidden asset/collectible groups
    QSet<QString> m_hiddenCommunityGroups;
    QStringList hiddenCommunityGroups() const;

    QSet<QString> m_hiddenCollectionGroups;
    QStringList hiddenCollectionGroups() const;
};
