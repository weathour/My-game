from __future__ import annotations

import hashlib
import os
import sys
import tempfile
import unittest
import wave
from pathlib import Path
from unittest.mock import patch

import numpy as np
from PySide6.QtCore import QCoreApplication, QEventLoop, QTimer
from PySide6.QtMultimedia import QAudio, QAudioFormat, QMediaDevices

ROOT = Path(__file__).resolve().parents[3]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.rhythm_tester import audio  # noqa: E402


_QT_APP: QCoreApplication | None = None


def ensure_qt_app() -> QCoreApplication:
    global _QT_APP
    if _QT_APP is None:
        _QT_APP = QCoreApplication.instance() or QCoreApplication(sys.argv)
    return _QT_APP


class FakeSignal:
    def __init__(self) -> None:
        self.slots = []

    def connect(self, slot) -> None:
        self.slots.append(slot)


class FakeDevice:
    def __init__(self, *, null: bool = False, supports_format: bool = True) -> None:
        self._null = null
        self._supports_format = supports_format

    def isNull(self) -> bool:
        return self._null

    def isFormatSupported(self, _format) -> bool:
        return self._supports_format


def fake_media_devices(device: FakeDevice):
    class FakeMediaDevices:
        @staticmethod
        def defaultAudioOutput():
            return device
    return FakeMediaDevices


class FakeSink:
    def __init__(self, *_args) -> None:
        self.stateChanged = FakeSignal()
        self._error = QAudio.Error.NoError
        self._processed_usec = 0
        self._volume = 1.0
        self._state = QAudio.State.StoppedState
        self.buffer = None
        self.requested_buffer_bytes = None
        self.buffer_bytes_requested_at_start = None
        self.actual_buffer_bytes = audio.REQUESTED_AUDIO_BUFFER_BYTES
        self.stopped = False
        self.reset_called = False
        self.suspended = False
        self.resumed = False
        self.deleted = False

    def setVolume(self, volume: float) -> None:
        self._volume = volume

    def setBufferSize(self, size: int) -> None:
        self.requested_buffer_bytes = size

    def bufferSize(self) -> int:
        return self.actual_buffer_bytes

    def start(self, buffer) -> None:
        self.buffer = buffer
        self.buffer_bytes_requested_at_start = self.requested_buffer_bytes
        self._state = QAudio.State.ActiveState

    def processedUSecs(self) -> int:
        return self._processed_usec

    def error(self):
        return self._error

    def suspend(self) -> None:
        self.suspended = True
        self._state = QAudio.State.SuspendedState

    def resume(self) -> None:
        self.resumed = True
        self._state = QAudio.State.ActiveState

    def stop(self) -> None:
        self.stopped = True
        self._state = QAudio.State.StoppedState

    def reset(self) -> None:
        self.reset_called = True
        self._state = QAudio.State.StoppedState

    def deleteLater(self) -> None:
        self.deleted = True


def decoded(pcm: np.ndarray, path: Path | None = None) -> audio.DecodedAudio:
    pcm = np.asarray(pcm, dtype=np.int16).reshape((-1, 2))
    return audio.DecodedAudio(path=path or Path("synthetic.wav"), pcm=pcm,
                              sample_rate=audio.SAMPLE_RATE,
                              duration_sec=len(pcm) / audio.SAMPLE_RATE,
                              sha256="a" * 64)


class DecodeTests(unittest.TestCase):
    def test_decode_audio_returns_stereo_48k_pcm_and_source_hash(self) -> None:
        source_pcm = np.column_stack([
            np.arange(4800, dtype=np.int16) - 2400,
            2400 - np.arange(4800, dtype=np.int16),
        ]).astype(np.int16)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "short.wav"
            with wave.open(str(path), "wb") as wav:
                wav.setnchannels(2)
                wav.setsampwidth(2)
                wav.setframerate(48_000)
                wav.writeframes(source_pcm.astype("<i2").tobytes())
            expected_hash = hashlib.sha256(path.read_bytes()).hexdigest()
            result = audio.decode_audio(path)
        self.assertEqual(result.sample_rate, 48_000)
        self.assertEqual(result.pcm.dtype, np.int16)
        self.assertEqual(result.pcm.shape, (4800, 2))
        self.assertAlmostEqual(result.duration_sec, 0.1, places=6)
        self.assertEqual(result.sha256, expected_hash)

    def test_decode_errors_are_explicit(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "missing.ogg"
            with self.assertRaisesRegex(RuntimeError, "does not exist"):
                audio.decode_audio(missing)
            bad = Path(directory) / "bad.ogg"
            bad.write_text("not audio", encoding="utf-8")
            with patch.object(audio.shutil, "which", return_value=None):
                with self.assertRaisesRegex(RuntimeError, "ffmpeg was not found"):
                    audio.decode_audio(bad)
            with patch.object(audio.shutil, "which", return_value="/usr/bin/ffmpeg"):
                with self.assertRaisesRegex(RuntimeError, "could not decode"):
                    audio.decode_audio(bad)


class ClickMixTests(unittest.TestCase):
    def test_click_changes_only_its_sample_regions_and_disabled_is_bit_exact(self) -> None:
        pcm = np.zeros((6000, 2), dtype=np.int16)
        enabled = audio.mix_clicks_pcm(pcm, 48_000, [0.010, 0.050, -0.5, 2.0], True, 0.05)
        off = audio.mix_clicks_pcm(pcm, 48_000, [0.010, 0.050], False, 0.05)
        np.testing.assert_array_equal(off, pcm)
        changed = np.any(enabled != pcm, axis=1)
        allowed = np.zeros(len(pcm), dtype=bool)
        tone_frames = round(audio.CLICK_DURATION_SECONDS * 48_000)
        for t in (0.010, 0.050):
            start = round(t * 48_000)
            allowed[start:start + tone_frames] = True
        self.assertTrue(np.any(changed))
        self.assertFalse(np.any(changed & ~allowed))

    def test_click_headroom_never_clips_or_changes_outside_click(self) -> None:
        pcm = np.full((4800, 2), 32_000, dtype=np.int16)
        mixed = audio.mix_clicks_pcm(pcm, 48_000, [0.020], True, 0.8)
        self.assertLessEqual(int(mixed.max()), 32767)
        self.assertGreaterEqual(int(mixed.min()), -32768)
        start = round(0.020 * 48_000)
        end = start + round(audio.CLICK_DURATION_SECONDS * 48_000)
        np.testing.assert_array_equal(mixed[:start], pcm[:start])
        np.testing.assert_array_equal(mixed[end:], pcm[end:])

    def test_click_input_validation(self) -> None:
        pcm = np.zeros((10, 2), dtype=np.int16)
        with self.assertRaisesRegex(ValueError, "finite"):
            audio.mix_clicks_pcm(pcm, 48_000, [float("nan")], True)
        with self.assertRaisesRegex(ValueError, "between 0 and 1"):
            audio.mix_clicks_pcm(pcm, 48_000, [], True, 1.1)


class TransportTests(unittest.TestCase):
    def setUp(self) -> None:
        ensure_qt_app()
        self.sinks: list[FakeSink] = []

        def make_sink(*args):
            sink = FakeSink(*args)
            self.sinks.append(sink)
            return sink

        self.device_patch = patch.object(audio, "QMediaDevices", fake_media_devices(FakeDevice()))
        self.sink_patch = patch.object(audio, "QAudioSink", side_effect=make_sink)
        self.device_patch.start()
        self.sink_patch.start()
        self.addCleanup(self.device_patch.stop)
        self.addCleanup(self.sink_patch.stop)
        self.transport = audio.AudioTransport()
        self.transport.load(decoded(np.zeros((144_000, 2), dtype=np.int16)))

    def tearDown(self) -> None:
        self.transport.close()

    def test_seek_pause_resume_uses_processed_pcm_and_preserves_state(self) -> None:
        self.transport.play()
        first = self.sinks[-1]
        self.assertEqual(first.requested_buffer_bytes, 9_600)
        self.assertEqual(first.buffer_bytes_requested_at_start, 9_600)
        self.assertEqual(self.transport.actual_buffer_bytes, 9_600)
        first._processed_usec = 250_000
        self.assertAlmostEqual(self.transport.position_seconds(), 0.25, places=4)

        self.transport.pause()
        self.assertEqual(self.transport.state, "paused")
        first._processed_usec = 600_000  # Simulate backend counter movement during suspend.
        self.assertAlmostEqual(self.transport.position_seconds(), 0.25, places=4)

        self.transport.resume()
        self.assertEqual(self.transport.state, "playing")
        self.assertTrue(first.resumed)
        self.assertAlmostEqual(self.transport.position_seconds(), 0.25, places=4)
        first._processed_usec = 800_000
        self.assertAlmostEqual(self.transport.position_seconds(), 0.45, places=4)

        self.transport.seek(1.0)
        self.assertEqual(self.transport.state, "playing")
        self.assertTrue(first.reset_called)
        self.assertFalse(first.stopped)
        self.assertAlmostEqual(self.transport.position_seconds(), 1.0, places=4)
        seek_sink = self.sinks[-1]
        self.assertEqual(seek_sink.buffer.pos(), 48_000 * 4)
        seek_sink._processed_usec = 100_000
        self.assertAlmostEqual(self.transport.position_seconds(), 1.1, places=4)

        self.transport.pause()
        self.transport.seek(0.5)
        self.assertEqual(self.transport.state, "paused")
        self.assertAlmostEqual(self.transport.position_seconds(), 0.5, places=4)
        self.transport.resume()
        self.assertEqual(self.transport.state, "playing")
        self.assertAlmostEqual(self.transport.position_seconds(), 0.5, places=4)
        self.transport.stop()
        self.assertEqual(self.transport.state, "stopped")
        self.assertEqual(self.transport.position_seconds(), 0.0)
        self.assertTrue(seek_sink.reset_called)
        self.assertFalse(seek_sink.stopped)

    def test_click_rebuild_preserves_position_and_play_state(self) -> None:
        self.transport.play()
        sink = self.sinks[-1]
        sink._processed_usec = 125_000
        self.transport.set_clicks([0.2, 0.5], True, 0.05)
        self.assertEqual(self.transport.state, "playing")
        self.assertTrue(sink.stopped)
        self.assertFalse(sink.reset_called)
        self.assertAlmostEqual(self.transport.position_seconds(), 0.125, places=4)
        new_sink = self.sinks[-1]
        self.assertEqual(new_sink.buffer.pos(), round(0.125 * 48_000) * 4)
        self.assertTrue(np.any(self.transport._mixed_pcm != self.transport._base_pcm))

        self.transport.pause()
        paused_pos = self.transport.position_seconds()
        self.transport.set_clicks([0.25], False)
        self.assertEqual(self.transport.state, "paused")
        self.assertAlmostEqual(self.transport.position_seconds(), paused_pos, places=4)
        np.testing.assert_array_equal(self.transport._mixed_pcm, self.transport._base_pcm)

    def test_volume_is_clamped_and_applied_to_active_sink(self) -> None:
        self.transport.play()
        sink = self.sinks[-1]
        self.transport.set_volume(0.2)
        self.assertEqual(sink._volume, 0.2)
        self.transport.set_volume(2.0)
        self.assertEqual(sink._volume, 1.0)

    def test_reload_and_close_reset_old_backend_queues(self) -> None:
        self.transport.play()
        first = self.sinks[-1]
        self.transport.load(decoded(np.zeros((96_000, 2), dtype=np.int16)))
        self.assertTrue(first.reset_called)
        self.assertFalse(first.stopped)
        self.transport.play()
        second = self.sinks[-1]
        self.transport.close()
        self.assertTrue(second.reset_called)
        self.assertFalse(second.stopped)

    def test_finish_signal_state_and_short_file_boundaries(self) -> None:
        short = decoded(np.zeros((2400, 2), dtype=np.int16))
        self.transport.load(short, click_times=[0.0, short.duration_sec - 1 / 48_000, short.duration_sec, 10.0], click_enabled=True)
        self.assertEqual(self.transport._mixed_pcm.shape, short.pcm.shape)
        self.transport.seek(-1.0)
        self.assertEqual(self.transport.position_seconds(), 0.0)
        self.transport.seek(99.0)
        self.assertAlmostEqual(self.transport.position_seconds(), short.duration_sec, places=6)
        finished: list[bool] = []
        self.transport.finished.connect(lambda: finished.append(True))
        self.transport.play(start_seconds=short.duration_sec)
        self.assertEqual(self.transport.state, "stopped")
        self.assertEqual(self.transport.position_seconds(), short.duration_sec)
        self.assertEqual(finished, [True])

        self.transport.seek(0.0)
        self.transport.play()
        sink = self.sinks[-1]
        # Simulate the static QBuffer reaching EOF before the final queued PCM drains.
        self.transport._buffer.seek(self.transport._buffer.size())
        sink._processed_usec = 50_000
        self.transport._handle_sink_state(sink, QAudio.State.IdleState)
        self.assertEqual(self.transport.state, "stopped")
        self.assertAlmostEqual(self.transport.position_seconds(), short.duration_sec, places=6)
        self.assertEqual(finished, [True, True])
        self.assertTrue(sink.stopped)
        self.assertFalse(sink.reset_called)

    def test_midstream_idle_or_underrun_does_not_finish_or_clear_sink(self) -> None:
        errors: list[str] = []
        finished: list[bool] = []
        self.transport.error.connect(errors.append)
        self.transport.finished.connect(lambda: finished.append(True))
        self.transport.play()
        sink = self.sinks[-1]
        sink._processed_usec = 125_000

        self.transport._handle_sink_state(sink, QAudio.State.IdleState)
        self.assertEqual(self.transport.state, "playing")
        self.assertIs(self.transport._sink, sink)
        self.assertFalse(sink.stopped)
        self.assertFalse(sink.reset_called)
        self.assertEqual(finished, [])

        sink._error = QAudio.Error.UnderrunError
        self.transport._handle_sink_state(sink, QAudio.State.IdleState)
        self.assertEqual(self.transport.state, "playing")
        self.assertIs(self.transport._sink, sink)
        self.assertEqual(errors, [])
        self.assertEqual(finished, [])

    def test_source_eof_waits_for_processed_tail_before_draining(self) -> None:
        short = decoded(np.zeros((2400, 2), dtype=np.int16))
        self.transport.load(short)
        self.transport.play()
        sink = self.sinks[-1]
        self.transport._buffer.seek(self.transport._buffer.size())
        sink._processed_usec = 25_000

        self.transport._handle_sink_state(sink, QAudio.State.IdleState)
        self.assertEqual(self.transport.state, "playing")
        self.assertIs(self.transport._sink, sink)
        self.assertTrue(self.transport._completion_timer.isActive())
        self.assertFalse(sink.stopped)

        finished: list[bool] = []
        loop = QEventLoop()
        self.transport.finished.connect(lambda: (finished.append(True), loop.quit()))
        QTimer.singleShot(20, lambda: setattr(sink, "_processed_usec", 50_000))
        QTimer.singleShot(200, loop.quit)
        loop.exec()
        self.assertEqual(self.transport.state, "stopped")
        self.assertAlmostEqual(self.transport.position_seconds(), short.duration_sec, places=6)
        self.assertEqual(finished, [True])
        self.assertTrue(sink.stopped)
        self.assertFalse(sink.reset_called)

    def test_fatal_sink_error_is_reported_and_clears_backend(self) -> None:
        errors: list[str] = []
        self.transport.error.connect(errors.append)
        self.transport.play()
        sink = self.sinks[-1]
        sink._error = QAudio.Error.FatalError
        self.transport._handle_sink_state(sink, QAudio.State.IdleState)
        self.assertEqual(self.transport.state, "ready")
        self.assertIsNone(self.transport._sink)
        self.assertTrue(sink.reset_called)
        self.assertIn("Audio output failed", errors[-1])

    def test_stopped_sink_with_underrun_reports_and_clears_backend(self) -> None:
        errors: list[str] = []
        self.transport.error.connect(errors.append)
        self.transport.play()
        sink = self.sinks[-1]
        sink._processed_usec = 250_000
        sink._error = QAudio.Error.UnderrunError
        self.transport._handle_sink_state(sink, QAudio.State.StoppedState)
        self.assertEqual(self.transport.state, "ready")
        self.assertIsNone(self.transport._sink)
        self.assertTrue(sink.reset_called)
        self.assertIn("stopped before playback completed", errors[-1])

    def test_no_default_or_unsupported_device_is_reported(self) -> None:
        errors: list[str] = []
        self.transport.error.connect(errors.append)
        with patch.object(audio, "QMediaDevices", fake_media_devices(FakeDevice(null=True))):
            self.transport.play()
        self.assertEqual(self.transport.state, "ready")
        self.assertIn("No default audio output", errors[-1])
        with patch.object(audio, "QMediaDevices", fake_media_devices(FakeDevice(supports_format=False))):
            self.transport.play()
        self.assertIn("does not support 48 kHz stereo PCM16", errors[-1])
        self.assertEqual(len(self.sinks), 0)


@unittest.skipUnless(os.environ.get("RHYTHM_TESTER_LIVE_AUDIO") == "1",
                     "set RHYTHM_TESTER_LIVE_AUDIO=1 to run the low-volume hardware smoke")
class LiveAudioDeviceTests(unittest.TestCase):
    def test_default_sink_processed_position_and_transport_controls(self) -> None:
        app = ensure_qt_app()
        device = QMediaDevices.defaultAudioOutput()
        self.assertFalse(device.isNull(), "No default audio output device")
        fmt = QAudioFormat()
        fmt.setSampleRate(48_000)
        fmt.setChannelCount(2)
        fmt.setSampleFormat(QAudioFormat.SampleFormat.Int16)
        self.assertTrue(device.isFormatSupported(fmt), device.description())

        frames = 48_000 * 2
        t = np.arange(frames, dtype=np.float64) / 48_000
        mono = np.rint(1800 * np.sin(2 * np.pi * 330 * t)).astype(np.int16)
        pcm = np.column_stack((mono, mono))
        transport = audio.AudioTransport()
        errors: list[str] = []
        finished: list[bool] = []
        transport.error.connect(errors.append)
        transport.finished.connect(lambda: finished.append(True))
        transport.load(decoded(pcm))
        transport.set_volume(0.015)

        def wait_ms(milliseconds: int) -> None:
            loop = QEventLoop()
            QTimer.singleShot(milliseconds, loop.quit)
            loop.exec()

        try:
            print(f"LIVE_AUDIO_DEVICE {device.description()} id={bytes(device.id()).decode(errors='replace')}")
            print(f"LIVE_AUDIO_PREFERRED_FORMAT valid={device.preferredFormat().isValid()} "
                  f"sample={device.preferredFormat().sampleFormat()}")
            transport.play(start_seconds=0.25)
            self.assertEqual(transport.state, "playing", errors)
            self.assertGreater(transport.actual_buffer_bytes, 0)
            print(f"LIVE_AUDIO_BUFFER requested_bytes={audio.REQUESTED_AUDIO_BUFFER_BYTES} "
                  f"actual_bytes_after_start={transport.actual_buffer_bytes} "
                  f"actual_ms={transport.actual_buffer_bytes / (48_000 * 4) * 1000:.3f}")
            p0 = transport.position_seconds()
            wait_ms(250)
            p1 = transport.position_seconds()
            print(f"LIVE_AUDIO_PLAY {p0:.6f}->{p1:.6f} over250ms")
            self.assertGreater(p1 - p0, 0.08)

            transport.pause()
            paused = transport.position_seconds()
            wait_ms(180)
            self.assertEqual(transport.position_seconds(), paused)
            self.assertEqual(transport.state, "paused")

            transport.resume()
            resumed = transport.position_seconds()
            wait_ms(160)
            self.assertGreater(transport.position_seconds(), resumed + 0.04)

            transport.seek(0.65)
            sought = transport.position_seconds()
            print(f"LIVE_AUDIO_BUFFER_AFTER_SEEK actual_bytes={transport.actual_buffer_bytes}")
            wait_ms(140)
            self.assertAlmostEqual(sought, 0.65, delta=0.02)
            self.assertGreater(transport.position_seconds(), sought + 0.03)

            before_mix = transport.position_seconds()
            transport.set_clicks([0.8, 1.0, 1.2, 1.4], True, 0.035)
            after_mix = transport.position_seconds()
            self.assertLess(abs(after_mix - before_mix), 0.03)
            self.assertTrue(np.any(transport._mixed_pcm != transport._base_pcm))

            transport.seek(1.75)
            wait_ms(500)
            self.assertEqual(transport.state, "stopped")
            self.assertAlmostEqual(transport.position_seconds(), transport.duration_seconds, delta=1 / 48_000)
            self.assertEqual(finished, [True])
            self.assertEqual(errors, [])
            transport.stop()
            self.assertEqual(transport.position_seconds(), 0.0)
            app.processEvents()
        finally:
            transport.stop()
            transport.close()
            app.processEvents()


if __name__ == "__main__":
    unittest.main()
