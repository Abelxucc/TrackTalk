from datetime import date, datetime, timezone
from unittest.mock import patch
from urllib.error import HTTPError

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from rest_framework.test import APIClient

from .models import ActivityRecord, FoodEntry, FoodRecord


class FoodAITests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.user = get_user_model().objects.create_user(username="tester")
        self.client.force_authenticate(self.user)
        self.parse_url = "/api/food-records/parse/"
        self.allergies_url = "/api/food-allergies/"
        self.week_url = "/api/food-recommendations/?date=2026-07-08"
        self.payload = {"text": "Porridge with milk for breakfast", "reference_date": "2026-07-08"}

    def test_endpoints_require_login(self):
        anonymous = APIClient()
        self.assertEqual(anonymous.post(self.parse_url, self.payload, format="json").status_code, 401)
        self.assertEqual(anonymous.get(self.week_url).status_code, 401)
        self.assertEqual(anonymous.get(self.allergies_url).status_code, 401)
        self.assertEqual(anonymous.put(self.allergies_url, {}, format="json").status_code, 401)

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_draft_leaves_missing_time_and_amount_empty_without_saving(self, ask):
        ask.return_value = {
            "status": "draft", "meal_type": "breakfast", "date": None, "time": None,
            "items": [
                {"name": "Porridge", "quantity": 1, "unit": "bowl"},
                {"name": "Milk", "quantity": None, "unit": ""},
            ],
        }
        result = self.client.post(self.parse_url, self.payload, format="json")
        self.assertEqual(result.status_code, 200, result.data)
        self.assertEqual(result.data["date"], "2026-07-08")
        self.assertIsNone(result.data["time"])
        self.assertIsNone(result.data["items"][1]["quantity"])
        self.assertFalse(FoodRecord.objects.exists())

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_explicit_portion_is_recovered_if_model_omits_it(self, ask):
        for text, name, quantity, unit in [
            ("I had a bowl of porridge with milk for breakfast", "porridge", "1.00", "bowl"),
            ("For breakfast, I ate two slices of toast with milk", "toast", "2.00", "slices"),
            ("I had half a bowl of porridge with milk", "porridge", "0.50", "bowl"),
        ]:
            with self.subTest(text=text):
                ask.return_value = {
                    "status": "draft", "meal_type": "breakfast", "date": None, "time": None,
                    "items": [
                        {"name": name, "quantity": None, "unit": ""},
                        {"name": "milk", "quantity": None, "unit": ""},
                    ],
                }
                result = self.client.post(self.parse_url, {**self.payload, "text": text}, format="json")
                self.assertEqual(result.status_code, 200, result.data)
                food, milk = result.data["items"]
                self.assertEqual((food["quantity"], food["unit"]), (quantity, unit))
                self.assertEqual((milk["quantity"], milk["unit"]), (None, ""))
        self.assertFalse(FoodRecord.objects.exists())

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_invalid_model_payload_cannot_be_saved(self, ask):
        ask.return_value = {
            "status": "draft", "meal_type": "breakfast", "date": None, "time": None,
            "items": [{"name": "Porridge", "quantity": -1, "unit": "bowl"}],
        }
        result = self.client.post(self.parse_url, self.payload, format="json")
        self.assertEqual(result.status_code, 400, result.data)
        self.assertFalse(FoodEntry.objects.exists())

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_activity_input_produces_a_draft_for_either_tab(self, ask):
        for mode, duration in [("food", 30), ("activity", None)]:
            with self.subTest(mode=mode):
                ask.return_value = {
                    "status": "activity", "date": None, "time": "08:15",
                    "activity_name": "Jogging", "duration_minutes": duration,
                    "items": [], "meal_type": None,
                }
                payload = {**self.payload, "text": "I went jogging", "mode": mode}
                result = self.client.post(self.parse_url, payload, format="json")
                self.assertEqual(result.status_code, 200, result.data)
                self.assertEqual(result.data, {
                    "kind": "activity", "activity_name": "Jogging",
                    "duration_minutes": duration, "date": "2026-07-08", "time": "08:15",
                })
        self.assertFalse(ActivityRecord.objects.exists())

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_food_input_in_activity_mode_produces_a_food_draft(self, ask):
        ask.return_value = {
            "status": "draft", "meal_type": "afternoon_tea", "date": None, "time": None,
            "items": [{"name": "Bubble tea", "quantity": 1, "unit": "cup"}],
        }
        result = self.client.post(self.parse_url, {
            **self.payload, "text": "I had one cup of bubble tea for afternoon tea", "mode": "activity",
        }, format="json")
        self.assertEqual(result.status_code, 200, result.data)
        self.assertEqual(result.data["meal_type"], "afternoon_tea")
        self.assertEqual(result.data["items"][0]["name"], "Bubble tea")
        self.assertFalse(FoodRecord.objects.exists())

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_invalid_activity_duration_is_rejected(self, ask):
        ask.return_value = {
            "status": "activity", "date": None, "time": None,
            "activity_name": "Jogging", "duration_minutes": 0,
        }
        result = self.client.post(self.parse_url, {**self.payload, "mode": "food"}, format="json")
        self.assertEqual(result.status_code, 400, result.data)
        self.assertFalse(ActivityRecord.objects.exists())

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai.urlopen")
    def test_openai_authentication_failure_reports_server_key_problem(self, request):
        request.side_effect = HTTPError(
            "https://api.openai.com/v1/responses", 401, "Unauthorized", None, None,
        )
        result = self.client.post(self.parse_url, self.payload, format="json")
        self.assertEqual(result.status_code, 503, result.data)
        self.assertIn("Check the API key", result.data["detail"])
        self.assertFalse(FoodRecord.objects.exists())

    def _record(self, user, timestamp, name):
        record = FoodRecord.objects.create(user=user, eaten_at=timestamp, meal_type="dinner")
        FoodEntry.objects.create(record=record, eaten_at=timestamp, name=name)

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_week_uses_owned_uk_week_and_caches_grounded_tip(self, ask):
        other = get_user_model().objects.create_user(username="other")
        in_week = datetime(2026, 7, 5, 23, 30, tzinfo=timezone.utc)
        self._record(self.user, in_week, "Chicken")
        self._record(self.user, datetime(2026, 7, 5, 22, 59, tzinfo=timezone.utc), "Apple")
        self._record(other, in_week, "Chickpeas")
        ask.return_value = {"tip_id": "lentils"}
        result = self.client.get(self.week_url)
        self.assertEqual(result.status_code, 200, result.data)
        self.assertEqual(result.data["days_logged"], 1)
        groups = {group["label"]: group["foods"] for group in result.data["groups"]}
        self.assertEqual(groups["Protein foods"], ["Chicken"])
        self.assertEqual(groups["Fruit & vegetables"], [])
        self.assertIn("lentils", result.data["recommendation"]["body"])
        self.assertEqual(self.client.get(self.week_url).data, result.data)
        ask.assert_called_once()

    @patch.dict("os.environ", {"OPENAI_API_KEY": ""})
    def test_week_with_logs_has_guide_tip_even_without_a_key(self):
        self._record(self.user, datetime(2026, 7, 8, 12, tzinfo=timezone.utc), "Chicken")
        week = self.client.get(self.week_url)
        self.assertEqual(week.status_code, 200)
        self.assertIn("nhs.uk", week.data["recommendation"]["source_url"])
        self.assertEqual(self.client.post(self.parse_url, self.payload, format="json").status_code, 503)

    @patch.dict("os.environ", {"OPENAI_API_KEY": ""})
    def test_recommendation_rolls_at_uk_midnight(self):
        url = "/api/food-recommendations/"
        self._record(self.user, datetime(2026, 6, 28, 23, tzinfo=timezone.utc), "Chickpeas")
        self._record(self.user, datetime(2026, 7, 5, 22, 59, tzinfo=timezone.utc), "Chicken")
        self._record(self.user, datetime(2026, 7, 6, 23, tzinfo=timezone.utc), "Lentils")

        with patch("tracker.food_ai.timezone.now",
                   return_value=datetime(2026, 7, 5, 22, 59, tzinfo=timezone.utc)):
            sunday = self.client.get(url)
        self.assertEqual(sunday.data["week_start"], date(2026, 6, 29))
        self.assertIn("apple", sunday.data["recommendation"]["body"])

        with patch("tracker.food_ai.timezone.now",
                   return_value=datetime(2026, 7, 5, 23, tzinfo=timezone.utc)):
            monday = self.client.get(url)
        self.assertEqual(monday.data["week_start"], date(2026, 7, 6))
        groups = {group["label"]: group["foods"] for group in monday.data["groups"]}
        self.assertEqual(groups["Protein foods"], ["Lentils"])
        self.assertEqual(monday.data["recommendation"]["title"], "No pulses logged in the last 7 days")
        self.assertEqual(FoodRecord.objects.filter(user=self.user).count(), 3)

    def test_allergy_settings_validate_and_save_by_user_without_an_account_profile(self):
        empty = self.client.get(self.allergies_url)
        self.assertEqual(empty.status_code, 200, empty.data)
        self.assertEqual(len(empty.data["options"]), 14)
        self.assertEqual(empty.data["allergen_ids"], [])
        self.assertEqual(empty.data["other_foods"], [])

        saved = self.client.put(self.allergies_url, {
            "allergen_ids": ["milk", "milk", "sesame"],
            "other_foods": ["  Red   lentils ", "RED LENTILS", "Kiwifruit"],
        }, format="json")
        self.assertEqual(saved.status_code, 200, saved.data)
        self.assertEqual(saved.data["allergen_ids"], ["milk", "sesame"])
        self.assertEqual(saved.data["other_foods"], ["Red lentils", "Kiwifruit"])

        invalid = self.client.put(self.allergies_url, {
            "allergen_ids": ["unknown"],
            "other_foods": ["..."],
        }, format="json")
        self.assertEqual(invalid.status_code, 400, invalid.data)
        self.assertEqual(self.client.get(self.allergies_url).data, saved.data)

        another = APIClient()
        another.force_authenticate(get_user_model().objects.create_user(username="another"))
        self.assertEqual(another.get(self.allergies_url).data, empty.data)

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_saved_allergies_filter_cached_candidates_and_reject_an_excluded_ai_choice(self, ask):
        self._record(self.user, datetime(2026, 7, 8, 12, tzinfo=timezone.utc), "Chicken")
        ask.return_value = {"tip_id": "chickpeas"}
        self.assertIn("chickpeas", self.client.get(self.week_url).data["recommendation"]["body"])

        saved = self.client.put(self.allergies_url, {
            "allergen_ids": ["gluten_cereals"],
            "other_foods": ["Garbanzo beans"],
        }, format="json")
        self.assertEqual(saved.status_code, 200, saved.data)

        refreshed = self.client.get(self.week_url)
        self.assertIn("lentils", refreshed.data["recommendation"]["body"])
        candidates = ask.call_args.args[3]["candidates"]
        self.assertNotIn("chickpeas", candidates)
        self.assertNotIn("oats", candidates)
        self.assertIn("brown_rice", candidates)
        self.assertEqual(ask.call_count, 2)

    @patch.dict("os.environ", {"OPENAI_API_KEY": ""})
    def test_missing_ai_uses_only_unexcluded_tips_and_can_return_no_tip(self):
        stamp = datetime(2026, 7, 8, 12, tzinfo=timezone.utc)
        self._record(self.user, stamp, "Chicken")
        self._record(self.user, stamp, "Carrots")
        foods_to_avoid = ["All pulses", "Fruit", "Vegetables", "Rice"]
        settings = {"allergen_ids": ["gluten_cereals"], "other_foods": foods_to_avoid}
        self.assertEqual(self.client.put(self.allergies_url, settings, format="json").status_code, 200)

        blocked = self.client.get(self.week_url)
        self.assertIsNone(blocked.data["recommendation"])
        self.assertEqual(blocked.data["recommendation_message"], "No food ideas match your allergy settings.")
        groups = {group["label"]: group["foods"] for group in blocked.data["groups"]}
        self.assertEqual(groups["Fruit & vegetables"], ["Carrots"])

        settings["other_foods"] = foods_to_avoid[:-1]
        self.assertEqual(self.client.put(self.allergies_url, settings, format="json").status_code, 200)
        self.assertIn("brown rice", self.client.get(self.week_url).data["recommendation"]["body"])

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_an_allergy_saved_while_ai_is_selecting_a_tip_is_applied_to_the_response(self, ask):
        self._record(self.user, datetime(2026, 7, 8, 12, tzinfo=timezone.utc), "Chicken")

        def save_allergy(*_, **_kwargs):
            response = self.client.put(self.allergies_url, {
                "allergen_ids": [],
                "other_foods": ["Red Lentil"],
            }, format="json")
            self.assertEqual(response.status_code, 200, response.data)
            return {"tip_id": "lentils"}

        ask.side_effect = save_allergy
        week = self.client.get(self.week_url)
        self.assertIn("chickpeas", week.data["recommendation"]["body"])
