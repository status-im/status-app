#pragma once

#include <QObject>
#include <QSize>
#include <QString>
#include <QVideoFrame>
#include <QVideoFrameFormat>
#include <QVideoSink>

#include <cstring>
#include <vector>

extern "C" {
#include "qrcodegen.h"
}

// Test-only helper: renders QR codes into synthetic NV12 video frames and
// pushes them into a QVideoSink (e.g. VideoOutput.videoSink), so the camera →
// FrameTap → QrScanner pipeline can be tested without a camera.
class FakeVideoSource : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    // One code, centered in a width x height frame (0 = just big enough).
    Q_INVOKABLE bool pushQr(QObject* sink, const QString& text, int width = 0, int height = 0)
    {
        auto qr = render(text, 6);
        if (qr.size == 0)
            return false;
        const int w = width > 0 ? width : qr.size + 64;
        const int h = height > 0 ? height : qr.size + 64;
        Luma img(w, h, 255);
        img.paste(qr, (w - qr.size) / 2, (h - qr.size) / 2);
        return push(sink, img);
    }

    // One code with its top-left corner at (x, y) in a width x height frame.
    Q_INVOKABLE bool pushQrAt(QObject* sink, const QString& text, int x, int y,
                              int width, int height)
    {
        auto qr = render(text, 4);
        if (qr.size == 0)
            return false;
        Luma img(width, height, 255);
        img.paste(qr, x, y);
        return push(sink, img);
    }

    // Two codes side by side, together centered in a width x height frame.
    Q_INVOKABLE bool pushTwoQrs(QObject* sink, const QString& left, const QString& right,
                                int width, int height)
    {
        auto a = render(left, 4);
        auto b = render(right, 4);
        if (a.size == 0 || b.size == 0)
            return false;
        const int gap = 16;
        const int x0 = (width - a.size - gap - b.size) / 2;
        Luma img(width, height, 255);
        img.paste(a, x0, (height - a.size) / 2);
        img.paste(b, x0 + a.size + gap, (height - b.size) / 2);
        return push(sink, img);
    }

    // As pushQrAt, in a frame shown rotated `rotation` degrees clockwise
    // (QVideoFrame::setRotation), as phone cameras deliver them. x, y: raw pixels.
    Q_INVOKABLE bool pushQrAtRotated(QObject* sink, const QString& text, int x, int y,
                                     int width, int height, int rotation)
    {
        auto qr = render(text, 4);
        if (qr.size == 0)
            return false;
        Luma img(width, height, 255);
        img.paste(qr, x, y);
        return push(sink, img, rotation);
    }

    // A white frame: sets the preview geometry without showing a code.
    Q_INVOKABLE bool pushBlank(QObject* sink, int width, int height, int rotation = 0)
    {
        return push(sink, Luma(width, height, 255), rotation);
    }

    // A large, noisy frame with a code inside: slow enough to decode that a test
    // can act (hide/close the scanner) while the decode is still running.
    Q_INVOKABLE bool pushSlowQr(QObject* sink, const QString& text)
    {
        auto qr = render(text, 6);
        if (qr.size == 0)
            return false;
        const int side = 2600;
        Luma img(side, side, 0);
        unsigned s = 5;
        for (auto& p : img.data) {
            s ^= s << 13; s ^= s >> 17; s ^= s << 5; // xorshift32 noise
            p = static_cast<unsigned char>(s);
        }
        img.paste(qr, side / 2, side / 2);
        return push(sink, img);
    }

private:
    struct Luma {
        int w = 0, h = 0, size = 0; // size: square images (rendered codes)
        std::vector<unsigned char> data;
        Luma() = default;
        Luma(int width, int height, unsigned char fill)
            : w(width), h(height), data(static_cast<size_t>(width) * height, fill) {}
        void paste(const Luma& src, int x0, int y0)
        {
            for (int y = 0; y < src.h && y0 + y < h; ++y)
                for (int x = 0; x < src.w && x0 + x < w; ++x)
                    data[(y0 + y) * w + x0 + x] = src.data[y * src.w + x];
        }
    };

    static Luma render(const QString& text, int scale)
    {
        std::vector<uint8_t> qr(qrcodegen_BUFFER_LEN_MAX), tmp(qrcodegen_BUFFER_LEN_MAX);
        const QByteArray utf8 = text.toUtf8();
        if (!qrcodegen_encodeText(utf8.constData(), tmp.data(), qr.data(), qrcodegen_Ecc_MEDIUM,
                                  qrcodegen_VERSION_MIN, qrcodegen_VERSION_MAX,
                                  qrcodegen_Mask_AUTO, true))
            return {};
        const int modules = qrcodegen_getSize(qr.data());
        const int quiet = 4;
        const int side = (modules + 2 * quiet) * scale;
        Luma img(side, side, 255);
        img.size = side;
        for (int my = 0; my < modules; ++my)
            for (int mx = 0; mx < modules; ++mx)
                if (qrcodegen_getModule(qr.data(), mx, my))
                    for (int dy = 0; dy < scale; ++dy)
                        std::memset(&img.data[((my + quiet) * scale + dy) * side + (mx + quiet) * scale],
                                    0, scale);
        return img;
    }

    static bool push(QObject* sinkObject, const Luma& img, int rotation = 0)
    {
        auto* sink = qobject_cast<QVideoSink*>(sinkObject);
        if (!sink)
            return false;
        QVideoFrame frame(QVideoFrameFormat(QSize(img.w, img.h), QVideoFrameFormat::Format_NV12));
        if (!frame.map(QVideoFrame::WriteOnly))
            return false;
        for (int y = 0; y < img.h; ++y)
            std::memcpy(frame.bits(0) + y * frame.bytesPerLine(0), &img.data[y * img.w], img.w);
        std::memset(frame.bits(1), 128, frame.mappedBytes(1)); // neutral chroma
        frame.unmap();
        frame.setRotation(QtVideo::Rotation(rotation));
        sink->setVideoFrame(frame);
        return true;
    }
};
