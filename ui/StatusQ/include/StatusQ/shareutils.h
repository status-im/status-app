#include <QObject>
#include <QDebug>

class ShareUtils : public QObject {
    Q_OBJECT
public:
    explicit ShareUtils(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE void shareText(const QString &text);
};
