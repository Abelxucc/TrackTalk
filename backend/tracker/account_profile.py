import base64
import re
from io import BytesIO

from PIL import Image, ImageOps
from django.db import IntegrityError
from django.views.decorators.cache import never_cache
from rest_framework import serializers, status
from rest_framework.authentication import TokenAuthentication
from rest_framework.decorators import (
    api_view, authentication_classes, parser_classes, permission_classes,
)
from rest_framework.parsers import JSONParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import AccountProfile


class ProfileFieldsSerializer(serializers.Serializer):
    phone_number = serializers.CharField(max_length=40, allow_blank=True, default="")
    gender = serializers.ChoiceField(choices=AccountProfile.Gender.choices, required=False)
    height_cm = serializers.DecimalField(
        max_digits=5, decimal_places=2, coerce_to_string=True,
        min_value=30, max_value=300, required=False,
    )
    weight_kg = serializers.DecimalField(
        max_digits=5, decimal_places=2, coerce_to_string=True,
        min_value=1, max_value=500, required=False,
    )
    age = serializers.IntegerField(min_value=1, max_value=120, required=False)

    def validate_phone_number(self, value):
        if not value:
            return ""
        # Accept readable formatting, but store only a leading + and digits.
        if not re.fullmatch(r"[+0-9 ()\-.]+", value):
            raise serializers.ValidationError("Enter a valid phone number.")
        normalized = re.sub(r"[ ()\-.]", "", value)
        if not re.fullmatch(r"\+?[0-9]{7,15}", normalized):
            raise serializers.ValidationError("Use 7 to 15 digits, with an optional country code.")
        return normalized


class ProfilePhotoField(serializers.Field):
    max_bytes = 1024 * 1024
    max_pixels = 16_000_000
    formats = ("JPEG", "PNG", "WEBP")
    default_error_messages = {
        "invalid": "Choose a JPEG, PNG, or WebP photo.",
        "too_large": "Choose a smaller photo (up to 1 MB).",
        "too_many_pixels": "Choose a photo with a lower resolution.",
    }

    def to_internal_value(self, data):
        if not isinstance(data, str) or not data:
            self.fail("invalid")
        if len(data) > 4 * ((self.max_bytes + 2) // 3):
            self.fail("too_large")
        try:
            contents = base64.b64decode(data, validate=True)
        except ValueError:
            self.fail("invalid")
        if len(contents) > self.max_bytes:
            self.fail("too_large")

        try:
            with Image.open(BytesIO(contents), formats=self.formats) as image:
                if image.width * image.height > self.max_pixels:
                    self.fail("too_many_pixels")
                ImageOps.exif_transpose(image, in_place=True)
                cropped = ImageOps.fit(image.convert("RGB"), (320, 320))
                with BytesIO() as output:
                    cropped.save(output, "JPEG", quality=85)
                    return output.getvalue()
        except Image.DecompressionBombError:
            self.fail("too_many_pixels")
        except (OSError, ValueError, SyntaxError):
            self.fail("invalid")

    def to_representation(self, value):
        return base64.b64encode(value).decode("ascii") if value else None


class AccountProfileSerializer(ProfileFieldsSerializer):
    name = serializers.CharField(max_length=80, allow_blank=True, required=False)
    photo = ProfilePhotoField(required=False)


@never_cache
@api_view(["GET", "PATCH"])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAuthenticated])
@parser_classes([JSONParser])
def account_profile(request):
    profile = AccountProfile.objects.filter(user=request.user).first()
    if request.method == "GET":
        return Response(AccountProfileSerializer(profile or AccountProfile()).data)

    serializer = AccountProfileSerializer(data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    unknown_fields = request.data.keys() - serializer.fields.keys()
    if unknown_fields:
        raise serializers.ValidationError({
            field: ["This field cannot be updated."] for field in sorted(unknown_fields)
        })
    updates = serializer.validated_data
    if not updates:
        return Response(AccountProfileSerializer(profile or AccountProfile()).data)

    if profile is None:
        email = request.user.email.strip().lower()
        if not email:
            return Response(
                {"detail": "A sign-in email is required to save your profile."},
                status=status.HTTP_409_CONFLICT,
            )
        try:
            profile, created = AccountProfile.objects.get_or_create(
                user=request.user, defaults={"email": email, **updates},
            )
        except IntegrityError:
            return Response(
                {"detail": "Could not create a profile for this account."},
                status=status.HTTP_409_CONFLICT,
            )
        if created:
            return Response(AccountProfileSerializer(profile).data)

    # Update only supplied fields, so concurrent edits to other fields survive.
    for field, value in updates.items():
        setattr(profile, field, value)
    profile.save(update_fields=updates)
    profile.refresh_from_db(fields=serializer.fields)
    return Response(AccountProfileSerializer(profile).data)
