"""Tests for the TTS pipeline.

These tests do NOT require piper-tts or sounddevice installed.
They verify the pipeline's state management and API contracts.
"""

import struct
import wave
from unittest import mock

import numpy as np

from aside.tts import TTSPipeline


class TestConstruction:
    """TTSPipeline can be created without loading piper."""

    def test_default_construction(self):
        p = TTSPipeline()
        assert p._model_path == TTSPipeline._DEFAULT_MODEL
        assert p._speed == 1.0
        assert p._voice is None  # piper not loaded

    def test_custom_construction(self):
        p = TTSPipeline(model="/tmp/voice.onnx", speed=1.5)
        assert p._model_path == "/tmp/voice.onnx"
        assert p._speed == 1.5
        assert p._voice is None

    def test_rhvoice_construction(self):
        p = TTSPipeline(backend="rhvoice", voice="vitaliy-ng", rate=115, pitch=95)
        assert p._backend == "rhvoice"
        assert p._voice_name == "vitaliy-ng"
        assert p._rate == 115
        assert p._pitch == 95


class TestUpdateConfig:
    """update_config changes internal state."""

    def test_updates_speed(self):
        p = TTSPipeline()
        p.update_config(model="", speed=1.5)
        assert p._speed == 1.5

    def test_model_change_clears_voice(self):
        p = TTSPipeline()
        p._voice = "fake-loaded-voice"
        p.update_config(model="/tmp/new.onnx", speed=1.0)
        assert p._model_path == "/tmp/new.onnx"
        assert p._voice is None  # cleared for reload

    def test_same_model_keeps_voice(self):
        p = TTSPipeline(model="/tmp/voice.onnx")
        p._voice = "fake-loaded-voice"
        p.update_config(model="/tmp/voice.onnx", speed=1.5)
        assert p._voice == "fake-loaded-voice"  # not cleared

    def test_backend_change_resets_loaded_state(self):
        p = TTSPipeline(backend="piper")
        p._voice = "fake-loaded-voice"
        p.update_config(model="", speed=1.0, backend="rhvoice", voice="aleksandr-hq")
        assert p._backend == "rhvoice"
        assert p._voice_name == "aleksandr-hq"
        assert p._voice is None
        assert p._rhvoice_ready is False


class TestRHVoiceBackend:
    def test_clamp_percent(self):
        assert TTSPipeline._clamp_percent(1) == 20
        assert TTSPipeline._clamp_percent(120) == 120
        assert TTSPipeline._clamp_percent(999) == 300

    @mock.patch("aside.tts.shutil.which")
    def test_ensure_loaded_requires_rhvoice_test(self, mock_which):
        mock_which.return_value = None
        p = TTSPipeline(backend="rhvoice")
        try:
            p._ensure_loaded()
        except ImportError as exc:
            assert "RHVoice-test" in str(exc)
        else:
            raise AssertionError("expected ImportError")

    @mock.patch("aside.tts.shutil.which")
    def test_ensure_loaded_accepts_rhvoice_test(self, mock_which):
        mock_which.return_value = "/usr/bin/RHVoice-test"
        p = TTSPipeline(backend="rhvoice", voice="vitaliy-ng")
        p._ensure_loaded()
        assert p._rhvoice_ready is True
        assert p._rhvoice_cmd == "/usr/bin/RHVoice-test"

    @mock.patch("aside.tts.subprocess.run")
    def test_rhvoice_synthesis_reads_wav(self, mock_run, tmp_path):
        def fake_run(cmd, input, text, stdout, stderr, check):
            out_path = cmd[cmd.index("-o") + 1]
            with wave.open(out_path, "wb") as wav:
                wav.setnchannels(1)
                wav.setsampwidth(2)
                wav.setframerate(24000)
                wav.writeframes(struct.pack("<hhh", 0, 16384, -16384))
            return mock.Mock(returncode=0, stderr="")

        mock_run.side_effect = fake_run
        p = TTSPipeline(backend="rhvoice", voice="vitaliy-ng", speed=1.2, rate=100)
        p._rhvoice_cmd = "/usr/bin/RHVoice-test"
        p._sample_rate = 24000

        audio = p._synthesize_rhvoice("Привет")

        assert isinstance(audio, np.ndarray)
        assert audio.dtype == np.float32
        assert audio.shape == (3,)
        cmd = mock_run.call_args.args[0]
        assert cmd[:4] == ["/usr/bin/RHVoice-test", "-p", "vitaliy-ng", "-o"]
        assert "-r" in cmd
        assert cmd[cmd.index("-r") + 1] == "120"


class TestRunningFlag:
    """_running starts as False."""

    def test_initial_state(self):
        p = TTSPipeline()
        assert p._running is False

    def test_threads_not_created(self):
        p = TTSPipeline()
        assert p._synth_thread is None
        assert p._play_thread is None


class TestSafeWhenNotStarted:
    """speak/stop/finish don't crash when pipeline is not started."""

    def test_speak_noop(self):
        p = TTSPipeline()
        p.speak("Hello world")  # should not raise

    def test_stop_noop(self):
        p = TTSPipeline()
        p.stop()  # should not raise

    def test_finish_noop(self):
        p = TTSPipeline()
        p.finish()  # should not raise

    def test_wait_done_returns_immediately(self):
        p = TTSPipeline()
        result = p.wait_done(timeout=1)
        assert result is True  # no thread to wait for
