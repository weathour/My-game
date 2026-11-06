"""Audio decoding, click mixing, and Qt-backed PCM playback for the rhythm tester.

Qt documents QAudioSink.processedUSecs() as audio data processed since start(), while
elapsedUSecs() includes suspend time. The transport freezes a cached frame on pause and
rebases the processed-frame epoch on resume. This tracks Qt-processed PCM, not calibrated
hardware presentation or input latency (see https://doc.qt.io/qt-6/qaudiosink.html).
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import math
from pathlib import Path
import shutil
import subprocess
from typing import Iterable

import numpy as np
from PySide6.QtCore import QByteArray, QBuffer, QIODevice, QObject, QTimer, Signal, Slot
from PySide6.QtMultimedia import QAudio, QAudioFormat, QAudioSink, QMediaDevices


SAMPLE_RATE = 48_000
CHANNELS = 2
SAMPLE_WIDTH_BYTES = 2
BYTES_PER_FRAME = CHANNELS * SAMPLE_WIDTH_BYTES
CLICK_FREQUENCY_HZ = 880.0
CLICK_DURATION_SECONDS = 0.035
REQUESTED_AUDIO_BUFFER_MS = 50
REQUESTED_AUDIO_BUFFER_BYTES = SAMPLE_RATE * BYTES_PER_FRAME * REQUESTED_AUDIO_BUFFER_MS // 1000


def _qt_enum_value(value: object) -> object:
    """Read Qt scoped-enum values without relying on wrapper object identity."""
    return getattr(value, "value", value)


@dataclass(frozen=True)
class DecodedAudio:
    path: Path
    pcm: np.ndarray
    sample_rate: int
    duration_sec: float
    sha256: str


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def decode_audio(path: Path) -> DecodedAudio:
    """Decode the first audio stream to 48 kHz stereo signed PCM16 with ffmpeg.

    Safe to call from a UI worker: this function does not create Qt objects.
    """
    source = Path(path).expanduser()
    if not source.is_file():
        raise RuntimeError(f"Audio file does not exist: {source}")
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise RuntimeError("ffmpeg was not found on PATH; audio cannot be decoded")
    try:
        completed = subprocess.run(
            [ffmpeg, "-nostdin", "-v", "error", "-i", str(source), "-map", "0:a:0",
             "-vn", "-sn", "-dn", "-f", "s16le", "-acodec", "pcm_s16le",
             "-ar", str(SAMPLE_RATE), "-ac", str(CHANNELS), "pipe:1"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
    except OSError as exc:
        raise RuntimeError(f"Could not start ffmpeg: {exc}") from exc
    if completed.returncode != 0:
        details = completed.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(f"ffmpeg could not decode {source}: {details or 'unknown decoding error'}")
    if len(completed.stdout) == 0:
        raise RuntimeError(f"ffmpeg decoded no audio samples from {source}")
    if len(completed.stdout) % BYTES_PER_FRAME:
        raise RuntimeError(f"ffmpeg returned an incomplete stereo PCM frame for {source}")
    pcm = np.frombuffer(completed.stdout, dtype="<i2").reshape((-1, CHANNELS)).copy()
    return DecodedAudio(path=source.resolve(), pcm=pcm, sample_rate=SAMPLE_RATE,
                        duration_sec=len(pcm) / SAMPLE_RATE, sha256=_sha256_file(source))


def mix_clicks_pcm(pcm: np.ndarray, sample_rate: int, click_times: Iterable[float],
                   enabled: bool, click_gain: float = 0.05) -> np.ndarray:
    """Return PCM with a quiet click at each in-range time, preserving all other samples.

    Click headroom is calculated separately for each event and only attenuates that
    click. The underlying music is never globally scaled, and int16 clipping is avoided.
    """
    source = np.asarray(pcm)
    if source.dtype != np.int16 or source.ndim != 2 or source.shape[1] != CHANNELS:
        raise ValueError("pcm must be an (n, 2) int16 array")
    if sample_rate <= 0:
        raise ValueError("sample_rate must be positive")
    if not math.isfinite(click_gain) or click_gain < 0.0 or click_gain > 1.0:
        raise ValueError("click_gain must be finite and between 0 and 1")
    output = np.ascontiguousarray(source).copy()
    if not enabled or click_gain == 0.0 or len(output) == 0:
        return output

    frame_count = len(output)
    tone_frames = max(1, int(round(CLICK_DURATION_SECONDS * sample_rate)))
    tone_t = np.arange(tone_frames, dtype=np.float64) / sample_rate
    envelope = np.exp(-tone_t * 95.0)
    wave = np.sin(2.0 * math.pi * CLICK_FREQUENCY_HZ * tone_t) * envelope
    base_click = wave * (click_gain * 32767.0)

    event_samples: set[int] = set()
    for raw_time in click_times:
        time_sec = float(raw_time)
        if not math.isfinite(time_sec):
            raise ValueError("click times must be finite")
        start = int(round(time_sec * sample_rate))
        if start < 0 or start >= frame_count:
            continue
        event_samples.add(start)
    for start in sorted(event_samples):
        end = min(frame_count, start + tone_frames)
        click = base_click[:end - start]
        original = output[start:end].astype(np.int32)
        safe_scale = 1.0
        positive = click > 0.0
        if np.any(positive):
            headroom = 32767 - original[positive]
            safe_scale = min(safe_scale, float(np.min(headroom / click[positive, None])))
        negative = click < 0.0
        if np.any(negative):
            headroom = -32768 - original[negative]
            safe_scale = min(safe_scale, float(np.min(headroom / click[negative, None])))
        safe_scale = max(0.0, min(1.0, safe_scale))
        addition = np.rint(click * safe_scale).astype(np.int32)[:, None]
        mixed = original + addition
        output[start:end] = np.clip(mixed, -32768, 32767).astype(np.int16)
    return output


class AudioTransport(QObject):
    """PCM transport whose position follows QAudioSink's processed sample time.

    The paused position is cached, and resume rebases the current sink counter to it.
    Position is not a measurement of when audio reached the listener.
    """

    stateChanged = Signal(str)
    error = Signal(str)
    finished = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._state = "empty"
        self._audio: DecodedAudio | None = None
        self._base_pcm = np.empty((0, CHANNELS), dtype=np.int16)
        self._mixed_pcm = np.empty((0, CHANNELS), dtype=np.int16)
        self._click_times: tuple[float, ...] = ()
        self._click_enabled = False
        self._click_gain = 0.05
        self._volume = 1.0
        self._position_frame = 0
        self._paused_frame = 0
        self._epoch_origin_frame = 0
        self._sink: QAudioSink | None = None
        self._buffer: QBuffer | None = None
        self._sink_generation = 0
        self._actual_buffer_bytes = 0
        self._format = self._make_format()
        self._completion_timer = QTimer(self)
        self._completion_timer.setInterval(10)
        self._completion_timer.timeout.connect(self._poll_completion)

    @staticmethod
    def _make_format() -> QAudioFormat:
        fmt = QAudioFormat()
        fmt.setSampleRate(SAMPLE_RATE)
        fmt.setChannelCount(CHANNELS)
        fmt.setSampleFormat(QAudioFormat.SampleFormat.Int16)
        return fmt

    @property
    def state(self) -> str:
        return self._state

    @property
    def duration_seconds(self) -> float:
        return len(self._base_pcm) / SAMPLE_RATE

    @property
    def sample_rate(self) -> int:
        return SAMPLE_RATE

    @property
    def actual_buffer_bytes(self) -> int:
        """Actual QAudioSink ring-buffer size from the most recent start, in bytes."""
        return self._actual_buffer_bytes

    def load(self, audio: DecodedAudio, click_times: Iterable[float] = (),
             click_enabled: bool = False, click_gain: float = 0.05) -> None:
        pcm = np.asarray(audio.pcm)
        if audio.sample_rate != SAMPLE_RATE:
            raise ValueError(f"DecodedAudio must be {SAMPLE_RATE} Hz")
        if pcm.dtype != np.int16 or pcm.ndim != 2 or pcm.shape[1] != CHANNELS:
            raise ValueError("DecodedAudio.pcm must be an (n, 2) int16 array")
        if len(pcm) == 0:
            raise ValueError("DecodedAudio contains no frames")
        if not math.isclose(audio.duration_sec, len(pcm) / SAMPLE_RATE, rel_tol=0.0, abs_tol=1e-6):
            raise ValueError("DecodedAudio.duration_sec does not match its PCM frame count")
        self._discard_backend(drain=False)
        self._audio = audio
        self._base_pcm = np.ascontiguousarray(pcm).copy()
        self._click_times = self._validate_click_times(click_times)
        self._click_enabled = bool(click_enabled)
        self._click_gain = self._validate_click_gain(click_gain)
        self._rebuild_mix()
        self._position_frame = 0
        self._paused_frame = 0
        self._set_state("ready")

    def play(self, start_seconds: float | None = None) -> None:
        if self._audio is None:
            self.error.emit("No audio is loaded.")
            return
        frame_count = len(self._mixed_pcm)
        if start_seconds is not None:
            target = float(start_seconds)
            if not math.isfinite(target):
                raise ValueError("play start time must be finite")
            target = min(self.duration_seconds, max(0.0, target))
            frame = min(frame_count, max(0, int(round(target * SAMPLE_RATE))))
            if self._state == "playing":
                self.seek(target)
                return
            self._discard_backend(drain=False)
            self._position_frame = frame
            self._paused_frame = frame
            if frame >= frame_count:
                self._position_frame = frame_count
                self._set_state("stopped")
                self.finished.emit()
                return
        elif self._state == "playing":
            return
        elif self._state == "paused":
            self.resume()
            return

        start_frame = self._position_frame
        if start_frame >= frame_count:
            start_frame = 0
            self._position_frame = 0
            self._paused_frame = 0
        if not self._start_backend(start_frame):
            return
        self._set_state("playing")

    def pause(self) -> None:
        if self._state != "playing" or self._sink is None:
            return
        self._sink.suspend()
        if _qt_enum_value(self._sink.error()) != _qt_enum_value(QAudio.Error.NoError):
            self._fail_output(f"Could not pause audio output (Qt error {self._sink.error()}).")
            return
        frame = self._current_playback_frame()
        self._paused_frame = frame
        self._position_frame = frame
        self._set_state("paused")

    def resume(self) -> None:
        if self._state != "paused" or self._audio is None:
            return
        if self._sink is None:
            if self._start_backend(self._paused_frame):
                self._set_state("playing")
            return
        # processedUSecs is cumulative from start(). Rebase so any backend-specific
        # suspended progress cannot move the logical playhead while paused.
        processed = self._processed_frames(self._sink)
        self._epoch_origin_frame = self._paused_frame - processed
        self._sink.resume()
        if _qt_enum_value(self._sink.error()) != _qt_enum_value(QAudio.Error.NoError):
            self._fail_output(f"Could not resume audio output (Qt error {self._sink.error()}).")
            return
        self._set_state("playing")

    def stop(self) -> None:
        self._discard_backend(drain=False)
        if self._audio is not None:
            self._position_frame = 0
            self._paused_frame = 0
            self._set_state("stopped")
        else:
            self._position_frame = 0
            self._paused_frame = 0
            self._set_state("empty")

    def seek(self, seconds: float) -> None:
        if self._audio is None:
            self.error.emit("No audio is loaded.")
            return
        target = float(seconds)
        if not math.isfinite(target):
            raise ValueError("seek time must be finite")
        target = min(self.duration_seconds, max(0.0, target))
        frame = min(len(self._mixed_pcm), max(0, int(round(target * SAMPLE_RATE))))
        prior_state = self._state
        if prior_state == "playing":
            # Snapshot processed PCM, tear down the current epoch and restart at target.
            self._discard_backend(drain=False)
            self._position_frame = frame
            self._paused_frame = frame
            if self._start_backend(frame):
                self._set_state("playing")
            return
        if prior_state == "paused":
            self._discard_backend(drain=False)
            self._paused_frame = frame
            self._position_frame = frame
            return
        self._position_frame = frame
        self._paused_frame = frame

    def set_volume(self, volume: float) -> None:
        value = float(volume)
        if not math.isfinite(value):
            raise ValueError("volume must be finite")
        self._volume = min(1.0, max(0.0, value))
        if self._sink is not None:
            self._sink.setVolume(self._volume)

    def set_clicks(self, times: Iterable[float], enabled: bool, click_gain: float = 0.05) -> None:
        if self._audio is None:
            self._click_times = self._validate_click_times(times)
            self._click_enabled = bool(enabled)
            self._click_gain = self._validate_click_gain(click_gain)
            return
        prior_state = self._state
        frame = self._current_playback_frame() if prior_state == "playing" else self._position_frame
        if prior_state == "paused":
            frame = self._paused_frame
        self._discard_backend(drain=True)
        self._click_times = self._validate_click_times(times)
        self._click_enabled = bool(enabled)
        self._click_gain = self._validate_click_gain(click_gain)
        self._rebuild_mix()
        frame = min(frame, len(self._mixed_pcm))
        self._position_frame = frame
        self._paused_frame = frame
        if prior_state == "playing":
            if self._start_backend(frame):
                self._set_state("playing")
        elif prior_state == "paused":
            self._set_state("paused")

    def position_seconds(self) -> float:
        if self._state == "playing" and self._sink is not None:
            frame = self._current_playback_frame()
        elif self._state == "paused":
            frame = self._paused_frame
        else:
            frame = self._position_frame
        return min(self.duration_seconds, max(0.0, frame / SAMPLE_RATE))

    def close(self) -> None:
        self._discard_backend(drain=False)
        self._audio = None
        self._base_pcm = np.empty((0, CHANNELS), dtype=np.int16)
        self._mixed_pcm = np.empty((0, CHANNELS), dtype=np.int16)
        self._click_times = ()
        self._position_frame = 0
        self._paused_frame = 0
        self._set_state("empty")

    @staticmethod
    def _validate_click_times(times: Iterable[float]) -> tuple[float, ...]:
        result = tuple(float(x) for x in times)
        if any(not math.isfinite(x) for x in result):
            raise ValueError("click times must be finite")
        return result

    @staticmethod
    def _validate_click_gain(gain: float) -> float:
        value = float(gain)
        if not math.isfinite(value) or value < 0.0 or value > 1.0:
            raise ValueError("click_gain must be finite and between 0 and 1")
        return value

    def _rebuild_mix(self) -> None:
        self._mixed_pcm = mix_clicks_pcm(self._base_pcm, SAMPLE_RATE, self._click_times,
                                         self._click_enabled, self._click_gain)

    def _start_backend(self, start_frame: int) -> bool:
        if self._audio is None:
            self.error.emit("No audio is loaded.")
            return False
        frame_count = len(self._mixed_pcm)
        if start_frame >= frame_count:
            self._position_frame = frame_count
            self._paused_frame = frame_count
            self._set_state("stopped")
            self.finished.emit()
            return False
        device = QMediaDevices.defaultAudioOutput()
        if device is None or device.isNull():
            self.error.emit("No default audio output device is available.")
            self._set_state("ready")
            return False
        if not device.isFormatSupported(self._format):
            self.error.emit("The default audio output does not support 48 kHz stereo PCM16.")
            self._set_state("ready")
            return False
        try:
            buffer = QBuffer(self)
            buffer.setData(QByteArray(self._mixed_pcm.tobytes()))
            if not buffer.open(QIODevice.OpenModeFlag.ReadOnly):
                self.error.emit("Could not open the in-memory PCM buffer.")
                self._set_state("ready")
                return False
            byte_offset = int(start_frame) * BYTES_PER_FRAME
            if not buffer.seek(byte_offset):
                buffer.close()
                self.error.emit("Could not seek the in-memory PCM buffer.")
                self._set_state("ready")
                return False
            sink = QAudioSink(device, self._format, self)
            sink.setBufferSize(REQUESTED_AUDIO_BUFFER_BYTES)
            sink.setVolume(self._volume)
            self._sink_generation += 1
            sink.stateChanged.connect(self._on_sink_state)
            self._buffer = buffer
            self._sink = sink
            self._epoch_origin_frame = int(start_frame)
            self._position_frame = int(start_frame)
            sink.start(buffer)
            startup_error = _qt_enum_value(sink.error())
            if startup_error not in (
                _qt_enum_value(QAudio.Error.NoError),
                _qt_enum_value(QAudio.Error.UnderrunError),
            ):
                if self._sink is sink:
                    self._fail_output(f"Could not start audio output (Qt error {sink.error()}).")
                return False
            self._actual_buffer_bytes = int(sink.bufferSize())
            return True
        except Exception as exc:  # Qt multimedia backends can fail during device setup.
            self._discard_backend(drain=False)
            self.error.emit(f"Could not start audio output: {exc}")
            self._set_state("ready")
            return False

    def _current_playback_frame(self) -> int:
        if self._sink is None:
            return self._position_frame
        frame = self._epoch_origin_frame + self._processed_frames(self._sink)
        return min(len(self._mixed_pcm), max(0, frame))

    @staticmethod
    def _processed_frames(sink: QAudioSink) -> int:
        return max(0, int(round(sink.processedUSecs() * SAMPLE_RATE / 1_000_000.0)))

    @Slot()
    def _on_sink_state(self) -> None:
        sink = self.sender()
        self._handle_sink_state(sink, sink.state() if sink is not None else None)

    def _handle_sink_state(self, sink: QAudioSink | None, state: QAudio.State | None) -> None:
        if sink is not self._sink or self._sink is None:
            return
        error_value = _qt_enum_value(sink.error())
        no_error = _qt_enum_value(QAudio.Error.NoError)
        underrun_error = _qt_enum_value(QAudio.Error.UnderrunError)
        if error_value not in (no_error, underrun_error):
            self._fail_output(f"Audio output failed (Qt error {sink.error()}).")
            return
        state_value = _qt_enum_value(state)
        if state_value == _qt_enum_value(QAudio.State.IdleState) and self._state == "playing":
            # Idle means the sink temporarily has no data to read. It can signal an
            # underrun, so only finish after the source and processed clock both end.
            self._finish_if_complete()
            if self._sink is sink and self._source_at_end():
                self._completion_timer.start()
        elif _qt_enum_value(state) == _qt_enum_value(QAudio.State.StoppedState) and self._state == "playing":
            self._position_frame = self._current_playback_frame()
            self._discard_backend(drain=False)
            self._set_state("ready")
            self.error.emit("Audio output stopped before playback completed.")

    def _source_at_end(self) -> bool:
        return self._buffer is not None and self._buffer.atEnd()

    def _finish_if_complete(self) -> bool:
        if self._sink is None or self._state != "playing" or not self._source_at_end():
            return False
        if self._current_playback_frame() < len(self._mixed_pcm):
            return False
        self._position_frame = len(self._mixed_pcm)
        self._paused_frame = self._position_frame
        self._discard_backend(drain=True)
        self._set_state("stopped")
        self.finished.emit()
        return True

    @Slot()
    def _poll_completion(self) -> None:
        if self._sink is None or self._state != "playing":
            self._completion_timer.stop()
            return
        if not self._source_at_end():
            self._completion_timer.stop()
            return
        if self._finish_if_complete():
            self._completion_timer.stop()

    def _fail_output(self, message: str) -> None:
        self._position_frame = self._current_playback_frame()
        self._paused_frame = self._position_frame
        self._discard_backend(drain=False)
        self._set_state("ready" if self._audio is not None else "empty")
        self.error.emit(message)

    def _discard_backend(self, *, drain: bool = False) -> None:
        self._completion_timer.stop()
        self._sink_generation += 1
        sink, self._sink = self._sink, None
        buffer, self._buffer = self._buffer, None
        if sink is not None:
            try:
                if drain:
                    sink.stop()
                else:
                    sink.reset()
            finally:
                sink.deleteLater()
        if buffer is not None:
            buffer.close()
            buffer.deleteLater()

    def _set_state(self, state: str) -> None:
        if self._state == state:
            return
        self._state = state
        self.stateChanged.emit(state)
