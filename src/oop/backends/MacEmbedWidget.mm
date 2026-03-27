#include "MacEmbedWidget.h"

#ifdef Q_OS_MACOS

#include "../EmbedControlChannel.h"
#include <QApplication>
#include <QJsonObject>
#include <QDebug>
#include <QTimer>
#include <QResizeEvent>
#include <QShowEvent>
#include <QHideEvent>
#include <QEvent>

// Timer intervals (ms)
static constexpr int kFastInterval = 4;    // ~250 Hz during active movement
static constexpr int kIdleInterval = 200;  // Low CPU when nothing is moving
static constexpr int kIdleThreshold = 10;  // Ticks without movement before going idle

MacEmbedWidget::MacEmbedWidget(EmbedControlChannel* channel, QWidget* parent)
    : OopEmbedWidget(channel, parent)
{
    // Transparent placeholder — prevents flickering when the child overlay
    // lags behind during window drags. Without this the user would see the
    // dark placeholder flash between child positions.
    setAttribute(Qt::WA_TranslucentBackground);
    setStyleSheet(QStringLiteral("background-color: transparent;"));

    // Adaptive timer: fast during movement, slow when idle.
    m_positionTimer = new QTimer(this);
    m_positionTimer->setInterval(kFastInterval);
    connect(m_positionTimer, &QTimer::timeout, this, &MacEmbedWidget::sendPositionUpdate);

    // Track application activation state: hide child OOP windows when the
    // user switches to another app, show them when switching back.
    connect(qApp, &QApplication::applicationStateChanged, this,
            [this](Qt::ApplicationState state) {
                if (!m_embedded || !m_channel || !m_channel->isConnected())
                    return;
                if (state == Qt::ApplicationActive) {
                    if (isVisible()) {
                        sendPositionUpdate();
                        m_channel->sendVisibility(true);
                        m_positionTimer->start();
                    }
                } else if (state == Qt::ApplicationInactive) {
                    m_positionTimer->stop();
                    m_channel->sendVisibility(false);
                }
            });
}

MacEmbedWidget::~MacEmbedWidget()
{
    if (m_positionTimer)
        m_positionTimer->stop();

    // Tell the child to hide before we go away
    if (m_channel && m_channel->isConnected())
        m_channel->sendVisibility(false);
}

bool MacEmbedWidget::embedSurface(const QJsonObject& handleData)
{
    bool ok = false;
    m_childWinId = handleData.value("winId").toVariant().toLongLong(&ok);
    if (!ok || m_childWinId == 0) {
        qWarning() << "MacEmbedWidget: invalid winId in surface handle";
        return false;
    }

    m_embedded = true;
    qDebug() << "MacEmbedWidget: overlay-tracking macOS child window" << m_childWinId;

    // If we're already visible, start tracking immediately
    if (isVisible()) {
        qDebug() << "MacEmbedWidget: already visible, sending initial position";
        sendPositionUpdate();
        m_channel->sendVisibility(true);
        m_positionTimer->start();
    } else {
        qDebug() << "MacEmbedWidget: not visible yet, waiting for showEvent";
        // Fallback: in case showEvent doesn't fire (e.g. MDI quirk),
        // schedule a deferred check.
        QTimer::singleShot(500, this, [this]() {
            if (m_embedded && isVisible() && !m_positionTimer->isActive()) {
                qDebug() << "MacEmbedWidget: deferred start of position tracking";
                sendPositionUpdate();
                m_channel->sendVisibility(true);
                m_positionTimer->start();
            }
        });
    }

    return true;
}

void MacEmbedWidget::sendPositionUpdate()
{
    if (!m_channel || !m_channel->isConnected() || !m_embedded)
        return;

    QPoint globalPos = mapToGlobal(QPoint(0, 0));
    QSize currentSize = size();

    bool moved = (globalPos != m_lastGlobalPos);
    bool resized = (currentSize != m_lastSize);

    if (moved || resized) {
        // Velocity prediction: extrapolate one step ahead to compensate
        // for the IPC round-trip latency. This makes the child window
        // appear to track the parent more closely during drags.
        QPoint velocity = globalPos - m_lastGlobalPos;
        QPoint predicted = globalPos + velocity;

        m_prevGlobalPos = m_lastGlobalPos;
        m_lastGlobalPos = globalPos;
        m_lastSize = currentSize;

        m_channel->sendReposition(predicted.x(), predicted.y(),
                                   currentSize.width(), currentSize.height());

        // Position is changing — keep the timer fast
        m_positionTimer->setInterval(kFastInterval);
        m_idleCount = 0;
    } else {
        // Position is stable — gradually slow down to save CPU
        if (++m_idleCount >= kIdleThreshold) {
            m_positionTimer->setInterval(kIdleInterval);
        }
    }
}

void MacEmbedWidget::resizeEvent(QResizeEvent* event)
{
    OopEmbedWidget::resizeEvent(event);
    // Wake up the fast timer on resize
    m_positionTimer->setInterval(kFastInterval);
    m_idleCount = 0;
    sendPositionUpdate();
}

void MacEmbedWidget::showEvent(QShowEvent* event)
{
    QWidget::showEvent(event);
    qDebug() << "MacEmbedWidget: showEvent, embedded:" << m_embedded
             << "channelConnected:" << (m_channel && m_channel->isConnected());
    if (m_embedded) {
        sendPositionUpdate();
        if (m_channel) m_channel->sendVisibility(true);
        m_positionTimer->start();
    }
}

void MacEmbedWidget::hideEvent(QHideEvent* event)
{
    QWidget::hideEvent(event);
    qDebug() << "MacEmbedWidget: hideEvent";
    m_positionTimer->stop();
    if (m_channel && m_channel->isConnected())
        m_channel->sendVisibility(false);
}

bool MacEmbedWidget::event(QEvent* event)
{
    // Also catch Move events (in case layout/MDI triggers them)
    if (event->type() == QEvent::Move) {
        m_positionTimer->setInterval(kFastInterval);
        m_idleCount = 0;
        sendPositionUpdate();
    }
    return OopEmbedWidget::event(event);
}

#endif // Q_OS_MACOS
