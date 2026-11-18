import io
import json
import wave
from email import policy
from email.parser import BytesParser
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from rest_framework.test import APIClient

from .food_ai import FoodAIUnavailable
from .models import ActivityRecord, FoodRecord
from .voice_ai import _clean_transcript


def _wav_upload():
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as audio:
        audio.setparams((1, 2, 16000, 0, "NONE", "not compressed"))
        audio.writeframes(b"\x00\x00" * 8000)
    return SimpleUploadedFile("recording.wav", buffer.getvalue(), content_type="audio/wav")


class VoiceAITests(TestCase):
    url = "/api/food-records/transcribe/"

    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.client.force_authenticate(get_user_model().objects.create_user(username="speaker"))

    def test_requires_login(self):
        response = APIClient().post(self.url, {"audio": _wav_upload()}, format="multipart")
        self.assertEqual(response.status_code, 401)

    @patch("tracker.voice_ai._transcribe")
    def test_rejects_invalid_or_oversized_audio_before_calling_ai(self, transcribe):
        for content in (b"not a recording", b"0" * 960045):
            with self.subTest(size=len(content)):
                response = self.client.post(
                    self.url, {"audio": SimpleUploadedFile("clip.wav", content)}, format="multipart",
                )
                self.assertEqual(response.status_code, 400)
        transcribe.assert_not_called()

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.voice_ai._ask")
    @patch("tracker.voice_ai.urlopen")
    def test_sends_wav_for_transcription_and_returns_clean_text_without_saving(self, send, ask):
        raw = "Um, I had a bowl of porridge, I had a bowl of porridge for breakfast."
        clean = "I had a bowl of porridge for breakfast."
        upload = _wav_upload()
        audio_bytes = upload.read()
        upload.seek(0)
        send.return_value = io.BytesIO(json.dumps({"text": raw}).encode())
        ask.return_value = {"text": clean}

        response = self.client.post(self.url, {"audio": upload}, format="multipart")

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data, {"text": clean})
        self.assertEqual(ask.call_args.args[3], {"text": raw})
        request = send.call_args.args[0]
        self.assertEqual(request.full_url, "https://api.openai.com/v1/audio/transcriptions")
        self.assertEqual(request.get_header("Authorization"), "Bearer test-key")
        content_type = request.get_header("Content-type")
        form = BytesParser(policy=policy.default).parsebytes(
            f"Content-Type: {content_type}\r\n\r\n".encode() + request.data
        )
        fields = {
            part.get_param("name", header="content-disposition"): part.get_payload(decode=True)
            for part in form.iter_parts()
        }
        self.assertEqual(fields["model"], b"gpt-transcribe")
        self.assertEqual(fields["file"], audio_bytes)
        self.assertFalse(FoodRecord.objects.exists())
        self.assertFalse(ActivityRecord.objects.exists())

    @patch("tracker.voice_ai._transcribe", return_value="Um, ah.")
    @patch("tracker.voice_ai._ask")
    def test_empty_speech_is_not_sent_for_cleanup(self, ask, _):
        response = self.client.post(self.url, {"audio": _wav_upload()}, format="multipart")
        self.assertEqual(response.status_code, 400)
        self.assertIn("No speech detected", response.data["detail"])
        ask.assert_not_called()

    @patch("tracker.voice_ai._ask")
    def test_cleanup_preserves_quantities_durations_and_distinct_portions(self, ask):
        for original, unsafe_cleanup in [
            ("I had 150 grams of chicken.", "I had chicken."),
            ("I walked for 35 minutes.", "I walked for 30 minutes."),
            (
                "I had one slice of toast and then another slice of toast.",
                "I had one slice of toast and then another.",
            ),
            ("I didn't eat peanuts.", "I did eat peanuts."),
        ]:
            with self.subTest(original=original):
                ask.return_value = {"text": unsafe_cleanup}
                self.assertEqual(_clean_transcript(original), original)

    @patch("tracker.voice_ai._ask", side_effect=FoodAIUnavailable)
    @patch("tracker.voice_ai._transcribe", return_value="I walked for 35 minutes.")
    def test_returns_original_transcript_when_cleanup_is_unavailable(self, _, __):
        response = self.client.post(self.url, {"audio": _wav_upload()}, format="multipart")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data, {"text": "I walked for 35 minutes."})
