#pragma once

#include <qqmlintegration.h>
#include <qtimer.h>

#include <algorithm>
#include <cstddef>

#include "service.hpp"

namespace caelestia::services {

class AudioProcessor : public QObject {
    Q_OBJECT

public:
    explicit AudioProcessor(QObject* parent = nullptr);
    ~AudioProcessor();

    void init();

public slots:
    void start();
    void stop();

protected:
    virtual void process() = 0;

    // A captured chunk is digital silence whenever nothing is playing, which is most of a
    // desktop's life, and every analysis here is a no-op on silence. Knowing this is what lets a
    // processor skip its work without changing what it reports.
    template <typename Sample> [[nodiscard]] static bool isSilent(const Sample* samples, std::size_t count) {
        return count == 0 || std::all_of(samples, samples + count, [](Sample sample) {
            return sample == Sample(0);
        });
    }

private:
    QTimer* m_timer = nullptr;
};

class AudioProvider : public Service {
    Q_OBJECT

public:
    explicit AudioProvider(QObject* parent = nullptr);
    ~AudioProvider();

protected:
    AudioProcessor* m_processor;

    void init();

private:
    QThread* m_thread;

    void start() override;
    void stop() override;
};

} // namespace caelestia::services
