#include "MonitorQtOutput.h"

#include <stdio.h>
#include <stdlib.h>

std::weak_ptr<QString> MonitorQtOutput::m_qtMessageOutputForSharing;
std::mutex MonitorQtOutput::m_mutex;
QtMessageHandler MonitorQtOutput::m_previousHandler = nullptr;


MonitorQtOutput::MonitorQtOutput()
{
    // Ensure only one instance registers a handler
    // Warning: don't call QT's logger functions inside the critical section
    std::unique_lock<std::mutex> localLock(m_mutex);
    auto globalMsgOut = m_qtMessageOutputForSharing.lock();
    auto prev = qInstallMessageHandler(qtMessageOutput);
    if(prev != qtMessageOutput)
        m_previousHandler = prev;
    if(!globalMsgOut) {
        m_thisMessageOutput = std::make_shared<QString>();
        m_qtMessageOutputForSharing = m_thisMessageOutput;
    }
    else {
        m_thisMessageOutput = globalMsgOut;
        m_start = m_thisMessageOutput->length();
    }
}

MonitorQtOutput::~MonitorQtOutput()
{
    std::unique_lock<std::mutex> localLock(m_mutex);
    if(m_thisMessageOutput.use_count() == 1) {
        // Last instance, restore the handler it replaced (QtTest's, so ignoreWarning keeps working)
        auto current = qInstallMessageHandler(m_previousHandler);
        if(current != qtMessageOutput)
            qInstallMessageHandler(current);
        m_thisMessageOutput.reset();
    }
}

void
MonitorQtOutput::qtMessageOutput(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    std::unique_lock<std::mutex> localLock(m_mutex);
    auto globalMsgOut = m_qtMessageOutputForSharing.lock();
    assert(globalMsgOut != nullptr);
    globalMsgOut->append(msg + '\n');
    // Also reproduce the default output
    m_previousHandler(type, context, msg);
}

QString
MonitorQtOutput::qtOuput()
{
    std::unique_lock<std::mutex> localLock(m_mutex);
    assert(m_thisMessageOutput->length() >= m_start);
    return m_thisMessageOutput->right(m_thisMessageOutput->length() - m_start);
}

void
MonitorQtOutput::restartCapturing()
{
    std::unique_lock<std::mutex> localLock(m_mutex);
    // Ensure the messageHandler is installed. Foun to be reset at test initializaiton
    auto prev = qInstallMessageHandler(qtMessageOutput);
    if(prev != qtMessageOutput)
        m_previousHandler = prev;
    m_start = m_thisMessageOutput->length();
}
