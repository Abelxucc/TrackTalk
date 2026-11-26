import base64
from decimal import Decimal
from io import BytesIO

from PIL import Image
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from .models import AccountProfile


class AccountProfileTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        user_model = get_user_model()
        cls.owner = user_model.objects.create_user(
            username="profile-owner", email="Owner@Example.com",
        )
        cls.other = user_model.objects.create_user(
            username="another-user", email="other@example.com",
        )
        cls.other_profile = AccountProfile.objects.create(
            user=cls.other, email=cls.other.email, age=61,
        )
        cls.token = Token.objects.create(user=cls.owner)

    def setUp(self):
        self.url = reverse("account_profile")
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {self.token.key}")

    def test_requires_token_for_read_and_write(self):
        anonymous = APIClient()
        self.assertEqual(anonymous.get(self.url).status_code, 401)
        self.assertEqual(anonymous.patch(self.url, {"age": 26}, format="json").status_code, 401)
        anonymous.credentials(HTTP_AUTHORIZATION="Token invalid")
        self.assertEqual(anonymous.get(self.url).status_code, 401)

    def test_legacy_read_and_empty_patch_leave_profile_uncreated(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {
            "phone_number": "", "gender": "", "height_cm": None,
            "weight_kg": None, "age": None, "name": "", "photo": None,
        })
        self.assertIn("no-store", response.headers["Cache-Control"])
        empty_patch = self.client.patch(self.url, {}, format="json")
        self.assertEqual(empty_patch.status_code, 200)
        self.assertEqual(empty_patch.json(), response.json())
        self.assertFalse(AccountProfile.objects.filter(user=self.owner).exists())

    def test_patch_creates_legacy_profile_with_supplied_fields_and_returns_all_values(self):
        updates = {
            "gender": "non_binary", "age": 29, "phone_number": "+44 (7700) 900123",
            "height_cm": "172.5", "weight_kg": "68.25",
        }
        result = self.client.patch(self.url, updates, format="json")
        self.assertEqual(result.status_code, 200, result.data)
        expected = {
            **updates, "phone_number": "+447700900123", "height_cm": "172.50",
            "name": "", "photo": None,
        }
        self.assertEqual(result.json(), expected)
        owner_profile = AccountProfile.objects.get(user=self.owner)
        self.assertEqual(owner_profile.email, "owner@example.com")
        self.assertEqual(owner_profile.height_cm, Decimal("172.50"))
        self.assertEqual(self.client.get(self.url).json(), expected)
        self.other_profile.refresh_from_db()
        self.assertEqual(self.other_profile.age, 61)

    def test_partial_patch_preserves_other_values_and_can_clear_phone(self):
        profile = AccountProfile.objects.create(
            user=self.owner, email=self.owner.email, age=29, gender="female",
            phone_number="+447700900123", height_cm="172.50",
        )
        result = self.client.patch(self.url, {"phone_number": "", "age": 30}, format="json")
        self.assertEqual(result.status_code, 200, result.data)
        self.assertEqual(result.json(), {
            "phone_number": "", "gender": "female", "height_cm": "172.50",
            "weight_kg": None, "age": 30, "name": "", "photo": None,
        })
        profile.refresh_from_db()
        self.assertEqual(profile.phone_number, "")
        self.assertEqual(profile.age, 30)
        self.assertEqual(profile.gender, "female")

    def test_name_and_photo_save_together_and_rejected_photo_leaves_both_intact(self):
        with BytesIO() as image_file:
            Image.new("RGB", (640, 480), "green").save(image_file, "PNG")
            photo = base64.b64encode(image_file.getvalue()).decode("ascii")

        saved = self.client.patch(self.url, {"name": "  Alex 陈  ", "photo": photo}, format="json")
        self.assertEqual(saved.status_code, 200, saved.data)
        self.assertEqual(saved.data["name"], "Alex 陈")
        with Image.open(BytesIO(base64.b64decode(saved.data["photo"]))) as avatar:
            self.assertEqual(avatar.format, "JPEG")
            self.assertEqual(avatar.size, (320, 320))

        invalid_photo = base64.b64encode(b"not an image").decode("ascii")
        failed = self.client.patch(self.url, {"name": "New name", "photo": invalid_photo}, format="json")
        self.assertEqual(failed.status_code, 400, failed.data)
        self.assertIn("photo", failed.data)
        self.assertEqual(self.client.get(self.url).json(), saved.json())

    def test_invalid_fields_and_account_changes_are_rejected_before_saving(self):
        profile = AccountProfile.objects.create(user=self.owner, email=self.owner.email, age=29)
        for field, value in [
            ("weight_kg", "501"), ("height_cm", "172.123"), ("gender", "invalid"),
            ("phone_number", "+123"), ("age", 29.5),
            ("user", self.other.pk), ("email", self.other.email), ("password", "bad"),
        ]:
            with self.subTest(field=field):
                payload = {"phone_number": "+447700900123", "age": 30, field: value}
                result = self.client.patch(self.url, payload, format="json")
                self.assertEqual(result.status_code, 400, result.data)
                self.assertIn(field, result.data)
        profile.refresh_from_db()
        self.other_profile.refresh_from_db()
        self.assertEqual(profile.phone_number, "")
        self.assertEqual(profile.age, 29)
        self.assertEqual(profile.email, self.owner.email)
        self.assertEqual(self.other_profile.age, 61)

    def test_legacy_account_cannot_claim_another_profiles_email(self):
        self.owner.email = self.other.email.upper()
        self.owner.save(update_fields=["email"])
        result = self.client.patch(self.url, {"age": 29}, format="json")
        self.assertEqual(result.status_code, 409, result.data)
        self.assertFalse(AccountProfile.objects.filter(user=self.owner).exists())
        self.other_profile.refresh_from_db()
        self.assertEqual(self.other_profile.age, 61)

    def test_account_without_a_sign_in_email_cannot_create_profile(self):
        self.owner.email = ""
        self.owner.save(update_fields=["email"])
        result = self.client.patch(self.url, {"age": 29}, format="json")
        self.assertEqual(result.status_code, 409, result.data)
        self.assertFalse(AccountProfile.objects.filter(user=self.owner).exists())
