#pragma once

#include <QColor>
#include <QQuickItem>

// Hosts a native iOS UIPasteControl (iOS 16+). The system reads the pasteboard
// itself and hands the contents to the app as NSItemProviders, so the app never
// touches UIPasteboard and the "Allow Paste?" alert is never shown - the tap on
// Apple's own control is the consent.
//
// Styling is limited to what UIPasteControlConfiguration exposes: display mode,
// tint colours and corner style. The label text is system-supplied and localized
// and cannot be changed. The control also clips rather than scales when given a
// frame smaller than its content needs, and reports no measurable size, so give
// it a generous box.
class NativePasteButtonItem : public QQuickItem
{
    Q_OBJECT

    Q_PROPERTY(DisplayMode displayMode READ displayMode WRITE setDisplayMode NOTIFY displayModeChanged)
    // REQUIRED: UIKit picks each tint's default independently, so setting only
    // one of them can leave the glyph unreadable against the fill.
    Q_PROPERTY(QColor foregroundColor READ foregroundColor WRITE setForegroundColor NOTIFY foregroundColorChanged REQUIRED)
    Q_PROPERTY(QColor backgroundColor READ backgroundColor WRITE setBackgroundColor NOTIFY backgroundColorChanged REQUIRED)
    Q_PROPERTY(CornerStyle cornerStyle READ cornerStyle WRITE setCornerStyle NOTIFY cornerStyleChanged)

public:
    enum DisplayMode {
        IconAndLabel,
        IconOnly,
        LabelOnly
    };
    Q_ENUM(DisplayMode)

    enum CornerStyle {
        Fixed,
        Dynamic,
        Small,
        Medium,
        Large,
        Capsule
    };
    Q_ENUM(CornerStyle)

    explicit NativePasteButtonItem(QQuickItem* parent = nullptr);
    ~NativePasteButtonItem() override = default;

    DisplayMode displayMode() const { return m_displayMode; }
    void setDisplayMode(DisplayMode mode);

    QColor foregroundColor() const { return m_foregroundColor; }
    void setForegroundColor(const QColor& color);

    QColor backgroundColor() const { return m_backgroundColor; }
    void setBackgroundColor(const QColor& color);

    CornerStyle cornerStyle() const { return m_cornerStyle; }
    void setCornerStyle(CornerStyle style);

signals:
    void displayModeChanged();
    void foregroundColorChanged();
    void backgroundColorChanged();
    void cornerStyleChanged();

    // Emitted once the system has handed over the pasteboard contents.
    void pasted(const QString& text);

protected:
    virtual void syncToNative() {}

private:
    DisplayMode m_displayMode = IconAndLabel;
    QColor m_foregroundColor;
    QColor m_backgroundColor;
    CornerStyle m_cornerStyle = Capsule;
};
