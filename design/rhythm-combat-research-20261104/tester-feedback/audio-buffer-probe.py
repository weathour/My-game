from __future__ import annotations
import math, time
import numpy as np
from PySide6.QtCore import QByteArray, QBuffer, QIODevice, QTimer
from PySide6.QtMultimedia import QAudioFormat, QAudioSink, QMediaDevices
from PySide6.QtWidgets import QApplication

RATE = 48_000
FRAMES = RATE * 12
app = QApplication([])
device = QMediaDevices.defaultAudioOutput()
fmt = QAudioFormat(); fmt.setSampleRate(RATE); fmt.setChannelCount(2); fmt.setSampleFormat(QAudioFormat.SampleFormat.Int16)
if device is None or device.isNull():
    raise SystemExit('no default output')
print('device=', device.description(), 'id=', device.id())
print('preferred=', device.preferredFormat().sampleRate(), device.preferredFormat().channelCount(), device.preferredFormat().sampleFormat())
print('requested_supported=', device.isFormatSupported(fmt))
# Quiet synthetic tone, volume kept at 0.02.
t = np.arange(FRAMES, dtype=np.float64) / RATE
wave = np.rint(np.sin(2 * math.pi * 220 * t) * 6000).astype('<i2')
pcm = np.column_stack((wave, wave)).tobytes()
buf = QBuffer(); buf.setData(QByteArray(pcm)); buf.open(QIODevice.OpenModeFlag.ReadOnly)
sink = QAudioSink(device, fmt); sink.setVolume(0.02)
print('pre_start_buffer_bytes=', sink.bufferSize(), 'frames=', sink.bufferSize() // 4)
sink.start(buf)
if sink.error().value != 0:
    raise SystemExit(f'start error={sink.error()} state={sink.state()}')
start = time.monotonic()
rows=[]
def sample(tag):
    now=time.monotonic(); elapsed=now-start
    row=(tag, round(elapsed,4), sink.elapsedUSecs(), sink.processedUSecs(), sink.bufferSize(), sink.bufferSize()//4, sink.bytesFree(), sink.state().value, sink.error().value)
    rows.append(row)
    print('sample=', *row)

def stop():
    sink.reset(); buf.close(); app.quit()

def suspend():
    sample('pre_suspend')
    sink.suspend()
    sample('suspended_immediate')
    QTimer.singleShot(250, resume)
def resume():
    sample('suspended_250ms')
    sink.resume()
    sample('resumed_immediate')
    QTimer.singleShot(850, lambda: (sample('resumed_850ms'), stop()))
QTimer.singleShot(100, lambda: (sample('active_100ms'), QTimer.singleShot(900, suspend)))
QTimer.singleShot(2500, stop)
app.exec()
